// SMM Web-to-Native App — main.dart (Flutter)
// Features: dynamic domain from backend + beautiful loading animation + offline fallback

import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_jailbreak_detection/flutter_jailbreak_detection.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lottie/lottie.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

void main() {
  runApp(const SmmApp());
}

// ============ CONFIG — HiroShi Services (preview mode + hardened) ============
// အခု App အရင်ကြည့်မယ် → Remote Config OFF, domain တိုက်ရိုက် load
// နောက်မှ domain-change လိုရင် kPreviewMode = false လုပ်ရုံပဲ
//
// SECURITY NOTE: secret/key တွေ ဒီ file ထဲ hardcode မလုပ်နဲ့.
// --dart-define=CONFIG_SECRET=xxx --dart-define=APP_KEY=yyy နဲ့ build�ချိန်ထည့်.
// (CI: GitHub Secrets → workflow → --dart-define)
const bool kPreviewMode = true;
// rooted / jailbroken device ကို block လုပ်မလား? (true = block, false = warning only)
const bool kBlockRooted = false;
const List<String> CONFIG_URLS = [
  'https://config.hiroshiservices.org/app-config',
  'https://hiroshiservices.org/app-config.json',
];
const String DEFAULT_DOMAIN = 'https://hiroshiservices.org';
// =============================================================

class SmmApp extends StatelessWidget {
  const SmmApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HiroShi Services',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
      ),
      home: const SplashScreen(),
    );
  }
}

// ---------- 1. Splash + Remote Config Fetch ----------
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  String _status = 'ချိတ်ဆက်နေသည်...';
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _loadConfig();
  }

  Future<void> _go(String url) {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 800),
        pageBuilder: (_, __, ___) => WebViewScreen(url: url),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  Future<void> _loadConfig() async {
    // 0. Root/jailbreak စစ် (mod/hook tool အများစု root လိုတယ်)
    final compromised = await AppSecurity.isDeviceCompromised();
    if (compromised && kBlockRooted && mounted) {
      setState(() => _status = 'လုံခြုံရေးအရ ဤ device တွင် အသုံးပြု၍မရပါ။');
      return;
    }
    // Preview mode: splash 1.5s ပြပြီး domain တိုက်ရိုက်သွား (server မစောင့်)
    if (kPreviewMode) {
      await Future.delayed(const Duration(milliseconds: 1500));
      _go(DEFAULT_DOMAIN);
      return;
    }
    try {
      setState(() => _status = 'Server နှင့် ချိတ်ဆက်နေသည်...');
      final url = await RemoteConfigService.fetchActiveDomain();
      _go(url);
    } catch (e) {
      // Backend လည်း မရ, cache လည်း မရှိမှ error ပြမယ်
      // cache ရှိရင် RemoteConfigService က cache ပြန်ပေးပြီးသား
      if (!mounted) return;
      setState(() => _status = 'အင်တာနက် ချိတ်ဆက်မှု မရပါ။ ထပ်ကြိုးစားပါ။');
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F172A), Color(0xFF1E3A8A), Color(0xFF7C3AED)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo pulse animation
              ScaleTransition(
                scale: Tween(begin: 0.9, end: 1.1).animate(
                  CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
                ),
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.4),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.rocket_launch, size: 55, color: Color(0xFF1E3A8A)),
                ),
              ),
              const SizedBox(height: 30),
              // Loading bar (Lottie file မရှိလည်း CircularProgressIndicator လှလှ)
              const SizedBox(
                width: 180,
                child: LinearProgressIndicator(
                  backgroundColor: Colors.white24,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.cyanAccent),
                  minHeight: 4,
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                ),
              ),
              const SizedBox(height: 16),
              Text(_status, style: const TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadConfig,
                icon: const Icon(Icons.refresh),
                label: const Text('ထပ်ကြိုးစားမည်'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF1E3A8A),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------- 2. Security helpers (anti-mod core) ----------
class AppSecurity {
  // build�ချိန် --dart-define နဲ့ ထည့်, repo ထဲ မထား
  static const _configSecret =
      String.fromEnvironment('CONFIG_SECRET', defaultValue: '');
  static const _appKey =
      String.fromEnvironment('APP_KEY', defaultValue: '');

  // WebView မှာ ဖွင့်ခွင့်ရှိတဲ့ host များ (suffix match)
  static const List<String> allowedHosts = [
    'hiroshiservices.org',
    'config.hiroshiservices.org',
  ];

  static bool isHostAllowed(String? host) {
    if (host == null || host.isEmpty) return false;
    final h = host.toLowerCase();
    return allowedHosts.any((a) => h == a || h.endsWith('.$a'));
  }

  static bool isHttpsAllowedUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    return uri.scheme == 'https' && isHostAllowed(uri.host);
  }

  /// Backend unsigned / old-format response ကို dev အတွက် လက်ခံ,
  /// production (secret ပေးထားရင်) signature မမှန်ရင် reject
  static Map<String, dynamic>? verifyAndExtract(Map<String, dynamic> body) {
    final hasEnvelope = body.containsKey('data') && body.containsKey('signature');
    if (!hasEnvelope) {
      // secret မပေးရသေးတဲ့ dev server / static json fallback
      if (_configSecret.isEmpty) return body;
      return null; // production: unsigned → reject
    }
    final data = Map<String, dynamic>.from(body['data'] as Map);
    if (_configSecret.isEmpty) return data; // preview build: verify skip
    final sig = (body['signature'] ?? '').toString();
    final raw = jsonEncode(_sorted(data));
    final calc = Hmac(sha256, utf8.encode(_configSecret))
        .convert(utf8.encode(raw))
        .toString();
    if (!_constantTimeEq(calc, sig)) return null;
    // replay guard: issued_at 24h ထက် ဟောင်းရင် reject
    final issued = (data['issued_at'] ?? 0) as int;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (issued > 0 && (now - issued).abs() > 24 * 3600) return null;
    return data;
  }

  static Map<String, dynamic> _sorted(Map<String, dynamic> m) {
    final keys = m.keys.toList()..sort();
    return {for (final k in keys) k: m[k]};
  }

  static bool _constantTimeEq(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }

  static Map<String, String> get headers => {
        if (_appKey.isNotEmpty) 'X-App-Key': _appKey,
      };

  /// Root/jailbreak + (optional) emulator စစ်
  static Future<bool> isDeviceCompromised() async {
    try {
      return await FlutterJailbreakDetection.isJailBroken;
    } catch (_) {
      return false;
    }
  }
}

// ---------- 3. Remote Config Service (signed + whitelisted) ----------
class RemoteConfigService {
  static const _cacheKey = 'cached_domain';
  static const _versionKey = 'config_version';

  /// CONFIG_URLS အစဉ်လိုက် try — signature + https + whitelist မအောင်ရင် skip
  static Future<String> fetchActiveDomain() async {
    final prefs = await SharedPreferences.getInstance();
    for (final url in CONFIG_URLS) {
      try {
        final res = await http
            .get(Uri.parse(url), headers: AppSecurity.headers)
            .timeout(const Duration(seconds: 7));

        if (res.statusCode == 200) {
          final body = Map<String, dynamic>.from(jsonDecode(res.body));
          final json = AppSecurity.verifyAndExtract(body);
          if (json == null) continue; // signature fail → နောက် URL
          if (json['maintenance_mode'] == true) {
            throw MaintenanceException(json['maintenance_message'] ?? 'Maintenance');
          }
          final domain = (json['active_domain'] as String).trim();
          // https + whitelist မအောင်တဲ့ domain ဆို လုံးဝ လက်မခံ (mod block)
          if (!AppSecurity.isHttpsAllowedUrl(domain)) continue;
          await prefs.setString(_cacheKey, domain);
          await prefs.setInt(_versionKey, (json['config_version'] ?? 0) as int);
          return domain;
        }
      } catch (e) {
        if (e is MaintenanceException) rethrow;
        continue; // ဒီ URL မရရင် နောက် URL စမ်း
      }
    }
    // cache ထဲက အဟောင်းတောင် whitelist အောင်မှ သုံး
    final cached = prefs.getString(_cacheKey);
    if (cached != null &&
        cached.isNotEmpty &&
        AppSecurity.isHttpsAllowedUrl(cached)) {
      return cached;
    }
    return DEFAULT_DOMAIN;
  }
}

class MaintenanceException implements Exception {
  final String message;
  MaintenanceException(this.message);
}

// ---------- 3. WebView + လှပသော Loading Effect ----------
class WebViewScreen extends StatefulWidget {
  final String url;
  const WebViewScreen({super.key, required this.url});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController _controller;
  double _progress = 0;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    // constructor ကနေ ဝင်လာတဲ့ URL တောင် whitelist မအောင်ရင် default သုံး
    final startUrl = AppSecurity.isHttpsAllowedUrl(widget.url)
        ? widget.url
        : DEFAULT_DOMAIN;
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          // *** ANTI-MOD: whitelist ပြင်ပ host block ***
          onNavigationRequest: (req) {
            final uri = Uri.tryParse(req.url);
            if (uri == null) return NavigationDecision.prevent;
            // https မဟုတ်ရင် block (http downgrade attack ကာကွယ်)
            if (uri.scheme != 'https') return NavigationDecision.prevent;
            if (AppSecurity.isHostAllowed(uri.host)) {
              return NavigationDecision.navigate;
            }
            // payment / play-store link လို အပြင် link ဆို block (နောက်မှ external browser option)
            return NavigationDecision.prevent;
          },
          onProgress: (p) => setState(() => _progress = p / 100),
          onPageStarted: (_) => setState(() { _isLoading = true; _hasError = false; }),
          onPageFinished: (_) => setState(() => _isLoading = false),
          onWebResourceError: (_) => setState(() { _isLoading = false; _hasError = true; }),
        ),
      )
      ..loadRequest(Uri.parse(startUrl));
  }

  Future<void> _reloadWithFreshConfig() async {
    setState(() { _isLoading = true; _hasError = false; });
    final freshUrl = await RemoteConfigService.fetchActiveDomain();
    await _controller.loadRequest(Uri.parse(freshUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            if (!_hasError)
              WebViewWidget(controller: _controller),

            // --- Top shimmer progress bar ---
            if (_isLoading && !_hasError)
              Positioned(
                top: 0, left: 0, right: 0,
                child: LinearProgressIndicator(
                  value: _progress == 0 ? null : _progress,
                  backgroundColor: Colors.transparent,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.cyanAccent),
                  minHeight: 3,
                ),
              ),

            // --- Full-screen skeleton loading ---
            if (_isLoading && !_hasError)
              Container(
                color: const Color(0xFF0F172A),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // shimmer blocks
                      _shimmerBox(width: 280, height: 18),
                      const SizedBox(height: 12),
                      _shimmerBox(width: 220, height: 14),
                      const SizedBox(height: 12),
                      _shimmerBox(width: 250, height: 14),
                      const SizedBox(height: 30),
                      const CircularProgressIndicator(color: Colors.cyanAccent),
                      const SizedBox(height: 16),
                      Text(
                        '${(_progress * 100).toInt()}% loading...',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ),

            // --- Error / banned-domain retry screen ---
            if (_hasError)
              Container(
                color: const Color(0xFF0F172A),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.cloud_off, size: 70, color: Colors.white38),
                      const SizedBox(height: 16),
                      const Text('ချိတ်ဆက်၍ မရပါ',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      const Text('Domain အသစ်ရှိမရှိ စစ်ဆေးရန် အောက်ကိုနှိပ်ပါ',
                          style: TextStyle(color: Colors.white60)),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: _reloadWithFreshConfig,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Domain အသစ် စစ်ဆေးမည်'),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.small(
        onPressed: () => _controller.reload(),
        child: const Icon(Icons.refresh),
      ),
    );
  }

  Widget _shimmerBox({required double width, required double height}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: LinearGradient(
          colors: [Colors.white.withOpacity(0.08), Colors.white.withOpacity(0.2), Colors.white.withOpacity(0.08)],
        ),
      ),
    );
  }
}
