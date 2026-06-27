import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const _bg = Color(0xFF0D0D0D);
  static const _surface = Color(0xFF1A1A1A);
  static const _border = Color(0xFF2A2A2A);
  static const _purple = Color(0xFF9C6FFF);
  static const _textPrimary = Color(0xFFF3F3F3);
  static const _textSecondary = Color(0xFF888888);

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: _bg,
      body: Column(
        children: [
          // ── Header ──
          Container(
            padding: EdgeInsets.only(
              top: topPad + 16,
              left: 20,
              right: 20,
              bottom: 16,
            ),
            decoration: const BoxDecoration(
              color: _bg,
              border: Border(bottom: BorderSide(color: _border)),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _surface,
                      shape: BoxShape.circle,
                      border: Border.all(color: _border),
                    ),
                    child: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: _textPrimary,
                      size: 15,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                const Text(
                  'Privacy Policy',
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),

          // ── Content ──
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Last updated chip
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: _purple.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _purple.withOpacity(0.25)),
                    ),
                    child: const Text(
                      'Last updated: June 2026',
                      style: TextStyle(
                        color: _purple,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'monospace',
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  const _PolicySection(
                    title: '1. Information We Collect',
                    content:
                        'PoseMuse collects the following information to provide and improve our services:\n\n'
                        '• Account information: email address and display name when you register.\n'
                        '• Profile photo: uploaded by you, stored securely in our database.\n'
                        '• Usage data: poses you save, albums you create, and app preferences.\n'
                        '• Device information: device type and OS version for compatibility purposes.',
                  ),

                  const _PolicySection(
                    title: '2. How We Use Your Information',
                    content:
                        'We use your information solely to:\n\n'
                        '• Provide and personalise your PoseMuse experience.\n'
                        '• Sync your poses, albums, and settings across sessions.\n'
                        '• Send pose reminders and push notifications (only if you enable them).\n'
                        '• Improve app performance and fix issues.',
                  ),

                  const _PolicySection(
                    title: '3. Data Storage & Security',
                    content:
                        'Your data is stored securely using Google Firebase (Firestore). '
                        'We use industry-standard encryption for data in transit and at rest. '
                        'Profile photos are stored as encoded data tied to your account. '
                        'We do not sell or share your personal data with third parties.',
                  ),

                  const _PolicySection(
                    title: '4. Notifications',
                    content:
                        'PoseMuse may send push notifications for pose reminders and updates. '
                        'You can enable or disable notifications at any time from the Settings screen. '
                        'Notification preferences are saved to your account and respected across devices.',
                  ),

                  const _PolicySection(
                    title: '5. Third-Party Services',
                    content:
                        'PoseMuse uses the following third-party services:\n\n'
                        '• Google Firebase — authentication, database, and cloud functions.\n'
                        '• Google ML Kit — on-device pose detection (no data sent to servers).\n\n'
                        'These services have their own privacy policies which we encourage you to review.',
                  ),

                  const _PolicySection(
                    title: '6. Your Rights',
                    content:
                        'You have the right to:\n\n'
                        '• Access the personal data we hold about you.\n'
                        '• Update or correct your information via Settings.\n'
                        '• Delete your account and all associated data at any time.\n'
                        '• Opt out of notifications from the Settings screen.',
                  ),

                  const _PolicySection(
                    title: '7. Children\'s Privacy',
                    content:
                        'PoseMuse is not directed at children under the age of 13. '
                        'We do not knowingly collect personal information from children. '
                        'If you believe a child has provided us with personal data, please contact us.',
                  ),

                  const _PolicySection(
                    title: '8. Changes to This Policy',
                    content:
                        'We may update this Privacy Policy from time to time. '
                        'The updated version will be indicated by the "Last updated" date at the top of this page. '
                        'Continued use of PoseMuse after changes constitutes acceptance of the updated policy.',
                  ),

                  // ── Contact Us ──
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _purple.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: _purple.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.mail_outline_rounded,
                                color: _purple,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Contact Us',
                              style: TextStyle(
                                color: _textPrimary,
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'For privacy questions, email us at',
                          style: TextStyle(
                            color: _textSecondary,
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        GestureDetector(
                          onTap: () {
                            Clipboard.setData(
                              const ClipboardData(
                                text: 'abhipsabose80@gmail.com',
                              ),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Email copied to clipboard'),
                                backgroundColor: Color(0xFF2E7D32),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: _purple.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _purple.withOpacity(0.2),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.alternate_email_rounded,
                                  color: _purple,
                                  size: 14,
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  'abhipsabose80@gmail.com',
                                  style: TextStyle(
                                    color: _purple,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.copy_rounded,
                                  color: _purple.withOpacity(0.6),
                                  size: 13,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'We aim to respond to all privacy-related queries within 48 hours.',
                          style: TextStyle(
                            color: _textSecondary,
                            fontSize: 12,
                            height: 1.5,
                          ),
                        ),
                      ],
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
  }
}

// ── Reusable policy section ──
class _PolicySection extends StatelessWidget {
  final String title;
  final String content;

  const _PolicySection({required this.title, required this.content});

  static const _textPrimary = Color(0xFFF3F3F3);
  static const _textSecondary = Color(0xFF888888);
  static const _border = Color(0xFF2A2A2A);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: _textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(
              color: _textSecondary,
              fontSize: 13,
              height: 1.7,
            ),
          ),
          const SizedBox(height: 20),
          const Divider(height: 1, thickness: 1, color: _border),
        ],
      ),
    );
  }
}
