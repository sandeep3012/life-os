import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/app_database_provider.dart';
import '../data/tags_repository.dart';

final tagsRepositoryProvider = Provider<TagsRepository>((ref) {
  return TagsRepository(ref.watch(appDatabaseProvider));
});

final allTagsProvider = StreamProvider<List<Tag>>((ref) {
  return ref.watch(tagsRepositoryProvider).watchAllTags();
});

final allEntityTagsProvider = StreamProvider<List<EntityTag>>((ref) {
  return ref.watch(tagsRepositoryProvider).watchAllEntityTags();
});

/// Tags attached to one entity, derived by joining the two bulk streams
/// client-side rather than a per-entity query — mirrors how `GoalLinks`
/// resolution works off `watchAllLinks()`.
final entityTagsProvider = Provider.family<List<Tag>, (String entityType, String entityId)>((
  ref,
  key,
) {
  final allTags = ref.watch(allTagsProvider).value ?? const [];
  final allEntityTags = ref.watch(allEntityTagsProvider).value ?? const [];
  final tagById = {for (final t in allTags) t.id: t};
  final tagIds = allEntityTags
      .where((e) => e.entityType == key.$1 && e.entityId == key.$2)
      .map((e) => e.tagId);
  return [for (final id in tagIds) if (tagById[id] != null) tagById[id]!];
});

class TagsController {
  TagsController(this._repo);

  final TagsRepository _repo;

  Future<void> addTag(String entityType, String entityId, String tagName) async {
    final tag = await _repo.findOrCreateTag(tagName);
    await _repo.addTagToEntity(tagId: tag.id, entityType: entityType, entityId: entityId);
  }

  Future<void> removeTag(String entityType, String entityId, String tagId) {
    return _repo.removeTagFromEntity(tagId: tagId, entityType: entityType, entityId: entityId);
  }
}

final tagsControllerProvider = Provider<TagsController>((ref) {
  return TagsController(ref.watch(tagsRepositoryProvider));
});
