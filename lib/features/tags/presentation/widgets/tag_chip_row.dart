import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/tags_providers.dart';

/// Deletable chips for every tag on one entity, plus a trailing "+ Add tag"
/// chip that opens an inline text field with autocomplete suggestions drawn
/// from every tag already used elsewhere in the app.
class TagChipRow extends ConsumerStatefulWidget {
  const TagChipRow({super.key, required this.entityType, required this.entityId});

  final String entityType;
  final String entityId;

  @override
  ConsumerState<TagChipRow> createState() => _TagChipRowState();
}

class _TagChipRowState extends ConsumerState<TagChipRow> {
  bool _adding = false;
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _startAdding() {
    setState(() => _adding = true);
    _focusNode.requestFocus();
  }

  Future<void> _submit(String name) async {
    final trimmed = name.trim();
    setState(() {
      _adding = false;
      _controller.clear();
    });
    if (trimmed.isEmpty) return;
    await ref
        .read(tagsControllerProvider)
        .addTag(widget.entityType, widget.entityId, trimmed);
  }

  @override
  Widget build(BuildContext context) {
    final tags = ref.watch(entityTagsProvider((widget.entityType, widget.entityId)));
    final allTags = ref.watch(allTagsProvider).value ?? const [];
    final query = _controller.text.trim().toLowerCase();
    final tagNames = {for (final t in tags) t.name.toLowerCase()};
    final suggestions = query.isEmpty
        ? const <String>[]
        : allTags
              .map((t) => t.name)
              .where(
                (name) =>
                    name.toLowerCase().contains(query) && !tagNames.contains(name.toLowerCase()),
              )
              .take(5)
              .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final tag in tags)
              InputChip(
                label: Text(tag.name),
                onDeleted: () => ref
                    .read(tagsControllerProvider)
                    .removeTag(widget.entityType, widget.entityId, tag.id),
              ),
            if (!_adding)
              ActionChip(
                avatar: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Add tag'),
                onPressed: _startAdding,
              ),
          ],
        ),
        if (_adding) ...[
          const SizedBox(height: 8),
          TextField(
            controller: _controller,
            focusNode: _focusNode,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Tag name'),
            onChanged: (_) => setState(() {}),
            onSubmitted: _submit,
          ),
          if (suggestions.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final name in suggestions)
                  ActionChip(label: Text(name), onPressed: () => _submit(name)),
              ],
            ),
          ],
        ],
      ],
    );
  }
}
