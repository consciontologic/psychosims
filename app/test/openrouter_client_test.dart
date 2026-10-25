import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:psychosims/shared/openrouter_client.dart';

Map<String, Object?> model({String id = 'test/patient:free'}) => {
  'id': id,
  'name': 'Patient model',
  'context_length': 8192,
  'architecture': {
    'input_modalities': ['text'],
    'output_modalities': ['text'],
  },
  'pricing': {'prompt': '0', 'completion': '0'},
  'supported_parameters': ['max_tokens'],
};

String event(String text, {String? returnedModel}) =>
    'data: ${jsonEncode({
      if (returnedModel != null) 'model': returnedModel,
      'choices': [
        {
          'delta': {'content': text},
        },
      ],
    })}\r\n\r\n';

class FakeClient extends http.BaseClient {
  FakeClient(this.handler);
  final FutureOr<http.StreamedResponse> Function(http.BaseRequest) handler;
  bool closed = false;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async =>
      handler(request);
  @override
  void close() => closed = true;
}

http.StreamedResponse response(
  String text, {
  int status = 200,
  Map<String, String>? headers,
}) => http.StreamedResponse(
  Stream.value(utf8.encode(text)),
  status,
  headers: headers ?? {'content-type': 'text/event-stream'},
);

void main() {
  late List<http.BaseRequest> requests;
  late List<FakeClient> transports;
  late bool online;
  late DateTime now;
  late FutureOr<http.StreamedResponse> Function(http.BaseRequest) completion;
  late List<Map<String, Object?>> catalog;
  late OpenRouterClient client;
  late List<Map<String, Object?>> endpoints;
  late int endpointStatus;

  setUp(() {
    requests = [];
    transports = [];
    online = true;
    now = DateTime.utc(2026, 10, 23);
    catalog = [model()];
    endpointStatus = 200;
    endpoints = [
      {
        'model_id': 'test/patient:free',
        'tag': 'test-provider',
        'status': 0,
        'context_length': 8192,
        'pricing': {'prompt': '0', 'completion': '0', 'discount': 0},
        'supported_parameters': ['max_tokens'],
      },
    ];
    completion = (_) => response('${event('hello')}data: [DONE]\n\n');
    client = OpenRouterClient(
      isOnline: () => online,
      now: () => now,
      clientFactory: () {
        final transport = FakeClient((request) {
          requests.add(request);
          if (request.url.path == '/api/v1/endpoints/zdr') {
            return response(
              jsonEncode({'data': endpoints}),
              status: endpointStatus,
              headers: {'content-type': 'application/json'},
            );
          }
          return request.method == 'GET'
              ? response(
                  jsonEncode({'data': catalog}),
                  headers: {'content-type': 'application/json'},
                )
              : completion(request);
        });
        transports.add(transport);
        return transport;
      },
    );
  });

  tearDown(() => client.dispose());

  Future<void> ready() async {
    client.setApiKey('unit-test-credential');
    await client.refreshCatalog();
  }

  Stream<OpenRouterUpdate> send([OpenRouterCancellation? cancel]) =>
      client.complete(
        modelId: 'test/patient:free',
        messages: const [OpenRouterMessage(role: 'user', content: 'Hello')],
        cancel: cancel ?? OpenRouterCancellation(),
      );

  test(
    'exact ZDR endpoint limits and capabilities constrain dispatch',
    () async {
      endpoints.single['context_length'] = 4096;
      endpoints.single['supported_parameters'] = <String>[];
      await ready();
      expect(client.models.single.contextLength, 4096);
      expect(client.models.single.supportsMaxTokens, isFalse);
      expect(client.models.single.providerTags, ['test-provider']);
      final result = await client
          .complete(
            modelId: 'test/patient:free',
            messages: const [OpenRouterMessage(role: 'user', content: 'Hello')],
            cancel: OpenRouterCancellation(),
            outputTokens: 64,
          )
          .last;
      expect(result.failure?.code, 'input');
      expect(requests.where((r) => r.method == 'POST'), isEmpty);
      expect((await send().last).done, isTrue);
    },
  );

  test('conflicting duplicate endpoint identities fail closed', () async {
    endpoints.add({
      ...endpoints.single,
      'pricing': {'prompt': '1', 'completion': '0'},
    });
    await ready();
    expect(client.models, isEmpty);
    expect((await send().last).failure?.code, 'model');
    expect(requests.where((r) => r.method == 'POST'), isEmpty);
  });

  test('paid base ZDR endpoints do not authorize a free variant', () async {
    endpoints.single['model_id'] = 'test/patient';
    await ready();
    expect(client.models, isEmpty);
    expect((await send().last).failure?.code, 'model');
    expect(requests.where((r) => r.method == 'POST'), isEmpty);
  });

  test('endpoint outage invalidates a previously usable catalog', () async {
    await ready();
    endpointStatus = 503;
    await expectLater(
      client.refreshCatalog(),
      throwsA(isA<OpenRouterFailure>()),
    );
    expect(client.catalogFresh, isFalse);
    expect((await send().last).failure?.code, 'catalog');
    expect(requests.where((r) => r.method == 'POST'), isEmpty);
  });

  test(
    'nonfree and unavailable private endpoints cannot authorize dispatch',
    () async {
      for (final invalid in [
        {
          'pricing': {'prompt': '0.0001', 'completion': '0'},
        },
        {
          'pricing': {'prompt': '0', 'completion': '0', 'request': '0.1'},
        },
        {
          'pricing': {'prompt': '1e-999', 'completion': '0'},
        },
        {
          'pricing': {'prompt': '0'},
        },
        {'status': 1},
        {'status': null},
        {'tag': 'bad provider'},
        {'context_length': 2048},
      ]) {
        final original = Map<String, Object?>.of(endpoints.single);
        endpoints = [
          {...original, ...invalid},
        ];
        await ready();
        expect(client.models, isEmpty, reason: invalid.toString());
        expect((await send().last).failure?.code, 'model');
        endpoints = [original];
      }
      expect(requests.where((r) => r.method == 'POST'), isEmpty);
    },
  );

  test(
    'catalog rejects paid unknown negative pricing and nontext models',
    () async {
      catalog.addAll([
        {
          ...model(id: 'paid'),
          'pricing': {'prompt': '0.001', 'completion': '0'},
        },
        {
          ...model(id: 'unknown'),
          'pricing': {'prompt': '0'},
        },
        {
          ...model(id: 'negative'),
          'pricing': {'prompt': '-1', 'completion': '0'},
        },
        {
          ...model(id: 'nan'),
          'pricing': {'prompt': 'NaN', 'completion': '0'},
        },
        {
          ...model(id: 'tiny'),
          'pricing': {'prompt': '1e-999', 'completion': '0'},
        },
        {
          ...model(id: 'extra'),
          'pricing': {'prompt': '0', 'completion': '0', 'request': '1'},
        },
        {
          ...model(id: 'image'),
          'architecture': {
            'input_modalities': ['text'],
            'output_modalities': ['image'],
          },
        },
      ]);
      final models = await client.refreshCatalog();
      expect(models.map((value) => value.id), ['test/patient:free']);
      expect(requests, hasLength(2));
      expect(
        requests.every((r) => !r.headers.containsKey('authorization')),
        isTrue,
      );
      expect(
        requests.first.url.toString(),
        'https://openrouter.ai/api/v1/models',
      );
    },
  );

  test('catalog refresh uses CORS-safe public request headers', () async {
    await client.refreshCatalog();
    expect(requests, hasLength(2));
    expect(requests.last.url.path, '/api/v1/endpoints/zdr');
    final request = requests.first;
    // OpenRouter does not allow Cache-Control in CORS preflight requests.
    expect(
      request.headers.map((key, value) => MapEntry(key.toLowerCase(), value)),
      {'accept': 'application/json'},
    );
    expect(request.followRedirects, isFalse);
  });

  test('completion sends only headers allowed by OpenRouter CORS', () async {
    await ready();
    expect((await send().last).done, isTrue);
    expect(
      requests.last.headers.map(
        (key, value) => MapEntry(key.toLowerCase(), value),
      ),
      {
        'authorization': 'Bearer unit-test-credential',
        'content-type': 'application/json',
        'accept': 'text/event-stream',
      },
    );
  });

  test(
    'requires online key and fresh catalog without network dispatch',
    () async {
      online = false;
      expect((await send().last).failure?.code, 'offline');
      expect(requests, isEmpty);
      online = true;
      expect((await send().last).failure?.code, 'key');
      client.setApiKey('unit-test-credential');
      expect((await send().last).failure?.code, 'catalog');
      await client.refreshCatalog();
      now = now.add(const Duration(minutes: 31));
      expect((await send().last).failure?.code, 'catalog');
      expect(requests.where((r) => r.method == 'POST'), isEmpty);
    },
  );

  test('removed model and failed refresh cannot authorize a request', () async {
    await ready();
    catalog = [];
    await client.refreshCatalog();
    expect((await send().last).failure?.code, 'model');
    catalog = [model()];
    await client.refreshCatalog();
    online = false;
    await expectLater(
      client.refreshCatalog(),
      throwsA(isA<OpenRouterFailure>()),
    );
    online = true;
    expect(client.models, hasLength(1));
    expect((await send().last).failure?.code, 'catalog');
  });

  test(
    'key only enters authorization, strict private free routing is explicit',
    () async {
      await ready();
      final updates = await send().toList();
      expect(updates.last.done, isTrue);
      final request = requests.last as http.Request;
      expect(request.headers['authorization'], 'Bearer unit-test-credential');
      expect(
        request.url.toString(),
        'https://openrouter.ai/api/v1/chat/completions',
      );
      expect(request.body, isNot(contains('unit-test-credential')));
      expect(request.url.query, isEmpty);
      expect(request.followRedirects, isFalse);
      expect(jsonDecode(request.body).containsKey('max_tokens'), isFalse);
      expect(jsonDecode(request.body)['provider'], {
        'allow_fallbacks': false,
        'only': ['test-provider'],
        'data_collection': 'deny',
        'zdr': true,
        'max_price': {
          'prompt': '0',
          'completion': '0',
          'request': '0',
          'image': '0',
          'audio': '0',
        },
      });
      expect(client.toString(), isNot(contains('unit-test-credential')));
      client.clearApiKey();
      expect(client.hasApiKey, isFalse);
      expect((await send().last).failure?.code, 'key');
      expect(transports.every((transport) => transport.closed), isTrue);
    },
  );

  test('SSE handles fragmented UTF8 CRLF multiline data and DONE', () async {
    await ready();
    final bytes = utf8.encode(
      ': heartbeat\r\n\r\ndata: {"choices":\r\ndata: [{"delta":{"content":"İ 🧠"}}]}\r\n\r\ndata: [DONE]\r\n\r\n',
    );
    completion = (_) => http.StreamedResponse(
      Stream.fromIterable(bytes.map((byte) => [byte])),
      200,
      headers: {'content-type': 'text/event-stream; charset=utf-8'},
    );
    final updates = await send().toList();
    expect(updates.last.text, 'İ 🧠');
    expect(updates.last.done, isTrue);
    expect(updates.last.failure, isNull);
  });

  test('truncation preserves partial text and never resends', () async {
    await ready();
    completion = (_) => response(event('partial'));
    final result = await send().last;
    expect(result.text, 'partial');
    expect(result.failure?.code, 'truncated');
    expect(result.done, isFalse);
    expect(requests.where((r) => r.method == 'POST'), hasLength(1));
  });

  test(
    'HTTP 200 error envelopes preserve output and redact upstream content',
    () async {
      await ready();
      completion = (_) => response(
        '${event('partial')}data: {"error":{"code":500,"message":"unit-test-credential PRIVATE PROMPT"}}\n\n',
      );
      final result = await send().last;
      expect(result.text, 'partial');
      expect(result.failure?.code, 'provider');
      expect(result.failure.toString(), isNot(contains('PRIVATE')));
      expect(
        result.failure.toString(),
        isNot(contains('unit-test-credential')),
      );
    },
  );

  for (final entry in {
    400: 'request settings',
    402: 'credits',
    404: 'resource',
    408: 'timed out',
    502: 'invalid response',
    503: 'routing requirements',
    500: 'selected model and privacy policy',
  }.entries) {
    test(
      'HTTP ${entry.key} gives safe actionable diagnostics without retry',
      () async {
        await ready();
        var readBody = false;
        completion = (_) => http.StreamedResponse(
          Stream<List<int>>.multi((controller) {
            readBody = true;
            controller.add(utf8.encode('PRIVATE BODY unit-test-credential'));
            controller.close();
          }),
          entry.key,
          headers: {'x-provider-debug': 'PRIVATE HEADER'},
          reasonPhrase: 'PRIVATE REASON',
        );
        final result = await send().last;
        await Future<void>.delayed(Duration.zero);
        expect(result.done, isFalse);
        expect(result.failure?.code, 'provider');
        expect(result.failure?.message, contains('HTTP ${entry.key}'));
        expect(result.failure?.message, contains(entry.value));
        expect(result.failure.toString(), isNot(contains('PRIVATE')));
        expect(
          result.failure.toString(),
          isNot(contains('unit-test-credential')),
        );
        expect(readBody, isFalse);
        expect(
          requests.where((request) => request.method == 'POST'),
          hasLength(1),
        );
        expect(transports.last.closed, isTrue);
        expect(client.hasApiKey, isTrue);
      },
    );
  }

  for (final status in [401, 403]) {
    test(
      'HTTP $status keeps authentication guidance and never retries',
      () async {
        await ready();
        completion = (_) =>
            response('PRIVATE unit-test-credential', status: status);
        final result = await send().last;
        expect(result.failure?.code, 'authentication');
        expect(
          result.failure?.message,
          'OpenRouter rejected this key or the private provider policy. Check your key and account settings.',
        );
        expect(
          requests.where((request) => request.method == 'POST'),
          hasLength(1),
        );
      },
    );
  }

  test(
    'different model, tools, content filter and malformed payload fail closed',
    () async {
      await ready();
      for (final payload in [
        event('wrong', returnedModel: 'different/model'),
        'data: {"choices":[{"delta":{"tool_calls":[{}]}}]}\n\n',
        'data: {"choices":[{"delta":{},"finish_reason":"content_filter"}]}\n\n',
        'data: not-json\n\n',
      ]) {
        completion = (_) => response('${payload}data: [DONE]\n\n');
        expect((await send().last).failure, isNotNull);
      }
    },
  );

  test('429 respects Retry-After and an explicit retry is needed', () async {
    await ready();
    completion = (_) =>
        response('PRIVATE', status: 429, headers: {'retry-after': '120'});
    expect(
      (await send().last).failure?.retryAfter,
      const Duration(seconds: 120),
    );
    expect((await send().last).failure?.code, 'cooldown');
    expect(requests.where((r) => r.method == 'POST'), hasLength(1));
    now = now.add(const Duration(seconds: 121));
    completion = (_) => response('${event('explicit retry')}data: [DONE]\n\n');
    expect((await send().last).done, isTrue);
    expect(requests.where((r) => r.method == 'POST'), hasLength(2));
  });

  test(
    'cancel closes the transport while preserving a partial response',
    () async {
      await ready();
      final source = StreamController<List<int>>();
      completion = (_) => http.StreamedResponse(
        source.stream,
        200,
        headers: {'content-type': 'text/event-stream'},
      );
      final cancel = OpenRouterCancellation();
      final received = Completer<void>();
      final values = <OpenRouterUpdate>[];
      final finished = send(cancel).forEach((update) {
        values.add(update);
        if (update.text == 'partial' && !received.isCompleted) {
          received.complete();
        }
      });
      source.add(utf8.encode(event('partial')));
      await received.future;
      cancel.cancel();
      await finished;
      expect(values.last.text, 'partial');
      expect(values.last.failure?.code, 'cancelled');
      expect(transports.last.closed, isTrue);
      await source.close();
    },
  );

  test(
    'ambiguous duplicate catalog entries cannot authorize inference',
    () async {
      catalog = [
        model(),
        {
          ...model(),
          'pricing': {'prompt': '1', 'completion': '0'},
        },
      ];
      await ready();
      expect(client.models, isEmpty);
      expect((await send().last).failure?.code, 'model');
    },
  );

  test('only an explicit supported output limit enters the request', () async {
    await ready();
    final result = await client
        .complete(
          modelId: 'test/patient:free',
          messages: const [OpenRouterMessage(role: 'user', content: 'Hello')],
          cancel: OpenRouterCancellation(),
          outputTokens: 64,
        )
        .last;
    expect(result.done, isTrue);
    final body = jsonDecode((requests.last as http.Request).body);
    expect(body['max_tokens'], 64);
    expect(body['provider']['require_parameters'], isTrue);
  });

  test('HTTP-date Retry-After is honored beyond the default wait', () async {
    await ready();
    completion = (_) => response(
      '',
      status: 429,
      headers: {'retry-after': 'Fri, 23 Oct 2026 02:00:00 GMT'},
    );
    expect((await send().last).failure?.retryAfter, const Duration(hours: 2));
  });

  test(
    'output arriving with a length stop remains in partial transcript',
    () async {
      await ready();
      completion = (_) => response(
        'data: {"choices":[{"delta":{"content":"last fragment"},"finish_reason":"length"}]}\n\ndata: [DONE]\n\n',
      );
      final result = await send().last;
      expect(result.text, 'last fragment');
      expect(result.failure?.code, 'finish');
      expect(result.done, isFalse);
    },
  );

  test(
    'pending header request can be cancelled and a second send is refused',
    () async {
      await ready();
      final pending = Completer<http.StreamedResponse>();
      final dispatched = Completer<void>();
      completion = (_) {
        dispatched.complete();
        return pending.future;
      };
      final cancel = OpenRouterCancellation();
      final result = send(cancel).last;
      await dispatched.future;
      expect((await send().last).failure?.code, 'busy');
      cancel.cancel();
      expect((await result).failure?.code, 'cancelled');
      expect(transports.last.closed, isTrue);
      pending.complete(response('data: [DONE]\n\n'));
    },
  );

  test(
    'key replacement stops active generation and invalid header keys rejected',
    () async {
      await ready();
      final source = StreamController<List<int>>();
      completion = (_) => http.StreamedResponse(
        source.stream,
        200,
        headers: {'content-type': 'text/event-stream'},
      );
      final result = send().last;
      await Future<void>.delayed(Duration.zero);
      client.clearApiKey();
      expect((await result).failure?.code, 'cancelled');
      expect(client.hasApiKey, isFalse);
      expect(
        () => client.setApiKey('bad\nheader'),
        throwsA(isA<OpenRouterFailure>()),
      );
      await source.close();
    },
  );

  test(
    'oversized context refuses dispatch instead of silently trimming',
    () async {
      await ready();
      final result = await client
          .complete(
            modelId: 'test/patient:free',
            messages: [OpenRouterMessage(role: 'user', content: 'x' * 30000)],
            cancel: OpenRouterCancellation(),
          )
          .last;
      expect(result.failure?.code, 'context');
      expect(requests.where((request) => request.method == 'POST'), isEmpty);
    },
  );

  test(
    'first useful output timeout ignores heartbeats and aborts once',
    () async {
      client.dispose();
      final source = StreamController<List<int>>();
      client = OpenRouterClient(
        isOnline: () => true,
        firstOutputTimeout: const Duration(milliseconds: 20),
        clientFactory: () => FakeClient((request) {
          requests.add(request);
          return request.method == 'GET'
              ? response(
                  jsonEncode({
                    'data': request.url.path == '/api/v1/endpoints/zdr'
                        ? endpoints
                        : [model()],
                  }),
                )
              : http.StreamedResponse(
                  source.stream,
                  200,
                  headers: {'content-type': 'text/event-stream'},
                );
        }),
      );
      await ready();
      final finished = send().last;
      source.add(utf8.encode(': heartbeat\n\n'));
      final result = await finished;
      expect(result.failure?.code, 'timeout');
      expect(requests.where((r) => r.method == 'POST'), hasLength(1));
      await source.close();
    },
  );
}
