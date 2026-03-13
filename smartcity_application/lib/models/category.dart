class Category {
  final int id;
  final String key;
  final String name;
  final String? emoji;
  final String? logo;
  final String? logoUrl;
  final bool isActive;
  final int displayOrder;
  final List<Subcategory>? subcategories;

  Category({
    required this.id,
    required this.key,
    required this.name,
    this.emoji,
    this.logo,
    this.logoUrl,
    required this.isActive,
    required this.displayOrder,
    this.subcategories,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] ?? 0,
      key: json['key'] ?? '',
      name: json['name'] ?? '',
      emoji: json['emoji'],
      logo: json['logo'],
      logoUrl: json['logo_url'],
      isActive: json['is_active'] ?? true,
      displayOrder: json['display_order'] ?? 0,
      subcategories: json['subcategories'] != null
          ? (json['subcategories'] as List)
              .map((s) => Subcategory.fromJson(s))
              .toList()
          : null,
    );
  }
}

class Subcategory {
  final int id;
  final String name;
  final bool isActive;
  final int displayOrder;
  final List<DynamicField>? dynamicFields;

  Subcategory({
    required this.id,
    required this.name,
    required this.isActive,
    required this.displayOrder,
    this.dynamicFields,
  });

  factory Subcategory.fromJson(Map<String, dynamic> json) {
    return Subcategory(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      isActive: json['is_active'] ?? true,
      displayOrder: json['display_order'] ?? 0,
      dynamicFields: json['dynamic_fields'] != null
          ? (json['dynamic_fields'] as List)
              .map((f) => DynamicField.fromJson(f))
              .toList()
          : null,
    );
  }
}

class DynamicField {
  final int id;
  final String label;
  final String fieldType;
  final String? options;
  final List<String>? optionsList;
  final bool isRequired;
  final int displayOrder;

  DynamicField({
    required this.id,
    required this.label,
    required this.fieldType,
    this.options,
    this.optionsList,
    required this.isRequired,
    required this.displayOrder,
  });

  factory DynamicField.fromJson(Map<String, dynamic> json) {
    return DynamicField(
      id: json['id'] ?? 0,
      label: json['label'] ?? '',
      fieldType: json['field_type'] ?? 'text',
      options: json['options'],
      optionsList: json['options_list'] != null
          ? List<String>.from(json['options_list'])
          : null,
      isRequired: json['is_required'] ?? false,
      displayOrder: json['display_order'] ?? 0,
    );
  }
}
