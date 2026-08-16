import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';

class TagsRepository {
  TagsRepository(this._db);

  final AppDatabase _db;

  Stream<List<Tag>> watchAllTags() {
    return (_db.select(_db.tags)..orderBy([(t) => OrderingTerm.asc(t.name)])).watch();
  }

  Stream<List<EntityTag>> watchAllEntityTags() => _db.select(_db.entityTags).watch();

  /// Case-insensitive match-or-insert so "Work" and "work" typed on
  /// different entities always resolve to the same shared tag.
  Future<Tag> findOrCreateTag(String name) async {
    final trimmed = name.trim();
    final existing = await (_db.select(
      _db.tags,
    )..where((t) => t.name.lower().equals(trimmed.toLowerCase()))).getSingleOrNull();
    if (existing != null) return existing;
    return _db.into(_db.tags).insertReturning(TagsCompanion.insert(name: trimmed));
  }

  Future<void> addTagToEntity({
    required String tagId,
    required String entityType,
    required String entityId,
  }) {
    return _db
        .into(_db.entityTags)
        .insertOnConflictUpdate(
          EntityTagsCompanion.insert(tagId: tagId, entityType: entityType, entityId: entityId),
        );
  }

  Future<void> removeTagFromEntity({
    required String tagId,
    required String entityType,
    required String entityId,
  }) {
    return (_db.delete(_db.entityTags)..where(
          (t) =>
              t.tagId.equals(tagId) &
              t.entityType.equals(entityType) &
              t.entityId.equals(entityId),
        ))
        .go();
  }

  /// Cascades: removes every [EntityTags] row pointing at this tag before
  /// deleting the tag itself, so no dangling links are left behind.
  Future<void> deleteTag(String id) async {
    await (_db.delete(_db.entityTags)..where((t) => t.tagId.equals(id))).go();
    await (_db.delete(_db.tags)..where((t) => t.id.equals(id))).go();
  }
}
