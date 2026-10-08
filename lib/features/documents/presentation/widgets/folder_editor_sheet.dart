import 'package:flutter/material.dart';

import '../../../../app/motion.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/widgets/compact_editor_sheet.dart';
import '../../domain/folder_icon.dart';

/// The "New folder" / "Edit folder" sheet: name, icon and colour. Shared by
/// the Documents screen and every folder's own screen, where it makes a
/// folder inside that folder.
class FolderEditorResult {
  const FolderEditorResult({
    required this.name,
    required this.iconName,
    required this.colorHex,
  });
  final String name;
  final String iconName;
  final String colorHex;
}

// Palette of folder accent colours.
const _folderColors = [
  ('Ocean', '#4B7BA6'),
  ('Terracotta', '#C2703D'),
  ('Sage', '#3E7C5A'),
  ('Lavender', '#7C6BC4'),
  ('Teal', '#3FA6A0'),
  ('Rose', '#B85C6E'),
  ('Amber', '#C49A3D'),
  ('Forest', '#2D6B4F'),
  ('Slate', '#5A6B7C'),
  ('Plum', '#7A3D8C'),
  ('Coral', '#D4624A'),
  ('Steel', '#4A6B8C'),
];

Future<FolderEditorResult?> showFolderEditorSheet(
  BuildContext context, {
  Folder? initial,
}) {
  return showCompactEditorSheet<FolderEditorResult>(
    context: context,
    builder: (ctx) => _CreateFolderSheet(initial: initial),
  );
}

class _CreateFolderSheet extends StatefulWidget {
  const _CreateFolderSheet({this.initial});
  final Folder? initial;

  @override
  State<_CreateFolderSheet> createState() => _CreateFolderSheetState();
}

class _CreateFolderSheetState extends State<_CreateFolderSheet> {
  late final _controller = TextEditingController(
    text: widget.initial?.name ?? '',
  );
  late String _selectedIcon =
      widget.initial?.iconName ?? FolderIcon.general.name;
  late String _selectedColorHex =
      widget.initial?.colorHex ?? _folderColors.first.$2;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = Theme.of(context).colorScheme;

    return CompactEditorSheet(
      title: widget.initial != null ? 'Edit folder' : 'New folder',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Folder name'),
          ),
          const SizedBox(height: 16),
          Text(
            'Icon',
            style: theme.textTheme.labelMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final fi in FolderIcon.all)
                GestureDetector(
                  onTap: () => setState(() => _selectedIcon = fi.name),
                  child: AnimatedContainer(
                    duration: AppMotion.of(
                      context,
                      const Duration(milliseconds: 130),
                    ),
                    width: 60,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: _selectedIcon == fi.name
                          ? colors.primary.withValues(alpha: 0.12)
                          : colors.surfaceContainerHighest.withValues(
                              alpha: 0.5,
                            ),
                      borderRadius: BorderRadius.circular(12),
                      border: _selectedIcon == fi.name
                          ? Border.all(
                              color: colors.primary.withValues(alpha: 0.4),
                            )
                          : null,
                    ),
                    child: Column(
                      children: [
                        Icon(
                          fi.icon,
                          size: 22,
                          color: _selectedIcon == fi.name
                              ? colors.primary
                              : colors.onSurfaceVariant,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          fi.label,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: _selectedIcon == fi.name
                                ? colors.primary
                                : colors.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Colour',
            style: theme.textTheme.labelMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final (label, hex) in _folderColors)
                GestureDetector(
                  onTap: () => setState(() => _selectedColorHex = hex),
                  child: Tooltip(
                    message: label,
                    child: AnimatedContainer(
                      duration: AppMotion.of(
                        context,
                        const Duration(milliseconds: 130),
                      ),
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Color(int.parse(hex.replaceFirst('#', '0xFF'))),
                        shape: BoxShape.circle,
                        border: _selectedColorHex == hex
                            ? Border.all(color: colors.onSurface, width: 2.5)
                            : Border.all(color: Colors.transparent, width: 2.5),
                        boxShadow: _selectedColorHex == hex
                            ? [
                                BoxShadow(
                                  color: Color(
                                    int.parse(hex.replaceFirst('#', '0xFF')),
                                  ).withValues(alpha: 0.4),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: _selectedColorHex == hex
                          ? const Icon(
                              Icons.check,
                              size: 18,
                              color: Colors.white,
                            )
                          : null,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _controller.text.trim().isEmpty
                  ? null
                  : () => Navigator.of(context).pop(
                      FolderEditorResult(
                        name: _controller.text.trim(),
                        iconName: _selectedIcon,
                        colorHex: _selectedColorHex,
                      ),
                    ),
              child: Text(
                widget.initial != null ? 'Save changes' : 'Create folder',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

