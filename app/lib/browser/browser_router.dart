import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Keep Flutter's default hash URL strategy: every route is served from the
/// same static index, including reloads on GitHub Pages.
String validBrowserPath(String value) =>
    const ['/', '/loadout', '/session', '/history', '/settings'].contains(value)
    ? value
    : '/';

class BrowserRouteParser extends RouteInformationParser<String> {
  const BrowserRouteParser();

  @override
  Future<String> parseRouteInformation(RouteInformation routeInformation) =>
      SynchronousFuture(validBrowserPath(routeInformation.uri.path));

  @override
  RouteInformation restoreRouteInformation(String configuration) =>
      RouteInformation(uri: Uri(path: validBrowserPath(configuration)));
}

/// Flutter owns route reporting and browser history. A stable shell page keeps
/// the game controller and widget state alive when a history entry changes.
class BrowserRouterDelegate extends RouterDelegate<String>
    with ChangeNotifier, PopNavigatorRouterDelegateMixin<String> {
  BrowserRouterDelegate({required this.pageBuilder});

  final Widget Function(BuildContext context) pageBuilder;
  String path = '/';

  @override
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  String get currentConfiguration => path;

  void navigate(String value) {
    final next = validBrowserPath(value);
    if (next == path) return;
    path = next;
    notifyListeners();
  }

  @override
  Future<void> setNewRoutePath(String configuration) {
    navigate(configuration);
    return SynchronousFuture(null);
  }

  @override
  Widget build(BuildContext context) => Navigator(
    key: navigatorKey,
    pages: [
      MaterialPage<void>(
        key: const ValueKey('psychosims-shell'),
        child: Builder(builder: pageBuilder),
      ),
    ],
    onDidRemovePage: (_) {},
  );
}
