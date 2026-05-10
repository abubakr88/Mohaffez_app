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

  /// Called by the teacher when starting an online session. Refreshes the
  /// session's `meeting.url` from the teacher's current `users/{uid}.meetingLink`
  /// (so a link added after acceptance is honored), then stamps `meetingStartedAt`
  /// so the student's UI immediately shows the join banner. Returns the meeting
  /// URL on success, or `null` if the teacher has not configured a meeting link.
  static Future<String?> markMeetingStarted({
    required String sessionId,
    required String teacherId,
  }) async {
    if (sessionId.isEmpty || teacherId.isEmpty) return null;

    final firestore = FirebaseFirestore.instance;

    final teacherSnap = await firestore.collection('users').doc(teacherId).get();
    final link = (teacherSnap.data()?['meetingLink'] as String?)?.trim() ?? '';
    if (link.isEmpty) return null;

    final provider = link.contains('zoom.us')
        ? 'zoom'
        : link.contains('meet.google.com')
            ? 'google-meet'
            : (link.contains('teams.microsoft.com') || link.contains('teams.live.com'))
                ? 'teams'
                : 'custom';

    try {
      await firestore.collection('hafizSessions').doc(sessionId).update({
        'meeting.url': link,
        'meeting.roomId': link,
        'meeting.provider': provider,
        'meetingStartedAt': FieldValue.serverTimestamp(),
        'meetingTeacherJoinedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
    return link;
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

