import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/ai_analyser_providers.dart';
import '../widgets/insight_card.dart';

class AiAnalyserScreen extends ConsumerStatefulWidget {
  const AiAnalyserScreen({super.key});

  @override
  ConsumerState<AiAnalyserScreen> createState() => _AiAnalyserScreenState();
}

class _AiAnalyserScreenState extends ConsumerState<AiAnalyserScreen> {
  bool _refreshing = false;

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    try {
      await ref.read(aiAnalyserControllerProvider).refresh();
    } catch (_) {
      // Navigating away mid-refresh disposes the providers refresh() is
      // still awaiting — nothing to show the user for that, just stop.
    }
    if (mounted) setState(() => _refreshing = false);
  }

  @override
  Widget build(BuildContext context) {
    final insights = ref.watch(activeInsightsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Insights'),
        actions: [
          IconButton(
            icon: _refreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
            onPressed: _refreshing ? null : _refresh,
          ),
        ],
      ),
      body: insights.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  _refreshing
                      ? 'Analysing your data…'
                      : 'No insights right now — you\'re all caught up.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: insights.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final insight = insights[index];
                return InsightCard(
                  insight: insight,
                  onDismiss: () => ref.read(aiAnalyserControllerProvider).dismiss(insight.id),
                );
              },
            ),
    );
  }
}
