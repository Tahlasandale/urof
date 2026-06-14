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
  final GlobalKey _contentKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _listenToOverlayData();
    // First resize right after initial frame (loading state)
    WidgetsBinding.instance.addPostFrameCallback((_) => _resizeToContent());
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
          // Resize once content is rendered after setState
          WidgetsBinding.instance.addPostFrameCallback((_) => _resizeToContent());
        }
      } catch (e) {
        debugPrint("Error processing overlay data: $e");
      }
    });
  }

  void _resizeToContent() {
    final RenderBox? renderBox =
        _contentKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null && renderBox.hasSize) {
      final size = renderBox.size;
      // Add padding (24px on each side = 48 total) and clamp to reasonable bounds
      final w = (size.width + 48).clamp(200.0, 400.0).ceil();
      final h = (size.height + 48).clamp(80.0, 500.0).ceil();
      FlutterOverlayWindow.resizeOverlay(w, h, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: _object == null ? _buildLoading() : _buildResult(),
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Container(
        key: _contentKey,
        padding: const EdgeInsets.all(24),
        decoration: _glassDecoration(),
        child: const Column(
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
    );
  }

  Widget _buildResult() {
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

    return Center(
      child: Container(
        key: _contentKey,
        padding: const EdgeInsets.all(16),
        decoration: _glassDecoration(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Close button row — toujours visible
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _buildCloseButton(),
              ],
            ),

            // Title
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

            // Type badge
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 90,
                              child: Text(
                                entry.key,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.45),
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

            // Footer link
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
    );
  }

  BoxDecoration _glassDecoration() {
    return BoxDecoration(
      color: const Color(0xEE12121A),
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
