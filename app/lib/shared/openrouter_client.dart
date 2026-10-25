import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'http_client.dart';

/// Public catalog metadata. Instances do not authorize dispatch: the client
/// checks its own most recently validated catalog at the transport boundary.
class OpenRouterModel {
  const OpenRouterModel({
    required this.id,
    required this.name,
    required this.contextLength,
    this.supportsMaxTokens = false,
    this.providerTags = const [],
  });
  final String id;
  final String name;
  final int contextLength;
  final bool supportsMaxTokens;
  final List<String> providerTags;
}

class OpenRouterMessage {
  const OpenRouterMessage({required this.role, required this.content});
  final String role;
  final String content;
  Map<String, String> toJson() => {'role': role, 'content': content};
}

/// Safe local messages only: upstream response bodies may echo credentials or
/// conversations and are deliberately never exposed as diagnostics.
class OpenRouterFailure implements Exception {
  const OpenRouterFailure(this.code, this.message, {this.retryAfter});
  final String code;
  final String message;
  final Duration? retryAfter;
  @override
  String toString() => message;
}

/// [text] is cumulative, including on failure/cancellation. Only [done] without
/// [failure] can be considered for validated application to deterministic state.
class OpenRouterUpdate {
  const OpenRouterUpdate({
    required this.text,
    this.done = false,
    this.failure,
    this.finishReason,
  });
  final String text;
  final bool done;
  final OpenRouterFailure? failure;
  final String? finishReason;
}

class OpenRouterCancellation {
  final _listeners = <void Function()>[];
  bool _cancelled = false;
  bool get isCancelled => _cancelled;

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    for (final listener in List.of(_listeners)) {
      listener();
    }
    _listeners.clear();
  }

  void Function() _listen(void Function() listener) {
    if (_cancelled) {
      listener();
      return () {};
    }
    _listeners.add(listener);
    return () => _listeners.remove(listener);
  }
}

/// Browser-only production use needs no application server. Keys and catalog
/// authorization stay in this object, never storage, URLs or worker caches.
/// No automatic retry, model/provider fallback, probe, or conversation replay.
class OpenRouterClient {
  OpenRouterClient({
    required bool Function() isOnline,
    http.Client Function()? clientFactory,
    DateTime Function()? now,
    this.catalogLifetime = const Duration(minutes: 30),
    this.firstOutputTimeout = const Duration(seconds: 90),
    this.idleTimeout = const Duration(seconds: 45),
    this.overallTimeout = const Duration(seconds: 300),
    this.catalogTimeout = const Duration(seconds: 30),
    this.maxResponseChars = 100000,
  }) : _isOnline = isOnline,
       _clientFactory = clientFactory ?? createHttpClient,
       _now = now ?? DateTime.now;

  final bool Function() _isOnline;
  final http.Client Function() _clientFactory;
  final DateTime Function() _now;
  final Duration catalogLifetime;
  final Duration firstOutputTimeout;
  final Duration idleTimeout;
  final Duration overallTimeout;
  final Duration catalogTimeout;
  final int maxResponseChars;
  String _key = '';
  bool _disposed = false;
  List<OpenRouterModel> _models = const [];
  DateTime? _catalogAt;
  DateTime? _retryAt;
  _Completion? _active;
  Future<List<OpenRouterModel>>? _catalogRequest;
  http.Client? _catalogTransport;

  bool get hasApiKey => _key.isNotEmpty;
  List<OpenRouterModel> get models => _models;
  bool get catalogFresh =>
      _catalogAt != null &&
      !_now().isBefore(_catalogAt!) &&
      _now().difference(_catalogAt!) < catalogLifetime;

  void setApiKey(String value) {
    final trimmed = value.trim();
    if (trimmed.length > 512 || RegExp(r'[\x00-\x20\x7f]').hasMatch(trimmed)) {
      throw const OpenRouterFailure('key', 'Enter a valid OpenRouter API key.');
    }
    if (_disposed) return;
    if (trimmed != _key) {
      _active?.fail(
        const OpenRouterFailure(
          'cancelled',
          'The key changed. Received text is kept.',
        ),
      );
      _key = trimmed;
    }
  }

  void clearApiKey() => setApiKey('');

  Future<List<OpenRouterModel>> refreshCatalog() {
    if (_catalogRequest != null) return _catalogRequest!;
    final request = _refreshCatalog();
    _catalogRequest = request;
    return request.whenComplete(() => _catalogRequest = null);
  }

  Future<List<OpenRouterModel>> _refreshCatalog() async {
    // Failed refreshes preserve display data, but invalidate dispatch permission.
    _catalogAt = null;
    if (_disposed || !_isOnline()) {
      throw const OpenRouterFailure(
        'offline',
        'Connect to refresh the available AI models.',
      );
    }
    final transport = _clientFactory();
    _catalogTransport = transport;
    final abort = Completer<void>();
    try {
      final result = await (() async {
        final catalog = await _readPublicCatalog(
          transport,
          '/api/v1/models',
          abort.future,
        );
        final endpoints = await _readPublicCatalog(
          transport,
          '/api/v1/endpoints/zdr',
          abort.future,
        );
        final accepted = <String, OpenRouterModel>{};
        final seenIds = <String>{};
        final duplicateIds = <String>{};
        for (final value in catalog) {
          if (value is Map &&
              value['id'] is String &&
              !seenIds.add(value['id'] as String)) {
            duplicateIds.add(value['id'] as String);
          }
          final entry = _parseModel(value);
          if (entry == null) continue;
          accepted[entry.id] = entry;
        }
        for (final id in duplicateIds) {
          accepted.remove(id);
        }
        // A model-level ZDR flag can describe its paid base variant. Require
        // an exact free model_id in the endpoint-level ZDR list instead.
        final result = _withPrivateEndpoints(accepted, endpoints)
          ..sort((a, b) => a.name.compareTo(b.name));
        return List<OpenRouterModel>.unmodifiable(result);
      })().timeout(catalogTimeout);
      if (_disposed) {
        throw const OpenRouterFailure('cancelled', 'Catalog refresh stopped.');
      }
      _models = result;
      _catalogAt = _now();
      return result;
    } on OpenRouterFailure {
      rethrow;
    } on TimeoutException {
      throw const OpenRouterFailure(
        'timeout',
        'The model catalog timed out. Refresh explicitly to try again.',
      );
    } on FormatException {
      throw const OpenRouterFailure(
        'catalog',
        'The model catalog has an unexpected format.',
      );
    } catch (_) {
      throw const OpenRouterFailure(
        'network',
        'The model catalog could not be reached.',
      );
    } finally {
      if (!abort.isCompleted) abort.complete();
      transport.close();
      if (identical(_catalogTransport, transport)) _catalogTransport = null;
    }
  }

  Future<List<dynamic>> _readPublicCatalog(
    http.Client transport,
    String path,
    Future<void> abort,
  ) async {
    final request =
        http.AbortableRequest(
            'GET',
            Uri.https('openrouter.ai', path),
            abortTrigger: abort,
          )
          ..followRedirects = false
          // Cache-Control is not allowed by OpenRouter's CORS policy. The browser
          // transport uses Fetch cache:no-store without adding a request header.
          ..headers['Accept'] = 'application/json';
    final response = await transport.send(request);
    if (response.statusCode != 200) throw _httpFailure(response);
    final bytes = <int>[];
    await for (final chunk in response.stream) {
      if (bytes.length + chunk.length > 4 * 1024 * 1024) {
        throw const OpenRouterFailure(
          'catalog',
          'The model catalog is too large.',
        );
      }
      bytes.addAll(chunk);
    }
    final object = jsonDecode(utf8.decode(bytes));
    if (object is! Map || object['data'] is! List) {
      throw const FormatException();
    }
    return object['data'] as List;
  }

  Stream<OpenRouterUpdate> complete({
    required String modelId,
    required List<OpenRouterMessage> messages,
    required OpenRouterCancellation cancel,
    int? outputTokens,
  }) {
    late StreamController<OpenRouterUpdate> controller;
    _Completion? run;
    controller = StreamController<OpenRouterUpdate>(
      onListen: () {
        final failure = _admissionFailure(
          modelId,
          messages,
          cancel,
          outputTokens,
        );
        if (failure != null) {
          controller.add(OpenRouterUpdate(text: '', failure: failure));
          unawaited(controller.close());
          return;
        }
        final model = _models.firstWhere((model) => model.id == modelId);
        run = _Completion(this, controller, cancel);
        _active = run;
        unawaited(run!.start(model, List.of(messages), _key, outputTokens));
      },
      onCancel: () => run?.stop(),
    );
    return controller.stream;
  }

  OpenRouterFailure? _admissionFailure(
    String modelId,
    List<OpenRouterMessage> messages,
    OpenRouterCancellation cancel,
    int? outputTokens,
  ) {
    if (_disposed || cancel.isCancelled) {
      return const OpenRouterFailure(
        'cancelled',
        'The AI request was cancelled.',
      );
    }
    if (!_isOnline()) {
      return const OpenRouterFailure(
        'offline',
        'AI is paused offline. Your game and transcript remain available.',
      );
    }
    if (!hasApiKey) {
      return const OpenRouterFailure(
        'key',
        'Add an OpenRouter API key for this browser session.',
      );
    }
    if (!catalogFresh) {
      return const OpenRouterFailure(
        'catalog',
        'Refresh the model catalog before requesting a new AI response.',
      );
    }
    final matches = _models.where((model) => model.id == modelId);
    if (matches.isEmpty) {
      return const OpenRouterFailure(
        'model',
        'Select a currently available free text model.',
      );
    }
    if (_active != null) {
      return const OpenRouterFailure(
        'busy',
        'Wait for or stop the current response.',
      );
    }
    if (outputTokens != null &&
        (!matches.single.supportsMaxTokens ||
            outputTokens < 16 ||
            outputTokens > 32768)) {
      return const OpenRouterFailure(
        'input',
        'This output limit is unsupported by the selected model.',
      );
    }
    if (_retryAt != null && _now().isBefore(_retryAt!)) {
      return OpenRouterFailure(
        'cooldown',
        'The provider requested a pause. Retry explicitly after the wait.',
        retryAfter: _retryAt!.difference(_now()),
      );
    }
    if (messages.isEmpty ||
        messages.any(
          (message) =>
              !const ['system', 'user', 'assistant'].contains(message.role) ||
              message.content.trim().isEmpty,
        )) {
      return const OpenRouterFailure(
        'input',
        'The conversation is empty or has an unsupported message.',
      );
    }
    final bytes = messages.fold<int>(
      0,
      (sum, message) => sum + utf8.encode(message.content).length + 24,
    );
    // A local conservative estimate, not a provider tokenizer measurement.
    if (bytes > 150000 ||
        (bytes / 3).ceil() + (outputTokens ?? 2048) >
            matches.single.contextLength) {
      return const OpenRouterFailure(
        'context',
        'The conversation exceeds this model’s context budget. Start a new session or choose a larger model.',
      );
    }
    return null;
  }

  OpenRouterFailure _httpFailure(http.StreamedResponse response) {
    final status = response.statusCode;
    if (status == 401 || status == 403) {
      return const OpenRouterFailure(
        'authentication',
        'OpenRouter rejected this key or the private provider policy. Check your key and account settings.',
      );
    }
    if (status == 429) {
      final retry = _retryAfter(response.headers['retry-after'], _now());
      _retryAt = _now().add(retry);
      return OpenRouterFailure(
        'rate_limit',
        'OpenRouter requested a pause. No request will be retried automatically.',
        retryAfter: retry,
      );
    }
    // Only the numeric HTTP status selects local copy. Upstream bodies, reason
    // phrases and diagnostic headers can contain credentials or conversation.
    final message = switch (status) {
      400 =>
        'OpenRouter rejected the request parameters (HTTP 400). Check that the selected model supports these request settings before retrying.',
      402 =>
        'OpenRouter reported insufficient credits or a spending limit (HTTP 402). Check your account balance and key limits before retrying.',
      404 =>
        'OpenRouter could not find a resource for this request (HTTP 404). Refresh the model catalog and check the selected model before retrying.',
      408 =>
        'OpenRouter timed out waiting for this request (HTTP 408). Retry explicitly when ready.',
      502 =>
        'The selected model is unavailable or returned an invalid response (HTTP 502). Retry explicitly later.',
      503 =>
        'No available provider meets this request’s routing requirements (HTTP 503). Choose another free model or retry later; private routing remains enforced.',
      _ =>
        'OpenRouter could not complete this request (HTTP $status) with the selected model and privacy policy. Retry only when ready.',
    };
    return OpenRouterFailure('provider', message);
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _active?.fail(
      const OpenRouterFailure(
        'cancelled',
        'The AI request was stopped. Received text is kept.',
      ),
    );
    _key = '';
    _catalogTransport?.close();
    _catalogAt = null;
  }
}

Duration _retryAfter(String? value, DateTime now) {
  final seconds = int.tryParse(value ?? '');
  if (seconds != null && seconds >= 0) return Duration(seconds: seconds);
  final match = RegExp(
    r'^[A-Za-z]{3}, (\d{2}) ([A-Za-z]{3}) (\d{4}) (\d{2}):(\d{2}):(\d{2}) GMT$',
  ).firstMatch(value ?? '');
  if (match != null) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final month = months.indexOf(match[2]!) + 1;
    if (month > 0) {
      final until = DateTime.utc(
        int.parse(match[3]!),
        month,
        int.parse(match[1]!),
        int.parse(match[4]!),
        int.parse(match[5]!),
        int.parse(match[6]!),
      );
      final remaining = until.difference(now);
      return remaining.isNegative ? Duration.zero : remaining;
    }
  }
  return const Duration(seconds: 60);
}

OpenRouterModel? _parseModel(Object? value) {
  if (value is! Map) return null;
  final id = value['id'];
  final name = value['name'];
  final context = value['context_length'];
  final architecture = value['architecture'];
  final pricing = value['pricing'];
  if (id is! String ||
      id.isEmpty ||
      id.length > 200 ||
      RegExp(r'[\s\x00-\x1f]').hasMatch(id) ||
      name is! String ||
      name.isEmpty ||
      name.length > 250 ||
      context is! int ||
      context < 4096 ||
      architecture is! Map ||
      architecture['input_modalities'] is! List ||
      !(architecture['input_modalities'] as List).contains('text') ||
      architecture['output_modalities'] is! List ||
      !(architecture['output_modalities'] as List).contains('text') ||
      pricing is! Map ||
      !pricing.containsKey('prompt') ||
      !pricing.containsKey('completion')) {
    return null;
  }
  // Exact lexical zero avoids numeric underflow turning tiny paid prices free.
  if (pricing.values.any((price) => !_zeroPrice(price))) return null;
  return OpenRouterModel(
    id: id,
    name: name,
    contextLength: context,
    supportsMaxTokens:
        value['supported_parameters'] is List &&
        (value['supported_parameters'] as List).contains('max_tokens'),
  );
}

bool _zeroPrice(Object? price) =>
    price is String &&
    RegExp(r'^0+(?:\.0+)?(?:[eE][+-]?\d+)?$').hasMatch(price);

List<OpenRouterModel> _withPrivateEndpoints(
  Map<String, OpenRouterModel> models,
  List<dynamic> values,
) {
  final endpoints = <String, List<Map>>{};
  final seen = <String>{};
  final duplicates = <String>{};
  for (final value in values) {
    if (value is! Map) continue;
    final id = value['model_id'];
    final tag = value['tag'];
    if (id is! String || tag is! String) continue;
    final identity = '$id\u0000$tag';
    if (!seen.add(identity)) duplicates.add(identity);
    final pricing = value['pricing'];
    final context = value['context_length'];
    if (!models.containsKey(id) ||
        tag.length > 200 ||
        !RegExp(r'^[a-z0-9]+(?:[._/-][a-z0-9]+)*$').hasMatch(tag) ||
        value['status'] != 0 ||
        context is! int ||
        context < 4096 ||
        pricing is! Map ||
        !_zeroPrice(pricing['prompt']) ||
        !_zeroPrice(pricing['completion']) ||
        pricing.entries.any(
          (entry) => entry.key != 'discount' && !_zeroPrice(entry.value),
        )) {
      continue;
    }
    // Discount is a fraction in endpoint metadata, not a billed price field.
    final discount = pricing['discount'];
    if (discount != null &&
        (discount is! num ||
            !discount.isFinite ||
            discount < 0 ||
            discount > 1)) {
      continue;
    }
    (endpoints[id] ??= []).add(value);
  }
  final result = <OpenRouterModel>[];
  for (final model in models.values) {
    final eligible = (endpoints[model.id] ?? [])
        .where(
          (endpoint) =>
              !duplicates.contains('${model.id}\u0000${endpoint['tag']}'),
        )
        .toList();
    if (eligible.isEmpty) continue;
    final tags = eligible.map((e) => e['tag'] as String).toList()..sort();
    final context = eligible.fold<int>(model.contextLength, (limit, endpoint) {
      final available = endpoint['context_length'] as int;
      return available < limit ? available : limit;
    });
    result.add(
      OpenRouterModel(
        id: model.id,
        name: model.name,
        contextLength: context,
        supportsMaxTokens:
            model.supportsMaxTokens &&
            eligible.every(
              (endpoint) =>
                  endpoint['supported_parameters'] is List &&
                  (endpoint['supported_parameters'] as List).contains(
                    'max_tokens',
                  ),
            ),
        providerTags: List<String>.unmodifiable(tags),
      ),
    );
  }
  return result;
}

class _Completion {
  _Completion(this.owner, this.controller, this.cancel);
  final OpenRouterClient owner;
  final StreamController<OpenRouterUpdate> controller;
  final OpenRouterCancellation cancel;
  final _abort = Completer<void>();
  http.Client? _transport;
  StreamSubscription<String>? _lines;
  Timer? _usefulTimer;
  Timer? _overallTimer;
  void Function()? _unlink;
  String _text = '';
  String? _finishReason;
  bool _finished = false;
  final _event = <String>[];
  int _eventChars = 0;
  int _receivedBytes = 0;
  int _receivedChars = 0;
  String _modelId = '';

  Future<void> start(
    OpenRouterModel model,
    List<OpenRouterMessage> messages,
    String key,
    int? outputTokens,
  ) async {
    _modelId = model.id;
    _unlink = cancel._listen(
      () => fail(
        const OpenRouterFailure(
          'cancelled',
          'The response was stopped. Received text is kept.',
        ),
      ),
    );
    if (_finished) return;
    _usefulTimer = Timer(owner.firstOutputTimeout, _timeout);
    _overallTimer = Timer(owner.overallTimeout, _timeout);
    try {
      final request =
          http.AbortableRequest(
              'POST',
              Uri.https('openrouter.ai', '/api/v1/chat/completions'),
              abortTrigger: _abort.future,
            )
            ..followRedirects = false
            ..headers.addAll({
              'Authorization': 'Bearer $key',
              'Content-Type': 'application/json',
              'Accept': 'text/event-stream',
            })
            ..body = jsonEncode({
              'model': model.id,
              'messages': messages.map((message) => message.toJson()).toList(),
              'stream': true,
              if (outputTokens != null) 'max_tokens': outputTokens,
              'provider': {
                'allow_fallbacks': false,
                'only': model.providerTags,
                if (outputTokens != null) 'require_parameters': true,
                'data_collection': 'deny',
                'zdr': true,
                'max_price': {
                  'prompt': '0',
                  'completion': '0',
                  'request': '0',
                  'image': '0',
                  'audio': '0',
                },
              },
            });
      _transport = owner._clientFactory();
      final response = await _transport!.send(request);
      if (_finished) return;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        fail(owner._httpFailure(response));
        return;
      }
      if (!(response.headers['content-type'] ?? '').toLowerCase().contains(
        'text/event-stream',
      )) {
        fail(
          const OpenRouterFailure(
            'format',
            'OpenRouter returned an unexpected response format.',
          ),
        );
        return;
      }
      final boundedBytes = response.stream.map((chunk) {
        _receivedBytes += chunk.length;
        if (_receivedBytes > owner.maxResponseChars * 8) {
          throw const OpenRouterFailure(
            'limit',
            'The response reached its size limit. Received text is kept.',
          );
        }
        return chunk;
      });
      _lines = boundedBytes
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
            _line,
            onError: (Object error) => fail(
              error is OpenRouterFailure
                  ? error
                  : const OpenRouterFailure(
                      'network',
                      'The connection was interrupted. Received text is kept. Retry explicitly if needed.',
                    ),
            ),
            onDone: () {
              if (!_finished) {
                fail(
                  const OpenRouterFailure(
                    'truncated',
                    'The response ended before its completion marker. Received text is kept.',
                  ),
                );
              }
            },
          );
    } catch (error) {
      fail(
        error is OpenRouterFailure
            ? error
            : const OpenRouterFailure(
                'network',
                'OpenRouter could not be reached. No automatic retry was made.',
              ),
      );
    }
  }

  void _timeout() => fail(
    const OpenRouterFailure(
      'timeout',
      'The AI response timed out. Received text is kept. Retry explicitly if needed.',
    ),
  );

  void _line(String line) {
    if (_finished) return;
    if (line.isEmpty) {
      if (_event.isNotEmpty) {
        final event = _event.join('\n');
        _event.clear();
        _eventChars = 0;
        _data(event);
      }
      return;
    }
    if (line.startsWith('data:')) {
      var part = line.substring(5);
      if (part.startsWith(' ')) part = part.substring(1);
      _eventChars += part.length;
      if (_eventChars > owner.maxResponseChars * 2) {
        fail(
          const OpenRouterFailure(
            'limit',
            'The response event reached its size limit. Received text is kept.',
          ),
        );
        return;
      }
      _event.add(part);
    }
  }

  void _data(String raw) {
    if (raw == '[DONE]') {
      if (_text.isEmpty) {
        fail(
          const OpenRouterFailure(
            'empty',
            'The model completed without a patient response.',
          ),
        );
      } else {
        _finish(
          OpenRouterUpdate(
            text: _text,
            done: true,
            finishReason: _finishReason,
          ),
        );
      }
      return;
    }
    try {
      final value = jsonDecode(raw);
      if (value is! Map) throw const FormatException();
      if (value['error'] != null) {
        fail(
          const OpenRouterFailure(
            'provider',
            'The provider interrupted the response. Received text is kept.',
          ),
        );
        return;
      }
      final returnedModel = value['model'];
      if (returnedModel != null &&
          returnedModel != _modelId &&
          !(_modelId.endsWith(':free') &&
              returnedModel == _modelId.substring(0, _modelId.length - 5))) {
        fail(
          const OpenRouterFailure(
            'model',
            'The provider returned a different model. Its response was rejected.',
          ),
        );
        return;
      }
      final choices = value['choices'];
      if (choices is! List) throw const FormatException();
      if (choices.isEmpty && value['usage'] is Map) return;
      if (choices.length != 1 || choices.first is! Map) {
        throw const FormatException();
      }
      final choice = choices.first as Map;
      final reason = choice['finish_reason'];
      if (reason != null && reason is! String) throw const FormatException();
      if (reason is String) _finishReason = reason;
      final delta = choice['delta'];
      if (delta is! Map) throw const FormatException();
      if (delta['tool_calls'] != null && delta['tool_calls'] is! List ||
          delta['tool_calls'] is List &&
              (delta['tool_calls'] as List).isNotEmpty ||
          delta['function_call'] != null) {
        fail(
          const OpenRouterFailure(
            'tools',
            'Unexpected tool calls were rejected. Nothing was executed.',
          ),
        );
        return;
      }
      final content = delta['content'];
      final reasoning = delta['reasoning'] ?? delta['reasoning_content'];
      if (content != null && content is! String ||
          reasoning != null && reasoning is! String) {
        throw const FormatException();
      }
      _receivedChars +=
          (content as String? ?? '').length +
          (reasoning as String? ?? '').length;
      if (_receivedChars > owner.maxResponseChars) {
        fail(
          const OpenRouterFailure(
            'limit',
            'The response reached its size limit. Received text is kept.',
          ),
        );
        return;
      }
      if ((content ?? '') != '' || (reasoning ?? '') != '') {
        _usefulTimer?.cancel();
        _usefulTimer = Timer(owner.idleTimeout, _timeout);
      }
      if (content is String && content.isNotEmpty) {
        _text += content;
        controller.add(
          OpenRouterUpdate(text: _text, finishReason: _finishReason),
        );
      }
      if (reason != null && reason != 'stop') {
        fail(
          OpenRouterFailure(
            'finish',
            reason == 'length'
                ? 'The response reached its output limit. Received text is kept.'
                : 'The provider stopped the response. Received text is kept.',
          ),
        );
      }
    } on FormatException {
      fail(
        const OpenRouterFailure(
          'format',
          'The model returned malformed stream data. Received text is kept.',
        ),
      );
    } catch (_) {
      fail(
        const OpenRouterFailure(
          'format',
          'The model returned an unsupported response. Received text is kept.',
        ),
      );
    }
  }

  void fail(OpenRouterFailure failure) => _finish(
    OpenRouterUpdate(
      text: _text,
      failure: failure,
      finishReason: _finishReason,
    ),
  );

  void _finish(OpenRouterUpdate update) {
    if (_finished) return;
    controller.add(update);
    stop();
    unawaited(controller.close());
  }

  void stop() {
    if (_finished) return;
    _finished = true;
    _usefulTimer?.cancel();
    _overallTimer?.cancel();
    _unlink?.call();
    if (!_abort.isCompleted) _abort.complete();
    _transport?.close();
    final lines = _lines;
    if (lines != null) unawaited(lines.cancel());
    if (identical(owner._active, this)) owner._active = null;
  }
}
