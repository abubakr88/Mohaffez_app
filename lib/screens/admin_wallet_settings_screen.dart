import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/system_config_provider.dart';
import '../shared/theme/app_theme_constants.dart';
import '../shared/widgets/admin_app_bar.dart';

class AdminWalletSettingsScreen extends ConsumerStatefulWidget {
  const AdminWalletSettingsScreen({super.key});

  @override
  ConsumerState<AdminWalletSettingsScreen> createState() =>
      _AdminWalletSettingsScreenState();
}

class _AdminWalletSettingsScreenState
    extends ConsumerState<AdminWalletSettingsScreen> {
  final _instapayController = TextEditingController();
  final _vodafoneController = TextEditingController();
  final _orangeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  /// Validates an Egyptian phone number (starts with 0, 10-11 digits)
  String? _validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // Allow empty (optional field)
    }
    final phone = value.trim();
    if (!RegExp(r'^0\d{9,10}$').hasMatch(phone)) {
      return 'أدخل رقم هاتف مصري صحيح (يبدأ بـ 0، 10-11 رقم)';
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCurrentValues();
    });
  }

  void _loadCurrentValues() {
    final config = ref.read(systemConfigProvider).value;
    // ignore: unnecessary_null_comparison
    if (config != null && config.adminWallets != null) {
      _instapayController.text = config.adminWallets['instapay'] ?? '';
      _vodafoneController.text = config.adminWallets['vodafonecash'] ?? '';
      _orangeController.text = config.adminWallets['orangemoney'] ?? '';
    }
  }

  @override
  void dispose() {
    _instapayController.dispose();
    _vodafoneController.dispose();
    _orangeController.dispose();
    super.dispose();
  }

  Future<void> _saveWallets() async {
    setState(() => _isLoading = true);

    try {
      await ref.read(systemConfigNotifierProvider.notifier).updateGlobalConfig({
        'adminWallets': {
          'instapay': _instapayController.text.trim(),
          'vodafonecash': _vodafoneController.text.trim(),
          'orangemoney': _orangeController.text.trim(),
        },
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حفظ الأرقام بنجاح'),
            backgroundColor: AppThemeConstants.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في الحفظ: $e'),
            backgroundColor: AppThemeConstants.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: const AdminAppBar(title: 'أرقام محافظ المنصة'),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppThemeConstants.spaceMd),
            children: [
            // Info header card
            Container(
              padding: const EdgeInsets.all(AppThemeConstants.spaceMd),
              decoration: BoxDecoration(
                color: AppThemeConstants.warning.withValues(alpha: 0.1),
                borderRadius: AppThemeConstants.borderRadiusMd,
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: AppThemeConstants.warning,
                  ),
                  SizedBox(width: AppThemeConstants.spaceSm),
                  Expanded(
                    child: Text(
                      'هذه الأرقام ستظهر للمحافظين عند دفع مستحقات المنصة',
                      style: TextStyle(
                        color: AppThemeConstants.warning,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppThemeConstants.spaceLg),

            // Section title
            const Text(
              'وسائل الدفع المتاحة',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppThemeConstants.spaceMd),

            // InstaPay
            TextFormField(
              controller: _instapayController,
              keyboardType: TextInputType.phone,
              validator: _validatePhone,
              decoration: const InputDecoration(
                labelText: 'InstaPay',
                hintText: 'رقم InstaPay',
                prefixIcon: Icon(Icons.account_balance),
                border: OutlineInputBorder(
                  borderRadius: AppThemeConstants.borderRadiusMd,
                ),
              ),
            ),
            const SizedBox(height: AppThemeConstants.spaceMd),

            // Vodafone Cash
            TextFormField(
              controller: _vodafoneController,
              keyboardType: TextInputType.phone,
              validator: _validatePhone,
              decoration: InputDecoration(
                labelText: 'Vodafone Cash',
                hintText: 'رقم Vodafone Cash',
                prefixIcon: Icon(
                  Icons.phone_android,
                  color: Colors.red.shade700,
                ),
                border: const OutlineInputBorder(
                  borderRadius: AppThemeConstants.borderRadiusMd,
                ),
              ),
            ),
            const SizedBox(height: AppThemeConstants.spaceMd),

            // Orange Money
            TextFormField(
              controller: _orangeController,
              keyboardType: TextInputType.phone,
              validator: _validatePhone,
              decoration: InputDecoration(
                labelText: 'Orange Money',
                hintText: 'رقم Orange Money',
                prefixIcon: Icon(
                  Icons.phone_android,
                  color: Colors.orange.shade700,
                ),
                border: const OutlineInputBorder(
                  borderRadius: AppThemeConstants.borderRadiusMd,
                ),
              ),
            ),
            const SizedBox(height: AppThemeConstants.spaceLg),

            // Save button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading
                    ? null
                    : () {
                        if (_formKey.currentState!.validate()) {
                          _saveWallets();
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppThemeConstants.primary,
                  foregroundColor: Colors.white,
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(
                        color: Colors.white,
                      )
                    : const Text(
                        'حفظ الأرقام',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  }
}


