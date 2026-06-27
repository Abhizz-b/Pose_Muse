import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import 'login_screen.dart';
import 'privacy_policy_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Theme notifier — app-level theme change ke liye
// main.dart mein ValueListenableBuilder wrap karo (niche instructions hain)
// ─────────────────────────────────────────────────────────────────────────────
final themeNotifier = ValueNotifier<ThemeMode>(ThemeMode.dark);

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _pushNotifications = true;
  bool _poseReminders = true;
  int _themeIndex = 2; // 0=System, 1=Light, 2=Dark
  bool _uploadingPhoto = false;
  bool _loadingPrefs = true;

  // Base64 profile photo (Firebase Storage nahi hai)
  String? _profilePhotoBase64;

  final ImagePicker _picker = ImagePicker();

  // ── Dark theme colors ──
  static const _bgDark = Color(0xFF0D0D0D);
  static const _surfaceDark = Color(0xFF1A1A1A);
  static const _borderDark = Color(0xFF2A2A2A);

  // ── Light theme colors ──
  static const _bgLight = Color(0xFFF5F5F7);
  static const _surfaceLight = Color(0xFFFFFFFF);
  static const _borderLight = Color(0xFFE0E0E0);

  // ── Common colors ──
  static const _purple = Color(0xFF9C6FFF);
  static const _red = Color(0xFFE24B4A);

  User? get _user => AuthService.currentUser;

  bool get _isDark => _themeIndex != 1;

  Color get _bg => _isDark ? _bgDark : _bgLight;
  Color get _surface => _isDark ? _surfaceDark : _surfaceLight;
  Color get _border => _isDark ? _borderDark : _borderLight;
  Color get _textPrimary => _isDark ? const Color(0xFFF3F3F3) : const Color(0xFF111111);
  Color get _textSecondary => _isDark ? const Color(0xFF888888) : const Color(0xFF777777);

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
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final notifPrefs = await FirestoreService.loadNotificationPrefs();
    final themeIndex = await FirestoreService.loadThemePref();
    final photoBase64 = await FirestoreService.loadProfilePhoto();

    if (!mounted) return;
    setState(() {
      _pushNotifications = notifPrefs['pushNotifications'] ?? true;
      _poseReminders = notifPrefs['poseReminders'] ?? true;
      _themeIndex = themeIndex;
      _profilePhotoBase64 = photoBase64;
      _loadingPrefs = false;
    });
    _applyTheme(themeIndex);
  }

  void _applyTheme(int index) {
    switch (index) {
      case 0:
        themeNotifier.value = ThemeMode.system;
        break;
      case 1:
        themeNotifier.value = ThemeMode.light;
        break;
      case 2:
        themeNotifier.value = ThemeMode.dark;
        break;
    }
  }

  Future<void> _onThemeChanged(int index) async {
    setState(() => _themeIndex = index);
    _applyTheme(index);
    await FirestoreService.saveThemePref(index);
  }

  Future<void> _onPushToggled(bool v) async {
    setState(() => _pushNotifications = v);
    await FirestoreService.saveNotificationPrefs(
      pushNotifications: v,
      poseReminders: _poseReminders,
    );
  }

  Future<void> _onRemindersToggled(bool v) async {
    setState(() => _poseReminders = v);
    await FirestoreService.saveNotificationPrefs(
      pushNotifications: _pushNotifications,
      poseReminders: v,
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    if (_loadingPrefs) {
      return Scaffold(
        backgroundColor: _bg,
        body: Center(
          child: CircularProgressIndicator(color: _purple),
        ),
      );
    }

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
                    child: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: _textPrimary,
                      size: 15,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Text(
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
                          style: TextStyle(
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
            _sectionLabel('Appearance'),
            _settingsCard([
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.contrast_rounded,
                          color: _textSecondary,
                          size: 20,
                        ),
                        const SizedBox(width: 14),
                        Text(
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
                          color: _isDark
                              ? const Color(0xFF0D0D0D)
                              : const Color(0xFFEAEAEA),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.all(3),
                        child: Row(
                          children: [
                            _themeTab('System', 0),
                            _themeTab('Light', 1),
                            _themeTab('Dark', 2),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 24),

            // ── Notifications ──
            _sectionLabel('Notifications'),
            _settingsCard([
              _settingsRow(
                icon: Icons.notifications_outlined,
                label: 'Push notifications',
                trailing: _purpleSwitch(
                  value: _pushNotifications,
                  onChanged: _onPushToggled,
                ),
                showDivider: true,
              ),
              _settingsRow(
                icon: Icons.calendar_today_outlined,
                label: 'New pose reminders',
                trailing: _purpleSwitch(
                  value: _poseReminders,
                  onChanged: _onRemindersToggled,
                ),
              ),
            ]),
            const SizedBox(height: 24),

            // ── Account ──
            _sectionLabel('Account'),
            _settingsCard([
              _settingsRow(
                icon: Icons.lock_outline_rounded,
                label: 'Change password',
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  color: _textSecondary,
                  size: 20,
                ),
                onTap: () => _showChangePasswordDialog(context),
                showDivider: true,
              ),
              _settingsRow(
                icon: Icons.logout_rounded,
                label: 'Log out',
                labelColor: _red,
                iconColor: _red,
                onTap: () => _confirmLogout(context),
              ),
            ]),
            const SizedBox(height: 24),

            // ── About ──
            _sectionLabel('About'),
            _settingsCard([
              _settingsRow(
                icon: Icons.info_outline_rounded,
                label: 'Version',
                trailing: Text(
                  '0.8.0',
                  style: TextStyle(
                    color: _textSecondary,
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
                showDivider: true,
              ),
              _settingsRow(
                icon: Icons.apps_rounded,
                label: 'About PoseMuse',
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  color: _textSecondary,
                  size: 20,
                ),
                onTap: () => _showAboutDialog(context),
                showDivider: true,
              ),
              _settingsRow(
                icon: Icons.shield_outlined,
                label: 'Privacy policy',
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  color: _textSecondary,
                  size: 20,
                ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PrivacyPolicyScreen(),
                  ),
                ),
                showDivider: true,
              ),
              _settingsRow(
                icon: Icons.description_outlined,
                label: 'Terms of service',
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  color: _textSecondary,
                  size: 20,
                ),
                onTap: () => _showTermsDialog(context),
                showDivider: true,
              ),
              _settingsRow(
                icon: Icons.help_outline_rounded,
                label: 'Help & support',
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  color: _textSecondary,
                  size: 20,
                ),
                onTap: () => _showHelpDialog(context),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Avatar — base64 ya initials
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildAvatar() {
    Widget photoWidget;

    if (_profilePhotoBase64 != null) {
      try {
        final bytes = base64Decode(_profilePhotoBase64!);
        photoWidget = ClipOval(
          child: Image.memory(
            bytes,
            width: 64,
            height: 64,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _initialsWidget(),
          ),
        );
      } catch (_) {
        photoWidget = _initialsWidget();
      }
    } else {
      photoWidget = _initialsWidget();
    }

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
          child: photoWidget,
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

  Widget _initialsWidget() {
    return Center(
      child: Text(
        _initials,
        style: const TextStyle(
          color: _purple,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Reusable UI builders (theme-aware)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: _textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w500,
          letterSpacing: 2,
          fontFamily: 'monospace',
        ),
      ),
    );
  }

  Widget _settingsCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(children: children),
    );
  }

  Widget _settingsRow({
    required IconData icon,
    required String label,
    Widget? trailing,
    VoidCallback? onTap,
    bool showDivider = false,
    Color? labelColor,
    Color? iconColor,
  }) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(icon, color: iconColor ?? _textSecondary, size: 20),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: labelColor ?? _textPrimary,
                      fontSize: 15,
                    ),
                  ),
                ),
                if (trailing != null) trailing,
              ],
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            thickness: 1,
            color: _border,
            indent: 16,
            endIndent: 16,
          ),
      ],
    );
  }

  Widget _themeTab(String label, int index) {
    final selected = _themeIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => _onThemeChanged(index),
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
                color: selected
                    ? Colors.white
                    : _textSecondary,
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _purpleSwitch({
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
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
          color: value ? _purple : _border,
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

  // ─────────────────────────────────────────────────────────────────────────
  // Dialogs
  // ─────────────────────────────────────────────────────────────────────────

  void _editName(BuildContext context) {
    final controller = TextEditingController(text: _user?.displayName ?? '');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Edit name',
          style: TextStyle(color: _textPrimary, fontWeight: FontWeight.w600),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: _textPrimary),
          cursorColor: _purple,
          decoration: InputDecoration(
            hintText: 'Your name',
            hintStyle: TextStyle(color: _textSecondary),
            enabledBorder: UnderlineInputBorder(
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
            child: Text('Cancel', style: TextStyle(color: _textSecondary)),
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
              title: Text(
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
              title: Text(
                'Choose from gallery',
                style: TextStyle(color: _textPrimary),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickPhoto(ImageSource.gallery);
              },
            ),
            if (_profilePhotoBase64 != null)
              ListTile(
                leading: Icon(Icons.delete_outline_rounded, color: _red),
                title: Text('Remove photo', style: TextStyle(color: _red)),
                onTap: () async {
                  Navigator.pop(context);
                  await FirestoreService.deleteProfilePhoto();
                  if (!mounted) return;
                  setState(() => _profilePhotoBase64 = null);
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
      maxWidth: 400,        // resize before encoding
      maxHeight: 400,
      imageQuality: 70,     // compress to stay under 300 KB
    );
    if (picked == null) return;

    setState(() => _uploadingPhoto = true);
    final result = await AuthService.uploadProfilePhoto(File(picked.path));
    if (!mounted) return;
    setState(() {
      _uploadingPhoto = false;
      if (result != null) _profilePhotoBase64 = result;
    });

    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Photo upload failed. Try a smaller image.',
          ),
          backgroundColor: _red,
        ),
      );
    }
  }

  void _confirmLogout(BuildContext context) {
    HapticFeedback.mediumImpact();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Log out?',
          style: TextStyle(color: _textPrimary, fontWeight: FontWeight.w600),
        ),
        content: Text(
          'You\'ll need to sign in again to access your account.',
          style: TextStyle(color: _textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: _textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await AuthService.signOut();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (_) => false,
                );
              }
            },
            child: Text(
              'Log out',
              style: TextStyle(color: _red, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool obscure = true;
    bool loading = false;
    String? errorText;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: _surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Change password',
            style: TextStyle(
              color: _textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _passwordField(
                  currentCtrl,
                  'Current password',
                  obscure,
                  () => setDialogState(() => obscure = !obscure),
                ),
                const SizedBox(height: 12),
                _passwordField(
                  newCtrl,
                  'New password',
                  obscure,
                  () => setDialogState(() => obscure = !obscure),
                ),
                const SizedBox(height: 12),
                _passwordField(
                  confirmCtrl,
                  'Confirm new password',
                  obscure,
                  () => setDialogState(() => obscure = !obscure),
                ),
                if (errorText != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    errorText!,
                    style: const TextStyle(color: _red, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: loading ? null : () => Navigator.pop(dialogContext),
              child:
                  Text('Cancel', style: TextStyle(color: _textSecondary)),
            ),
            TextButton(
              onPressed: loading
                  ? null
                  : () async {
                      final current = currentCtrl.text.trim();
                      final newPass = newCtrl.text.trim();
                      final confirm = confirmCtrl.text.trim();

                      if (current.isEmpty ||
                          newPass.isEmpty ||
                          confirm.isEmpty) {
                        setDialogState(
                            () => errorText = 'Fill in all fields.');
                        return;
                      }
                      if (newPass.length < 6) {
                        setDialogState(
                          () => errorText =
                              'New password must be at least 6 characters.',
                        );
                        return;
                      }
                      if (newPass != confirm) {
                        setDialogState(
                            () => errorText = 'Passwords do not match.');
                        return;
                      }
                      setDialogState(() {
                        loading = true;
                        errorText = null;
                      });
                      final error = await AuthService.changePassword(
                        currentPassword: current,
                        newPassword: newPass,
                      );
                      if (error != null) {
                        setDialogState(() {
                          loading = false;
                          errorText = error;
                        });
                        return;
                      }
                      Navigator.pop(dialogContext);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Password updated.'),
                            backgroundColor: Color(0xFF2E7D32),
                          ),
                        );
                      }
                    },
              child: loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _purple,
                      ),
                    )
                  : const Text(
                      'Update',
                      style: TextStyle(
                        color: _purple,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _passwordField(
    TextEditingController controller,
    String hint,
    bool obscure,
    VoidCallback toggleObscure,
  ) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: TextStyle(color: _textPrimary),
      cursorColor: _purple,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: _textSecondary),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: _border),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: _purple),
        ),
        suffixIcon: GestureDetector(
          onTap: toggleObscure,
          child: Icon(
            obscure
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            color: _textSecondary,
            size: 18,
          ),
        ),
      ),
    );
  }

  // ── About dialogs ──

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _purple.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.self_improvement_rounded,
                  color: _purple, size: 20),
            ),
            const SizedBox(width: 10),
            Text(
              'PoseMuse',
              style: TextStyle(
                color: _textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        content: Text(
          'PoseMuse is your AI-powered photography pose assistant.\n\n'
          'Discover hundreds of poses, organise them into albums, '
          'and get real-time pose guidance using your camera.\n\n'
          'Version 0.8.0\nBuilt with Flutter & Firebase.',
          style: TextStyle(color: _textSecondary, fontSize: 13, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: _purple)),
          ),
        ],
      ),
    );
  }

  void _showTermsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Terms of Service',
          style: TextStyle(color: _textPrimary, fontWeight: FontWeight.w600),
        ),
        content: SingleChildScrollView(
          child: Text(
            'By using PoseMuse, you agree to use it for personal, non-commercial purposes only.\n\n'
            'You may not redistribute, reverse-engineer, or misuse any content or features within the app.\n\n'
            'PoseMuse is provided "as is" without warranty of any kind. '
            'We reserve the right to update these terms at any time.\n\n'
            'For questions, contact us at abhipsabose80@gmail.com.',
            style:
                TextStyle(color: _textSecondary, fontSize: 13, height: 1.6),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: _purple)),
          ),
        ],
      ),
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Help & Support',
          style: TextStyle(color: _textPrimary, fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Need help? Here are some quick tips:\n',
              style: TextStyle(
                  color: _textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600),
            ),
            Text(
              '• Tap any pose to preview it in full screen.\n'
              '• Long-press a pose to save it to an album.\n'
              '• Use the camera tab for real-time pose guidance.\n'
              '• Enable notifications in Settings to get daily pose reminders.\n\n'
              'Still need help? Reach us at:\nabhipsabose80@gmail.com',
              style:
                  TextStyle(color: _textSecondary, fontSize: 13, height: 1.6),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it', style: TextStyle(color: _purple)),
          ),
        ],
      ),
    );
  }
}
