import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../sync/application/sync_providers.dart';
import '../domain/voice_draft.dart';
import 'sample_voice_parser.dart';

/// What the server needs to read one sentence: the sentence, and enough of
/// the person's setup to pick their own accounts and categories.
class VoiceRequest {
  const VoiceRequest({
    required this.text,
    required this.now,
    required this.timeZone,
    required this.currency,
    required this.accounts,
    required this.expenseCategories,
    required this.incomeCategories,
    required this.plannerCategories,
  });

  final String text;
  final DateTime now;
  final String timeZone;
  final String currency;
  final List<String> accounts;
  final List<String> expenseCategories;
  final List<String> incomeCategories;
  final List<String> plannerCategories;

  Map<String, Object?> toJson() => {
    'text': text,
    // Local wall-clock time with its offset, so "tomorrow 6 pm" lands on
    // the person's tomorrow.
    'now': _localIso(now),
    'timeZone': timeZone,
    'currency': currency,
    'accounts': accounts,
    'categories': {
      'expense': expenseCategories,
      'income': incomeCategories,
      'planner': plannerCategories,
    },
  };

  static String _localIso(DateTime t) {
    final offset = t.timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    String two(int n) => n.abs().toString().padLeft(2, '0');
    final local = t.toIso8601String().split('.').first;
    return '$local$sign${two(offset.inHours)}:${two(offset.inMinutes % 60)}';
  }
}

/// Something to tell the person instead of options.
class VoiceParseException implements Exception {
  const VoiceParseException(this.message);
  final String message;

  @override
  String toString() => message;
}

abstract class VoiceParser {
  /// Up to three readings, the most likely first.
  Future<List<VoiceDraft>> parse(VoiceRequest request);
}

/// [VoiceParser] over the `voice-parse` Edge Function
/// (`supabase/functions/voice-parse`).
class SupabaseVoiceParser implements VoiceParser {
  SupabaseVoiceParser(this._client);

  final SupabaseClient _client;

  @override
  Future<List<VoiceDraft>> parse(VoiceRequest request) async {
    if (_client.auth.currentSession == null) {
      throw const VoiceParseException('Sign in to use voice entry.');
    }
    final FunctionResponse response;
    try {
      response = await _client.functions.invoke(
        'voice-parse',
        body: request.toJson(),
      );
    } on FunctionException catch (e) {
      throw VoiceParseException(_message(e.status, e.details));
    } on Object {
      throw const VoiceParseException(
        "Couldn't reach the server. Check your connection and try again.",
      );
    }
    final data = response.data;
    final options = data is Map ? data['options'] : null;
    final drafts = [
      for (final o in (options as List?) ?? const [])
        ?VoiceDraft.fromJson(o),
    ];
    if (drafts.isEmpty) {
      throw const VoiceParseException(
        "Couldn't work out what to add. Try saying it another way.",
      );
    }
    return drafts.take(3).toList();
  }

  static String _message(int status, Object? details) {
    final code = details is Map ? details['error'] : null;
    return switch ((status, code)) {
      (401, _) => 'Sign in to use voice entry.',
      (429, _) => "You've reached today's voice entry limit. Try again "
          'tomorrow.',
      (422, _) => "Couldn't work out what to add. Try saying it another way.",
      (503, _) => 'Voice entry is busy right now. Try again in a moment.',
      _ => "Couldn't understand that just now. Try again in a moment.",
    };
  }
}

/// The sample parser in a debug build's test mode; otherwise the real
/// service, or null in a build without Supabase.
final voiceParserProvider = Provider<VoiceParser?>((ref) {
  if (ref.watch(voiceTestModeProvider)) return const SampleVoiceParser();
  final client = ref.watch(supabaseClientProvider);
  return client == null ? null : SupabaseVoiceParser(client);
});
