@TestOn('browser')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:psychosims/shared/http_client.dart';
import 'package:psychosims/shared/openrouter_client.dart';
import 'package:web/web.dart' as web;

@JS('fetch')
external JSFunction get browserFetch;
@JS('fetch')
external set browserFetch(JSFunction value);

void main() {
  late JSFunction originalFetch;
  late Future<web.Response> Function(String, web.RequestInit) respond;
  late List<web.RequestInit> options;
  late List<String> urls;
  late http.Client client;

  setUp(() {
    originalFetch = browserFetch;
    options = [];
    urls = [];
    respond = (_, _) async => web.Response('hello'.toJS);
    browserFetch = ((JSString url, web.RequestInit init) {
      urls.add(url.toDart);
      options.add(init);
      return respond(url.toDart, init).toJS;
    }).toJS;
    client = createHttpClient();
  });

  tearDown(() {
    client.close();
    browserFetch = originalFetch;
  });

  http.AbortableRequest request({Completer<void>? abort}) =>
      http.AbortableRequest(
          'GET',
          Uri.parse('https://openrouter.ai/api/v1/models'),
          abortTrigger: abort?.future,
        )
        ..followRedirects = false
        ..headers['Accept'] = 'application/json';

  test(
    'public catalog fetch bypasses HTTP cache without CORS headers',
    () async {
      respond = (url, _) async => web.Response(
        jsonEncode({
          'data': url.endsWith('/endpoints/zdr')
              ? [
                  {
                    'model_id': 'test/patient:free',
                    'tag': 'test-provider',
                    'status': 0,
                    'context_length': 8192,
                    'pricing': {
                      'prompt': '0',
                      'completion': '0',
                      'discount': 0,
                    },
                  },
                ]
              : [
                  {
                    'id': 'test/patient:free',
                    'name': 'Patient',
                    'context_length': 8192,
                    'architecture': {
                      'input_modalities': ['text'],
                      'output_modalities': ['text'],
                    },
                    'pricing': {'prompt': '0', 'completion': '0'},
                  },
                ],
        }).toJS,
        web.ResponseInit(
          headers: {'content-type': 'application/json'}.jsify()! as JSObject,
        ),
      );
      final openRouter = OpenRouterClient(isOnline: () => true);
      addTearDown(openRouter.dispose);
      expect(
        (await openRouter.refreshCatalog()).single.id,
        'test/patient:free',
      );
      expect(urls, [
        'https://openrouter.ai/api/v1/models',
        'https://openrouter.ai/api/v1/endpoints/zdr',
      ]);
      for (var index = 0; index < urls.length; index++) {
        expect(web.Request(urls[index].toJS, options[index]).cache, 'no-store');
        expect(options[index].credentials, 'omit');
        expect(options[index].redirect, 'error');
        final headers = web.Headers(options[index].headers);
        expect(headers.get('accept'), 'application/json');
        expect(headers.has('cache-control'), isFalse);
        expect(headers.has('authorization'), isFalse);
      }
    },
  );

  test('POST body and headers reach Fetch with HTTP cache disabled', () async {
    final outgoing =
        http.AbortableRequest(
            'POST',
            Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
          )
          ..followRedirects = false
          ..headers.addAll({
            'Authorization': 'Bearer test-only-not-a-real-key',
            'Content-Type': 'application/json',
            'Accept': 'text/event-stream',
          })
          ..body = '{"messages":[{"content":"İ hello"}]}';
    await (await client.send(outgoing)).stream.drain<void>();
    expect(web.Request(urls.single.toJS, options.single).cache, 'no-store');
    expect(options.single.credentials, 'omit');
    expect(options.single.redirect, 'error');
    expect(options.single.method, 'POST');
    expect(
      utf8.decode((options.single.body! as JSUint8Array).toDart),
      outgoing.body,
    );
    final headers = web.Headers(options.single.headers);
    expect(headers.get('authorization'), 'Bearer test-only-not-a-real-key');
    expect(headers.has('cache-control'), isFalse);
  });

  test('response bytes stream before the upstream body closes', () async {
    late web.ReadableStreamDefaultController source;
    respond = (_, _) async => web.Response(
      web.ReadableStream(
        {
              'start': ((web.ReadableStreamDefaultController value) {
                source = value;
              }).toJS,
            }.jsify()!
            as JSObject,
      ),
      web.ResponseInit(
        headers: {'content-type': 'text/event-stream'}.jsify()! as JSObject,
      ),
    );
    final response = await client.send(request());
    expect(response.headers['content-type'], 'text/event-stream');
    final received = Completer<void>();
    final bytes = <int>[];
    final finished = response.stream.forEach((chunk) {
      bytes.addAll(chunk);
      if (!received.isCompleted) received.complete();
    });
    source.enqueue(Uint8List.fromList([0xc4]).toJS);
    await received.future;
    expect(bytes, [0xc4]);
    source.enqueue(Uint8List.fromList([0xb0]).toJS);
    source.close();
    await finished;
    expect(utf8.decode(bytes), 'İ');
  });

  test(
    'abort while waiting for response headers rejects the request',
    () async {
      final abort = Completer<void>();
      final dispatched = Completer<void>();
      respond = (_, init) {
        final pending = Completer<web.Response>();
        init.signal!.addEventListener(
          'abort',
          ((web.Event _) {
            pending.completeError(StateError('Stopped'));
          }).toJS,
        );
        dispatched.complete();
        return pending.future;
      };
      final result = expectLater(
        client.send(request(abort: abort)),
        throwsA(isA<http.RequestAbortedException>()),
      );
      await dispatched.future;
      abort.complete();
      await result;
    },
  );

  for (final action in ['abort', 'close', 'cancel']) {
    test(
      '$action stops a response after its headers and first chunk',
      () async {
        final abort = Completer<void>();
        final signalSeen = Completer<void>();
        late web.ReadableStreamDefaultController source;
        respond = (_, init) async {
          final body = web.ReadableStream(
            {
                  'start': ((web.ReadableStreamDefaultController value) {
                    source = value;
                  }).toJS,
                }.jsify()!
                as JSObject,
          );
          init.signal!.addEventListener(
            'abort',
            ((web.Event _) {
              signalSeen.complete();
              source.error(web.DOMException('Stopped', 'AbortError'));
            }).toJS,
          );
          return web.Response(body);
        };
        final response = await client.send(request(abort: abort));
        final firstChunk = Completer<void>();
        final errors = <Object>[];
        final done = Completer<void>();
        final subscription = response.stream.listen(
          (_) => firstChunk.complete(),
          onError: (Object error) => errors.add(error),
          onDone: done.complete,
        );
        source.enqueue(Uint8List.fromList([1]).toJS);
        await firstChunk.future;
        if (action == 'abort') abort.complete();
        if (action == 'close') client.close();
        if (action == 'cancel') await subscription.cancel();
        await signalSeen.future;
        if (action != 'cancel') {
          await done.future;
          expect(errors.single, isA<http.RequestAbortedException>());
        } else {
          expect(errors, isEmpty);
        }
      },
    );
  }

  test('closed clients refuse new requests without dispatch', () async {
    client.close();
    await expectLater(
      client.send(request()),
      throwsA(isA<http.ClientException>()),
    );
    expect(options, isEmpty);
  });
}
