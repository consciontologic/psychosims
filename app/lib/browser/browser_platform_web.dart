import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'browser_store.dart';

class _LocalBrowserStore implements BrowserStore {
  @override
  String? read() => web.window.localStorage.getItem(browserSaveKey);
  @override
  void write(String value) =>
      web.window.localStorage.setItem(browserSaveKey, value);
  @override
  void clear() => web.window.localStorage.removeItem(browserSaveKey);
}

BrowserStore createBrowserStore() => _LocalBrowserStore();
bool browserOnline() => web.window.navigator.onLine;

Stream<bool> onlineChanges() {
  late StreamController<bool> controller;
  final listener = ((web.Event event) => controller.add(browserOnline())).toJS;
  controller = StreamController<bool>(
    onListen: () {
      web.window.addEventListener('online', listener);
      web.window.addEventListener('offline', listener);
    },
    onCancel: () {
      web.window.removeEventListener('online', listener);
      web.window.removeEventListener('offline', listener);
    },
  );
  return controller.stream;
}
