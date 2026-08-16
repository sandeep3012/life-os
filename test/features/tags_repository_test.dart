import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/database/app_database.dart';
import 'package:life_manager/features/tags/data/tags_repository.dart';

void main() {
  late AppDatabase db;
  late TagsRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = TagsRepository(db);
  });

  tearDown(() => db.close());

  test('findOrCreateTag creates a new tag when none matches', () async {
    final tag = await repo.findOrCreateTag('Work');
    expect(tag.name, 'Work');

    final all = await repo.watchAllTags().first;
    expect(all, hasLength(1));
  });

  test('findOrCreateTag reuses an existing tag case-insensitively', () async {
    final first = await repo.findOrCreateTag('Work');
    final second = await repo.findOrCreateTag('work');

    expect(second.id, first.id);
    final all = await repo.watchAllTags().first;
    expect(all, hasLength(1));
  });

  test('addTagToEntity then removeTagFromEntity round-trips', () async {
    final tag = await repo.findOrCreateTag('Personal');
    await repo.addTagToEntity(tagId: tag.id, entityType: 'note', entityId: 'note-1');

    var links = await repo.watchAllEntityTags().first;
    expect(links, hasLength(1));
    expect(links.first.tagId, tag.id);
    expect(links.first.entityType, 'note');
    expect(links.first.entityId, 'note-1');

    await repo.removeTagFromEntity(tagId: tag.id, entityType: 'note', entityId: 'note-1');
    links = await repo.watchAllEntityTags().first;
    expect(links, isEmpty);
  });

  test('deleteTag cascades to remove its links without touching other tags', () async {
    final workTag = await repo.findOrCreateTag('Work');
    final personalTag = await repo.findOrCreateTag('Personal');
    await repo.addTagToEntity(tagId: workTag.id, entityType: 'note', entityId: 'note-1');
    await repo.addTagToEntity(tagId: personalTag.id, entityType: 'note', entityId: 'note-1');
    await repo.addTagToEntity(tagId: workTag.id, entityType: 'document', entityId: 'doc-1');

    await repo.deleteTag(workTag.id);

    final tags = await repo.watchAllTags().first;
    expect(tags.map((t) => t.id), [personalTag.id]);

    final links = await repo.watchAllEntityTags().first;
    expect(links, hasLength(1));
    expect(links.first.tagId, personalTag.id);
  });
}
