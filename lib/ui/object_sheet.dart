import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/urof_object.dart';

class ObjectSheet extends StatelessWidget {
  final UrofObject object;
  final VoidCallback onClose;

  const ObjectSheet({
    super.key,
    required this.object,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    // Get color theme based on object type
    Color primaryColor;
    IconData typeIcon;
    switch (object.type) {
      case 'person':
        primaryColor = Colors.cyanAccent;
        typeIcon = Icons.person_rounded;
        break;
      case 'city':
        primaryColor = Colors.greenAccent;
        typeIcon = Icons.location_city_rounded;
        break;
      case 'movie':
        primaryColor = Colors.pinkAccent;
        typeIcon = Icons.movie_filter_rounded;
        break;
      case 'book':
        primaryColor = Colors.amberAccent;
        typeIcon = Icons.menu_book_rounded;
        break;
      case 'animal':
        primaryColor = Colors.orangeAccent;
        typeIcon = Icons.pets_rounded;
        break;
      default:
        primaryColor = Colors.purpleAccent;
        typeIcon = Icons.info_outline_rounded;
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xE60D0D12), // 90% opacity deep dark obsidian
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 24,
            spreadRadius: 4,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
          ),

          // Header with Title and Type Badge
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        object.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Type Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: primaryColor.withOpacity(0.3),
                            width: 1.0,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              typeIcon,
                              size: 14,
                              color: primaryColor,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              object.type.toUpperCase(),
                              style: TextStyle(
                                color: primaryColor,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Close button
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.06),
                    hoverColor: Colors.white.withOpacity(0.12),
                  ),
                ),
              ],
            ),
          ),

          // Main content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Image (if available)
                  if (object.imageUrl != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        object.imageUrl!,
                        height: 200,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return Container(
                            height: 200,
                            color: Colors.white.withOpacity(0.02),
                            child: const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Description
                  if (object.description.isNotEmpty) ...[
                    Text(
                      object.description,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 15,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Attributes Grid / List
                  if (object.attributes.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.04),
                          width: 1.0,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Fiche Technique",
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...object.attributes.entries.map((entry) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 120,
                                  child: Text(
                                    entry.key,
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.4),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    entry.value,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Footer actions (Wikidata details, copy to clipboard, etc.)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (object.sourceUrl != null)
                        TextButton.icon(
                          onPressed: () {
                            // Copy link or launch in browser if url launcher is installed,
                            // or copy to clipboard for now
                            Clipboard.setData(ClipboardData(text: object.sourceUrl!));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Lien copié dans le presse-papiers"),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                          icon: const Icon(Icons.link_rounded, size: 16),
                          label: const Text(
                            "Copier le lien Wikidata",
                            style: TextStyle(fontSize: 12),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: primaryColor,
                          ),
                        ),
                      IconButton(
                        icon: const Icon(Icons.share_rounded, size: 18),
                        onPressed: () {
                          // Quick share copy
                          final infoText = "${object.title}\n${object.description}\n\n${object.attributes.entries.map((e) => "${e.key}: ${e.value}").join('\n')}";
                          Clipboard.setData(ClipboardData(text: infoText));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Fiche copiée dans le presse-papiers"),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        color: Colors.white60,
                        tooltip: "Copier la fiche",
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
