import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mohaffez_core/mohaffez_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class MeetingLauncherService {
  static const _checklistKey = 'online_checklist_seen_v1';
  static const _infoCardKey = 'online_session_info_seen_v1';

  static Future<bool> isChecklistSeen() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_checklistKey) ?? false;
  }

  static Future<void> markChecklistSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_checklistKey, true);
  }

  static Future<bool> isInfoCardSeen() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_infoCardKey) ?? false;
  }

  static Future<void> markInfoCardSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_infoCardKey, true);
  }

  /// Main entry point called by the join button. The meeting opens in an
  /// external app (Zoom / Meet / Teams), which handles its own camera and
  /// microphone permissions — Mohaffez never touches them.
  static Future<void> launch({
    required BuildContext context,
    required WidgetRef ref,
    required MeetingInfo info,
    required String sessionId,
    required String role, // 'student' | 'mohaffez'
  }) async {
    final checklistSeen = await isChecklistSeen();
    if (!checklistSeen && context.mounted) {
      final proceed = await _showChecklist(context);
      if (!proceed) return;
    }

    await _launchUrl(info.url);
    await _writeJoinTimestamp(sessionId, role);
  }

  static Future<bool> _showChecklist(BuildContext context) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ChecklistSheet(),
    );
    return result ?? false;
  }

  static Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  static Future<void> _writeJoinTimestamp(
    String sessionId,
    String role,
  ) async {
    if (sessionId.isEmpty) return;
    final field = role == 'mohaffez'
        ? 'meetingTeacherJoinedAt'
        : 'meetingStudentJoinedAt';
    try {
      await FirebaseFirestore.instance
          .collection('hafizSessions')
          .doc(sessionId)
          .update({
        field: FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  /// Result of attempting to start an online meeting. Exactly one of
  /// `url` or `error` is non-null on a non-success result; on success
  /// `url` is set and `error` is null.
  ///
  /// Errors are returned (not thrown) so the caller can render an
  /// appropriate snackbar/dialog without try/catch noise.
  ///
  /// `error` codes:
  /// - `noLink`     — teacher has not configured any meeting link
  /// - `tooEarly`   — `now < sessionDate − leadTime`
  /// - `concurrent` — teacher already has another in-progress online session
  /// - `notFound`   — session document does not exist
  /// - `unknown`    — write failed
  ///
  /// Called by the teacher when starting an online session. Refreshes the
  /// session's `meeting.url` from the teacher's current `users/{uid}.meetingLink`
  /// (so a link added after acceptance is honored), then stamps `meetingStartedAt`
  /// so the student's UI immediately shows the join banner.
  static Future<({String? url, String? error, int? minutesUntilEarliestStart})>
      markMeetingStarted({
    required String sessionId,
    required String teacherId,
    required int leadTimeMinutes,
  }) async {
    if (sessionId.isEmpty || teacherId.isEmpty) {
      return (url: null, error: 'notFound', minutesUntilEarliestStart: null);
    }

    final firestore = FirebaseFirestore.instance;

    final sessionSnap =
        await firestore.collection('hafizSessions').doc(sessionId).get();
    if (!sessionSnap.exists) {
      return (url: null, error: 'notFound', minutesUntilEarliestStart: null);
    }
    final sessionData = sessionSnap.data() ?? const <String, dynamic>{};
    final preferredProvider =
        (sessionData['preferredProvider'] as String?)?.trim() ?? '';

    // Guard 1 — too early. Teacher can only start within `leadTimeMinutes`
    // before sessionDate.
    final sessionDateRaw = sessionData['sessionDate'];
    final DateTime? sessionDate = sessionDateRaw is Timestamp
        ? sessionDateRaw.toDate()
        : (sessionDateRaw is DateTime ? sessionDateRaw : null);
    if (sessionDate != null) {
      final earliestStart =
          sessionDate.subtract(Duration(minutes: leadTimeMinutes));
      final now = DateTime.now();
      if (now.isBefore(earliestStart)) {
        return (
          url: null,
          error: 'tooEarly',
          minutesUntilEarliestStart:
              earliestStart.difference(now).inMinutes + 1,
        );
      }
    }

    // Guard 2 — no concurrent in-progress sessions for this teacher.
    // Equality-only query (no range filter) so we don't need a composite
    // index. The `meetingStartedAt`/`meetingEndedAt` predicate is applied
    // client-side; result set is small (one teacher's accepted online
    // sessions) so this is cheap.
    final concurrent = await firestore
        .collection('hafizSessions')
        .where('mohaffezId', isEqualTo: teacherId)
        .where('sessionType', isEqualTo: 'online')
        .where('status', isEqualTo: 'accepted')
        .get();
    final hasOther = concurrent.docs.any((d) {
      if (d.id == sessionId) return false;
      final data = d.data();
      return data['meetingStartedAt'] != null &&
          data['meetingEndedAt'] == null;
    });
    if (hasOther) {
      return (
        url: null,
        error: 'concurrent',
        minutesUntilEarliestStart: null,
      );
    }

    final teacherSnap = await firestore.collection('users').doc(teacherId).get();
    final teacherData = teacherSnap.data() ?? const <String, dynamic>{};
    final linksRaw = teacherData['meetingLinks'];
    final Map<String, String> links = linksRaw is Map
        ? linksRaw.map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''))
        : <String, String>{};

    String link = '';
    String provider = '';

    // 1. Honor the student's pick.
    if (preferredProvider.isNotEmpty &&
        (links[preferredProvider]?.trim().isNotEmpty ?? false)) {
      link = links[preferredProvider]!.trim();
      provider = preferredProvider;
    }

    // 2. Any configured provider.
    if (link.isEmpty) {
      for (final entry in links.entries) {
        if (entry.value.trim().isNotEmpty) {
          link = entry.value.trim();
          provider = entry.key;
          break;
        }
      }
    }

    // 3. Legacy fallback.
    if (link.isEmpty) {
      link = (teacherData['meetingLink'] as String?)?.trim() ?? '';
      if (link.isNotEmpty) {
        provider = link.contains('zoom.us')
            ? 'zoom'
            : link.contains('meet.google.com')
                ? 'googleMeet'
                : (link.contains('teams.microsoft.com') ||
                        link.contains('teams.live.com'))
                    ? 'teams'
                    : 'custom';
      }
    }

    if (link.isEmpty) {
      return (url: null, error: 'noLink', minutesUntilEarliestStart: null);
    }

    try {
      await firestore.collection('hafizSessions').doc(sessionId).update({
        'meeting.url': link,
        'meeting.roomId': link,
        'meeting.provider': provider,
        'meetingStartedAt': FieldValue.serverTimestamp(),
        'meetingTeacherJoinedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      return (url: null, error: 'unknown', minutesUntilEarliestStart: null);
    }
    return (url: link, error: null, minutesUntilEarliestStart: null);
  }
}

// ─── Checklist bottom sheet ───────────────────────────────────────────────────

class _ChecklistSheet extends StatefulWidget {
  const _ChecklistSheet();

  @override
  State<_ChecklistSheet> createState() => _ChecklistSheetState();
}

class _ChecklistSheetState extends State<_ChecklistSheet> {
  bool _dontShowAgain = false;

  static const _items = [
    (Icons.videocam_outlined, 'كاميرا تعمل بشكل جيد'),
    (Icons.mic_outlined, 'ميكروفون يعمل'),
    (Icons.headphones_outlined, 'سماعة أو سماعات جاهزة'),
    (Icons.wifi, 'إنترنت قوي (موصى به: Wi-Fi)'),
    (Icons.light_mode_outlined, 'مكان هادئ ومضاء جيداً'),
  ];

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppThemeConstants.grey300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppThemeConstants.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.videocam_rounded,
                      color: AppThemeConstants.primary, size: 22),
                ),
                const SizedBox(width: 12),
                const Text(
                  'قبل بدء الجلسة تأكد من:',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppThemeConstants.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ..._items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppThemeConstants.success.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(item.$1,
                            color: AppThemeConstants.success, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        item.$2,
                        style: const TextStyle(
                          fontSize: 15,
                          color: AppThemeConstants.textPrimary,
                        ),
                      ),
                    ],
                  ),
                )),
            const SizedBox(height: 8),
            Row(
              children: [
                Checkbox(
                  value: _dontShowAgain,
                  activeColor: AppThemeConstants.primary,
                  onChanged: (v) => setState(() => _dontShowAgain = v ?? false),
                ),
                const Text(
                  'لا تظهر مرة أخرى',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppThemeConstants.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  if (_dontShowAgain) {
                    await MeetingLauncherService.markChecklistSeen();
                  }
                  if (context.mounted) Navigator.pop(context, true);
                },
                icon: const Icon(Icons.play_circle_outline),
                label: const Text(
                  'متابعة وفتح الجلسة',
                  style: TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppThemeConstants.primary,
                  foregroundColor: AppThemeConstants.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

