import 'dart:async';
import 'dart:js_interop';

import 'package:http/http.dart' as http;
import 'package:web/web.dart' as web;

http.Client createHttpClient() => _BrowserHttpClient();

@JS('fetch')
external JSPromise<web.Response> _fetch(JSString url, web.RequestInit options);

@JS()
extension type _IterableHeaders(JSObject _) implements JSObject {
  external void forEach(JSFunction callback);
}

/// Fetch's cache option avoids storing catalog or dialogue responses without
/// adding request headers that OpenRouter rejects during CORS preflight.
class _BrowserHttpClient extends http.BaseClient {
  bool _closed = false;
  final _active = <web.AbortController>{};

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (_closed) throw http.ClientException('Client is closed.', request.url);
    final abort = web.AbortController();
    _active.add(abort);
    if (request case http.Abortable(:final abortTrigger?)) {
      unawaited(
        abortTrigger.then((_) {
          if (_active.contains(abort)) abort.abort();
        }),
      );
    }
    try {
      final bytes = await request.finalize().toBytes();
      if (abort.signal.aborted) throw http.RequestAbortedException(request.url);
      final response = await _fetch(
        request.url.toString().toJS,
        web.RequestInit(
          method: request.method,
          headers: request.headers.jsify()! as JSObject,
          body: bytes.isEmpty ? null : bytes.toJS,
          cache: 'no-store',
          credentials: 'omit',
          redirect: request.followRedirects ? 'follow' : 'error',
          signal: abort.signal,
        ),
      ).toDart;
      final headers = <String, String>{};
      _IterableHeaders(response.headers).forEach(
        ((String value, String key, JSAny? _) {
          headers[key.toLowerCase()] = value;
        }).toJS,
      );
      final rawLength = headers['content-length'];
      final length = rawLength == null ? null : int.tryParse(rawLength);
      if (rawLength != null && (length == null || length < 0)) {
        throw http.ClientException('Invalid response length.', request.url);
      }
      return http.StreamedResponse(
        _bodyStream(response, request, abort),
        response.status,
        headers: headers,
        contentLength: length,
        request: request,
        reasonPhrase: response.statusText,
      );
    } catch (error, stack) {
      final failure = _failure(error, request, abort);
      _active.remove(abort);
      abort.abort();
      Error.throwWithStackTrace(failure, stack);
    }
  }

  Stream<List<int>> _bodyStream(
    web.Response response,
    http.BaseRequest request,
    web.AbortController abort,
  ) {
    final reader =
        response.body?.getReader() as web.ReadableStreamDefaultReader?;
    if (reader == null) {
      _active.remove(abort);
      return const Stream.empty();
    }
    var cancelled = false;
    var finished = false;
    Completer<void>? resume;
    final stopped = Completer<void>();
    late StreamController<List<int>> stream;

    void resumeReading() {
      final waiting = resume;
      resume = null;
      waiting?.complete();
    }

    final onAbort = ((web.Event _) => resumeReading()).toJS;
    abort.signal.addEventListener('abort', onAbort);

    Future<void> read() async {
      try {
        while (!cancelled) {
          if (stream.isPaused && !abort.signal.aborted) {
            await (resume ??= Completer<void>()).future;
          }
          if (cancelled) break;
          if (abort.signal.aborted) {
            throw http.RequestAbortedException(request.url);
          }
          final chunk = await reader.read().toDart;
          if (cancelled || chunk.done) break;
          stream.add((chunk.value! as JSUint8Array).toDart);
        }
      } catch (error, stack) {
        if (!cancelled) stream.addError(_failure(error, request, abort), stack);
      } finally {
        finished = true;
        abort.signal.removeEventListener('abort', onAbort);
        _active.remove(abort);
        reader.releaseLock();
        stopped.complete();
        if (!cancelled) unawaited(stream.close());
      }
    }

    stream = StreamController<List<int>>(
      sync: true,
      onListen: () => unawaited(read()),
      onResume: resumeReading,
      onCancel: () {
        if (finished) return null;
        cancelled = true;
        abort.abort();
        resumeReading();
        return stopped.future;
      },
    );
    return stream.stream;
  }

  http.ClientException _failure(
    Object error,
    http.BaseRequest request,
    web.AbortController abort,
  ) => abort.signal.aborted
      ? http.RequestAbortedException(request.url)
      : error is http.ClientException
      ? error
      : http.ClientException('Browser request failed.', request.url);

  @override
  void close() {
    if (_closed) return;
    _closed = true;
    for (final abort in _active.toList()) {
      abort.abort();
    }
    _active.clear();
  }
}
