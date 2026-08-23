import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../models/player_params.dart';

/// The full player flow:
/// 1. Show a WebView pointing at studyspark.study/player (hidden behind our UI)
///    exposing ONLY the Cloudflare Turnstile iframe, centred on screen.
/// 2. Intercept the cf-turnstile token via JavaScript → postMessage bridge.
/// 3. POST token to streamworld.vercel.app/player2 → get redirect / HTML.
/// 4. Load the real player URL in the WebView (same session).
/// 5. Any navigation away from /player2 → open in system browser.
class PlayerScreen extends StatefulWidget {
  final PlayerParams params;
  const PlayerScreen({super.key, required this.params});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

enum _Phase { turnstile, loading, player, error }

class _PlayerScreenState extends State<PlayerScreen> {
  static const _turnstileOrigin = 'https://studyspark.study';
  static const _playerBase = 'https://streamworld.vercel.app/player2';
  static const _allowedPlayerHost = 'streamworld.vercel.app';
  static const _allowedPlayerPath = '/player2';
  static const _sitekey = '0x4AAAAAACqytllG1rHL_Acz';

  InAppWebViewController? _webViewController;
  _Phase _phase = _Phase.turnstile;
  String? _errorMessage;

  // We keep track of the turnstile WebView separately to keep it truly hidden
  InAppWebViewController? _turnstileController;

  @override
  void initState() {
    super.initState();
    // Enter immersive mode for the player
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  // ─── Turnstile HTML ────────────────────────────────────────────────────────

  /// Minimal HTML that renders ONLY the Turnstile widget and posts the token
  /// back to us via the JavaScript channel "TurnstileBridge".
  String _buildTurnstileHtml() {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    html, body {
      width: 100%; height: 100%;
      background: transparent;
      display: flex;
      align-items: center;
      justify-content: center;
      overflow: hidden;
    }
    .cf-turnstile { display: block; }
  </style>
</head>
<body>
  <div class="cf-turnstile"
       data-sitekey="$_sitekey"
       data-callback="onTokenReceived"
       data-theme="dark"
       data-size="normal">
  </div>
  <script src="https://challenges.cloudflare.com/turnstile/v0/api.js" async defer></script>
  <script>
    function onTokenReceived(token) {
      if (window.TurnstileBridge) {
        TurnstileBridge.postMessage(token);
      }
    }
  </script>
</body>
</html>
''';
  }

  // ─── Token exchange ────────────────────────────────────────────────────────

  Future<void> _onTurnstileToken(String token) async {
    setState(() => _phase = _Phase.loading);

    try {
      final playerUrl = widget.params.buildPlayerUrl(_playerBase);

      // POST the token to player2; follow redirects manually so we land on
      // the actual player page inside our WebView.
      final response = await http
          .post(
            Uri.parse(playerUrl),
            headers: {
              'Content-Type': 'application/x-www-form-urlencoded',
              'Origin': 'https://streamworld.vercel.app',
              'Referer': 'https://streamworld.vercel.app/',
              'User-Agent':
                  'Mozilla/5.0 (Linux; Android 11) AppleWebKit/537.36 '
                  '(KHTML, like Gecko) Chrome/120 Mobile Safari/537.36',
            },
            body: {'cf-turnstile-response': token},
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode >= 200 && response.statusCode < 400) {
        // Success – now load the player URL in the main WebView
        _loadPlayer(playerUrl, token);
      } else {
        _setError('Verification failed (${response.statusCode}).\nPlease try again.');
      }
    } on TimeoutException {
      _setError('Request timed out. Check your connection and try again.');
    } catch (e) {
      _setError('Could not connect to the player.\n$e');
    }
  }

  void _loadPlayer(String url, String turnstileToken) {
    setState(() => _phase = _Phase.player);
    _webViewController?.loadUrl(
      urlRequest: URLRequest(
        url: WebUri(url),
        headers: {
          'X-Turnstile-Token': turnstileToken,
        },
      ),
    );
  }

  void _setError(String msg) {
    setState(() {
      _phase = _Phase.error;
      _errorMessage = msg;
    });
  }

  // ─── Navigation policy ────────────────────────────────────────────────────

  /// Returns true if the URL should stay inside our WebView.
  bool _isAllowedUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host == _allowedPlayerHost &&
          uri.path.startsWith(_allowedPlayerPath);
    } catch (_) {
      return false;
    }
  }

  Future<void> _openExternal(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // ─── Cookie injection ─────────────────────────────────────────────────────

  Future<void> _injectCookie(InAppWebViewController controller) async {
    if (widget.params.cookie == null) return;

    final cookieManager = CookieManager.instance();
    await cookieManager.setCookie(
      url: WebUri('https://$_allowedPlayerHost'),
      name: widget.params.cookieName,
      value: widget.params.cookie!,
      domain: _allowedPlayerHost,
      path: '/',
      isSecure: true,
      isHttpOnly: true,
    );
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0F),
      body: Stack(
        children: [
          // ── Phase: Turnstile ─────────────────────────────────────────────
          if (_phase == _Phase.turnstile) _buildTurnstileView(),

          // ── Phase: Loading (token exchange in progress) ──────────────────
          if (_phase == _Phase.loading) _buildLoadingView(),

          // ── Phase: Player ────────────────────────────────────────────────
          if (_phase == _Phase.player) _buildPlayerView(),

          // ── Phase: Error ─────────────────────────────────────────────────
          if (_phase == _Phase.error) _buildErrorView(),
        ],
      ),
    );
  }

  Widget _buildTurnstileView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _MiniLogo(),
          const SizedBox(height: 32),
          const Text(
            'Quick verification',
            style: TextStyle(
              color: Color(0xFFE8E8F0),
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Complete the check below to continue',
            style: TextStyle(
              color: Color(0xFF6B6B80),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 28),

          // Turnstile widget container
          Container(
            width: 302,
            height: 70,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: const Color(0xFF16161C),
            ),
            clipBehavior: Clip.hardEdge,
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
                userAgent:
                    'Mozilla/5.0 (Linux; Android 11) AppleWebKit/537.36 '
                    '(KHTML, like Gecko) Chrome/120 Mobile Safari/537.36',
                // Disable scrolling – widget is fixed size
                disableVerticalScroll: true,
                disableHorizontalScroll: true,
              ),
              onWebViewCreated: (controller) {
                _turnstileController = controller;
                controller.addJavaScriptHandler(
                  handlerName: 'TurnstileBridge',
                  callback: (args) {
                    if (args.isNotEmpty && args[0] is String) {
                      final token = args[0] as String;
                      _onTurnstileToken(token);
                    }
                  },
                );
              },
              shouldOverrideUrlLoading: (controller, action) async {
                // Don't allow any navigation in the turnstile view
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

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _MiniLogo(),
          const SizedBox(height: 32),
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Color(0xFF7C6EF7),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Connecting…',
            style: TextStyle(
              color: Color(0xFF6B6B80),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerView() {
    return InAppWebView(
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        domStorageEnabled: true,
        mediaPlaybackRequiresUserGesture: false,
        allowsInlineMediaPlayback: true,
        allowsPictureInPictureMediaPlayback: true,
        useWideViewPort: true,
        loadWithOverviewMode: true,
        userAgent:
            'Mozilla/5.0 (Linux; Android 11) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/120 Mobile Safari/537.36',
      ),
      onWebViewCreated: (controller) async {
        _webViewController = controller;
        // Inject cookie before loading
        await _injectCookie(controller);
      },
      shouldOverrideUrlLoading: (controller, action) async {
        final url = action.request.url?.toString() ?? '';
        if (_isAllowedUrl(url)) {
          return NavigationActionPolicy.ALLOW;
        }
        // Open everything else in the system browser
        _openExternal(url);
        return NavigationActionPolicy.CANCEL;
      },
      onLoadError: (controller, url, code, message) {
        _setError('Failed to load player ($code).\n$message');
      },
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(36),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Color(0xFF7C6EF7),
              size: 40,
            ),
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
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 13),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C6EF7).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFF7C6EF7).withOpacity(0.4),
                  ),
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

class _MiniLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
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
      child: const Icon(
        Icons.play_arrow_rounded,
        color: Colors.white,
        size: 22,
      ),
    );
  }
}
