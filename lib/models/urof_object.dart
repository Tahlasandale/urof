class UrofObject {
  final String id;
  final String title;
  final String type;
  final String description;
  final String? imageUrl;
  final Map<String, String> attributes;
  final String? sourceUrl;

  const UrofObject({
    required this.id,
    required this.title,
    required this.type,
    required this.description,
    this.imageUrl,
    required this.attributes,
    this.sourceUrl,
  });

  factory UrofObject.empty(String text) {
    return UrofObject(
      id: '',
      title: text,
      type: 'unknown',
      description: 'Aucune information trouvée.',
      attributes: {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'type': type,
      'description': description,
      'imageUrl': imageUrl,
      'attributes': attributes,
      'sourceUrl': sourceUrl,
    };
  }

  factory UrofObject.fromJson(Map<String, dynamic> json) {
    return UrofObject(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      type: json['type'] as String? ?? 'unknown',
      description: json['description'] as String? ?? '',
      imageUrl: json['imageUrl'] as String?,
      attributes: Map<String, String>.from(json['attributes'] ?? {}),
      sourceUrl: json['sourceUrl'] as String?,
    );
  }
}
