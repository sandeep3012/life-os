import 'voice_command.dart';

/// Deliberately local and deterministic. Broader natural-language support can
/// be added as small, independently tested intent parsers over time.
VoiceCommand parseVoiceCommand(String transcript) {
  final text = transcript.trim();
  final lower = text.toLowerCase();
  const taskPrefixes = ['add task ', 'create task ', 'remind me to '];
  for (final prefix in taskPrefixes) {
    if (lower.startsWith(prefix) && text.length > prefix.length) {
      return CreateTaskVoiceCommand(text, text.substring(prefix.length).trim());
    }
  }
  const habitPrefix = 'complete habit ';
  if (lower.startsWith(habitPrefix) && text.length > habitPrefix.length) {
    return CompleteHabitVoiceCommand(text, text.substring(habitPrefix.length).trim());
  }
  return UnrecognisedVoiceCommand(text);
}
