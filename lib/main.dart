import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'models/urof_object.dart';
import 'services/cache_service.dart';
import 'services/wikidata_service.dart';
import 'ui/object_sheet.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive for caching
  await Hive.initFlutter();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UROF',
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
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  static const _channel = MethodChannel('com.urof.urof/process_text');
  final _cacheService = CacheService();
  late final WikidataService _wikidataService;
  final _textController = TextEditingController();

  bool _isLoading = false;
  UrofObject? _resolvedObject;
  String? _errorMessage;
  bool _isProcessTextLaunch = false;

  @override
  void initState() {
    super.initState();
    _initServices();
  }

  Future<void> _initServices() async {
    await _cacheService.init();
    _wikidataService = WikidataService(cacheService: _cacheService);
    _setupPlatformChannel();
    _checkInitialText();
  }

  void _setupPlatformChannel() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onTextReceived') {
        final text = call.arguments as String?;
        if (text != null && text.isNotEmpty) {
          _resolveText(text, isProcessText: true);
        }
      }
    });
  }

  Future<void> _checkInitialText() async {
    try {
      final initialText = await _channel.invokeMethod<String>('getSharedText');
      if (initialText != null && initialText.isNotEmpty) {
        _resolveText(initialText, isProcessText: true);
      }
    } on PlatformException catch (e) {
      print("Failed to get initial shared text: ${e.message}");
    }
  }

  Future<void> _resolveText(String text, {bool isProcessText = false}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _resolvedObject = null;
      if (isProcessText) _isProcessTextLaunch = true;
    });

    final obj = await _wikidataService.resolveText(text);

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (obj != null) {
          _resolvedObject = obj;
        } else {
          _errorMessage = 'Aucune information trouvée pour "$text"';
        }
      });
    }
  }

  void _closeApp() {
    SystemNavigator.pop();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasActiveSheet = _isLoading || _resolvedObject != null || _errorMessage != null;

    return Scaffold(
      backgroundColor: hasActiveSheet ? Colors.black.withValues(alpha: 0.4) : const Color(0xFF09090B),
      body: SafeArea(
        child: Stack(
          children: [
            // Standard App Dashboard (when launched normally)
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 40),
                  const Center(
                    child: Hero(
                      tag: 'logo',
                      child: Icon(
                        Icons.unfold_more_rounded,
                        size: 64,
                        color: Colors.deepPurpleAccent,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Center(
                    child: Text(
                      'UROF',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.0,
                      ),
                    ),
                  ),
                  const Center(
                    child: Text(
                      'Universal Rich Object Format',
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 14,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),
                  const Text(
                    'Résoudre manuellement',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Manual search box
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                        width: 1.5,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _textController,
                            decoration: const InputDecoration(
                              hintText: 'Entrez un mot, lieu, film...',
                              hintStyle: TextStyle(color: Colors.white30),
                              border: InputBorder.none,
                            ),
                            style: const TextStyle(color: Colors.white),
                            onSubmitted: (val) {
                              if (val.trim().isNotEmpty) {
                                _resolveText(val.trim());
                              }
                            },
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.arrow_forward_rounded, color: Colors.deepPurpleAccent),
                          onPressed: () {
                            final val = _textController.text.trim();
                            if (val.isNotEmpty) {
                              _resolveText(val);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Instructions card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.deepPurpleAccent.withValues(alpha: 0.1),
                          Colors.purpleAccent.withValues(alpha: 0.05),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.deepPurpleAccent.withValues(alpha: 0.2),
                      ),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.flash_on_rounded, color: Colors.amberAccent, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Comment utiliser UROF ?',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12),
                        Text(
                          '1. Sélectionnez du texte dans n\'importe quelle application sur votre téléphone.\n'
                          '2. Cliquez sur UROF dans le menu de sélection de texte.\n'
                          '3. Une fiche détaillée apparaît instantanément en surimpression.',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Loading state overlay
            if (_isLoading)
              Positioned.fill(
                child: Container(
                  color: Colors.black45,
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          color: Colors.deepPurpleAccent,
                          strokeWidth: 3,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Recherche sur Wikidata...',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Error display
            if (_errorMessage != null)
              Positioned(
                left: 16,
                right: 16,
                bottom: 24,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2D161B),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 18),
                        onPressed: () {
                          setState(() {
                            _errorMessage = null;
                            // If came from PROCESS_TEXT and there's no result, close app
                            if (_isProcessTextLaunch && _resolvedObject == null) {
                              _closeApp();
                            }
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),

            // Sliding UI bottom sheet
            if (_resolvedObject != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: ObjectSheet(
                  object: _resolvedObject!,
                  onClose: () {
                    setState(() {
                      _resolvedObject = null;
                    });
                    if (_isProcessTextLaunch) {
                      _closeApp();
                    }
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
