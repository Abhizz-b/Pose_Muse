import 'package:flutter/material.dart';
import '../screens/settings_screen.dart';

class AboutPoseMuseScreen extends StatelessWidget {
  const AboutPoseMuseScreen({super.key});

  static const _purple = Color(0xFF9C6FFF);

  // Theme-aware colors
  static const _bgDark = Color(0xFF0D0D0D);
  static const _bgLight = Color(0xFFF5F5F7);
  static const _surfaceDark = Color(0xFF1A1A1A);
  static const _surfaceLight = Color(0xFFFFFFFF);
  static const _borderDark = Color(0xFF2A2A2A);
  static const _borderLight = Color(0xFFE0E0E0);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, themeMode, _) {
        final isDark = themeMode != ThemeMode.light;
        final bg = isDark ? _bgDark : _bgLight;
        final surface = isDark ? _surfaceDark : _surfaceLight;
        final border = isDark ? _borderDark : _borderLight;
        final textPrimary = isDark
            ? const Color(0xFFF3F3F3)
            : const Color(0xFF111111);
        final textSecondary = isDark
            ? const Color(0xFF888888)
            : const Color(0xFF666666);
        final topPad = MediaQuery.of(context).padding.top;

        return Scaffold(
          backgroundColor: bg,
          body: Column(
            children: [
              // Header
              Container(
                padding: EdgeInsets.only(
                  top: topPad + 16,
                  left: 20,
                  right: 20,
                  bottom: 16,
                ),
                decoration: BoxDecoration(
                  color: bg,
                  border: Border(bottom: BorderSide(color: border)),
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: surface,
                          shape: BoxShape.circle,
                          border: Border.all(color: border),
                        ),
                        child: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: textPrimary,
                          size: 15,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      'About Pose Muse',
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 26,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Greeting card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: _purple.withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hey there!',
                              style: TextStyle(
                                color: _purple,
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Thank you so much for using Pose Muse.',
                              style: TextStyle(
                                color: textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Story
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'The Story',
                              style: TextStyle(
                                color: textPrimary,
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              "I'm Abhipsa Bose, a final year B.Tech student. This app started with a very ordinary moment — I was sitting in my college library, trying to click selfies, and completely ran out of poses.\n\nThat small frustration sparked an idea: what if an app could detect your surroundings and suggest the perfect pose for the moment?\n\nSo I built it. From scratch. Alone.\n\nThe idea, the design, the code, the deployment — every single part of Pose Muse was made by just me. This is my very first app, and I'm genuinely proud to have taken it from a random thought in a library to something you're actually using right now.",
                              style: TextStyle(
                                color: textSecondary,
                                fontSize: 14,
                                height: 1.75,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: _purple.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: _purple.withOpacity(0.2),
                                ),
                              ),
                              child: Text(
                                'Also — yes, the dataset in the catalog? That\'s me. Had to avoid copyright issues somehow.',
                                style: TextStyle(
                                  color: _purple,
                                  fontSize: 13,
                                  height: 1.5,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // About the app
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'About the App',
                              style: TextStyle(
                                color: textPrimary,
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _featureRow(
                              icon: Icons.self_improvement_rounded,
                              title: 'AI Pose Assistant',
                              desc:
                                  'Pose Muse is your personal photography pose guide — browse hundreds of curated poses and find the perfect one for any moment.',
                              textPrimary: textPrimary,
                              textSecondary: textSecondary,
                              border: border,
                            ),
                            const SizedBox(height: 12),
                            _featureRow(
                              icon: Icons.crop_free_rounded,
                              title: 'Scene Detection',
                              desc:
                                  'Point your camera at your surroundings and let PoseMuse recommend poses that match your environment.',
                              textPrimary: textPrimary,
                              textSecondary: textSecondary,
                              border: border,
                            ),
                            const SizedBox(height: 12),
                            _featureRow(
                              icon: Icons.photo_library_outlined,
                              title: 'Your Pose Collection',
                              desc:
                                  'Save your favourite poses, organise them into albums, and access them anytime — even offline.',
                              textPrimary: textPrimary,
                              textSecondary: textSecondary,
                              border: border,
                            ),
                            const SizedBox(height: 12),
                            _featureRow(
                              icon: Icons.camera_alt_outlined,
                              title: 'Real-time Guidance',
                              desc:
                                  'Use the camera tab to get live pose guidance while you shoot — no more awkward pauses between shots.',
                              textPrimary: textPrimary,
                              textSecondary: textSecondary,
                              border: border,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Feedback
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Your Feedback Matters',
                              style: TextStyle(
                                color: textPrimary,
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'This is just the beginning. I have so many ideas I want to bring to life, and your support is what makes that possible.\n\nIf you have feedback, suggestions, or just want to say hi — I would genuinely love to hear from you.',
                              style: TextStyle(
                                color: textSecondary,
                                fontSize: 14,
                                height: 1.7,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'abhipsabose80@gmail.com',
                              style: TextStyle(
                                color: _purple,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),
                      Center(
                        child: Text(
                          'Made with love, one pose at a time.',
                          style: TextStyle(
                            color: textSecondary,
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _featureRow({
    required IconData icon,
    required String title,
    required String desc,
    required Color textPrimary,
    required Color textSecondary,
    required Color border,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _purple.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: _purple, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                desc,
                style: TextStyle(
                  color: textSecondary,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
