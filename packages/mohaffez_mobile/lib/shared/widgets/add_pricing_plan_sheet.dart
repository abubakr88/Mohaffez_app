// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'package:flutter/material.dart';
import 'package:mohaffez_core/mohaffez_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'meeting_links_sheet.dart';

class AddPricingPlanSheet extends ConsumerStatefulWidget {
  final String mohaffezId;
  final PricingPlanModel? existingPlan;

  const AddPricingPlanSheet({
    super.key,
    required this.mohaffezId,
    this.existingPlan,
  });

  @override
  ConsumerState<AddPricingPlanSheet> createState() =>
      _AddPricingPlanSheetState();
}

// Paymob gateway fee constants (Egypt). Confirmed with the user:
//   gatewayFee  = price * 2.75% + 3 EGP
//   VAT         = gatewayFee * 14%
//   paymobTotal = gatewayFee + VAT = gatewayFee * 1.14
const double _kPaymobPercent = 0.0275;
const double _kPaymobFlat = 3.0;
const double _kVatRate = 0.14;
const double _kDefaultCommission =
    0.15; // starter-tier fallback when config is null

class _AddPricingPlanSheetState extends ConsumerState<AddPricingPlanSheet> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _titleController;
  late TextEditingController _priceController;
  late TextEditingController _netController;
  late TextEditingController _descriptionController;

  // Reentrancy guards so price↔net auto-sync doesn't loop.
  bool _syncingFromPrice = false;
  bool _syncingFromNet = false;

  PlanType _selectedType = PlanType.single;
  SessionMode _selectedMode = SessionMode.online;
  late PricingCountryOption _selectedCountry;
  int _sessionsCount = 1;
  int? _sessionDurationMinutes;
  int? _validityDays;
  int? _sessionsPerWeek;

  @override
  void initState() {
    super.initState();
    final plan = widget.existingPlan;

    _selectedCountry = PricingCountryUtils.byCode(plan?.countryCode);

    _titleController = TextEditingController(text: plan?.title ?? '');
    _priceController = TextEditingController(
      text: plan == null
          ? ''
          : PricingCountryUtils.displayAmount(plan).toStringAsFixed(2),
    );
    _netController = TextEditingController();
    _descriptionController =
        TextEditingController(text: plan?.description ?? '');

    if (plan != null) {
      _selectedType = plan.type;
      _selectedMode = plan.mode ?? SessionMode.online;
      _selectedCountry = PricingCountryUtils.byCode(plan.countryCode);
      _sessionsCount = plan.sessionsCount;
      _sessionDurationMinutes = plan.sessionDurationMinutes;
      _validityDays = plan.validityDays;
      _sessionsPerWeek = plan.sessionsPerWeek;
    }

    _priceController.addListener(_onPriceChanged);
    _netController.addListener(_onNetChanged);

    // Pre-fill net field from existing price on edit.
    WidgetsBinding.instance.addPostFrameCallback((_) => _onPriceChanged());
  }

  /// Effective rate for this teacher: per-teacher rate (set by the
  /// scheduled tier recompute) wins over the global rate. Falls back to
  /// the hardcoded default while either source is still loading.
  double get _commissionRate {
    final teacherInfo =
        ref.read(teacherCommissionInfoProvider(widget.mohaffezId)).valueOrNull;
    final config = ref.read(systemConfigProvider).valueOrNull;
    final starterRate = config == null
        ? _kDefaultCommission
        : CommissionTierModel.starterRate(config.commissionTiers);
    if (teacherInfo != null) {
      return teacherInfo.effectiveRate(starterRate);
    }
    return starterRate;
  }

  void _onPriceChanged() {
    if (_syncingFromNet) return;
    _syncingFromPrice = true;
    final localPrice = double.tryParse(_priceController.text);
    if (localPrice == null || localPrice <= 0) {
      _netController.text = '';
    } else {
      final breakdown = _calcFromPrice(
        _selectedCountry.toEgp(localPrice),
        _commissionRate,
      );
      _netController.text =
          breakdown.net <= 0 ? '0' : breakdown.net.toStringAsFixed(2);
    }
    _syncingFromPrice = false;
    if (mounted) setState(() {}); // refresh breakdown card
  }

  void _onNetChanged() {
    if (_syncingFromPrice) return;
    _syncingFromNet = true;
    final net = double.tryParse(_netController.text);
    if (net == null || net <= 0) {
      _priceController.text = '';
    } else {
      // price = (net + flat * (1+vat)) / (1 - pct*(1+vat) - commission)
      final denom = 1 - _kPaymobPercent * (1 + _kVatRate) - _commissionRate;
      if (denom > 0) {
        final egpPrice = (net + _kPaymobFlat * (1 + _kVatRate)) / denom;
        final localPrice = _selectedCountry.fromEgp(egpPrice);
        _priceController.text = localPrice.toStringAsFixed(2);
      }
    }
    _syncingFromNet = false;
    if (mounted) setState(() {});
  }

  /// Pretty-print a 0–1 rate as a percent string, dropping trailing
  /// zeros so 0.05 → "5%", 0.1122 → "11.22%", 0.1 → "10%".
  String _formatPercent(double rate) {
    final pct = rate * 100;
    var s = pct.toStringAsFixed(2);
    if (s.contains('.')) {
      s = s.replaceFirst(RegExp(r'0+$'), '');
      s = s.replaceFirst(RegExp(r'\.$'), '');
    }
    return '$s%';
  }

  _PriceBreakdown _calcFromPrice(double price, double commissionRate) {
    final gatewayFee = price * _kPaymobPercent + _kPaymobFlat;
    final vat = gatewayFee * _kVatRate;
    final paymobTotal = gatewayFee + vat;
    final commission = price * commissionRate;
    final net = price - paymobTotal - commission;
    return _PriceBreakdown(
      price: price,
      gatewayFee: gatewayFee,
      vat: vat,
      commission: commission,
      net: net,
    );
  }

  double? get _localPrice => double.tryParse(_priceController.text);

  double? get _chargedPriceEgp {
    final localPrice = _localPrice;
    if (localPrice == null || localPrice <= 0) return null;
    return _selectedCountry.toEgp(localPrice);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 24,
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.existingPlan == null
                      ? 'إضافة خطة تسعير'
                      : 'تعديل خطة التسعير',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),

                // Plan Type Selection
                const Text('نوع الخطة',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButtonFormField<PlanType>(
                  // FIX: Use initialValue instead of value
                  initialValue: _selectedType,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.category),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: PlanType.single,
                      child: Text('جلسة واحدة'),
                    ),
                    DropdownMenuItem(
                      value: PlanType.bundle,
                      child: Text('باقة جلسات'),
                    ),
                    // PlanType.subscription intentionally omitted from the
                    // picker: same outcome achievable via bundles. The enum
                    // value stays for backward-compat with existing docs.
                  ],
                  onChanged: (val) {
                    setState(() {
                      _selectedType = val!;
                      _updateDefaultValues();
                    });
                  },
                ),
                const SizedBox(height: 16),

                // Session Mode
                const Text('نوع الجلسة',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButtonFormField<SessionMode>(
                  initialValue: _selectedMode,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.location_on),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: SessionMode.online,
                      child: Text('جلسة أونلاين'),
                    ),
                    DropdownMenuItem(
                      value: SessionMode.home,
                      child: Text('جلسة منزلية'),
                    ),
                    DropdownMenuItem(
                      value: SessionMode.mosque,
                      child: Text('جلسة في المسجد'),
                    ),
                  ],
                  onChanged: (val) => setState(() => _selectedMode = val!),
                ),
                const SizedBox(height: 16),

                // Country / currency
                const Text('دولة الطالب والسعر المحلي',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButtonFormField<PricingCountryOption>(
                  initialValue: _selectedCountry,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.public),
                  ),
                  items: PricingCountryUtils.countries
                      .map(
                        (country) => DropdownMenuItem(
                          value: country,
                          child: Text(
                            '${country.nameAr} (${country.currencyCode})',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (val) {
                    if (val == null) return;
                    setState(() => _selectedCountry = val);
                    _onPriceChanged();
                  },
                ),
                const SizedBox(height: 16),

                const Text('مدة الجلسة داخل هذه الخطة',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  initialValue: _sessionDurationMinutes ?? 30,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.timer_outlined),
                    suffixText: 'دقيقة',
                  ),
                  items: const [30, 45, 60, 75, 90, 120]
                      .map(
                        (minutes) => DropdownMenuItem(
                          value: minutes,
                          child: Text('$minutes دقيقة'),
                        ),
                      )
                      .toList(),
                  onChanged: (val) =>
                      setState(() => _sessionDurationMinutes = val),
                ),
                const SizedBox(height: 16),

                // Title
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'عنوان الخطة',
                    hintText: 'مثال: باقة 5 جلسات',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.title),
                  ),
                  validator: (val) => val == null || val.isEmpty
                      ? 'الرجاء إدخال عنوان الخطة'
                      : null,
                ),
                const SizedBox(height: 16),

                // Sessions Count (for bundle/subscription)
                if (_selectedType != PlanType.single) ...[
                  const Text('عدد الجلسات',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Slider(
                          value: _sessionsCount.toDouble(),
                          min: 1,
                          max: 30,
                          divisions: 29,
                          label: '$_sessionsCount جلسة',
                          onChanged: (val) =>
                              setState(() => _sessionsCount = val.toInt()),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          // FIX: Use withValues instead of withOpacity
                          color:
                              AppThemeConstants.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$_sessionsCount',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                if (_selectedType == PlanType.bundle) ...[
                  const Text('صلاحية الباقة',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    initialValue: _validityDays ?? 30,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.schedule),
                      suffixText: 'يوم',
                    ),
                    items: const [14, 30, 45, 60, 90, 120]
                        .map(
                          (days) => DropdownMenuItem(
                            value: days,
                            child: Text('$days يوم'),
                          ),
                        )
                        .toList(),
                    onChanged: (val) => setState(() => _validityDays = val),
                  ),
                  const SizedBox(height: 16),
                ],

                // Price
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _priceController,
                        decoration: InputDecoration(
                          labelText: 'السعر للطالب',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.payments),
                          suffixText: _selectedCountry.currencyLabel,
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        validator: (val) {
                          if (val == null || val.isEmpty) {
                            return 'الرجاء إدخال السعر';
                          }
                          if (double.tryParse(val) == null) {
                            return 'رقم غير صحيح';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _netController,
                        decoration: const InputDecoration(
                          labelText: 'ما ستستلمه',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.account_balance_wallet),
                          suffixText: 'ج.م',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildBreakdownCard(),
                const SizedBox(height: 16),

                // Description (optional)
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'وصف إضافي (اختياري)',
                    hintText: 'مثال: وفر 100 جنيه',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.description),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),

                const SizedBox(height: 24),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('إلغاء'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _savePlan,
                        child:
                            Text(widget.existingPlan == null ? 'إضافة' : 'حفظ'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _updateDefaultValues() {
    switch (_selectedType) {
      case PlanType.single:
        _sessionsCount = 1;
        _validityDays = null;
        _titleController.text = 'جلسة واحدة';
        break;
      case PlanType.bundle:
        _sessionsCount = 5;
        _validityDays ??= 30;
        _titleController.text = 'باقة 5 جلسات';
        break;
    }
  }

  /// Returns `true` if the teacher already has at least one meeting link
  /// configured, OR after they add one via the bottom sheet. Returns `false`
  /// if the user dismisses the prompt without adding any link — in which case
  /// the caller must abort plan creation.
  Future<bool> _ensureTeacherHasMeetingLink() async {
    final teacher =
        await ref.read(getUserOnceProvider(widget.mohaffezId).future);
    final hasMap = teacher != null &&
        teacher.meetingLinks.values.any((v) => v.trim().isNotEmpty);
    final hasLegacy =
        teacher != null && (teacher.meetingLink?.trim().isNotEmpty ?? false);
    if (hasMap || hasLegacy) return true;

    if (!mounted) return false;
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('أضف رابط اجتماع أولاً'),
          content: const Text(
            'لتفعيل الجلسات أونلاين، أضف رابط Zoom أو Google Meet أو Teams من ملفك الشخصي. الطالب سيختار المنصة عند الحجز.',
            style: TextStyle(height: 1.6),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.add_link_rounded, size: 18),
              label: const Text('أضف الآن'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppThemeConstants.primary,
                foregroundColor: AppThemeConstants.white,
              ),
            ),
          ],
        ),
      ),
    );
    if (proceed != true || !mounted) return false;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MeetingLinksSheet(user: teacher!),
    );
    if (saved == true) {
      ref.invalidate(getUserOnceProvider(widget.mohaffezId));
      // Re-check: even if saved=true, user might have left all fields empty.
      final fresh =
          await ref.read(getUserOnceProvider(widget.mohaffezId).future);
      return fresh != null &&
          (fresh.meetingLinks.values.any((v) => v.trim().isNotEmpty) ||
              (fresh.meetingLink?.trim().isNotEmpty ?? false));
    }
    return false;
  }

  Future<void> _savePlan() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedMode == SessionMode.online) {
      final allowed = await _ensureTeacherHasMeetingLink();
      if (!allowed) return;
    }

    final localPrice = double.parse(_priceController.text);
    final chargedPriceEgp = _selectedCountry.toEgp(localPrice);
    final sessionDuration = _sessionDurationMinutes ?? 30;

    final plan = PricingPlanModel(
      id: widget.existingPlan?.id,
      mohaffezId: widget.mohaffezId,
      title: _titleController.text.trim(),
      type: _selectedType,
      mode: _selectedMode,
      priceEGP: chargedPriceEgp,
      countryCode: _selectedCountry.code,
      countryName: _selectedCountry.nameAr,
      currencyCode: _selectedCountry.currencyCode,
      currencyLabel: _selectedCountry.currencyLabel,
      displayPrice: localPrice,
      fxRateToEGP: _selectedCountry.egpRate,
      sessionsCount: _sessionsCount,
      sessionDurationMinutes: sessionDuration,
      validityDays: _selectedType == PlanType.bundle
          ? (_validityDays ?? 30)
          : _validityDays,
      sessionsPerWeek: _sessionsPerWeek,
      isFreeTrialAvailable: false,
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      createdAt: widget.existingPlan?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    try {
      // FIX: Call on notifier, not state
      if (widget.existingPlan == null) {
        await ref.read(pricingActionsProvider.notifier).createPlan(plan);
      } else {
        await ref.read(pricingActionsProvider.notifier).updatePlan(plan);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حفظ خطة التسعير بنجاح')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _priceController.removeListener(_onPriceChanged);
    _netController.removeListener(_onNetChanged);
    _titleController.dispose();
    _priceController.dispose();
    _netController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Widget _buildBreakdownCard() {
    final localPrice = double.tryParse(_priceController.text);
    final price = _chargedPriceEgp;
    if (localPrice == null || localPrice <= 0 || price == null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppThemeConstants.grey100,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppThemeConstants.grey300),
        ),
        child: const Row(
          children: [
            Icon(Icons.calculate_outlined,
                size: 20, color: AppThemeConstants.grey600),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'أدخل السعر أو ما تريد استلامه لرؤية تفاصيل الخصومات',
                style:
                    TextStyle(fontSize: 13, color: AppThemeConstants.grey700),
              ),
            ),
          ],
        ),
      );
    }

    final b = _calcFromPrice(price, _commissionRate);
    final isBundle = _selectedType == PlanType.bundle && _sessionsCount > 1;
    final perSession = isBundle ? (b.net / _sessionsCount) : null;
    final isNegative = b.net <= 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isNegative
            ? AppThemeConstants.error.withValues(alpha: 0.08)
            : AppThemeConstants.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isNegative
              ? AppThemeConstants.error
              : AppThemeConstants.primary.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long,
                  size: 18, color: AppThemeConstants.primary),
              const SizedBox(width: 6),
              Text(
                'تفاصيل الحساب',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: AppThemeConstants.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _breakdownRow(
            'السعر للطالب (${localPrice.toStringAsFixed(2)} ${_selectedCountry.currencyLabel})',
            b.price,
            isPositive: true,
          ),
          if (_selectedCountry.code != PricingCountryUtils.egypt.code)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                'سيتم تحصيل ما يعادل ${b.price.toStringAsFixed(2)} ج.م',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppThemeConstants.grey700,
                ),
              ),
            ),
          _breakdownRow('رسوم بوابة الدفع (2.75% + 3 ج.م)', -b.gatewayFee),
          _breakdownRow('ضريبة قيمة مضافة 14%', -b.vat),
          _breakdownRow('عمولة التطبيق (${_formatPercent(_commissionRate)})',
              -b.commission),
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'صافي ما ستستلمه',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              Text(
                '${b.net.toStringAsFixed(2)} ج.م',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: isNegative
                      ? AppThemeConstants.error
                      : AppThemeConstants.success,
                ),
              ),
            ],
          ),
          if (isBundle && perSession != null) ...[
            const SizedBox(height: 6),
            Text(
              'تستلم تقريباً ${perSession.toStringAsFixed(2)} ج.م لكل جلسة '
              '($_sessionsCount جلسات)',
              style: const TextStyle(
                fontSize: 12,
                color: AppThemeConstants.grey700,
              ),
            ),
          ],
          if (isNegative) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: AppThemeConstants.error, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'السعر منخفض جداً — الرسوم والعمولة أكبر من المبلغ.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppThemeConstants.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _breakdownRow(String label, double amount, {bool isPositive = false}) {
    final sign = amount < 0 ? '−' : (isPositive ? '' : '+');
    final abs = amount.abs();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '$sign ${abs.toStringAsFixed(2)} ج.م',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isPositive
                  ? AppThemeConstants.textPrimary
                  : AppThemeConstants.grey700,
            ),
          ),
        ],
      ),
    );
  }
}

class _PriceBreakdown {
  final double price;
  final double gatewayFee;
  final double vat;
  final double commission;
  final double net;

  const _PriceBreakdown({
    required this.price,
    required this.gatewayFee,
    required this.vat,
    required this.commission,
    required this.net,
  });
}
