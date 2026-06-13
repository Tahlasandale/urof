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
}
