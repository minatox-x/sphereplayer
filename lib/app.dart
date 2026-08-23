import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/player_screen.dart';
import 'services/protocol_handler.dart';

class SpherePlayerApp extends StatefulWidget {
  const SpherePlayerApp({super.key});

  @override
  State<SpherePlayerApp> createState() => _SpherePlayerAppState();
}

class _SpherePlayerAppState extends State<SpherePlayerApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _initProtocolHandler();
  }

  void _initProtocolHandler() {
    ProtocolHandler.instance.init((params) {
      _navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => PlayerScreen(params: params),
        ),
        (route) => false,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'Sphere Player',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF7C6EF7),
          secondary: Color(0xFF5A4ED1),
          surface: Color(0xFF0D0D0F),
          onSurface: Color(0xFFE8E8F0),
        ),
        scaffoldBackgroundColor: const Color(0xFF0D0D0F),
        fontFamily: 'SF Pro Display',
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
