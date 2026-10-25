/// One atomic browser-local snapshot. Credentials never enter this interface.
abstract interface class BrowserStore {
  String? read();
  void write(String value);
  void clear();
}

const browserSaveKey = 'psychosims.offline.v1';

/// In-memory implementation for deterministic tests and non-browser previews.
class MemoryBrowserStore implements BrowserStore {
  String? value;
  bool failWrites = false;
  @override
  String? read() => value;
  @override
  void write(String value) {
    if (failWrites) throw StateError('Storage unavailable');
    this.value = value;
  }

  @override
  void clear() {
    if (failWrites) throw StateError('Storage unavailable');
    value = null;
  }
}
