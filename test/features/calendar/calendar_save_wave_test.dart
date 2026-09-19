import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/haptics.dart';
import 'package:life_manager/features/calendar/presentation/widgets/calendar_save_wave.dart';

void main() {
  testWidgets('Android save uses native pattern; disabled haptics skip it', (
    tester,
  ) async {
    const channel = MethodChannel('com.sandeep.lifeos/haptics');
    final calls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      calls.add(call.method);
      return null;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    await const LifeHaptics(enabled: true).calendarSave();
    await const LifeHaptics(enabled: false).calendarSave();
    expect(calls, ['calendarSave']);
  });
  for (final reduceMotion in [false, true]) {
    testWidgets(
      'save feedback renders and clears (reduceMotion: $reduceMotion)',
      (tester) async {
        var taps = 0;
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(disableAnimations: reduceMotion),
              child: child!,
            ),
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () {
                      taps++;
                    },
                    child: const Text('Still interactive'),
                  ),
                ),
                floatingActionButton: FloatingActionButton(
                  onPressed: () => showCalendarSaveWave(context),
                  child: const Icon(Icons.check),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.byType(FloatingActionButton));
        await tester.pump();
        expect(tester.takeException(), isNull);
        await tester.pump(Duration(milliseconds: reduceMotion ? 40 : 300));
        final wave = find.byWidgetPredicate(
          (widget) =>
              widget is CustomPaint &&
              widget.painter.runtimeType.toString() ==
                  '_CalendarSaveWavePainter',
        );
        expect(wave, findsOneWidget);
        expect(tester.getSize(wave), tester.getSize(find.byType(Scaffold)));
        expect(wave, reduceMotion ? (paints..rect()) : (paints..circle()));
        await tester.tap(find.text('Still interactive'));
        expect(taps, 1);
        await tester.pumpAndSettle();
        expect(wave, findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('calendar save emits two haptics and honors disabled gate', (
    tester,
  ) async {
    final calls = <Object?>[];
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') calls.add(call.arguments);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final feedback = const LifeHaptics(enabled: true).calendarSave();
    await tester.pump();
    expect(calls, ['HapticFeedbackType.lightImpact']);
    await tester.pump(const Duration(milliseconds: 100));
    await feedback;
    expect(calls, [
      'HapticFeedbackType.lightImpact',
      'HapticFeedbackType.mediumImpact',
    ]);
    calls.clear();
    await const LifeHaptics(enabled: false).calendarSave();
    expect(calls, isEmpty);
    debugDefaultTargetPlatformOverride = null;
  });
}
