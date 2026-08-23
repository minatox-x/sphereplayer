import 'dart:async';
import 'dart:io';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import '../models/player_params.dart';

typedef ProtocolCallback = void Function(PlayerParams params);

class ProtocolHandler {
  static final ProtocolHandler instance = ProtocolHandler._internal();
  ProtocolHandler._internal();

  final AppLinks _appLinks = AppLinks();
  StreamSubscription? _sub;
  ProtocolCallback? _callback;

  /// Call once from app init. The callback fires whenever a valid
  /// streamplayer:// link is received (initial launch or while running).
  void init(ProtocolCallback callback) {
    _callback = callback;

    // Handle the link that cold-started the app
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) _handle(uri);
    });

    // Handle links while the app is already running
    _sub = _appLinks.uriLinkStream.listen((uri) {
      _handle(uri);
    }, onError: (err) {
      debugPrint('[ProtocolHandler] stream error: $err');
    });
  }

  void _handle(Uri uri) {
    debugPrint('[ProtocolHandler] received: $uri');
    if (uri.scheme != 'streamplayer') return;

    final params = PlayerParams.fromUri(uri);
    _callback?.call(params);
  }

  void dispose() {
    _sub?.cancel();
  }
}
