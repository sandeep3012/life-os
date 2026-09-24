import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Semantic category for a stored document. Stored as a plain string in the
/// database so new types can be added without a migration.
class DocumentType {
  const DocumentType._({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  final String value;
  final String label;
  final IconData icon;
  final Color color;

  static const identity = DocumentType._(
    value: 'identity',
    label: 'Identity',
    icon: LucideIcons.idCard,
    color: Color(0xFF4B7BA6),
  );
  static const financial = DocumentType._(
    value: 'financial',
    label: 'Financial',
    icon: LucideIcons.banknote,
    color: Color(0xFFC2703D),
  );
  static const medical = DocumentType._(
    value: 'medical',
    label: 'Medical',
    icon: LucideIcons.heartPulse,
    color: Color(0xFF0E9F6E),
  );
  static const insurance = DocumentType._(
    value: 'insurance',
    label: 'Insurance',
    icon: LucideIcons.shieldCheck,
    color: Color(0xFF3FA6A0),
  );
  static const property = DocumentType._(
    value: 'property',
    label: 'Property',
    icon: LucideIcons.house,
    color: Color(0xFF7C6BC4),
  );
  static const education = DocumentType._(
    value: 'education',
    label: 'Education',
    icon: LucideIcons.graduationCap,
    color: Color(0xFF3E7C5A),
  );
  static const other = DocumentType._(
    value: 'other',
    label: 'Other',
    icon: LucideIcons.file,
    color: Color(0xFF9A9384),
  );

  static const all = [
    identity,
    financial,
    medical,
    insurance,
    property,
    education,
    other,
  ];

  static DocumentType? fromValue(String? value) {
    if (value == null) return null;
    for (final t in all) {
      if (t.value == value) return t;
    }
    return null;
  }
}
