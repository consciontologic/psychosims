import 'browser_store.dart';

BrowserStore createBrowserStore() => MemoryBrowserStore();
bool browserOnline() => true;
Stream<bool> onlineChanges() => const Stream.empty();
