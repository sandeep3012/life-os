import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/router/route_paths.dart';

class _MoreEntry {
  const _MoreEntry(this.label, this.icon, this.color, this.path);

  final String label;
  final IconData icon;
  final Color color;
  final String path;
}

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    final entries = [
      _MoreEntry('Search', LucideIcons.search, appColors.info, RoutePaths.search),
      _MoreEntry('Notes', LucideIcons.notebookPen, appColors.notes, RoutePaths.notes),
      _MoreEntry('Documents', LucideIcons.folders, appColors.documents, RoutePaths.documents),
      _MoreEntry('Goals', LucideIcons.flag, appColors.goals, RoutePaths.goals),
      _MoreEntry('AI Analyser', LucideIcons.chartLine, appColors.aiAnalyser, RoutePaths.aiAnalyser),
      _MoreEntry('Settings', LucideIcons.settings, Colors.grey, RoutePaths.settings),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: GridView.builder(
        padding: const EdgeInsets.all(AppSpacing.md),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: AppSpacing.md,
          crossAxisSpacing: AppSpacing.md,
          childAspectRatio: 1.1,
        ),
        itemCount: entries.length,
        itemBuilder: (context, index) {
          final entry = entries[index];
          return Card(
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => context.push(entry.path),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: entry.color.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(entry.icon, size: 32, color: entry.color),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(entry.label, style: Theme.of(context).textTheme.titleSmall),
                ],
              ),
            ),
          ).animate().fadeIn(delay: (60 * index).ms).slideY(begin: 0.1, end: 0);
        },
      ),
    );
  }
}
