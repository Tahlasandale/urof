import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/urof_object.dart';

class OverlayApp extends StatelessWidget {
  const OverlayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UROF Overlay',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.transparent,
        colorScheme: const ColorScheme.dark(
          primary: Colors.deepPurpleAccent,
          surface: Color(0xFF0F0F14),
        ),
        useMaterial3: true,
      ),
      home: const OverlayScreen(),
    );
  }
}

class OverlayScreen extends StatefulWidget {
  const OverlayScreen({super.key});

  @override
  State<OverlayScreen> createState() => _OverlayScreenState();
}

class _OverlayScreenState extends State<OverlayScreen> {
  UrofObject? _object;

  @override
  void initState() {
    super.initState();
    _listenToOverlayData();
  }

  void _listenToOverlayData() {
    FlutterOverlayWindow.overlayListener.listen((event) {
      try {
        if (event == null) return;
        
        Map<String, dynamic>? jsonMap;
        if (event is Map) {
          jsonMap = Map<String, dynamic>.from(event);
        } else if (event is String) {
          final decoded = jsonDecode(event);
          if (decoded is Map) {
            jsonMap = Map<String, dynamic>.from(decoded);
          }
        }
        
        if (jsonMap != null) {
          setState(() {
            _object = UrofObject.fromJson(jsonMap!);
          });
        }
      } catch (e) {
        debugPrint("Error processing overlay data: $e");
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_object == null) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: ContainerGlass(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(strokeWidth: 2),
                  SizedBox(height: 12),
                  Text(
                    "Chargement...",
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final object = _object!;

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

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: ContainerGlass(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top Banner / Image or color header
                  if (object.imageUrl != null)
                    Stack(
                      children: [
                        Image.network(
                          object.imageUrl!,
                          height: 110,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const SizedBox.shrink(),
                        ),
                        Container(
                          height: 110,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.8),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: _buildCloseButton(),
                        ),
                      ],
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.only(top: 12, right: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [_buildCloseButton()],
                      ),
                    ),

                  // Content
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Title & Badge
                          Text(
                            object.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: primaryColor.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: primaryColor.withOpacity(0.3),
                                    width: 1.0,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(typeIcon, size: 11, color: primaryColor),
                                    const SizedBox(width: 4),
                                    Text(
                                      object.type.toUpperCase(),
                                      style: TextStyle(
                                        color: primaryColor,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Description
                          if (object.description.isNotEmpty) ...[
                            Text(
                              object.description,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.75),
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],

                          // Attributes
                          if (object.attributes.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.03),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.04),
                                  width: 1.0,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "INFORMATIONS",
                                    style: TextStyle(
                                      color: Colors.white38,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  ...object.attributes.entries.map(
                                    (entry) => Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 3),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          SizedBox(
                                            width: 90,
                                            child: Text(
                                              entry.key,
                                              style: TextStyle(
                                                color: Colors.white
                                                    .withOpacity(0.45),
                                                fontSize: 11,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            child: Text(
                                              entry.value,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],

                          // Footer Links
                          if (object.sourceUrl != null)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                InkWell(
                                  onTap: () async {
                                    final url = Uri.parse(object.sourceUrl!);
                                    if (await canLaunchUrl(url)) {
                                      await launchUrl(url);
                                    }
                                  },
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.open_in_new_rounded,
                                        size: 12,
                                        color: primaryColor,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        "Wikidata",
                                        style: TextStyle(
                                          color: primaryColor,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCloseButton() {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: const Icon(Icons.close_rounded, size: 16, color: Colors.white),
        onPressed: () async {
          await FlutterOverlayWindow.closeOverlay();
        },
      ),
    );
  }
}

class ContainerGlass extends StatelessWidget {
  final Widget child;

  const ContainerGlass({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 350,
      height: 400,
      decoration: BoxDecoration(
        color: const Color(0xEE12121A), // Dark obsidian, slightly transparent
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.6),
            blurRadius: 16,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}
