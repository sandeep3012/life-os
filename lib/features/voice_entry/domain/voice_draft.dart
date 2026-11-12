import '../../../core/database/app_database.dart';
import '../../../core/scheduling/repeat_schedule.dart';

enum VoiceDraftKind {
  expense,
  income,
  task,
  habit,
  event;

  static VoiceDraftKind? fromName(Object? value) {
    for (final kind in values) {
      if (kind.name == value) return kind;
    }
    return null;
  }

  bool get isMoney => this == expense || this == income;
}

/// One reading of what the person said, as the server returned it: names
/// rather than ids, dates and times as text. [resolve] matches it to this
/// phone's accounts and categories.
class VoiceDraft {
  const VoiceDraft({
    required this.kind,
    required this.summary,
    required this.title,
    this.amount,
    this.account,
    this.category,
    this.date,
    this.time,
    this.endTime,
    this.repeat = 'none',
    this.weekdays = const [],
    this.notes,
  });

  final VoiceDraftKind kind;
  final String summary;
  final String title;

  /// Major units — 250.5 — for expense and income.
  final double? amount;
  final String? account;
  final String? category;

  /// YYYY-MM-DD.
  final String? date;

  /// HH:MM, 24-hour.
  final String? time;
  final String? endTime;

  /// none | daily | weekly | monthly | yearly.
  final String repeat;

  /// 1 = Monday … 7 = Sunday.
  final List<int> weekdays;
  final String? notes;

  /// Null for anything that isn't a usable option — an unknown kind, a
  /// money record without an amount, or no title.
  static VoiceDraft? fromJson(Object? value) {
    if (value is! Map) return null;
    final kind = VoiceDraftKind.fromName(value['kind']);
    final title = (value['title'] as String?)?.trim() ?? '';
    final amount = (value['amount'] as num?)?.toDouble();
    if (kind == null || title.isEmpty) return null;
    if (kind.isMoney && (amount == null || amount <= 0)) return null;
    String? text(String key) {
      final v = (value[key] as String?)?.trim();
      return v == null || v.isEmpty ? null : v;
    }

    final repeat = value['repeat'];
    return VoiceDraft(
      kind: kind,
      summary: text('summary') ?? title,
      title: title,
      amount: amount,
      account: text('account'),
      category: text('category'),
      date: text('date'),
      time: text('time'),
      endTime: text('endTime'),
      repeat: RepeatSchedule.frequencies.contains(repeat)
          ? repeat as String
          : 'none',
      weekdays: [
        for (final d in (value['weekdays'] as List?) ?? const [])
          if (d is int && d >= 1 && d <= 7) d,
      ],
      notes: text('notes'),
    );
  }

  /// Ties the names to this phone's rows: an account or category the model
  /// named that doesn't exist here (or isn't the right kind) falls back to
  /// the one new entries start on.
  ResolvedVoiceDraft resolve({
    required List<Account> accounts,
    required List<Category> categories,
    required DateTime now,
  }) {
    Account? account;
    if (kind.isMoney && accounts.isNotEmpty) {
      account =
          _byName(accounts, this.account, (a) => a.name) ?? accounts.first;
    }
    final categoryKind = switch (kind) {
      VoiceDraftKind.expense => 'expense',
      VoiceDraftKind.income => 'income',
      _ => plannerCategoryKind,
    };
    final ofKind = [
      for (final c in categories)
        if (c.kind == categoryKind) c,
    ];
    var category = _byName(ofKind, this.category, (c) => c.name);
    // Money always gets a category, as the add form does; tasks, habits
    // and events stay uncategorised unless one was named.
    if (category == null && kind.isMoney && ofKind.isNotEmpty) {
      category = ofKind.first;
    }

    final day = _parseDate(date);
    final at = _parseTime(time);
    final end = _parseTime(endTime);
    DateTime? when;
    if (day != null || at != null) {
      final base = day ?? RepeatSchedule.day(now);
      when = DateTime(
        base.year,
        base.month,
        base.day,
        at?.$1 ?? (kind == VoiceDraftKind.event ? 9 : 0),
        at?.$2 ?? 0,
      );
    }
    DateTime? endsAt;
    if (when != null && end != null) {
      endsAt = DateTime(when.year, when.month, when.day, end.$1, end.$2);
      if (!endsAt.isAfter(when)) endsAt = null;
    }

    return ResolvedVoiceDraft(
      draft: this,
      account: account,
      category: category,
      when: when,
      endsAt: endsAt,
      hasTime: at != null,
    );
  }

  static T? _byName<T>(List<T> rows, String? name, String Function(T) of) {
    if (name == null) return null;
    final wanted = name.toLowerCase();
    for (final row in rows) {
      if (of(row).toLowerCase() == wanted) return row;
    }
    // "HDFC" for "HDFC Savings".
    for (final row in rows) {
      if (of(row).toLowerCase().contains(wanted)) return row;
    }
    return null;
  }

  static DateTime? _parseDate(String? value) {
    if (value == null) return null;
    final parsed = DateTime.tryParse(value);
    return parsed == null ? null : RepeatSchedule.day(parsed);
  }

  static (int, int)? _parseTime(String? value) {
    final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(value ?? '');
    if (match == null) return null;
    final h = int.parse(match.group(1)!), m = int.parse(match.group(2)!);
    if (h > 23 || m > 59) return null;
    return (h, m);
  }
}

/// A [VoiceDraft] matched to this phone's data, ready to save.
class ResolvedVoiceDraft {
  const ResolvedVoiceDraft({
    required this.draft,
    this.account,
    this.category,
    this.when,
    this.endsAt,
    this.hasTime = false,
    this.categoryFromHistory = false,
  });

  final VoiceDraft draft;

  /// The category came from a past entry with the same name, not from the
  /// AI's guess — shown on the card as "as last time".
  final bool categoryFromHistory;
  final Account? account;
  final Category? category;

  /// The date (and time, if [hasTime]) it's for, in local time.
  final DateTime? when;
  final DateTime? endsAt;
  final bool hasTime;

  VoiceDraftKind get kind => draft.kind;

  /// A detail changed on the card before saving. [clearCategory] removes
  /// the category (tasks, habits and events can go without one).
  ResolvedVoiceDraft copyWith({
    Account? account,
    Category? category,
    bool clearCategory = false,
    DateTime? when,
    bool? hasTime,
    bool? categoryFromHistory,
  }) {
    final nextWhen = when ?? this.when;
    // A moved date keeps the event's length.
    DateTime? nextEnd = endsAt;
    if (when != null && this.when != null && endsAt != null) {
      nextEnd = when.add(endsAt!.difference(this.when!));
    }
    return ResolvedVoiceDraft(
      draft: draft,
      account: account ?? this.account,
      category: clearCategory ? null : category ?? this.category,
      when: nextWhen,
      endsAt: nextEnd,
      hasTime: hasTime ?? this.hasTime,
      // A category picked by hand is no longer "as last time".
      categoryFromHistory:
          categoryFromHistory ??
          (category != null || clearCategory ? false : this.categoryFromHistory),
    );
  }

  /// Expense and income need an account to save into.
  bool get canSave => !kind.isMoney || account != null;

  /// Money in minor units: negative for an expense, positive for income.
  int? get amountMinor {
    final amount = draft.amount;
    if (amount == null) return null;
    final minor = (amount * 100).round();
    return kind == VoiceDraftKind.expense ? -minor : minor;
  }

  /// The repeat, for tasks, habits and events that have one, starting at
  /// [start].
  RepeatSchedule schedule(DateTime start) {
    return RepeatSchedule(
      start: start,
      frequency: draft.repeat,
      weekdays: draft.repeat == 'weekly' ? draft.weekdays : const [],
    );
  }
}
