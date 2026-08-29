import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/features/voice_commands/domain/voice_command.dart';
import 'package:life_manager/features/voice_commands/domain/voice_command_parser.dart';

void main() {
  test('parses a local task command', () {
    final command = parseVoiceCommand('Add task call the plumber');
    expect(command, isA<CreateTaskVoiceCommand>());
    expect((command as CreateTaskVoiceCommand).title, 'call the plumber');
  });
}
