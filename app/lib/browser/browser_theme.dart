import 'package:flutter/material.dart';

import '../shared/l10n.dart';

/// Local, original artwork and a shared ink / pigment / paper visual language.
abstract final class Noir {
  static const ink = Color(0xFF10191A);
  static const panel = Color(0xFF1C2829);
  static const paper = Color(0xFFF3E6CD);
  static const muted = Color(0xFFB9BAAD);
  static const gold = Color(0xFFE8B76F);
  static const rust = Color(0xFFEC9776);
  static const teal = Color(0xFF8BC7BD);
  static const line = Color(0xFF586563);
  static const scene = 'assets/art/clinic-noir.png';
  static const portrait = 'assets/art/restless-hour-portrait.png';

  static ThemeData theme({bool highContrast = false}) {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: gold,
          brightness: Brightness.dark,
          contrastLevel: highContrast ? 1 : 0,
        ).copyWith(
          primary: gold,
          onPrimary: ink,
          secondary: teal,
          onSecondary: ink,
          surface: ink,
          onSurface: highContrast ? Colors.white : paper,
          onSurfaceVariant: highContrast ? paper : muted,
          primaryContainer: const Color(0xFF39392B),
          onPrimaryContainer: paper,
          secondaryContainer: panel,
          onSecondaryContainer: paper,
          error: rust,
          outline: highContrast ? paper : line,
        );
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      fontFamily: 'Roboto',
      fontFamilyFallback: const ['NotoSansSymbols'],
      scaffoldBackgroundColor: ink,
      visualDensity: VisualDensity.standard,
    );
    TextStyle display(double size) => TextStyle(
      fontFamily: 'NotoSerif',
      fontFamilyFallback: const ['NotoSansSymbols'],
      fontSize: size,
      fontWeight: FontWeight.w700,
      height: 1.12,
      letterSpacing: -0.6,
      color: scheme.onSurface,
    );
    final border = WidgetStateProperty.resolveWith<BorderSide>((states) {
      return BorderSide(
        color: states.contains(WidgetState.focused) ? paper : scheme.outline,
        width: states.contains(WidgetState.focused) ? 3 : 1,
      );
    });
    final button = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
      ),
      side: border,
      textStyle: const WidgetStatePropertyAll(
        TextStyle(
          fontFamily: 'Roboto',
          fontFamilyFallback: ['NotoSansSymbols'],
          fontWeight: FontWeight.w700,
          fontSize: 15,
        ),
      ),
    );
    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        displayLarge: display(68),
        displayMedium: display(48),
        headlineLarge: display(36),
        headlineMedium: display(30),
        headlineSmall: display(24),
        titleLarge: display(20),
        bodyLarge: base.textTheme.bodyLarge!.copyWith(
          fontSize: 17,
          height: 1.55,
          color: scheme.onSurface,
        ),
        bodyMedium: base.textTheme.bodyMedium!.copyWith(
          fontSize: 15,
          height: 1.5,
          color: scheme.onSurface,
        ),
        labelSmall: base.textTheme.labelSmall!.copyWith(
          fontSize: 11,
          letterSpacing: 1.6,
          color: muted,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: ink,
        foregroundColor: paper,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontFamily: 'NotoSerif',
          fontFamilyFallback: ['NotoSansSymbols'],
          fontSize: 23,
          fontWeight: FontWeight.w700,
          color: paper,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(style: button),
      outlinedButtonTheme: OutlinedButtonThemeData(style: button),
      textButtonTheme: TextButtonThemeData(
        style: button.copyWith(
          side: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.focused)
                ? const BorderSide(color: paper, width: 3)
                : BorderSide.none,
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: ink,
        indicatorColor: const Color(0xFF394443),
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => base.textTheme.labelMedium!.copyWith(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w400,
            color: states.contains(WidgetState.selected) ? gold : paper,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: panel,
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(2),
          side: BorderSide(color: scheme.outline),
        ),
      ),
      dividerTheme: DividerThemeData(color: scheme.outline, thickness: 1),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: panel,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: gold, width: 2),
        ),
        contentPadding: EdgeInsets.all(16),
      ),
      expansionTileTheme: const ExpansionTileThemeData(
        iconColor: gold,
        textColor: paper,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: panel,
        shape: RoundedRectangleBorder(),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: gold,
        linearTrackColor: line,
      ),
    );
  }
}

class NoirEyebrow extends StatelessWidget {
  const NoirEyebrow(this.text, {super.key, this.color = Noir.gold});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      color: color,
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 2.2,
      height: 1.5,
    ),
  );
}

class PatientPortrait extends StatelessWidget {
  const PatientPortrait({super.key, required this.height, this.width});
  final double height;
  final double? width;

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: L10n.noirPortraitDescription,
    child: Image.asset(
      Noir.portrait,
      width: width,
      height: height,
      fit: BoxFit.cover,
      alignment: const Alignment(0, -0.5),
      excludeFromSemantics: true,
    ),
  );
}

class NoirMeter extends StatelessWidget {
  const NoirMeter({
    super.key,
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    child: ExcludeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 10),
          TweenAnimationBuilder<double>(
            tween: Tween(end: (value / 100).clamp(0, 1)),
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 350),
            builder: (context, progress, _) => LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              color: color,
              backgroundColor: Noir.line,
            ),
          ),
        ],
      ),
    ),
  );
}
