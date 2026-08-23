import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const _websiteUrl = 'https://streamworld.vercel.app';

  Future<void> _openWebsite() async {
    final uri = Uri.parse(_websiteUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0F),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 36),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Logo mark
                _LogoMark(),
                const SizedBox(height: 32),

                // App name
                const Text(
                  'Sphere Player',
                  style: TextStyle(
                    color: Color(0xFFE8E8F0),
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 10),

                // Tagline
                const Text(
                  'Streaming companion',
                  style: TextStyle(
                    color: Color(0xFF6B6B80),
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 48),

                // Instruction card
                _InstructionCard(),
                const SizedBox(height: 32),

                // CTA button
                _WebsiteButton(onTap: _openWebsite),
                const SizedBox(height: 16),

                // Protocol note
                const _ProtocolNote(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LogoMark extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          colors: [Color(0xFF9B8EFF), Color(0xFF4B3FD1)],
          center: Alignment(-0.3, -0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C6EF7).withOpacity(0.35),
            blurRadius: 32,
            spreadRadius: 4,
          ),
        ],
      ),
      child: const Icon(
        Icons.play_arrow_rounded,
        color: Colors.white,
        size: 38,
      ),
    );
  }
}

class _InstructionCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF16161C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF2A2A38),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            'Getting started',
            style: TextStyle(
              color: Color(0xFF7C6EF7),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
          SizedBox(height: 12),
          _Step(
            number: '1',
            text: 'Visit StreamWorld from your browser',
          ),
          SizedBox(height: 10),
          _Step(
            number: '2',
            text: 'Open a video — the player will launch here automatically',
          ),
          SizedBox(height: 10),
          _Step(
            number: '3',
            text: 'Allow "Open in Sphere Player" when your browser asks',
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final String number;
  final String text;

  const _Step({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 20,
          height: 20,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF7C6EF7).withOpacity(0.15),
          ),
          child: Text(
            number,
            style: const TextStyle(
              color: Color(0xFF7C6EF7),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xFFBBBBCC),
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _WebsiteButton extends StatelessWidget {
  final VoidCallback onTap;
  const _WebsiteButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF7C6EF7), Color(0xFF5A4ED1)],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: const Text(
            'Go to StreamWorld',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _ProtocolNote extends StatelessWidget {
  const _ProtocolNote();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'Allow protocol links (streamplayer://) in your browser for the best experience.',
      textAlign: TextAlign.center,
      style: TextStyle(
        color: Color(0xFF44445A),
        fontSize: 11,
        height: 1.6,
      ),
    );
  }
}
