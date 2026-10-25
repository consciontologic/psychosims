import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psychosims/browser/browser_theme.dart';

void main() {
  for (final highContrast in [false, true]) {
    test(
      'ordinary text keeps bundled font coverage at contrast $highContrast',
      () {
        final theme = Noir.theme(highContrast: highContrast);
        for (final style in [
          theme.textTheme.bodyLarge,
          theme.textTheme.bodyMedium,
          theme.textTheme.labelSmall,
          theme.navigationBarTheme.labelTextStyle!.resolve({}),
          theme.navigationBarTheme.labelTextStyle!.resolve({
            WidgetState.selected,
          }),
        ]) {
          expect(style!.fontFamily, 'Roboto');
          expect(style.fontFamilyFallback, contains('NotoSansSymbols'));
        }
      },
    );
  }
}
