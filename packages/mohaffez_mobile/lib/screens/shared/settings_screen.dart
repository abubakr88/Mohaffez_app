import 'package:firebase_auth/firebase_auth.dart';
import 'package:mohaffez_core/mohaffez_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../shared/theme/theme_extensions.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('الإعدادات'),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // التطبيق
            buildSection(
              title: 'التطبيق',
              children: [
                buildSettingTile(
                  icon: Icons.language,
                  title: 'اللغة',
                  subtitle: 'العربية',
                  onTap: () => showLanguageDialog(context),
                ),
                const Divider(height: 1),
                buildSettingTile(
                  icon: Icons.notifications,
                  title: 'الإشعارات',
                  subtitle: 'إدارة الإشعارات',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const NotificationSettingsScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),

            Spacing.vLg,

            // الحساب
            buildSection(
              title: 'الحساب',
              children: [
                buildSettingTile(
                  icon: Icons.lock,
                  title: 'تغيير كلمة المرور',
                  subtitle: 'تحديث كلمة المرور',
                  onTap: () => showChangePasswordDialog(context),
                ),
                const Divider(height: 1),
                buildSettingTile(
                  icon: Icons.email,
                  title: 'البريد الإلكتروني',
                  subtitle: 'إدارة إشعارات البريد',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const EmailNotificationsScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),

            Spacing.vLg,

            // معلومات
            buildSection(
              title: 'معلومات',
              children: [
                buildSettingTile(
                  icon: Icons.privacy_tip,
                  title: 'سياسة الخصوصية',
                  subtitle: 'كيف نحمي بياناتك',
                  onTap: () => _openPrivacyPolicy(context),
                ),
                const Divider(height: 1),
                buildSettingTile(
                  icon: Icons.info,
                  title: 'عن التطبيق',
                  subtitle: '1.0.0',
                  onTap: () => showAboutDialog(context),
                ),
                const Divider(height: 1),
                buildSettingTile(
                  icon: Icons.help,
                  title: 'المساعدة',
                  subtitle: 'الأسئلة الشائعة والدعم',
                  onTap: () => showHelpDialog(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 16, bottom: 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppThemeConstants.grey500,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppThemeConstants.surface,
            borderRadius: AppThemeConstants.borderRadiusMd,
            boxShadow: [
              BoxShadow(
                color: AppThemeConstants.black.withValues(alpha: 0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget buildSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor ?? AppThemeConstants.primary),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }

  void _openPrivacyPolicy(BuildContext context) async {
    const privacyPolicyUrl = 'https://mohaffez-ba2ec.web.app/privacy-policy';
    final uri = Uri.parse(privacyPolicyUrl);
    
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('لا يمكن فتح رابط سياسة الخصوصية'),
              backgroundColor: AppThemeConstants.error,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ: $e'),
            backgroundColor: AppThemeConstants.error,
          ),
        );
      }
    }
  }

  void showLanguageDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('اختر اللغة'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('العربية'),
                trailing: const Icon(Icons.check,
                    color: AppThemeConstants.primary),
                onTap: () => Navigator.pop(ctx),
              ),
              ListTile(
                title: const Text('English'),
                onTap: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('قريباً')),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void showChangePasswordDialog(BuildContext context) {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تغيير كلمة المرور'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: currentPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'كلمة المرور الحالية',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'يرجى إدخال كلمة المرور الحالية' : null,
                ),
                const SizedBox(height: AppThemeConstants.spaceMd - AppThemeConstants.spaceXs),
                TextFormField(
                  controller: newPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'كلمة المرور الجديدة',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'يرجى إدخال كلمة مرور جديدة';
                    if (v.length < 6) return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
                    return null;
                  },
                ),
                const SizedBox(height: AppThemeConstants.spaceMd - AppThemeConstants.spaceXs),
                TextFormField(
                  controller: confirmPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'تأكيد كلمة المرور',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      v != newPasswordController.text ? 'كلمتا المرور غير متطابقتين' : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                Navigator.pop(ctx);
                try {
                  final user = FirebaseAuth.instance.currentUser;
                  if (user == null || user.email == null) return;
                  final cred = EmailAuthProvider.credential(
                    email: user.email!,
                    password: currentPasswordController.text,
                  );
                  await user.reauthenticateWithCredential(cred);
                  await user.updatePassword(newPasswordController.text);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('تم تغيير كلمة المرور بنجاح'),
                        backgroundColor: AppThemeConstants.success,
                      ),
                    );
                  }
                } on FirebaseAuthException catch (e) {
                  if (context.mounted) {
                    final msg = e.code == 'wrong-password'
                        ? 'كلمة المرور الحالية غير صحيحة'
                        : 'حدث خطأ: ${e.message}';
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(msg), backgroundColor: AppThemeConstants.error),
                    );
                  }
                }
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  void showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('عن التطبيق'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'محفظ فايندر - Mohaffez Finder',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 12),
              Text('الإصدار: 1.0.0'),
              SizedBox(height: 8),
              Text('تطبيق للربط بين الطلاب ومحفظي القرآن الكريم'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('حسناً'),
            ),
          ],
        ),
      ),
    );
  }

  void showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('المساعدة والدعم'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'للتواصل معنا:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Spacing.vSm,
                const Text('📧 البريد: support@mohaffez.com'),
                const SizedBox(height: 4),
                const Text('📱 الهاتف: 0123456789'),
                Spacing.vMd,
                const Text(
                  'الأسئلة الشائعة:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Spacing.vSm,
                _buildFAQItem('• كيف أحجز جلسة مع محفظ؟'),
                _buildFAQItem('• كيف أتابع تقدمي في الحفظ؟'),
                _buildFAQItem('• كيف أغير معلومات الحساب؟'),
                _buildFAQItem('• كيف أتواصل مع المحفظ؟'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('حسناً'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFAQItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(text, style: const TextStyle(fontSize: 14)),
    );
  }
}

// شاشات إضافية بسيطة

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  bool sessionNotifications = true;
  bool assignmentNotifications = true;
  bool messageNotifications = true;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          leading: context.canPop()
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_ios),
                  onPressed: () => context.pop(),
                  tooltip: 'رجوع',
                )
              : null,
          title: const Text('إعدادات الإشعارات'),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SwitchListTile(
              title: const Text('إشعارات الجلسات'),
              subtitle: const Text('تلقي إشعارات عن الجلسات القادمة'),
              value: sessionNotifications,
              onChanged: (val) => setState(() => sessionNotifications = val),
            ),
            SwitchListTile(
              title: const Text('إشعارات الواجبات'),
              subtitle: const Text('تلقي إشعارات عن الواجبات الجديدة'),
              value: assignmentNotifications,
              onChanged: (val) => setState(() => assignmentNotifications = val),
            ),
            SwitchListTile(
              title: const Text('إشعارات الرسائل'),
              subtitle: const Text('تلقي إشعارات عن الرسائل الجديدة'),
              value: messageNotifications,
              onChanged: (val) => setState(() => messageNotifications = val),
            ),
          ],
        ),
      ),
    );
  }
}

class EmailNotificationsScreen extends StatefulWidget {
  const EmailNotificationsScreen({super.key});

  @override
  State<EmailNotificationsScreen> createState() =>
      _EmailNotificationsScreenState();
}

class _EmailNotificationsScreenState extends State<EmailNotificationsScreen> {
  bool sessionReminders = true;
  bool assignmentUpdates = true;
  bool weeklyReports = false;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          leading: context.canPop()
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_ios),
                  onPressed: () => context.pop(),
                  tooltip: 'رجوع',
                )
              : null,
          title: const Text('إشعارات البريد الإلكتروني'),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Text(
                'اختر الإشعارات التي تريد استلامها عبر البريد الإلكتروني:',
                style: TextStyle(color: AppThemeConstants.grey500),
              ),
            ),
            SwitchListTile(
              title: const Text('تذكير الجلسات'),
              subtitle: const Text('إرسال تذكير قبل 24 ساعة من الجلسة'),
              value: sessionReminders,
              onChanged: (val) => setState(() => sessionReminders = val),
            ),
            SwitchListTile(
              title: const Text('تحديثات الواجبات'),
              subtitle: const Text('إرسال إشعار عند تحديث الواجبات'),
              value: assignmentUpdates,
              onChanged: (val) => setState(() => assignmentUpdates = val),
            ),
            SwitchListTile(
              title: const Text('التقارير الأسبوعية'),
              subtitle: const Text('ملخص أسبوعي عن تقدمك'),
              value: weeklyReports,
              onChanged: (val) => setState(() => weeklyReports = val),
            ),
          ],
        ),
      ),
    );
  }
}
