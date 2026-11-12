import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../sync/application/sync_providers.dart';
import '../domain/voice_draft.dart';
import 'voice_parser.dart';

/// Debug builds only: voice entry without the server or the AI. Three
/// sample readings are built from the words actually heard — an expense, a
/// task and an event or habit — so speech recognition, the option cards,
/// saving and Undo can all be tried before Supabase is set up. The readings
/// are deliberately simple; they are not what the AI would return.
class SampleVoiceParser implements VoiceParser {
  const SampleVoiceParser();

  @override
  Future<List<VoiceDraft>> parse(VoiceRequest request) async {
    // Long enough to see "Working it out…".
    await Future<void>.delayed(const Duration(milliseconds: 600));
    final text = request.text.trim();
    final lower = text.toLowerCase();
    final now = request.now;
    final title = _title(text);
    final amount = _amount(lower);
    final date = _date(lower, now);
    final time = _time(lower);
    final repeats = RegExp(r'\b(every|daily|each)\b').hasMatch(lower);
    final account = _mentioned(lower, request.accounts);
    final expenseCategory = _guess(lower, request.expenseCategories);
    final plannerCategory = _guess(lower, request.plannerCategories);

    String day(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';

    final options = <Map<String, Object?>>[
      {
        'kind': 'expense',
        'summary': 'Sample · expense',
        'title': title,
        // An expense needs an amount; 100 stands in when none was said.
        'amount': amount ?? 100,
        'account': account,
        'category': expenseCategory,
        'date': day(date ?? now),
      },
      {
        'kind': 'task',
        'summary': 'Sample · task',
        'title': title,
        'category': plannerCategory,
        'date': date == null && time == null ? null : day(date ?? now),
        'time': time,
      },
      if (repeats)
        {
          'kind': 'habit',
          'summary': 'Sample · habit',
          'title': title,
          'category': plannerCategory,
          'time': time,
          'repeat': 'daily',
        }
      else
        {
          'kind': 'event',
          'summary': 'Sample · event',
          'title': title,
          'date': day(date ?? now.add(const Duration(days: 1))),
          'time': time ?? '10:00',
        },
    ];
    return [for (final o in options) ?VoiceDraft.fromJson(o)];
  }

  /// Everyday words → words a category name for them is likely to contain.
  static const _synonyms = <String, List<String>>{
    'dinner': ['dining', 'food', 'restaurant', 'eating'],
    'lunch': ['dining', 'food', 'restaurant', 'eating'],
    'breakfast': ['dining', 'food', 'restaurant', 'eating'],
    'restaurant': ['dining', 'food', 'eating'],
    'swiggy': ['dining', 'food', 'delivery'],
    'zomato': ['dining', 'food', 'delivery'],
    'coffee': ['dining', 'food', 'cafe'],
    'grocery': ['groceries', 'grocery'],
    'groceries': ['groceries', 'grocery'],
    'vegetables': ['groceries', 'grocery'],
    'milk': ['groceries', 'grocery'],
    'uber': ['transport', 'travel', 'cab'],
    'ola': ['transport', 'travel', 'cab'],
    'cab': ['transport', 'travel'],
    'taxi': ['transport', 'travel'],
    'petrol': ['transport', 'fuel', 'car'],
    'fuel': ['transport', 'fuel', 'car'],
    'metro': ['transport', 'travel'],
    'rent': ['rent', 'housing', 'home'],
    'movie': ['entertainment', 'fun'],
    'netflix': ['subscriptions', 'entertainment'],
    'salary': ['salary', 'income'],
    'gym': ['fitness', 'health', 'exercise'],
    'workout': ['fitness', 'health', 'exercise'],
    'run': ['fitness', 'health', 'exercise'],
    'meditate': ['wellness', 'health', 'mind'],
    'read': ['learning', 'reading', 'study'],
    'study': ['learning', 'study', 'work'],
    'doctor': ['health', 'medical'],
    'medicine': ['health', 'medical'],
  };

  /// A category whose name was said, or that a said word points to.
  static String? _guess(String lower, List<String> names) {
    final said = _mentioned(lower, names);
    if (said != null) return said;
    final words = RegExp(r'[a-z]+').allMatches(lower).map((m) => m.group(0)!);
    for (final word in words) {
      for (final hint in _synonyms[word] ?? const <String>[]) {
        for (final name in names) {
          if (name.toLowerCase().contains(hint)) return name;
        }
      }
    }
    return null;
  }

  /// A name from [names] that appears in what was said ("HDFC" → "HDFC
  /// Savings"), longest first so "Credit Card" beats "Card".
  static String? _mentioned(String lower, List<String> names) {
    final byLength = [...names]..sort((a, b) => b.length - a.length);
    for (final name in byLength) {
      final n = name.toLowerCase();
      if (lower.contains(n)) return name;
      final first = n.split(RegExp(r'\s+')).first;
      if (first.length >= 3 && RegExp('\\b${RegExp.escape(first)}\\b').hasMatch(lower)) {
        return name;
      }
    }
    return null;
  }

  static String _title(String text) {
    final t = text.length > 48 ? '${text.substring(0, 48).trim()}…' : text;
    return t.isEmpty ? 'Untitled' : t[0].toUpperCase() + t.substring(1);
  }

  static double? _amount(String lower) {
    final m = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(lower.replaceAll(',', ''));
    return m == null ? null : double.tryParse(m.group(1)!);
  }

  static DateTime? _date(String lower, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    if (lower.contains('tomorrow') || lower.contains('kal')) {
      return today.add(const Duration(days: 1));
    }
    if (lower.contains('today') || lower.contains('aaj')) return today;
    return null;
  }

  /// "at 6", "6 pm", "6:30 am", "18:00".
  static String? _time(String lower) {
    final m = RegExp(
      r'\b(?:at\s+)?(\d{1,2})(?::(\d{2}))?\s*(am|pm|a\.m\.|p\.m\.)?',
    ).allMatches(lower).where((m) {
      // Only something that reads as a time: "at 6", "6 pm" or "6:30".
      return lower.substring(m.start, m.end).startsWith('at') ||
          m.group(2) != null ||
          m.group(3) != null;
    }).firstOrNull;
    if (m == null) return null;
    var h = int.parse(m.group(1)!);
    final min = int.tryParse(m.group(2) ?? '0') ?? 0;
    final pm = (m.group(3) ?? '').startsWith('p');
    if (pm && h < 12) h += 12;
    if (!pm && (m.group(3) ?? '').startsWith('a') && h == 12) h = 0;
    if (h > 23 || min > 59) return null;
    return '${h.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')}';
  }
}

/// Settings → Developer tools → "Voice entry test mode". Debug builds only;
/// release builds always use the real service. It starts on only when
/// there's no signed-in Supabase session to reach the real one with — the
/// switch isn't saved, so it shouldn't fall back to samples on every launch
/// once the server is set up.
class VoiceTestMode extends Notifier<bool> {
  @override
  bool build() {
    if (!kDebugMode) return false;
    final client = ref.read(supabaseClientProvider);
    return client?.auth.currentSession == null;
  }

  void set(bool on) => state = kDebugMode && on;
}

final voiceTestModeProvider = NotifierProvider<VoiceTestMode, bool>(
  VoiceTestMode.new,
);
