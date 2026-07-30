class BranchLocation {
  const BranchLocation({
    required this.id,
    required this.slug,
    required this.name,
    required this.sortOrder,
    required this.isActive,
    required this.isDefault,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String slug;
  final String name;
  final int sortOrder;
  final bool isActive;
  final bool isDefault;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory BranchLocation.fromSupabaseRow(Map<String, dynamic> row) {
    return BranchLocation(
      id: row['id'] as String? ?? '',
      slug: row['slug'] as String? ?? '',
      name: row['name'] as String? ?? '',
      sortOrder: row['sort_order'] as int? ?? 0,
      isActive: row['is_active'] as bool? ?? true,
      isDefault: row['is_default'] as bool? ?? false,
      createdAt: row['created_at'] != null
          ? DateTime.tryParse(row['created_at'] as String)
          : null,
      updatedAt: row['updated_at'] != null
          ? DateTime.tryParse(row['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toSupabaseRow() => {
    'id': id,
    'slug': slug,
    'name': name,
    'sort_order': sortOrder,
    'is_active': isActive,
    'is_default': isDefault,
  };
}
