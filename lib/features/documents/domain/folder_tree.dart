import '../../../core/database/app_database.dart';

/// Folders can sit inside folders; these read that tree from the flat list
/// the database returns.
abstract final class FolderTree {
  /// The folders directly inside [parentId] — the top level when null —
  /// sorted by name.
  static List<Folder> childrenOf(List<Folder> folders, String? parentId) =>
      folders.where((f) => f.parentFolderId == parentId).toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  /// "Work / Contracts / 2026" for a nested folder, so pickers that list
  /// every folder can tell two "2026" folders apart.
  static String pathOf(List<Folder> folders, String id) {
    final byId = {for (final f in folders) f.id: f};
    final names = <String>[];
    final seen = <String>{};
    String? current = id;
    while (current != null && seen.add(current)) {
      final f = byId[current];
      if (f == null) break;
      names.add(f.name);
      current = f.parentFolderId;
    }
    return names.reversed.join(' / ');
  }

  /// Every folder in display order, each parent followed by its children.
  static List<Folder> flattened(List<Folder> folders) {
    final out = <Folder>[];
    final seen = <String>{};
    void visit(String? parentId) {
      for (final f in childrenOf(folders, parentId)) {
        if (!seen.add(f.id)) continue;
        out.add(f);
        visit(f.id);
      }
    }

    visit(null);
    // Anything whose parent is missing still gets listed.
    out.addAll(folders.where((f) => !seen.contains(f.id)));
    return out;
  }
}
