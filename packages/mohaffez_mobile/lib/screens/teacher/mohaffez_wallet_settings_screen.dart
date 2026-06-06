import 'package:flutter/material.dart';
import 'package:mohaffez_core/mohaffez_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MohaffezWalletSettingsScreen extends StatefulWidget {
  const MohaffezWalletSettingsScreen({super.key});

  @override
  State<MohaffezWalletSettingsScreen> createState() =>
      _MohaffezWalletSettingsScreenState();
}

class _MohaffezWalletSettingsScreenState
    extends State<MohaffezWalletSettingsScreen> {
  final _instapayCtrl = TextEditingController();
  final _vodafoneCtrl = TextEditingController();
  final _orangeCtrl = TextEditingController();
  final _etisalatCtrl = TextEditingController();
  final _wePayCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadWallets();
  }

  Future<void> _loadWallets() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final wallets = await DirectPaymentService.getMohaffezWalletNumbers(uid);
    setState(() {
      _instapayCtrl.text = wallets['instapay'] ?? '';
      _vodafoneCtrl.text = wallets['vodafonecash'] ?? '';
      _orangeCtrl.text = wallets['orangemoney'] ?? '';
      _etisalatCtrl.text = wallets['etisalatcash'] ?? '';
      _wePayCtrl.text = wallets['wepay'] ?? '';
      _loading = false;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      await DirectPaymentService.saveMohaffezWalletNumbers(
        mohaffezId: uid,
        instapayNumber: _instapayCtrl.text.trim().isEmpty
            ? null
            : _instapayCtrl.text.trim(),
        vodafoneNumber: _vodafoneCtrl.text.trim().isEmpty
            ? null
            : _vodafoneCtrl.text.trim(),
        orangeNumber:
            _orangeCtrl.text.trim().isEmpty ? null : _orangeCtrl.text.trim(),
        etisalatNumber: _etisalatCtrl.text.trim().isEmpty
            ? null
            : _etisalatCtrl.text.trim(),
        wePayNumber:
            _wePayCtrl.text.trim().isEmpty ? null : _wePayCtrl.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حفظ أرقام المحافظ بنجاح'),
          backgroundColor: AppThemeConstants.secondary,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذّر حفظ الإعدادات. يرجى المحاولة مرة أخرى'), backgroundColor: AppThemeConstants.error),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _instapayCtrl.dispose();
    _vodafoneCtrl.dispose();
    _orangeCtrl.dispose();
    _etisalatCtrl.dispose();
    _wePayCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('أرقام محافظ الدفع المباشر'),
          backgroundColor: AppThemeConstants.secondary,
          foregroundColor: AppThemeConstants.onPrimary,
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Info banner
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: AppThemeConstants.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppThemeConstants.warning),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: AppThemeConstants.warning),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'أضف رقم محفظة واحدة على الأقل لتفعيل خيار الدفع المباشر للطلاب.',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),

                  _walletField(
                    controller: _instapayCtrl,
                    label: 'InstaPay',
                    hint: 'رقم الهاتف أو اسم المستخدم',
                    icon: Icons.account_balance,
                    color: AppThemeConstants.accentPurple,
                  ),
                  _walletField(
                    controller: _vodafoneCtrl,
                    label: 'فودافون كاش',
                    hint: '01xxxxxxxxx',
                    icon: Icons.phone_android,
                    color: AppThemeConstants.error,
                  ),
                  _walletField(
                    controller: _orangeCtrl,
                    label: 'أورانج موني',
                    hint: '01xxxxxxxxx',
                    icon: Icons.phone_android,
                    color: AppThemeConstants.accentOrange,
                  ),
                  _walletField(
                    controller: _etisalatCtrl,
                    label: 'اتصالات كاش',
                    hint: '01xxxxxxxxx',
                    icon: Icons.phone_android,
                    color: AppThemeConstants.success,
                  ),
                  _walletField(
                    controller: _wePayCtrl,
                    label: 'WE Pay',
                    hint: '01xxxxxxxxx',
                    icon: Icons.phone_android,
                    color: AppThemeConstants.accentBlue,
                  ),

                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: AppThemeConstants.white))
                          : const Icon(Icons.save, color: AppThemeConstants.white),
                      label: Text(
                        _saving ? 'جاري الحفظ...' : 'حفظ الأرقام',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppThemeConstants.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppThemeConstants.secondary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _walletField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.phone,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: color),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: color, width: 2),
          ),
        ),
      ),
    );
  }
}
