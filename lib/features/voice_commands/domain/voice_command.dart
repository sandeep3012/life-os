sealed class VoiceCommand {
  const VoiceCommand(this.transcript);
  final String transcript;
}

class CreateTaskVoiceCommand extends VoiceCommand {
  const CreateTaskVoiceCommand(super.transcript, this.title);
  final String title;
}

class CompleteHabitVoiceCommand extends VoiceCommand {
  const CompleteHabitVoiceCommand(super.transcript, this.habitName);
  final String habitName;
}

class UnrecognisedVoiceCommand extends VoiceCommand {
  const UnrecognisedVoiceCommand(super.transcript);
}
