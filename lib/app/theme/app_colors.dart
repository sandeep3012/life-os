import 'package:flutter/material.dart';

/// Module accent, status, and spend-category colors, mirrored 1:1 from the
/// validated prototype palette (see the published HTML mock-up). Values are
/// exposed as a [ThemeExtension] so every screen reads the brightness-correct
/// variant via `Theme.of(context).extension<AppColors>()!`.
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.finance,
    required this.spend,
    required this.habits,
    required this.tasks,
    required this.documents,
    required this.calendar,
    required this.goals,
    required this.aiAnalyser,
    required this.notes,
    required this.good,
    required this.warning,
    required this.critical,
    required this.info,
    required this.catDining,
    required this.catGroceries,
    required this.catTransport,
    required this.catRent,
    required this.catEntertainment,
    required this.catOther,
  });

  final Color finance;
  final Color spend;
  final Color habits;
  final Color tasks;
  final Color documents;
  final Color calendar;
  final Color goals;
  final Color aiAnalyser;
  final Color notes;

  final Color good;
  final Color warning;
  final Color critical;
  final Color info;

  final Color catDining;
  final Color catGroceries;
  final Color catTransport;
  final Color catRent;
  final Color catEntertainment;
  final Color catOther;

  List<Color> get modulePalette => [
    finance,
    spend,
    habits,
    tasks,
    documents,
    calendar,
    goals,
    aiAnalyser,
    notes,
  ];

  List<Color> get spendCategoryPalette => [
    catDining,
    catGroceries,
    catTransport,
    catRent,
    catEntertainment,
    catOther,
  ];

  static const seed = Color(0xFF6750E7);

  static const light = AppColors(
    finance: Color(0xFF1E8F5E),
    spend: Color(0xFFE8611B),
    habits: Color(0xFF0E9488),
    tasks: Color(0xFF2F6FED),
    documents: Color(0xFFA63FBE),
    calendar: Color(0xFFD63860),
    goals: Color(0xFF4347B0),
    aiAnalyser: Color(0xFF0891A8),
    notes: Color(0xFFA67C00),
    good: Color(0xFF1E8F5E),
    warning: Color(0xFFC77D0A),
    critical: Color(0xFFD6304A),
    info: Color(0xFF2F6FED),
    catDining: Color(0xFFE0475A),
    catGroceries: Color(0xFF2E9E63),
    catTransport: Color(0xFF2F6FED),
    catRent: Color(0xFFA67C00),
    catEntertainment: Color(0xFFA63FBE),
    catOther: Color(0xFF8B84A3),
  );

  static const dark = AppColors(
    finance: Color(0xFF33A873),
    spend: Color(0xFFD9692F),
    habits: Color(0xFF1F9E8E),
    tasks: Color(0xFF6C9CFF),
    documents: Color(0xFFD283DE),
    calendar: Color(0xFFE86D86),
    goals: Color(0xFF8D86EE),
    aiAnalyser: Color(0xFF3FC0D9),
    notes: Color(0xFFD6B04E),
    good: Color(0xFF33A873),
    warning: Color(0xFFE0A429),
    critical: Color(0xFFE86D7F),
    info: Color(0xFF6C9CFF),
    catDining: Color(0xFFE86D7F),
    catGroceries: Color(0xFF4CB884),
    catTransport: Color(0xFF6C9CFF),
    catRent: Color(0xFFD6B04E),
    catEntertainment: Color(0xFFD283DE),
    catOther: Color(0xFF8B84A3),
  );

  @override
  AppColors copyWith({
    Color? finance,
    Color? spend,
    Color? habits,
    Color? tasks,
    Color? documents,
    Color? calendar,
    Color? goals,
    Color? aiAnalyser,
    Color? notes,
    Color? good,
    Color? warning,
    Color? critical,
    Color? info,
    Color? catDining,
    Color? catGroceries,
    Color? catTransport,
    Color? catRent,
    Color? catEntertainment,
    Color? catOther,
  }) {
    return AppColors(
      finance: finance ?? this.finance,
      spend: spend ?? this.spend,
      habits: habits ?? this.habits,
      tasks: tasks ?? this.tasks,
      documents: documents ?? this.documents,
      calendar: calendar ?? this.calendar,
      goals: goals ?? this.goals,
      aiAnalyser: aiAnalyser ?? this.aiAnalyser,
      notes: notes ?? this.notes,
      good: good ?? this.good,
      warning: warning ?? this.warning,
      critical: critical ?? this.critical,
      info: info ?? this.info,
      catDining: catDining ?? this.catDining,
      catGroceries: catGroceries ?? this.catGroceries,
      catTransport: catTransport ?? this.catTransport,
      catRent: catRent ?? this.catRent,
      catEntertainment: catEntertainment ?? this.catEntertainment,
      catOther: catOther ?? this.catOther,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      finance: Color.lerp(finance, other.finance, t)!,
      spend: Color.lerp(spend, other.spend, t)!,
      habits: Color.lerp(habits, other.habits, t)!,
      tasks: Color.lerp(tasks, other.tasks, t)!,
      documents: Color.lerp(documents, other.documents, t)!,
      calendar: Color.lerp(calendar, other.calendar, t)!,
      goals: Color.lerp(goals, other.goals, t)!,
      aiAnalyser: Color.lerp(aiAnalyser, other.aiAnalyser, t)!,
      notes: Color.lerp(notes, other.notes, t)!,
      good: Color.lerp(good, other.good, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      critical: Color.lerp(critical, other.critical, t)!,
      info: Color.lerp(info, other.info, t)!,
      catDining: Color.lerp(catDining, other.catDining, t)!,
      catGroceries: Color.lerp(catGroceries, other.catGroceries, t)!,
      catTransport: Color.lerp(catTransport, other.catTransport, t)!,
      catRent: Color.lerp(catRent, other.catRent, t)!,
      catEntertainment: Color.lerp(catEntertainment, other.catEntertainment, t)!,
      catOther: Color.lerp(catOther, other.catOther, t)!,
    );
  }
}

extension AppColorsContext on BuildContext {
  AppColors get appColors => Theme.of(this).extension<AppColors>()!;
}
