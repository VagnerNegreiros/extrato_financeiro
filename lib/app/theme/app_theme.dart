import 'package:flutter/material.dart';

/// Spacing scale (multiples of 4). Widgets never use magic numbers.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

abstract final class AppRadius {
  static const double card = 16;
  static const double chip = 8;
}

/// Semantic colors for money, beyond the Material color scheme.
///
/// Colors are never the only signal: amounts always carry a sign and an
/// icon too (see `AmountText` and `StatusChip`).
@immutable
final class FinancialColors extends ThemeExtension<FinancialColors> {
  const new({
    required this.credit,
    required this.debit,
    required this.completed,
    required this.pending,
    required this.failed,
    required this.reversed,
    required this.warning,
  });

  static const light = FinancialColors(
    credit: Color(0xFF1B7F3B),
    debit: Color(0xFFB3261E),
    completed: Color(0xFF1B7F3B),
    pending: Color(0xFF8A5A00),
    failed: Color(0xFFB3261E),
    reversed: Color(0xFF5E5E70),
    warning: Color(0xFF8A5A00),
  );

  static const dark = FinancialColors(
    credit: Color(0xFF7EDC98),
    debit: Color(0xFFFFB4AB),
    completed: Color(0xFF7EDC98),
    pending: Color(0xFFFFCF70),
    failed: Color(0xFFFFB4AB),
    reversed: Color(0xFFC6C5D6),
    warning: Color(0xFFFFCF70),
  );

  final Color credit;
  final Color debit;
  final Color completed;
  final Color pending;
  final Color failed;
  final Color reversed;
  final Color warning;

  @override
  FinancialColors copyWith({
    Color? credit,
    Color? debit,
    Color? completed,
    Color? pending,
    Color? failed,
    Color? reversed,
    Color? warning,
  }) => FinancialColors(
    credit: credit ?? this.credit,
    debit: debit ?? this.debit,
    completed: completed ?? this.completed,
    pending: pending ?? this.pending,
    failed: failed ?? this.failed,
    reversed: reversed ?? this.reversed,
    warning: warning ?? this.warning,
  );

  @override
  FinancialColors lerp(FinancialColors? other, double t) {
    if (other == null) return this;
    return FinancialColors(
      credit: Color.lerp(credit, other.credit, t)!,
      debit: Color.lerp(debit, other.debit, t)!,
      completed: Color.lerp(completed, other.completed, t)!,
      pending: Color.lerp(pending, other.pending, t)!,
      failed: Color.lerp(failed, other.failed, t)!,
      reversed: Color.lerp(reversed, other.reversed, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
    );
  }
}

extension FinancialColorsContext on BuildContext {
  FinancialColors get financialColors =>
      Theme.of(this).extension<FinancialColors>() ?? FinancialColors.light;
}

abstract final class AppTheme {
  static const seedColor = Color(0xFF0E7C66);

  static ThemeData get light => _build(Brightness.light);

  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
    );
    return ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      extensions: [
        if (brightness == Brightness.light)
          FinancialColors.light
        else
          FinancialColors.dark,
      ],
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.chip),
        ),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

/// Monetary values use tabular figures so digits line up in lists.
const tabularFigures = [FontFeature.tabularFigures()];
