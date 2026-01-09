import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../shared/widgets/session_card.dart';
import '../shared/widgets/empty_state.dart';
import '../shared/widgets/shimmer_widgets.dart';
import '../shared/widgets/error_widgets.dart';
import '../shared/widgets/empty_state_illustrations.dart';
import '../providers/session_provider.dart';
import '../providers/user_provider.dart';

class AcceptedSessionsScreen extends ConsumerWidget {
  const AcceptedSessionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return userAsync.when(
      data: (user) {
        if (user == null) {
          return const Scaffold(
            body: Center(child: Text('يرجى تسجيل الدخول')),
          );
        }
        return _buildContent(context, ref, user.uid);
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        body: ErrorDisplay.dataLoad(
          onRetry: () => ref.invalidate(currentUserProvider),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, String studentId) {
    final sessionsAsync = ref.watch(studentSessionsProvider(studentId));

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('الجلسات المقبولة'),
        ),
        body: sessionsAsync.when(
          data: (sessions) {
            if (sessions.isEmpty) {
              return IllustratedEmptyState(
                illustration: EmptyStateIllustrations.noSessions(),
                title: 'لا توجد جلسات',
                message: 'لم تقبل أي جلسات بعد. ابدأ بالبحث عن محفظين قريبين.',
                action: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.search),
                  label: const Text('ابحث عن محفظ'),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: sessions.length,
              itemBuilder: (context, index) {
                final session = sessions[index];
                
                // Handle nullable fields safely
                final sessionType = session.sessionType ?? '';
                final timeSlot = session.preferredTimeSlot ?? '';
                final hasValidSubtitle = sessionType.isNotEmpty && timeSlot.isNotEmpty;
                
                return SessionCard(
                  title: session.mohaffezName ?? 'محفظ',
                  subtitle: hasValidSubtitle ? '$sessionType - $timeSlot' : null,
                  location: session.location ?? '',
                  dateTime: session.sessionDate ?? session.slotStart,
                  hifz: session.hifzAssignment ?? '',
                  muraja: session.murajaAssignment ?? '',
                  rating: session.sessionRating ?? 0,
                  notes: session.sessionNotes ?? '',
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (session.imamAddressLat != null &&
                          session.imamAddressLng != null)
                        TextButton.icon(
                          onPressed: () async {
                            final uri = Uri.parse(
                              'https://www.google.com/maps/search/?api=1&query=${session.imamAddressLat},${session.imamAddressLng}',
                            );
                            await launchUrl(
                              uri,
                              mode: LaunchMode.externalApplication,
                            );
                          },
                          icon: const Icon(Icons.map, size: 16),
                          label: const Text('خريطة'),
                        ),
                      if (session.mohaffezPhone != null && 
                          session.mohaffezPhone!.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: () async {
                            final uri =
                                Uri.parse('https://wa.me/${session.mohaffezPhone}');
                            await launchUrl(
                              uri,
                              mode: LaunchMode.externalApplication,
                            );
                          },
                          icon: Icon(
                            Icons.phone,
                            color: Colors.green.shade600,
                            size: 16,
                          ),
                          label: const Text('واتساب'),
                        ),
                      ],
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
            onRetry: () => ref.invalidate(studentSessionsProvider(studentId)),
          ),
        ),
      ),
    );
  }
}
