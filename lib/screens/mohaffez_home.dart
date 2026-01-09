import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../shared/widgets/session_card.dart';
import '../shared/widgets/empty_state.dart';
import '../shared/constants/app_theme.dart';
import '../shared/widgets/shimmer_widgets.dart';
import '../shared/widgets/error_widgets.dart';
import '../providers/user_provider.dart';
import '../providers/session_provider.dart';
import '../shared/utils/error_handler.dart';

class MohaffezHome extends ConsumerStatefulWidget {
  const MohaffezHome({super.key});

  @override
  ConsumerState<MohaffezHome> createState() => _MohaffezHomeState();
}

class _MohaffezHomeState extends ConsumerState<MohaffezHome>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);

    return userAsync.when(
      data: (user) {
        if (user == null) {
          return const Scaffold(
            body: Center(child: Text('يرجى تسجيل الدخول')),
          );
        }
        return _buildContent(user.uid);
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorDisplay.dataLoad(
        onRetry: () => ref.invalidate(currentUserProvider),
      ),
    );
  }

  Widget _buildContent(String mohaffezId) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          title: const Text('لوحة المحفظ'),
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'طلبات الجلسات'),
              Tab(text: 'الجلسات المقبولة'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildRequestsTab(mohaffezId),
            _buildAcceptedTab(mohaffezId),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestsTab(String mohaffezId) {
    final requestsAsync = ref.watch(pendingRequestsProvider(mohaffezId));

    return requestsAsync.when(
      data: (requests) {
        if (requests.isEmpty) {
          return const EmptyState(
            icon: Icons.inbox_outlined,
            title: 'لا توجد طلبات',
            message: 'لا توجد طلبات جلسات جديدة في الوقت الحالي.',
            animated: true,
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final request = requests[index];
            return _buildRequestCard(request);
          },
        );
      },
      loading: () => ShimmerWidgets.list(
        itemCount: 3,
        itemBuilder: () => ShimmerWidgets.listItem(
          showAvatar: true,
          lines: 3,
        ),
      ),
      error: (e, _) => ErrorDisplay.dataLoad(
        onRetry: () => ref.invalidate(pendingRequestsProvider(mohaffezId)),
      ),
    );
  }

  Widget _buildRequestCard(request) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.person, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    request.studentName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
            // Details
            if (request.sessionType.isNotEmpty && request.preferredTimeSlot.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                '${request.sessionType} - ${request.preferredTimeSlot}',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
            if (request.imamAddressText?.isNotEmpty ?? false) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.location_on, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      request.imamAddressText!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (request.slotStart != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.access_time, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    '${request.slotStart!.day}/${request.slotStart!.month}/${request.slotStart!.year} - ${request.slotStart!.hour.toString().padLeft(2, '0')}:${request.slotStart!.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _rejectRequest(request.id!),
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('رفض'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _acceptRequest(request),
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('قبول'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentGreen,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAcceptedTab(String mohaffezId) {
    final sessionsAsync = ref.watch(acceptedSessionsProvider(mohaffezId));

    return sessionsAsync.when(
      data: (sessions) {
        if (sessions.isEmpty) {
          return const EmptyState(
            icon: Icons.school_outlined,
            title: 'لا توجد جلسات',
            message: 'لم تقبل أي جلسات بعد.',
            animated: true,
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: sessions.length,
          itemBuilder: (context, index) {
            final session = sessions[index];
            
            // Handle nullable fields
            final sessionType = session.sessionType ?? '';
            final timeSlot = session.preferredTimeSlot ?? '';
            final hasValidSubtitle = sessionType.isNotEmpty && timeSlot.isNotEmpty;
            
            return SessionCard(
              title: session.studentName ?? 'طالب',
              subtitle: hasValidSubtitle ? '$sessionType - $timeSlot' : null,
              location: session.location ?? '',
              dateTime: session.sessionDate,
              hifz: session.hifzAssignment ?? '',
              muraja: session.murajaAssignment ?? '',
              rating: session.sessionRating ?? 0,
              notes: session.sessionNotes ?? '',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, size: 20),
                    onPressed: () => _showAssignmentDialog(session),
                    tooltip: 'تحرير التكليف',
                  ),
                  if (session.imamAddressLat != null && session.imamAddressLng != null)
                    IconButton(
                      icon: const Icon(Icons.map, size: 20),
                      onPressed: () async {
                        final uri = Uri.parse(
                          'https://www.google.com/maps/search/?api=1&query=${session.imamAddressLat},${session.imamAddressLng}',
                        );
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      },
                      tooltip: 'خريطة',
                    ),
                ],
              ),
            );
          },
        );
      },
      loading: () => ShimmerWidgets.list(
        itemCount: 4,
        itemBuilder: () => ShimmerWidgets.listItem(
          showAvatar: true,
          lines: 3,
        ),
      ),
      error: (e, _) => ErrorDisplay.dataLoad(
        onRetry: () => ref.invalidate(acceptedSessionsProvider(mohaffezId)),
      ),
    );
  }
  Future<void> _acceptRequest(request) async {
    final notifier = ref.read(sessionBookingProvider.notifier);
    
    await notifier.acceptRequest(
      request.id!,
      {
        'mohaffezId': request.mohaffezId,
        'studentId': request.studentId,
        'mohaffezName': request.mohaffezName,
        'studentName': request.studentName,
        'sessionType': request.sessionType,
        'imamAddressText': request.imamAddressText,
        'imamAddressLat': request.imamAddressLat,
        'imamAddressLng': request.imamAddressLng,
        'mohaffezPhone': request.mohaffezPhone,
        'preferredTimeSlot': request.preferredTimeSlot,
        'slotStart': request.slotStart,
        'slotEnd': request.slotEnd,
      },
    );

    if (mounted) {
      ErrorHandler.showSuccess(context, 'تم قبول الطلب بنجاح');
    }
  }

  Future<void> _rejectRequest(String requestId) async {
    final notifier = ref.read(sessionBookingProvider.notifier);
    await notifier.rejectRequest(requestId);

    if (mounted) {
      ErrorHandler.showSuccess(context, 'تم رفض الطلب');
    }
  }

  void _showAssignmentDialog(session) {
    final hifzController = TextEditingController(text: session.hifzAssignment);
    final murajaController = TextEditingController(text: session.murajaAssignment);
    final notesController = TextEditingController(text: session.sessionNotes);
    int rating = session.sessionRating;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('تحرير التكليف'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: hifzController,
                    decoration: const InputDecoration(
                      labelText: 'تكليف الحفظ',
                      hintText: 'مثال: من آية 1 إلى آية 10',
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: murajaController,
                    decoration: const InputDecoration(
                      labelText: 'تكليف المراجعة',
                      hintText: 'مثال: سورة البقرة كاملة',
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesController,
                    decoration: const InputDecoration(
                      labelText: 'ملاحظات',
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'التقييم',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(10, (index) {
                      return GestureDetector(
                        onTap: () => setState(() => rating = index + 1),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: rating >= index + 1
                                ? AppTheme.accentGreen
                                : Colors.grey.shade200,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: rating >= index + 1 ? Colors.white : Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      );
                    }),
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
                  final notifier = ref.read(sessionBookingProvider.notifier);
                  await notifier.updateAssignment(
                    sessionId: session.id!,
                    hifzAssignment: hifzController.text.trim(),
                    murajaAssignment: murajaController.text.trim(),
                    rating: rating,
                    notes: notesController.text.trim(),
                  );

                  if (context.mounted) {
                    Navigator.pop(ctx);
                    ErrorHandler.showSuccess(context, 'تم تحديث التكليف بنجاح');
                  }
                },
                child: const Text('حفظ'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
