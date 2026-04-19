// screens/privacy_settings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../shared/theme/app_theme_constants.dart';
import '../../shared/utils/error_handler.dart';

class PrivacySettingsScreen extends ConsumerStatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  ConsumerState<PrivacySettingsScreen> createState() =>
      _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends ConsumerState<PrivacySettingsScreen> {
  bool _showPhoneNumber = true;
  bool _allowMessages = true;
  bool _showLocation = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = doc.data();
      if (data != null && data['privacySettings'] != null) {
        final settings = data['privacySettings'] as Map<String, dynamic>;
        setState(() {
          _showPhoneNumber = settings['showPhoneNumber'] ?? true;
          _allowMessages = settings['allowMessages'] ?? true;
          _showLocation = settings['showLocation'] ?? true;
        });
      }
      setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) ErrorHandler.showError(context, "فشل تحميل الإعدادات");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateSetting(String key, bool value) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // تحديث الواجهة فوراً (Optimistic UI)
    setState(() {
      if (key == 'showPhoneNumber') _showPhoneNumber = value;
      if (key == 'allowMessages') _allowMessages = value;
      if (key == 'showLocation') _showLocation = value;
    });

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'privacySettings': {
          'showPhoneNumber':
              key == 'showPhoneNumber' ? value : _showPhoneNumber,
          'allowMessages': key == 'allowMessages' ? value : _allowMessages,
          'showLocation': key == 'showLocation' ? value : _showLocation,
        }
      }, SetOptions(merge: true));
    } catch (e) {
      if (mounted) ErrorHandler.showError(context, "فشل حفظ الإعدادات");
      // إعادة التعيين في حال الفشل
      _loadSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("إعدادات الخصوصية"),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildSwitchTile(
                    "إظهار رقم الهاتف",
                    "السماح للطلاب برؤية رقم هاتفك في الملف الشخصي",
                    _showPhoneNumber,
                    (val) => _updateSetting('showPhoneNumber', val),
                    Icons.phone,
                  ),
                  const Divider(),
                  _buildSwitchTile(
                    "استقبال الرسائل",
                    "السماح للآخرين بإرسال رسائل نصية لك",
                    _allowMessages,
                    (val) => _updateSetting('allowMessages', val),
                    Icons.message,
                  ),
                  const Divider(),
                  _buildSwitchTile(
                    "إظهار الموقع التقريبي",
                    "السماح بعرض موقعك الجغرافي للباحثين عن محفظين",
                    _showLocation,
                    (val) => _updateSetting('showLocation', val),
                    Icons.location_on,
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildSwitchTile(String title, String subtitle, bool value,
      ValueChanged<bool> onChanged, IconData icon) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      title: Row(
        children: [
          Icon(icon, color: AppThemeConstants.primary, size: 20),
          const SizedBox(width: 12),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(right: 32.0, top: 4),
        child: Text(subtitle,
            style: const TextStyle(fontSize: 12, color: AppThemeConstants.textSecondary)),
      ),
      activeThumbColor: AppThemeConstants.secondary,
    );
  }
}
