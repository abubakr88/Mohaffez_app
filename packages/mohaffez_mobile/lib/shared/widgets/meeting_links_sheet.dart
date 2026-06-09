import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mohaffez_core/mohaffez_core.dart';

/// Provider IDs persisted in `users/{uid}.meetingLinks`. Adding a new provider
/// later means adding one entry here — every other surface (profile, booking
/// picker, Cloud Function) reads from this list.
class MeetingProviderSpec {
  final String id; // 'zoom', 'googleMeet', 'teams'
  final String label;
  final String hostMatch; // substring matched against URL host
  final String hint;
  final IconData icon;
  final Color color;

  const MeetingProviderSpec({
    required this.id,
    required this.label,
    required this.hostMatch,
    required this.hint,
    required this.icon,
    required this.color,
  });
}

const meetingProviders = <MeetingProviderSpec>[
  MeetingProviderSpec(
    id: 'zoom',
    label: 'Zoom',
    hostMatch: 'zoom.us',
    hint: 'https://zoom.us/j/...',
    icon: Icons.videocam_rounded,
    color: Color(0xFF2D8CFF),
  ),
  MeetingProviderSpec(
    id: 'googleMeet',
    label: 'Google Meet',
    hostMatch: 'meet.google.com',
    hint: 'https://meet.google.com/...',
    icon: Icons.video_call_rounded,
    color: Color(0xFF00897B),
  ),
  MeetingProviderSpec(
    id: 'teams',
    label: 'Microsoft Teams',
    hostMatch: 'teams.microsoft.com',
    hint: 'https://teams.microsoft.com/...',
    icon: Icons.groups_rounded,
    color: Color(0xFF6264A7),
  ),
];

bool _hostMatches(String url, String hostMatch) {
  final normalized = _normalizeMeetingUrl(url);
  if (normalized.isEmpty || RegExp(r'\s').hasMatch(normalized)) return false;
  final uri = Uri.tryParse(normalized);
  if (uri == null || !uri.hasScheme || !uri.hasAuthority) return false;
  if (uri.scheme != 'https' && uri.scheme != 'http') return false;
  final host = uri.host.toLowerCase();
  if (hostMatch == 'teams.microsoft.com') {
    return host.contains('teams.microsoft.com') ||
        host.contains('teams.live.com');
  }
  return host.contains(hostMatch);
}

String _normalizeMeetingUrl(String value) {
  var url = value.trim();
  if (url.isEmpty) return '';

  url = url
      .replaceFirst(RegExp(r'^https//', caseSensitive: false), 'https://')
      .replaceFirst(RegExp(r'^http//', caseSensitive: false), 'http://');
  url = url
      .replaceFirstMapped(
        RegExp(r'^https:/([^/])', caseSensitive: false),
        (match) => 'https://${match.group(1)}',
      )
      .replaceFirstMapped(
        RegExp(r'^http:/([^/])', caseSensitive: false),
        (match) => 'http://${match.group(1)}',
      );

  final hasScheme =
      RegExp(r'^[a-z][a-z0-9+.-]*://', caseSensitive: false).hasMatch(url);
  if (!hasScheme) {
    url = 'https://$url';
  } else if (url.toLowerCase().startsWith('http://')) {
    url = 'https://${url.substring(7)}';
  }

  return url;
}

String _invalidLinkMessage(MeetingProviderSpec provider) {
  return 'رابط ${provider.label} غير صحيح. '
      'الصق رابط ${provider.label}، ويمكن كتابته بدون https://';
}

String _saveErrorMessage(Object error) {
  if (error is FirebaseException && error.code == 'permission-denied') {
    return 'لا يمكن حفظ الروابط الآن بسبب صلاحيات الحساب. '
        'يرجى تحديث التطبيق أو التواصل مع الدعم.';
  }
  return 'تعذّر حفظ روابط الاجتماعات. يرجى المحاولة مرة أخرى.';
}

class MeetingLinksSheet extends ConsumerStatefulWidget {
  final UserModel user;
  const MeetingLinksSheet({super.key, required this.user});

  @override
  ConsumerState<MeetingLinksSheet> createState() => _MeetingLinksSheetState();
}

class _MeetingLinksSheetState extends ConsumerState<MeetingLinksSheet> {
  late final Map<String, TextEditingController> _controllers;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controllers = {
      for (final p in meetingProviders)
        p.id: TextEditingController(text: widget.user.meetingLinks[p.id] ?? ''),
    };
    // Migrate legacy single meetingLink into whichever provider it matches,
    // but only if the user has no map entries yet.
    final legacy = widget.user.meetingLink?.trim() ?? '';
    if (legacy.isNotEmpty && widget.user.meetingLinks.isEmpty) {
      for (final p in meetingProviders) {
        if (_hostMatches(legacy, p.hostMatch)) {
          _controllers[p.id]!.text = legacy;
          break;
        }
      }
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final newMap = <String, String>{};
    for (final p in meetingProviders) {
      final v = _normalizeMeetingUrl(_controllers[p.id]!.text);
      if (v.isEmpty) continue;
      if (!_hostMatches(v, p.hostMatch)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_invalidLinkMessage(p)),
            backgroundColor: AppThemeConstants.error,
          ),
        );
        return;
      }
      newMap[p.id] = v;
    }

    setState(() => _saving = true);
    try {
      // Pick a "primary" link to mirror into legacy meetingLink, so old
      // sessions accepted before the booking-picker rolls out still work.
      final primary = newMap.values.isNotEmpty ? newMap.values.first : null;
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.user.uid)
          .update({
        'meetingLinks': newMap,
        'meetingLink': primary,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_saveErrorMessage(e)),
            backgroundColor: AppThemeConstants.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.only(bottom: viewInsets),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: SingleChildScrollView(
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
                const SizedBox(height: 18),
                const Text(
                  'روابط الاجتماعات أونلاين',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppThemeConstants.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'أضف رابطاً واحداً على الأقل من غرفتك الشخصية. الطالب سيختار المنصة المفضلة عند الحجز.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppThemeConstants.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 18),
                for (final p in meetingProviders) ...[
                  _ProviderField(
                    spec: p,
                    controller: _controllers[p.id]!,
                    onClear: () => setState(() => _controllers[p.id]!.clear()),
                  ),
                  const SizedBox(height: 14),
                ],
                const SizedBox(height: 4),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_rounded, size: 18),
                    label: const Text(
                      'حفظ',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppThemeConstants.primary,
                      foregroundColor: AppThemeConstants.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProviderField extends StatelessWidget {
  final MeetingProviderSpec spec;
  final TextEditingController controller;
  final VoidCallback onClear;

  const _ProviderField({
    required this.spec,
    required this.controller,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: spec.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(spec.icon, color: spec.color, size: 16),
            ),
            const SizedBox(width: 10),
            Text(
              spec.label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppThemeConstants.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: TextInputType.url,
          autocorrect: false,
          decoration: InputDecoration(
            hintText: spec.hint,
            hintStyle: const TextStyle(fontSize: 12, color: AppThemeConstants.grey400),
            isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            suffixIcon: ListenableBuilder(
              listenable: controller,
              builder: (_, __) => controller.text.isEmpty
                  ? const SizedBox.shrink()
                  : IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      color: AppThemeConstants.grey500,
                      onPressed: onClear,
                    ),
            ),
          ),
        ),
      ],
    );
  }
}
