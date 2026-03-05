import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/system_config_provider.dart';
import '../shared/theme/app_theme_constants.dart';

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
  bool _isLoading = false;

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
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في الحفظ: $e'),
            backgroundColor: Colors.red,
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
        appBar: AppBar(
          title: const Text('أرقام محافظ المنصة'),
          backgroundColor: AppThemeConstants.primaryAmber,
          foregroundColor: Colors.white,
        ),
        body: ListView(
          padding: const EdgeInsets.all(AppThemeConstants.spaceMd),
          children: [
            // Info header card
            Container(
              padding: const EdgeInsets.all(AppThemeConstants.spaceMd),
              decoration: BoxDecoration(
                color: Colors.amber.shade100,
                borderRadius: AppThemeConstants.borderRadiusMd,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.amber.shade800,
                  ),
                  const SizedBox(width: AppThemeConstants.spaceSm),
                  Expanded(
                    child: Text(
                      'هذه الأرقام ستظهر للمحافظين عند دفع مستحقات المنصة',
                      style: TextStyle(
                        color: Colors.amber.shade900,
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
                onPressed: _isLoading ? null : _saveWallets,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppThemeConstants.primaryAmber,
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
    );
  }
}
