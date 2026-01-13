import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection; // Hide TextDirection from intl
import '../models/session_model.dart';
import '../shared/constants/app_theme.dart';
import '../shared/widgets/cached_avatar.dart';
import 'package:url_launcher/url_launcher.dart';

class SessionDetailsScreen extends ConsumerWidget {
  final SessionModel session;

  const SessionDetailsScreen({
    super.key,
    required this.session,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          title: const Text('تفاصيل الجلسة'),
          elevation: 0,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card
              _buildHeaderCard(),
              const SizedBox(height: 16),

              // Session Info
              _buildInfoCard(),
              const SizedBox(height: 16),

              // Location
              _buildLocationCard(),
              const SizedBox(height: 16),

              // Assignments (if any)
              if (_hasAssignments()) ...[
                _buildAssignmentsCard(),
                const SizedBox(height: 16),
              ],

              // Rating & Notes (if completed)
              if (_isCompleted()) ...[
                _buildRatingCard(),
                const SizedBox(height: 16),
              ],

              // Actions
              _buildActionsCard(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primaryAmber, AppTheme.lightAmber],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          CachedAvatar(
            imageUrl: null, // Add mohaffez photo if available
            radius: 40,
            semanticLabel: session.mohaffezName,
          ),
          const SizedBox(height: 12),
          Text(
            session.mohaffezName,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _getSessionTypeLabel(session.sessionType),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'معلومات الجلسة',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Divider(height: 24),
          _buildInfoRow(
            icon: Icons.calendar_today,
            label: 'التاريخ',
            value: _formatDate(session.sessionDate ?? session.slotStart),
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            icon: Icons.access_time,
            label: 'الوقت',
            value: session.preferredTimeSlot ?? _formatTime(session.slotStart),
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            icon: Icons.book,
            label: 'عدد الأجزاء',
            value: '${session.juzCount} جزء',
          ),
          if (session.mohaffezPhone != null && session.mohaffezPhone!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildInfoRow(
              icon: Icons.phone,
              label: 'رقم المحفظ',
              value: session.mohaffezPhone!,
              trailing: IconButton(
                icon: const Icon(Icons.call, color: Colors.green),
                onPressed: () => _makeCall(session.mohaffezPhone!),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLocationCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _getLocationIcon(),
                color: AppTheme.accentGreen,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'الموقع',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Text(
            session.location,
            style: const TextStyle(fontSize: 15),
          ),
          if (session.imamAddressLat != null && session.imamAddressLng != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _openMap(),
                icon: const Icon(Icons.map, size: 18),
                label: const Text('فتح الخريطة'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAssignmentsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.assignment, color: AppTheme.primaryAmber, size: 20),
              SizedBox(width: 8),
              Text(
                'الواجبات',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          if (session.hifzAssignment?.isNotEmpty ?? false) ...[
            const Text(
              'حفظ جديد',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Text(
                session.hifzAssignment!,
                style: const TextStyle(fontSize: 15),
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (session.murajaAssignment?.isNotEmpty ?? false) ...[
            const Text(
              'مراجعة',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Text(
                session.murajaAssignment!,
                style: const TextStyle(fontSize: 15),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRatingCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'التقييم والملاحظات',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Divider(height: 24),
          if ((session.sessionRating ?? 0) > 0) ...[
            Row(
              children: [
                const Text(
                  'التقييم: ',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                ...List.generate(
                  10,
                  (index) => Icon(
                    index < (session.sessionRating ?? 0)
                        ? Icons.star
                        : Icons.star_border,
                    size: 18,
                    color: Colors.amber,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${session.sessionRating}/10',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          if (session.sessionNotes?.isNotEmpty ?? false) ...[
            const Text(
              'ملاحظات المحفظ:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Text(
                session.sessionNotes!,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionsCard(BuildContext context) {
    // Only show cancel for pending sessions
    final isPending = session.sessionDate != null &&
        session.sessionDate!.isAfter(DateTime.now());

    if (!isPending) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _confirmCancel(context),
              icon: const Icon(Icons.cancel),
              label: const Text('إلغاء الجلسة'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    Widget? trailing,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppTheme.primaryAmber),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  // Helper methods
  bool _hasAssignments() {
    return (session.hifzAssignment?.isNotEmpty ?? false) ||
        (session.murajaAssignment?.isNotEmpty ?? false);
  }

  bool _isCompleted() {
    return (session.sessionRating ?? 0) > 0 ||
        (session.sessionNotes?.isNotEmpty ?? false);
  }

  String _getSessionTypeLabel(String type) {
    switch (type.toLowerCase()) {
      case 'home':
        return 'في البيت';
      case 'mosque':
        return 'في المسجد';
      case 'online':
        return 'أونلاين';
      default:
        return type;
    }
  }

  IconData _getLocationIcon() {
    switch (session.sessionType.toLowerCase()) {
      case 'home':
        return Icons.home;
      case 'mosque':
        return Icons.mosque;
      case 'online':
        return Icons.videocam;
      default:
        return Icons.location_on;
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'غير محدد';
    return DateFormat('yyyy/MM/dd').format(date);
  }

  String _formatTime(DateTime? date) {
    if (date == null) return 'غير محدد';
    return DateFormat('HH:mm').format(date);
  }

  void _makeCall(String phone) async {
    final uri = Uri.parse('tel:$phone');
    await launchUrl(uri);
  }

  void _openMap() async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${session.imamAddressLat},${session.imamAddressLng}',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _confirmCancel(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('إلغاء الجلسة'),
          content: const Text('هل أنت متأكد من إلغاء هذه الجلسة؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('لا'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                // TODO: Implement cancel logic
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تم إلغاء الجلسة')),
                );
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('نعم، إلغاء'),
            ),
          ],
        ),
      ),
    );
  }
}
