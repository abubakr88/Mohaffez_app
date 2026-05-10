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
  ConsumerState<AddPricingPlanSheet> createState() => _AddPricingPlanSheetState();
}

class _AddPricingPlanSheetState extends ConsumerState<AddPricingPlanSheet> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _titleController;
  late TextEditingController _priceController;
  late TextEditingController _descriptionController;
  
  PlanType _selectedType = PlanType.single;
  SessionMode _selectedMode = SessionMode.online;
  int _sessionsCount = 1;
  int? _validityDays;
  int? _sessionsPerWeek;
  bool _isFreeTrialAvailable = false;

  @override
  void initState() {
    super.initState();
    final plan = widget.existingPlan;
    
    _titleController = TextEditingController(text: plan?.title ?? '');
    _priceController = TextEditingController(
      text: plan?.priceEGP.toString() ?? '',
    );
    _descriptionController = TextEditingController(text: plan?.description ?? '');
    
    if (plan != null) {
      _selectedType = plan.type;
      _selectedMode = plan.mode ?? SessionMode.online;
      _sessionsCount = plan.sessionsCount;
      _validityDays = plan.validityDays;
      _sessionsPerWeek = plan.sessionsPerWeek;
      _isFreeTrialAvailable = plan.isFreeTrialAvailable;
    }
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
                const Text('نوع الخطة', style: TextStyle(fontWeight: FontWeight.bold)),
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
                    DropdownMenuItem(
                      value: PlanType.subscription,
                      child: Text('اشتراك شهري'),
                    ),
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
                const Text('نوع الجلسة', style: TextStyle(fontWeight: FontWeight.bold)),
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
                  const Text('عدد الجلسات', style: TextStyle(fontWeight: FontWeight.bold)),
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
                          onChanged: (val) => setState(() => _sessionsCount = val.toInt()),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          // FIX: Use withValues instead of withOpacity
                          color: AppThemeConstants.primary.withValues(alpha: 0.1),
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
                
                // Subscription specific fields
                if (_selectedType == PlanType.subscription) ...[
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: _sessionsPerWeek?.toString() ?? '2',
                          decoration: const InputDecoration(
                            labelText: 'جلسات في الأسبوع',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.calendar_today),
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (val) => _sessionsPerWeek = int.tryParse(val),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          initialValue: _validityDays?.toString() ?? '30',
                          decoration: const InputDecoration(
                            labelText: 'صالح لـ (أيام)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.schedule),
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (val) => _validityDays = int.tryParse(val),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
                
                // Price
                TextFormField(
                  controller: _priceController,
                  decoration: const InputDecoration(
                    labelText: 'السعر (جنيه مصري)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.payments),
                    suffixText: 'ج.م',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (val) {
                    if (val == null || val.isEmpty) return 'الرجاء إدخال السعر';
                    if (double.tryParse(val) == null) return 'الرجاء إدخال رقم صحيح';
                    return null;
                  },
                ),
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
                
                // Free Trial
                SwitchListTile(
                  value: _isFreeTrialAvailable,
                  onChanged: (val) => setState(() => _isFreeTrialAvailable = val),
                  title: const Text('يتضمن جلسة تجريبية مجانية'),
                  subtitle: const Text('سيتمكن الطلاب من تجربة جلسة قبل الدفع'),
                  // FIX: Use activeThumbColor instead of activeColor
                  activeThumbColor: AppThemeConstants.secondary,
                ),
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
                        child: Text(widget.existingPlan == null ? 'إضافة' : 'حفظ'),
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
        _titleController.text = 'جلسة واحدة';
        break;
      case PlanType.bundle:
        _sessionsCount = 5;
        _titleController.text = 'باقة 5 جلسات';
        break;
      case PlanType.subscription:
        _sessionsCount = 8; // 2 sessions/week * 4 weeks
        _sessionsPerWeek = 2;
        _validityDays = 30;
        _titleController.text = 'اشتراك شهري';
        break;
    }
  }

  /// Returns `true` if the teacher already has at least one meeting link
  /// configured, OR after they add one via the bottom sheet. Returns `false`
  /// if the user dismisses the prompt without adding any link — in which case
  /// the caller must abort plan creation.
  Future<bool> _ensureTeacherHasMeetingLink() async {
    final teacher = await ref.read(getUserOnceProvider(widget.mohaffezId).future);
    final hasMap = teacher != null &&
        teacher.meetingLinks.values.any((v) => v.trim().isNotEmpty);
    final hasLegacy = teacher != null &&
        (teacher.meetingLink?.trim().isNotEmpty ?? false);
    if (hasMap || hasLegacy) return true;

    if (!mounted) return false;
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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

    final plan = PricingPlanModel(
      id: widget.existingPlan?.id,
      mohaffezId: widget.mohaffezId,
      title: _titleController.text.trim(),
      type: _selectedType,
      mode: _selectedMode,
      priceEGP: double.parse(_priceController.text),
      sessionsCount: _sessionsCount,
      validityDays: _validityDays,
      sessionsPerWeek: _sessionsPerWeek,
      isFreeTrialAvailable: _isFreeTrialAvailable,
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
    _titleController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}
