import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  String _taglineText = '';
  final String _fullTagline = 'STRIKE THE PERFECT POSE';
  bool _showCursor = false;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;
  late AnimationController _lineController;
  late Animation<double> _lineAnim;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _fadeAnim = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeIn));

    _lineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _lineAnim = Tween<double>(begin: 0, end: 1).animate(_lineController);

    _startSequence();
    _navigateToHome();
  }

  void _startSequence() async {
    await Future.delayed(const Duration(milliseconds: 300));
    _fadeController.forward();

    await Future.delayed(const Duration(milliseconds: 2500));
    _lineController.forward();
    if (mounted) setState(() => _showCursor = true);

    for (int i = 0; i < _fullTagline.length; i++) {
      await Future.delayed(const Duration(milliseconds: 55));
      if (mounted) {
        setState(() {
          _taglineText = _fullTagline.substring(0, i + 1);
        });
      }
    }
    await Future.delayed(const Duration(milliseconds: 400));
    if (mounted) setState(() => _showCursor = false);
  }

  void _navigateToHome() async {
    await Future.delayed(const Duration(milliseconds: 4500));
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _lineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon
            ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Image.asset(
                'assets/images/app_icon.png',
                width: 90,
                height: 90,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 28),

            // Pose Muse fade in
            FadeTransition(
              opacity: _fadeAnim,
              child: ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Colors.white, Color(0xFFC4A8FF), Color(0xFF9C6FFF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ).createShader(bounds),
                child: const Text(
                  'Pose Muse',
                  style: TextStyle(
                    fontFamily: 'DancingScript',
                    fontSize: 52,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Tagline typewriter
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FadeTransition(
                  opacity: _lineAnim,
                  child: Container(
                    width: 18,
                    height: 1,
                    color: const Color(0xFF9C6FFF),
                  ),
                ),
                const SizedBox(width: 10),
                Row(
                  children: [
                    Text(
                      _taglineText,
                      style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFC4A8FF),
                        letterSpacing: 2.5,
                      ),
                    ),
                    if (_showCursor)
                      Container(
                        width: 1.5,
                        height: 12,
                        margin: const EdgeInsets.only(left: 1),
                        color: const Color(0xFF9C6FFF),
                      ),
                  ],
                ),
                const SizedBox(width: 10),
                FadeTransition(
                  opacity: _lineAnim,
                  child: Container(
                    width: 18,
                    height: 1,
                    color: const Color(0xFF9C6FFF),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
