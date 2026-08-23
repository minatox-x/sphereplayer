import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/player_params.dart';

/// Full player flow
/// ───────────────
/// 1. Turnstile phase: renders bare CF challenge HTML with baseUrl=studyspark.study.
///    The real origin is never shown — our dark UI wraps the invisible WebView.
/// 2. Token arrives via flutter_inappwebview JS handler → _onTurnstileToken().
/// 3. Cookie is injected into CookieManager for streamworld.vercel.app FIRST.
/// 4. Player WebView is built and loads the fully-parameterised /player2 URL.
/// 5. Navigation policy: only streamworld.vercel.app/player2* stays in-app.
///    Everything else (links, /generate, etc.) → system browser.
class PlayerScreen extends StatefulWidget {
  final PlayerParams params;
  const PlayerScreen({super.key, required this.params});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

enum _Phase { turnstile, loading, player, error }

class _PlayerScreenState extends State<PlayerScreen> {
  // ── Constants ──────────────────────────────────────────────────────────────
  static const _turnstileOrigin = 'https://studyspark.study';
  static const _playerBase     = 'https://streamworld.vercel.app/player2';
  static const _playerHost     = 'streamworld.vercel.app';
  static const _playerPath     = '/player2';
  static const _sitekey        = '0x4AAAAAACqytllG1rHL_Acz';

  // ── State ──────────────────────────────────────────────────────────────────
  _Phase  _phase        = _Phase.turnstile;
  String? _errorMessage;
  String? _resolvedUrl;   // final player URL after params are merged
  String? _turnstileToken;

  // The player WebView controller — set in onWebViewCreated
  InAppWebViewController? _playerController;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    // Pre-build the player URL once so we don't repeat it
    _resolvedUrl = widget.params.buildPlayerUrl(_playerBase);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  // ── Turnstile HTML ─────────────────────────────────────────────────────────

  String _buildTurnstileHtml() => '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <style>
    *{margin:0;padding:0;box-sizing:border-box}
    html,body{
      width:100%;height:100%;
      background:transparent;
      display:flex;align-items:center;justify-content:center;
      overflow:hidden;
    }
  </style>
</head>
<body>
  <div class="cf-turnstile"
       data-sitekey="$_sitekey"
       data-callback="onToken"
       data-theme="dark"
       data-size="normal">
  </div>
  <script src="https://challenges.cloudflare.com/turnstile/v0/api.js" async defer></script>
  <script>
    function onToken(t){
      // flutter_inappwebview JS handler syntax
      window.flutter_inappwebview.callHandler("TurnstileBridge", t);
    }
  </script>
</body>
</html>
''';

  // ── Token received → inject cookie → load player ───────────────────────────

  Future<void> _onTurnstileToken(String token) async {
    if (!mounted) return;
    setState(() {
      _turnstileToken = token;
      _phase = _Phase.loading;
    });

    try {
      // Step 1: inject cookie BEFORE the player WebView loads anything
      await _setCookieGlobally();

      // Step 2: transition to player phase — the WebView will be built fresh
      if (!mounted) return;
      setState(() => _phase = _Phase.player);
    } catch (e) {
      _setError('Setup failed: $e');
    }
  }

  /// Writes the cookie into flutter_inappwebview's shared CookieManager so it
  /// is present for every request the player WebView makes to the host.
  Future<void> _setCookieGlobally() async {
    if (widget.params.cookie == null) return;

    final mgr = CookieManager.instance();
    final url = WebUri('https://$_playerHost');

    // Set cookie before the WebView even exists — CookieManager is global
    await mgr.setCookie(
      url: url,
      name: widget.params.cookieName,
      value: widget.params.cookie!,
      domain: _playerHost,
      path: '/',
      isSecure: true,
      isHttpOnly: true,
      sameSite: HTTPCookieSameSitePolicy.LAX,
    );
  }

  void _setError(String msg) {
    if (!mounted) return;
    setState(() {
      _phase = _Phase.error;
      _errorMessage = msg;
    });
  }

  // ── Navigation policy ──────────────────────────────────────────────────────

  bool _isAllowedInApp(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host == _playerHost && uri.path.startsWith(_playerPath);
    } catch (_) {
      return false;
    }
  }

  Future<void> _openInBrowser(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0F),
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_phase == _Phase.turnstile) _buildTurnstilePhase(),
          if (_phase == _Phase.loading)   _buildLoadingPhase(),
          if (_phase == _Phase.player)    _buildPlayerPhase(),
          if (_phase == _Phase.error)     _buildErrorPhase(),
        ],
      ),
    );
  }

  // ── Turnstile phase ────────────────────────────────────────────────────────

  Widget _buildTurnstilePhase() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _SphereIcon(size: 44),
          const SizedBox(height: 28),
          const Text(
            'Quick verification',
            style: TextStyle(
              color: Color(0xFFE8E8F0),
              fontSize: 18,
              fontWeight: FontWeight.w500,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Complete the check below to continue',
            style: TextStyle(color: Color(0xFF6B6B80), fontSize: 13),
          ),
          const SizedBox(height: 28),

          // ── Turnstile iframe container ──
          Container(
            width: 302,
            height: 70,
            clipBehavior: Clip.hardEdge,
            decoration: BoxDecoration(
              color: const Color(0xFF16161C),
              borderRadius: BorderRadius.circular(8),
            ),
            child: InAppWebView(
              initialData: InAppWebViewInitialData(
                data: _buildTurnstileHtml(),
                baseUrl: WebUri(_turnstileOrigin),
                mimeType: 'text/html',
                encoding: 'utf-8',
              ),
              initialSettings: InAppWebViewSettings(
                transparentBackground: true,
                javaScriptEnabled: true,
                domStorageEnabled: true,
                disableVerticalScroll: true,
                disableHorizontalScroll: true,
                userAgent:
                    'Mozilla/5.0 (Linux; Android 11) AppleWebKit/537.36 '
                    '(KHTML, like Gecko) Chrome/120 Mobile Safari/537.36',
              ),
              onWebViewCreated: (ctrl) {
                ctrl.addJavaScriptHandler(
                  handlerName: 'TurnstileBridge',
                  callback: (args) {
                    if (args.isNotEmpty && args[0] is String) {
                      _onTurnstileToken(args[0] as String);
                    }
                  },
                );
              },
              shouldOverrideUrlLoading: (ctrl, action) async {
                final url = action.request.url?.toString() ?? '';
                if (url.startsWith(_turnstileOrigin) ||
                    url.startsWith('https://challenges.cloudflare.com')) {
                  return NavigationActionPolicy.ALLOW;
                }
                return NavigationActionPolicy.CANCEL;
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Loading phase ──────────────────────────────────────────────────────────

  Widget _buildLoadingPhase() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SphereIcon(size: 40),
          SizedBox(height: 28),
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Color(0xFF7C6EF7),
            ),
          ),
          SizedBox(height: 14),
          Text(
            'Setting up…',
            style: TextStyle(color: Color(0xFF6B6B80), fontSize: 13),
          ),
        ],
      ),
    );
  }

  // ── Player phase ───────────────────────────────────────────────────────────

  Widget _buildPlayerPhase() {
    final url = _resolvedUrl!;

    return InAppWebView(
      initialUrlRequest: URLRequest(
        url: WebUri(url),
        headers: {
          // Forward the turnstile token as a header so the server can verify
          if (_turnstileToken != null)
            'X-Cf-Turnstile-Token': _turnstileToken!,
        },
      ),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        domStorageEnabled: true,
        mediaPlaybackRequiresUserGesture: false,
        allowsInlineMediaPlayback: true,
        allowsPictureInPictureMediaPlayback: true,
        useWideViewPort: true,
        loadWithOverviewMode: true,
        supportZoom: false,
        userAgent:
            'Mozilla/5.0 (Linux; Android 11) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/120 Mobile Safari/537.36',
      ),
      onWebViewCreated: (ctrl) {
        _playerController = ctrl;
      },
      shouldOverrideUrlLoading: (ctrl, action) async {
        final url = action.request.url?.toString() ?? '';
        if (_isAllowedInApp(url)) return NavigationActionPolicy.ALLOW;
        _openInBrowser(url);
        return NavigationActionPolicy.CANCEL;
      },
      onLoadError: (ctrl, url, code, message) {
        _setError('Player failed to load ($code).\n$message');
      },
    );
  }

  // ── Error phase ────────────────────────────────────────────────────────────

  Widget _buildErrorPhase() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: Color(0xFF7C6EF7), size: 40),
            const SizedBox(height: 20),
            Text(
              _errorMessage ?? 'Something went wrong.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFBBBBCC),
                fontSize: 14,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 28),
            GestureDetector(
              onTap: () {
                setState(() {
                  _phase = _Phase.turnstile;
                  _errorMessage = null;
                  _turnstileToken = null;
                });
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 13),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C6EF7).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: const Color(0xFF7C6EF7).withOpacity(0.4)),
                ),
                child: const Text(
                  'Try again',
                  style: TextStyle(
                    color: Color(0xFF7C6EF7),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Reusable logo icon ─────────────────────────────────────────────────────

class _SphereIcon extends StatelessWidget {
  final double size;
  const _SphereIcon({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          colors: [Color(0xFF9B8EFF), Color(0xFF4B3FD1)],
          center: Alignment(-0.3, -0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C6EF7).withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Icon(Icons.play_arrow_rounded,
          color: Colors.white, size: size * 0.5),
    );
  }
}
