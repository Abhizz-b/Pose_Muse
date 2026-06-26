import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _pushNotifications = true;
  bool _poseReminders = true;
  int _themeIndex = 2; // 0 = System, 1 = Light, 2 = Dark
  bool _uploadingPhoto = false;

  final ImagePicker _picker = ImagePicker();

  // ── Colors ──
  static const _bg = Color(0xFF0D0D0D);
  static const _surface = Color(0xFF1A1A1A);
  static const _border = Color(0xFF2A2A2A);
  static const _purple = Color(0xFF9C6FFF);
  static const _textPrimary = Color(0xFFF3F3F3);
  static const _textSecondary = Color(0xFF888888);
  static const _red = Color(0xFFE24B4A);

  User? get _user => AuthService.currentUser;

  String get _displayName {
    final name = _user?.displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    return 'Add your name';
  }

  String get _initials {
    final name = _user?.displayName?.trim();
    if (name != null && name.isNotEmpty) {
      final parts = name.split(RegExp(r'\s+'));
      if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
        return (parts[0][0] + parts[1][0]).toUpperCase();
      }
      return name[0].toUpperCase();
    }
    final email = _user?.email;
    if (email != null && email.isNotEmpty) return email[0].toUpperCase();
    return '?';
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: _bg,
      body: SingleChildScrollView(
        padding: EdgeInsets.only(
          top: topPad + 16,
          left: 20,
          right: 20,
          bottom: 40,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Back + Title ──
            Row(
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
                  'Settings',
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── Profile Card ──
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _border),
              ),
              child: Row(
                children: [
                  _buildAvatar(),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                _displayName,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: _displayName == 'Add your name'
                                      ? _textSecondary
                                      : _textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  fontStyle: _displayName == 'Add your name'
                                      ? FontStyle.italic
                                      : FontStyle.normal,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: () => _editName(context),
                              behavior: HitTestBehavior.opaque,
                              child: const Padding(
                                padding: EdgeInsets.all(2),
                                child: Icon(
                                  Icons.edit_outlined,
                                  color: _purple,
                                  size: 15,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _user?.email ?? '',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _textSecondary,
                            fontSize: 12,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Appearance ──
            _SectionLabel('Appearance'),
            _SettingsCard(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.contrast_rounded,
                            color: _textSecondary,
                            size: 20,
                          ),
                          const SizedBox(width: 14),
                          const Text(
                            'Theme',
                            style: TextStyle(color: _textPrimary, fontSize: 15),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.only(left: 34),
                        child: Container(
                          decoration: BoxDecoration(
                            color: _bg,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.all(3),
                          child: Row(
                            children: [
                              _ThemeTab(
                                label: 'System',
                                selected: _themeIndex == 0,
                                onTap: () => setState(() => _themeIndex = 0),
                              ),
                              _ThemeTab(
                                label: 'Light',
                                selected: _themeIndex == 1,
                                onTap: () => setState(() => _themeIndex = 1),
                              ),
                              _ThemeTab(
                                label: 'Dark',
                                selected: _themeIndex == 2,
                                onTap: () => setState(() => _themeIndex = 2),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── Notifications ──
            _SectionLabel('Notifications'),
            _SettingsCard(
              children: [
                _SettingsRow(
                  icon: Icons.notifications_outlined,
                  label: 'Push notifications',
                  trailing: _PurpleSwitch(
                    value: _pushNotifications,
                    onChanged: (v) => setState(() => _pushNotifications = v),
                  ),
                  showDivider: true,
                ),
                _SettingsRow(
                  icon: Icons.calendar_today_outlined,
                  label: 'New pose reminders',
                  trailing: _PurpleSwitch(
                    value: _poseReminders,
                    onChanged: (v) => setState(() => _poseReminders = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── Account ──
            _SectionLabel('Account'),
            _SettingsCard(
              children: [
                _SettingsRow(
                  icon: Icons.lock_outline_rounded,
                  label: 'Change password',
                  trailing: const Icon(
                    Icons.chevron_right_rounded,
                    color: _textSecondary,
                    size: 20,
                  ),
                  onTap: () {},
                  showDivider: true,
                ),
                _SettingsRow(
                  icon: Icons.logout_rounded,
                  label: 'Log out',
                  labelColor: _red,
                  iconColor: _red,
                  onTap: () => _confirmLogout(context),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── About ──
            _SectionLabel('About'),
            _SettingsCard(
              children: [
                _SettingsRow(
                  icon: Icons.info_outline_rounded,
                  label: 'Version',
                  trailing: const Text(
                    '0.8.0',
                    style: TextStyle(
                      color: _textSecondary,
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                  showDivider: true,
                ),
                _SettingsRow(
                  icon: Icons.shield_outlined,
                  label: 'Privacy policy',
                  trailing: const Icon(
                    Icons.chevron_right_rounded,
                    color: _textSecondary,
                    size: 20,
                  ),
                  onTap: () {},
                  showDivider: true,
                ),
                _SettingsRow(
                  icon: Icons.description_outlined,
                  label: 'Terms of service',
                  trailing: const Icon(
                    Icons.chevron_right_rounded,
                    color: _textSecondary,
                    size: 20,
                  ),
                  onTap: () {},
                  showDivider: true,
                ),
                _SettingsRow(
                  icon: Icons.help_outline_rounded,
                  label: 'Help & support',
                  trailing: const Icon(
                    Icons.chevron_right_rounded,
                    color: _textSecondary,
                    size: 20,
                  ),
                  onTap: () {},
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Avatar with photo / initials + camera badge ──
  Widget _buildAvatar() {
    final photoUrl = _user?.photoURL;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF1E1A2E),
            border: Border.all(color: _purple.withOpacity(0.35), width: 1.5),
          ),
          child: photoUrl != null
              ? ClipOval(
                  child: Image.network(
                    photoUrl,
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Center(
                      child: Text(
                        _initials,
                        style: const TextStyle(
                          color: _purple,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                )
              : Center(
                  child: Text(
                    _initials,
                    style: const TextStyle(
                      color: _purple,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
        ),
        if (_uploadingPhoto)
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black54,
              ),
              child: const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        Positioned(
          bottom: -2,
          right: -2,
          child: GestureDetector(
            onTap: _uploadingPhoto ? null : () => _showPhotoOptions(context),
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: _purple,
                shape: BoxShape.circle,
                border: Border.all(color: _surface, width: 2),
              ),
              child: const Icon(
                Icons.camera_alt_rounded,
                color: Colors.white,
                size: 11,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _editName(BuildContext context) {
    final controller = TextEditingController(text: _user?.displayName ?? '');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Edit name',
          style: TextStyle(color: _textPrimary, fontWeight: FontWeight.w600),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: _textPrimary),
          cursorColor: _purple,
          decoration: InputDecoration(
            hintText: 'Your name',
            hintStyle: const TextStyle(color: _textSecondary),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: _border),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: _purple),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: _textSecondary),
            ),
          ),
          TextButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(context);
              final error = await AuthService.updateDisplayName(name);
              if (!mounted) return;
              if (error != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(error), backgroundColor: _red),
                );
              } else {
                setState(() {});
              }
            },
            child: const Text(
              'Save',
              style: TextStyle(color: _purple, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _showPhotoOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: _border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: _purple),
              title: const Text(
                'Take photo',
                style: TextStyle(color: _textPrimary),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickPhoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: _purple),
              title: const Text(
                'Choose from gallery',
                style: TextStyle(color: _textPrimary),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickPhoto(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 800,
      imageQuality: 85,
    );
    if (picked == null) return;

    setState(() => _uploadingPhoto = true);
    final url = await AuthService.uploadProfilePhoto(File(picked.path));
    if (!mounted) return;
    setState(() => _uploadingPhoto = false);

    if (url == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Photo upload failed. Try again.'),
          backgroundColor: _red,
        ),
      );
    } else {
      setState(() {});
    }
  }

  void _confirmLogout(BuildContext context) {
    HapticFeedback.mediumImpact();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Log out?',
          style: TextStyle(color: _textPrimary, fontWeight: FontWeight.w600),
        ),
        content: const Text(
          'You\'ll need to sign in again to access your account.',
          style: TextStyle(color: _textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: _textSecondary),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // dialog band karo
              await AuthService.signOut();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (_) => false,
                );
              }
            },
            child: const Text(
              'Log out',
              style: TextStyle(color: _red, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section Label ──
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: Color(0xFF888888),
          fontSize: 11,
          fontWeight: FontWeight.w500,
          letterSpacing: 2,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}

// ── Settings Card Container ──
class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(children: children),
    );
  }
}

// ── Single Settings Row ──
class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showDivider;
  final Color labelColor;
  final Color iconColor;

  const _SettingsRow({
    required this.icon,
    required this.label,
    this.trailing,
    this.onTap,
    this.showDivider = false,
    this.labelColor = const Color(0xFFF3F3F3),
    this.iconColor = const Color(0xFF888888),
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(icon, color: iconColor, size: 20),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(color: labelColor, fontSize: 15),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
        ),
        if (showDivider)
          const Divider(
            height: 1,
            thickness: 1,
            color: Color(0xFF2A2A2A),
            indent: 16,
            endIndent: 16,
          ),
      ],
    );
  }
}

// ── Theme Selector Tab ──
class _ThemeTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  static const _purple = Color(0xFF9C6FFF);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? _purple : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : const Color(0xFF888888),
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Purple Toggle Switch ──
class _PurpleSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _PurpleSwitch({required this.value, required this.onChanged});

  static const _purple = Color(0xFF9C6FFF);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onChanged(!value);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 44,
        height: 26,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(13),
          color: value ? _purple : const Color(0xFF2A2A2A),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.all(3),
            width: 20,
            height: 20,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
