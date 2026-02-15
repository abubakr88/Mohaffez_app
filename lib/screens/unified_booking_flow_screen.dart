import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/pricing_plan_model.dart';
import '../models/payment_model.dart'; // âœ… ADD THIS
import '../providers/pricing_provider.dart';
import '../providers/user_provider.dart';
import '../providers/payment_provider.dart';
import '../shared/constants/app_theme.dart';
import '../widgets/location_picker_widget.dart';
import 'payment_webview_screen.dart';

/// Unified booking flow: Pricing â†’ Details â†’ Payment
class UnifiedBookingFlowScreen extends ConsumerStatefulWidget {
  final String mohaffezId;
  final String mohaffezName;
  final Map<String, dynamic> mohaffezProfile;

  const UnifiedBookingFlowScreen({
    super.key,
    required this.mohaffezId,
    required this.mohaffezName,
    required this.mohaffezProfile,
  });

  @override
  ConsumerState<UnifiedBookingFlowScreen> createState() =>
      _UnifiedBookingFlowScreenState();
}

class _UnifiedBookingFlowScreenState
    extends ConsumerState<UnifiedBookingFlowScreen> {
  int currentStep = 0;
  PricingPlanModel? selectedPlan;
  String selectedSessionType = 'home';
  Map<String, dynamic>? selectedTimeSlot;
  DateTime? selectedDate;
  int? selectedDayOfWeek;
  String? selectedAddress;
  double? selectedLat;
  double? selectedLng;

  @override
  Widget build(BuildContext context) {
    final plansAsync = ref.watch(activePricingPlansProvider(widget.mohaffezId));

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Ø¥ØªÙ…Ø§Ù… Ø§Ù„Ø­Ø¬Ø²'),
          backgroundColor: AppTheme.accentGreen,
        ),
        body: Column(
          children: [
            // Progress Indicator
            _buildProgressIndicator(),

            // Content
            Expanded(
              child: plansAsync.when(
                data: (plans) {
                  final filteredPlans = plans.where((p) {
                    if (selectedSessionType == 'home')
                      return p.mode == SessionMode.home;
                    if (selectedSessionType == 'mosque')
                      return p.mode == SessionMode.mosque;
                    if (selectedSessionType == 'online')
                      return p.mode == SessionMode.online;
                    return false;
                  }).toList();

                  switch (currentStep) {
                    case 0:
                      return _buildPricingStep(filteredPlans);
                    case 1:
                      return _buildBookingDetailsStep();
                    case 2:
                      return _buildConfirmationStep();
                    default:
                      return const SizedBox();
                  }
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Ø®Ø·Ø£: $e')),
              ),
            ),

            // Navigation Buttons
            _buildNavigationButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildStepIndicator(0, 'Ø§Ø®ØªØ± Ø§Ù„Ø¨Ø§Ù‚Ø©', Icons.payment),
          _buildStepConnector(0),
          _buildStepIndicator(1, 'Ø§Ù„ØªÙØ§ØµÙŠÙ„', Icons.event),
          _buildStepConnector(1),
          _buildStepIndicator(2, 'Ø§Ù„ØªØ£ÙƒÙŠØ¯', Icons.check_circle),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(int step, String label, IconData icon) {
    final isActive = currentStep == step;
    final isCompleted = currentStep > step;

    return Expanded(
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isCompleted || isActive
                  ? AppTheme.accentGreen
                  : Colors.grey.shade300,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isCompleted ? Icons.check : icon,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              color: isActive ? AppTheme.accentGreen : Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStepConnector(int step) {
    final isCompleted = currentStep > step;
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 30),
        color: isCompleted ? AppTheme.accentGreen : Colors.grey.shade300,
      ),
    );
  }

  // STEP 1: Pricing Selection
  Widget _buildPricingStep(List<PricingPlanModel> plans) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Value Proposition
        _buildValueProposition(),
        const SizedBox(height: 24),

        // Session Type Selector
        const Text(
          'Ù†ÙˆØ¹ Ø§Ù„Ø¬Ù„Ø³Ø©',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        _buildSessionTypeSelector(),
        const SizedBox(height: 24),

        // Pricing Plans
        const Text(
          'Ø§Ø®ØªØ± Ø§Ù„Ø¨Ø§Ù‚Ø© Ø§Ù„Ù…Ù†Ø§Ø³Ø¨Ø©',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),

        if (plans.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: Text(
                  'Ù„Ø§ ØªÙˆØ¬Ø¯ Ø¨Ø§Ù‚Ø§Øª Ù…ØªØ§Ø­Ø© Ù„Ù‡Ø°Ø§ Ø§Ù„Ù†ÙˆØ¹'),
            ),
          )
        else
          ...plans.map((plan) => _buildPlanCard(plan)),
      ],
    );
  }

  Widget _buildValueProposition() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.accentGreen, Color(0xFF66BB6A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Icon(Icons.verified, color: Colors.white, size: 48),
          const SizedBox(height: 12),
          Text(
            widget.mohaffezName,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildFeatureBadge(Icons.lock, 'Ø¯ÙØ¹ Ø¢Ù…Ù†'),
              const SizedBox(width: 12),
              _buildFeatureBadge(Icons.replay, 'Ø§Ø³ØªØ±Ø¬Ø§Ø¹ Ù…Ø¶Ù…ÙˆÙ†'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureBadge(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionTypeSelector() {
    return Row(
      children: [
        Expanded(
          child: _buildSessionTypeCard(
            'home',
            'Ø§Ù„Ù…Ù†Ø²Ù„',
            Icons.home,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSessionTypeCard(
            'mosque',
            'Ø§Ù„Ù…Ø³Ø¬Ø¯',
            Icons.mosque,
            Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSessionTypeCard(
            'online',
            'Ø£ÙˆÙ†Ù„Ø§ÙŠÙ†',
            Icons.videocam,
            Colors.purple,
          ),
        ),
      ],
    );
  }

  Widget _buildSessionTypeCard(
    String type,
    String label,
    IconData icon,
    Color color,
  ) {
    final isSelected = selectedSessionType == type;
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedSessionType = type;
          selectedPlan = null; // Reset plan when type changes
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? color : Colors.grey, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? color : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanCard(PricingPlanModel plan) {
    final isSelected = selectedPlan?.id == plan.id;
    final pricePerSession = plan.priceEGP / plan.sessionsCount;
    final savings = plan.sessionsCount > 1
        ? ((plan.sessionsCount * 50) - plan.priceEGP).toInt()
        : 0;

    return GestureDetector(
      onTap: () => setState(() => selectedPlan = plan),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppTheme.accentGreen : Colors.grey.shade300,
            width: isSelected ? 3 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.accentGreen.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Selection Indicator
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.accentGreen
                            : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? AppTheme.accentGreen
                              : Colors.grey.shade400,
                          width: 2,
                        ),
                      ),
                      child: isSelected
                          ? const Icon(Icons.check,
                              size: 16, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            plan.title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${plan.sessionsCount} ${plan.sessionsCount == 1 ? "Ø¬Ù„Ø³Ø©" : "Ø¬Ù„Ø³Ø§Øª"}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Price
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${plan.priceEGP.toStringAsFixed(0)} Ø¬.Ù…',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? AppTheme.accentGreen
                                : AppTheme.primaryAmber,
                          ),
                        ),
                        if (plan.sessionsCount > 1)
                          Text(
                            '${pricePerSession.toStringAsFixed(0)} Ø¬.Ù…/Ø¬Ù„Ø³Ø©',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),

                // Savings Badge
                if (savings > 0) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.local_offer,
                            size: 16, color: Colors.orange),
                        const SizedBox(width: 6),
                        Text(
                          'ÙˆÙØ± $savings Ø¬.Ù…',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Description
                if (plan.description != null &&
                    plan.description!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    plan.description!,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ],
            ),

            // Best Value Badge
            if (plan.type == PlanType.subscription || savings > 100)
              Positioned(
                top: 0,
                left: 0,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.purple, Colors.deepPurple],
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      bottomRight: Radius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Ø§Ù„Ø£ÙØ¶Ù„ Ù‚ÙŠÙ…Ø©',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // STEP 2: Booking Details
  Widget _buildBookingDetailsStep() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Selected Plan Summary
        if (selectedPlan != null) _buildSelectedPlanSummary(),
        const SizedBox(height: 24),

        // Date Selection
        const Text(
          'Ø§Ø®ØªØ± Ø§Ù„ØªØ§Ø±ÙŠØ® ÙˆØ§Ù„ÙˆÙ‚Øª',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),

        // Date Selector (simplified for demo)
        _buildDateSelector(),
        const SizedBox(height: 16),

        // Time Slot Selector
        if (selectedDate != null) _buildTimeSlotSelector(),
        if (selectedSessionType != 'online') ...[
          const SizedBox(height: 20),
          const Text(
            'Ø­Ø¯Ø¯ Ù…ÙˆÙ‚Ø¹ Ø§Ù„Ø¬Ù„Ø³Ø©',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          LocationPickerWidget(
            initialAddress: selectedAddress,
            onLocationSelected: (address, lat, lng) {
              setState(() {
                selectedAddress = address;
                selectedLat = lat;
                selectedLng = lng;
              });
            },
          ),
        ],
      ],
    );
  }

  Widget _buildSelectedPlanSummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.accentGreen.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.accentGreen.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: AppTheme.accentGreen),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  selectedPlan!.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  '${selectedPlan!.priceEGP.toStringAsFixed(0)} Ø¬.Ù…',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelector() {
    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 14, // Next 14 days
        itemBuilder: (context, index) {
          final date = DateTime.now().add(Duration(days: index));
          final isSelected =
              selectedDate != null && DateUtils.isSameDay(selectedDate, date);

          return GestureDetector(
            onTap: () {
              setState(() {
                selectedDate = date;
                selectedDayOfWeek = date.weekday;
                selectedTimeSlot = null; // Reset time slot
              });
            },
            child: Container(
              width: 80,
              margin: const EdgeInsets.only(left: 12),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.accentGreen : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color:
                      isSelected ? AppTheme.accentGreen : Colors.grey.shade300,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _getArabicDayName(date.weekday),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('dd/MM').format(date),
                    style: TextStyle(
                      fontSize: 12,
                      color: isSelected ? Colors.white70 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTimeSlotSelector() {
    // Mock time slots - replace with actual availability query
    final timeSlots = [
      {'startTime': '08:00', 'endTime': '08:45'},
      {'startTime': '10:00', 'endTime': '10:45'},
      {'startTime': '14:00', 'endTime': '14:45'},
      {'startTime': '16:00', 'endTime': '16:45'},
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: timeSlots.map((slot) {
        final isSelected = selectedTimeSlot?['startTime'] == slot['startTime'];
        return GestureDetector(
          onTap: () => setState(() => selectedTimeSlot = slot),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.accentGreen : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? AppTheme.accentGreen : Colors.grey.shade300,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Text(
              '${slot['startTime']} - ${slot['endTime']}',
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.white : Colors.grey.shade800,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // STEP 3: Confirmation
  Widget _buildConfirmationStep() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Booking Summary Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ù…Ù„Ø®Øµ Ø§Ù„Ø­Ø¬Ø²',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const Divider(height: 24),
              _buildSummaryRow(
                  Icons.person, 'Ø§Ù„Ù…Ø­ÙØ¸', widget.mohaffezName),
              const SizedBox(height: 12),
              _buildSummaryRow(
                Icons.event,
                'Ø§Ù„ØªØ§Ø±ÙŠØ®',
                selectedDate != null
                    ? DateFormat('EEEE, dd MMMM yyyy', 'ar')
                        .format(selectedDate!)
                    : '-',
              ),
              const SizedBox(height: 12),
              _buildSummaryRow(
                Icons.access_time,
                'Ø§Ù„ÙˆÙ‚Øª',
                selectedTimeSlot != null
                    ? '${selectedTimeSlot!['startTime']} - ${selectedTimeSlot!['endTime']}'
                    : '-',
              ),
              const SizedBox(height: 12),
              _buildSummaryRow(
                _getSessionTypeIcon(selectedSessionType),
                'نوع الجلسة',
                _getSessionTypeLabel(selectedSessionType),
              ),
              if (selectedAddress != null && selectedAddress!.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildSummaryRow(Icons.location_on, 'الموقع', selectedAddress!),
              ],
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Ø§Ù„Ø¥Ø¬Ù…Ø§Ù„ÙŠ',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${selectedPlan?.priceEGP.toStringAsFixed(0)} Ø¬.Ù…',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.accentGreen,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Trust Badges
        _buildTrustBadges(),

        const SizedBox(height: 24),

        // Terms Checkbox
        _buildTermsCheckbox(),
      ],
    );
  }

  Widget _buildSummaryRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        const SizedBox(width: 12),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w600,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildTrustBadges() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildTrustBadge(Icons.lock, 'Ø¯ÙØ¹ Ø¢Ù…Ù†'),
              _buildTrustBadge(Icons.verified_user, 'Ù…Ø¹ØªÙ…Ø¯'),
              _buildTrustBadge(Icons.support_agent, 'Ø¯Ø¹Ù… 24/7'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.credit_card, color: Colors.green, size: 24),
              SizedBox(width: 8),
              Icon(Icons.account_balance_wallet,
                  color: Colors.orange, size: 24),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTrustBadge(IconData icon, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.green.shade700, size: 24),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.green.shade700,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  bool agreedToTerms = false;

  Widget _buildTermsCheckbox() {
    return Row(
      children: [
        Checkbox(
          value: agreedToTerms,
          onChanged: (val) => setState(() => agreedToTerms = val ?? false),
          activeColor: AppTheme.accentGreen,
        ),
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => agreedToTerms = !agreedToTerms),
            child: const Text(
              'Ø£ÙˆØ§ÙÙ‚ Ø¹Ù„Ù‰ Ø§Ù„Ø´Ø±ÙˆØ· ÙˆØ§Ù„Ø£Ø­ÙƒØ§Ù… ÙˆØ³ÙŠØ§Ø³Ø© Ø§Ù„Ø§Ø³ØªØ±Ø¬Ø§Ø¹',
              style: TextStyle(fontSize: 13),
            ),
          ),
        ),
      ],
    );
  }

  // Navigation Buttons
  Widget _buildNavigationButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => currentStep--),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Ø±Ø¬ÙˆØ¹'),
              ),
            ),
          if (currentStep > 0) const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _canProceed() ? _onNextPressed : null,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: AppTheme.accentGreen,
              ),
              child: Text(
                currentStep == 2 ? 'Ø§Ø¯ÙØ¹ Ø§Ù„Ø¢Ù†' : 'Ø§Ù„ØªØ§Ù„ÙŠ',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _canProceed() {
    switch (currentStep) {
      case 0:
        return selectedPlan != null;
      case 1:
        if (selectedDate == null || selectedTimeSlot == null) {
          return false;
        }
        if (selectedSessionType != 'online') {
          return selectedAddress != null && selectedAddress!.trim().isNotEmpty;
        }
        return true;
      case 2:
        return agreedToTerms;
      default:
        return false;
    }
  }

  void _onNextPressed() {
    if (currentStep < 2) {
      setState(() => currentStep++);
    } else {
      _proceedToPayment();
    }
  }

  Future<void> _proceedToPayment() async {
    final user = ref.read(currentUserProvider).value;
    if (user == null) return;

    // Show processing dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const PaymentProcessingDialog(),
    );

    try {
      // âœ… FIXED: Create PaymentModel properly
      final payment = PaymentModel(
        studentId: user.uid,
        studentName: user.name,
        studentEmail: user.email,
        studentPhone: user.phoneNumber ?? '',
        mohaffezId: widget.mohaffezId,
        mohaffezName: widget.mohaffezName,
        planId: selectedPlan!.id!,
        planTitle: selectedPlan!.title,
        amount: selectedPlan!.priceEGP,
        method: PaymentMethod.card,
        status: PaymentStatus.pending,
        gateway: PaymentGateway.paymob,
        createdAt: DateTime.now(),
        metadata: {
          'sessionType': selectedSessionType,
          'sessionDate': selectedDate?.toIso8601String(),
          'timeSlot': selectedTimeSlot,
          'location': selectedAddress,
          'locationLat': selectedLat,
          'locationLng': selectedLng,
        },
      );

      final paymentResult = await ref
          .read(paymentActionsProvider.notifier)
          .startPaymentAndHandleResult(
            basePayment: payment,
            plan: selectedPlan!,
          );

      if (!mounted) return;
      Navigator.pop(context); // Close loading

      if (paymentResult == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('ÙØ´Ù„ Ø¥Ù†Ø´Ø§Ø¡ Ø±Ø§Ø¨Ø· Ø§Ù„Ø¯ÙØ¹')),
        );
        return;
      }

      // Navigate to payment WebView
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (ctx) => PaymentWebViewScreen(
            paymentUrl: paymentResult.paymentUrl,
            paymentId: paymentResult.paymentId,
            plan: selectedPlan!,
          ),
        ),
      );

      if (result == true && mounted) {
        // Payment successful
        Navigator.of(context).popUntil((route) => route.isFirst);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ØªÙ… Ø§Ù„Ø¯ÙØ¹ Ø¨Ù†Ø¬Ø§Ø­! ðŸŽ‰'),
            backgroundColor: AppTheme.accentGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ø®Ø·Ø£: $e')),
        );
      }
    }
  }

  String _getArabicDayName(int weekday) {
    const days = [
      'Ø§Ù„Ø¥Ø«Ù†ÙŠÙ†',
      'Ø§Ù„Ø«Ù„Ø§Ø«Ø§Ø¡',
      'Ø§Ù„Ø£Ø±Ø¨Ø¹Ø§Ø¡',
      'Ø§Ù„Ø®Ù…ÙŠØ³',
      'Ø§Ù„Ø¬Ù…Ø¹Ø©',
      'Ø§Ù„Ø³Ø¨Øª',
      'Ø§Ù„Ø£Ø­Ø¯'
    ];
    return days[weekday - 1];
  }

  IconData _getSessionTypeIcon(String type) {
    switch (type) {
      case 'home':
        return Icons.home;
      case 'mosque':
        return Icons.mosque;
      case 'online':
        return Icons.videocam;
      default:
        return Icons.event;
    }
  }

  String _getSessionTypeLabel(String type) {
    switch (type) {
      case 'home':
        return 'Ø§Ù„Ù…Ù†Ø²Ù„';
      case 'mosque':
        return 'Ø§Ù„Ù…Ø³Ø¬Ø¯';
      case 'online':
        return 'Ø£ÙˆÙ†Ù„Ø§ÙŠÙ†';
      default:
        return type;
    }
  }
}

/// Payment Processing Dialog
class PaymentProcessingDialog extends StatelessWidget {
  const PaymentProcessingDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl, // âœ… FIXED
      child: AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            const Text(
              'Ø¬Ø§Ø±ÙŠ ØªØ£Ù…ÙŠÙ† Ø¹Ù…Ù„ÙŠØ© Ø§Ù„Ø¯ÙØ¹...',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'ÙŠØ±Ø¬Ù‰ Ø§Ù„Ø§Ù†ØªØ¸Ø§Ø±',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}
