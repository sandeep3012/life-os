import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Named icon options users can assign to a document folder.
class FolderIcon {
  const FolderIcon._({
    required this.name,
    required this.label,
    required this.icon,
  });

  final String name;
  final String label;
  final IconData icon;

  static const general = FolderIcon._(
    name: 'folder',
    label: 'General',
    icon: LucideIcons.folder,
  );
  static const financial = FolderIcon._(
    name: 'banknote',
    label: 'Financial',
    icon: LucideIcons.banknote,
  );
  static const insurance = FolderIcon._(
    name: 'shield',
    label: 'Insurance',
    icon: LucideIcons.shieldCheck,
  );
  static const property = FolderIcon._(
    name: 'house',
    label: 'Property',
    icon: LucideIcons.house,
  );
  static const identity = FolderIcon._(
    name: 'id-card',
    label: 'Identity',
    icon: LucideIcons.idCard,
  );
  static const medical = FolderIcon._(
    name: 'heart',
    label: 'Medical',
    icon: LucideIcons.heartPulse,
  );
  static const education = FolderIcon._(
    name: 'graduation',
    label: 'Education',
    icon: LucideIcons.graduationCap,
  );
  static const work = FolderIcon._(
    name: 'briefcase',
    label: 'Work',
    icon: LucideIcons.briefcase,
  );
  static const travel = FolderIcon._(
    name: 'plane',
    label: 'Travel',
    icon: LucideIcons.plane,
  );
  static const family = FolderIcon._(
    name: 'users',
    label: 'Family',
    icon: LucideIcons.users,
  );
  static const vehicle = FolderIcon._(
    name: 'car',
    label: 'Vehicle',
    icon: LucideIcons.car,
  );
  static const receipts = FolderIcon._(
    name: 'receipt',
    label: 'Receipts',
    icon: LucideIcons.receipt,
  );

  static const all = [
    general,
    financial,
    insurance,
    property,
    identity,
    medical,
    education,
    work,
    travel,
    family,
    vehicle,
    receipts,
  ];

  static FolderIcon fromName(String? name) {
    if (name == null) return general;
    for (final f in all) {
      if (f.name == name) return f;
    }
    return general;
  }
}
