import 'package:flutter/material.dart';

import 'browser/browser_app.dart';
export 'browser/browser_app.dart' show PsychosimsApp;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PsychosimsApp());
}
