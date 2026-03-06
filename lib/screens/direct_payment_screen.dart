import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../models/direct_payment_model.dart';
import '../services/direct_payment_service.dart';
import '../shared/theme/app_theme_constants.dart';

class DirectPaymentScreen extends StatefulWidget {
  final String requestId;
  final String mohaffezId;
  final String mohaffezName;
  final String studentName;
  final double amount;
  final String sessionType;
  final String preferredTimeSlot;
  final DateTime slotDate;
  final DateTime slotStart;
  final DateTime slotEnd;
  final String? imamAddressText;
  final double? imamAddressLat;
  final double? imamAddressLng;
  final String? mohaffezPhone;

  const DirectPaymentScreen({
    super.key,
    required this.requestId,
    required this.mohaffezId,
    required this.mohaffezName,
    required this.studentName,
    required this.amount,
    required this.sessionType,
    required this.preferredTimeSlot,
    required this.slotDate,
    required this.slotStart,
    required this.slotEnd,
    this.imamAddressText,
    this.imamAddressLat,
    this.imamAddressLng,
    this.mohaffezPhone,
  });

  @override
  State<DirectPaymentScreen> createState() => _DirectPaymentScreenState();
}

class _DirectPaymentScreenState extends State<DirectPaymentScreen> {
  Map<String, String?> _wallets = {};
  DirectPaymentMethod? _selectedMethod;
  bool _loading = true;
  bool _submitting = false;
  final _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadWallets();
  }

  Future<void> _loadWallets() async {
    final wallets =
        await DirectPaymentService.getMohaffezWalletNumbers(widget.mohaffezId);
    setState(() {
      _wallets = wallets;
      _loading = false;
    });
  }

  List<DirectPaymentMethod> get _availableMethods => DirectPaymentMethod.values
      .where((m) => (_wallets[m.value] ?? '').isNotEmpty)
      .toList();

  // ignore: unused_element
  String get _selectedNumber => _wallets[_selectedMethod?.value ?? ''] ?? '';

  Future<void> _confirmPayment() async {
    // Early exit — no await here so context is safe
    if (_selectedMethod == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('اختر طريقة الدفع أولاً')));
      return;
    }

    setState(() => _submitting = true);

    try {
      await DirectPaymentService.studentMarkPaid(
        requestId: widget.requestId,
        mohaffezId: widget.mohaffezId,
        mohaffezName: widget.mohaffezName,
        studentName: widget.studentName,
        amount: widget.amount,
        sessionType: widget.sessionType,
        preferredTimeSlot: widget.preferredTimeSlot,
        slotDate: widget.slotDate,
        slotStart: widget.slotStart,
        slotEnd: widget.slotEnd,
        paymentMethod: _selectedMethod!.value,
        studentNote: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        imamAddressText: widget.imamAddressText,
        imamAddressLat: widget.imamAddressLat,
        imamAddressLng: widget.imamAddressLng,
        mohaffezPhone: widget.mohaffezPhone,
      );

      if (!mounted) return; // FIXED: FIX-1 — widget may be disposed after await

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog( // ✅ use dialogContext, not outer context
          title: const Text('تم إرسال الإشعار ✅'),
          content: const Text(
            'تم إرسال إشعار الدفع للمحفظ.\n'
            'سيتم قبول جلستك فور تأكيده استلام المبلغ.',
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () {
                // ✅ dialogContext is always valid here — dialog is still mounted
                Navigator.of(dialogContext).popUntil((r) => r.isFirst);
              },
              child: const Text('حسناً'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return; // FIXED: FIX-1 — guard before ScaffoldMessenger too
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('خطأ: $e')));
    } finally {
      // ✅ mounted check required — finally always runs, even after early return
      if (mounted) setState(() => _submitting = false);
    }
  }

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
          title: const Text('الدفع المباشر'),
          backgroundColor: AppThemeConstants.accentGreen,
          foregroundColor: Colors.white,
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _availableMethods.isEmpty
                ? const Center(
                    child: Text(
                      'المحفظ لم يضف أرقام المحافظ الإلكترونية بعد.\nتواصل معه مباشرة.',
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Amount banner
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              AppThemeConstants.accentGreen,
                              Color(0xFF43A047),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(children: [
                          const Text('المبلغ المطلوب',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 14)),
                          const SizedBox(height: 6),
                          Text('${widget.amount.toStringAsFixed(0)} ج.م',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('إلى: ${widget.mohaffezName}',
                              style: const TextStyle(color: Colors.white70)),
                        ]),
                      ),
                      const SizedBox(height: 24),

                      const Text('اختر طريقة الدفع',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),

                      // Wallet method cards
                      ..._availableMethods.map((method) {
                        final isSelected = _selectedMethod == method;
                        final number = _wallets[method.value] ?? '';
                        return GestureDetector(
                          onTap: () => setState(() => _selectedMethod = method),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppThemeConstants.accentGreen
                                      .withValues(alpha: 0.08)
                                  : Colors.grey.shade50,
                              border: Border.all(
                                color: isSelected
                                    ? AppThemeConstants.accentGreen
                                    : Colors.grey.shade300,
                                width: isSelected ? 2 : 1,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(children: [
                              Icon(
                                isSelected
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_unchecked,
                                color: isSelected
                                    ? AppThemeConstants.accentGreen
                                    : Colors.grey,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(method.label,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16)),
                                    const SizedBox(height: 4),
                                    Row(children: [
                                      Text(number,
                                          style: const TextStyle(
                                              fontSize: 18,
                                              color: AppThemeConstants.accentGreen,
                                              fontWeight: FontWeight.w600,
                                              letterSpacing: 1.2)),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: const Icon(Icons.copy, size: 18),
                                        onPressed: () {
                                          Clipboard.setData(
                                              ClipboardData(text: number));
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(const SnackBar(
                                                  content:
                                                      Text('تم نسخ الرقم')));
                                        },
                                      ),
                                    ]),
                                  ],
                                ),
                              ),
                            ]),
                          ),
                        );
                      }),

                      const SizedBox(height: 16),

                      // Instructions
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.amber.shade200),
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Icon(Icons.info_outline,
                                  color: Colors.orange, size: 18),
                              SizedBox(width: 6),
                              Text('تعليمات الدفع',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange)),
                            ]),
                            SizedBox(height: 8),
                            Text(
                              '١. انسخ رقم المحفظة\n'
                              '٢. افتح تطبيق الدفع واختر "تحويل"\n'
                              '٣. ادفع المبلغ المحدد بالضبط\n'
                              '٤. عد هنا واضغط "لقد دفعت"\n'
                              '٥. انتظر تأكيد المحفظ (عادةً خلال دقائق)',
                              style: TextStyle(fontSize: 13, height: 1.8),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),
                      TextField(
                        controller: _noteController,
                        decoration: InputDecoration(
                          labelText: 'ملاحظة للمحفظ (اختياري)',
                          hintText: 'مثال: تحويل من فودافون كاش رقم 010x',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 80),
                    ],
                  ),
        bottomNavigationBar: _availableMethods.isEmpty
            ? null
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: ElevatedButton.icon(
                    onPressed: _submitting ? null : _confirmPayment,
                    icon: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check_circle, color: Colors.white),
                    label: Text(
                      _submitting ? 'جاري الإرسال...' : 'لقد دفعت ✓',
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppThemeConstants.accentGreen,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }
}
