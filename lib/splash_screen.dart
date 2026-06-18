import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  String _displayedText = '';
  final String _fullText = 'Pose Muse';
  bool _showTagline = false;
  bool _showCursor = true;

  late AnimationController _taglineController;
  late Animation<double> _taglineFade;

  @override
  void initState() {
    super.initState();

    _taglineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _taglineFade = Tween<double>(begin: 0, end: 1).animate(_taglineController);

    _startAnimation();
    _navigateToHome();
  }

  void _startAnimation() async {
    await Future.delayed(const Duration(milliseconds: 300));
    for (int i = 0; i < _fullText.length; i++) {
      await Future.delayed(const Duration(milliseconds: 90));
      if (mounted) {
        setState(() {
          _displayedText = _fullText.substring(0, i + 1);
        });
      }
    }
    await Future.delayed(const Duration(milliseconds: 400));
    if (mounted) setState(() => _showCursor = false);
    if (mounted) setState(() => _showTagline = true);
    _taglineController.forward();
  }

  void _navigateToHome() async {
    await Future.delayed(const Duration(milliseconds: 2800));
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  @override
  void dispose() {
    _taglineController.dispose();
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
            // App Icon
            ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Image.asset(
                'assets/images/app_icon.png',
                width: 100,
                height: 100,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 28),

            // Typewriter Text
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  _displayedText,
                  style: const TextStyle(
                    fontFamily: 'DancingScript',
                    fontSize: 44,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                if (_showCursor)
                  Container(
                    width: 2,
                    height: 30,
                    margin: const EdgeInsets.only(left: 2),
                    color: const Color(0xFF9C6FFF),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Tagline
            FadeTransition(
              opacity: _taglineFade,
              child: _showTagline
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 14,
                          height: 1,
                          color: const Color(0xFF9C6FFF),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'STRIKE THE PERFECT POSE',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            letterSpacing: 2.5,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 14,
                          height: 1,
                          color: const Color(0xFF9C6FFF),
                        ),
                      ],
                    )
                  : const SizedBox(),
            ),
          ],
        ),
      ),
    );
  }
}
