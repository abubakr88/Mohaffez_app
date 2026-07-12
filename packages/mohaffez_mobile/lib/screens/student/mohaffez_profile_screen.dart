// lib/screens/mohaffez_profile_screen.dart

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:mohaffez_core/mohaffez_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../shared/utils/exported_profile_image_share.dart';
import '../../shared/widgets/skeleton_card.dart';
import '../../shared/utils/time_formatter.dart';
import '../../providers/mohaffez_profile_providers.dart';
import '../../providers/trial_session_provider.dart';
import 'request_trial_session_sheet.dart';
import '../../tour/tour_guard_helper.dart';

String _teacherNameFromProfile(
  Map<String, dynamic> profile, {
  String fallback = 'المحفظ',
}) {
  final name = (profile['name'] as String?)?.trim() ?? '';
  if (name.isEmpty) return fallback;
  return composeTeacherDisplayName(name, profile['honorific'] as String?);
}

class MohaffezProfileScreen extends ConsumerStatefulWidget {
  final String mohaffezId;
  final double? userLat;
  final double? userLng;
  final bool previewMode;
  final bool publicMode;

  const MohaffezProfileScreen({
    super.key,
    required this.mohaffezId,
    this.userLat,
    this.userLng,
    this.previewMode = false,
    this.publicMode = false,
  });

  @override
  ConsumerState<MohaffezProfileScreen> createState() =>
      _MohaffezProfileScreenState();
}

class _MohaffezProfileScreenState extends ConsumerState<MohaffezProfileScreen> {
  // Empty by default — student must tap a session-type tile after plans load.
  // Hardcoding any value (e.g. 'home') let students complete a booking with
  // an unsupported session type when the teacher had no plan for that type.
  String selectedSessionType = '';
  PricingPlanModel? selectedPricingPlan;
  Map<String, dynamic>? selectedTimeSlot;
  DateTime? selectedDate;
  int? selectedDayOfWeek;
  final GlobalKey _profileExportKey = GlobalKey();
  final GlobalKey _pricingStepKey = GlobalKey();
  final GlobalKey _scheduleStepKey = GlobalKey();
  bool _isExportingProfile = false;

  bool get _isPublicView => widget.publicMode;

  void _revealStep(GlobalKey key) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final targetContext = key.currentContext;
      if (!mounted || targetContext == null) return;
      Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        alignment: 0.08,
      );
    });
  }

  /// Helper to filter pricing plans by selected session type
  List<PricingPlanModel> _relevantPlans(List<PricingPlanModel> plans) {
    final modePlans = plans
        .where((plan) =>
            selectedSessionType.isNotEmpty &&
            PricingCountryUtils.matchesMode(plan, selectedSessionType))
        .toList();
    final studentCountry = PricingCountryUtils.inferUserCountry(
        ref.read(currentUserProvider).valueOrNull);
    return PricingCountryUtils.preferCountryPlans(
      modePlans,
      studentCountry.code,
    );
  }

  String? _teacherVideoUrl(Map<String, dynamic> profile) {
    for (final key in const [
      'youtubeVideoUrl',
      'introVideoUrl',
      'videoUrl',
    ]) {
      final value = (profile[key] as String?)?.trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  Uri? _normalizedWebUri(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    if (RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(trimmed)) {
      return Uri.parse('https://www.youtube.com/watch?v=$trimmed');
    }
    final withScheme =
        trimmed.startsWith('http://') || trimmed.startsWith('https://')
            ? trimmed
            : 'https://$trimmed';
    final uri = Uri.tryParse(withScheme);
    if (uri == null ||
        !uri.hasAuthority ||
        (!uri.host.contains('.') && uri.host != 'localhost')) {
      return null;
    }
    return uri;
  }

  String? _youtubeVideoId(String value) {
    final uri = _normalizedWebUri(value);
    if (uri == null) return null;
    final host = uri.host.toLowerCase().replaceFirst('www.', '');

    if (host == 'youtu.be' && uri.pathSegments.isNotEmpty) {
      return uri.pathSegments.first;
    }
    if (host.endsWith('youtube.com')) {
      final queryId = uri.queryParameters['v'];
      if (queryId != null && queryId.isNotEmpty) return queryId;
      final segments = uri.pathSegments;
      if (segments.length >= 2 &&
          const {'embed', 'shorts', 'live'}.contains(segments.first)) {
        return segments[1];
      }
    }
    return null;
  }

  Future<void> _openTeacherVideo(String url) async {
    final uri = _normalizedWebUri(url);
    if (uri == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('رابط الفيديو غير صالح'),
            backgroundColor: AppThemeConstants.error,
          ),
        );
      }
      return;
    }

    var launched = false;
    try {
      launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      launched = false;
    }
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر فتح رابط الفيديو'),
          backgroundColor: AppThemeConstants.error,
        ),
      );
    }
  }

  // ─── Navigation helper ────────────────────────────────────────────────────

  void _openTeacherPhotoPreview(String imageUrl, String teacherName) {
    final trimmedUrl = imageUrl.trim();
    if (trimmedUrl.isEmpty) return;

    showDialog<void>(
      context: context,
      barrierColor: AppThemeConstants.black.withValues(alpha: 0.86),
      builder: (dialogContext) {
        return Directionality(
          textDirection: ui.TextDirection.rtl,
          child: Dialog.fullscreen(
            backgroundColor: AppThemeConstants.black,
            child: SafeArea(
              child: Stack(
                children: [
                  Center(
                    child: InteractiveViewer(
                      minScale: 0.8,
                      maxScale: 4,
                      child: CachedNetworkImage(
                        imageUrl: trimmedUrl,
                        fit: BoxFit.contain,
                        placeholder: (context, url) => const SizedBox(
                          width: 48,
                          height: 48,
                          child: CircularProgressIndicator(
                            color: AppThemeConstants.secondary,
                            strokeWidth: 3,
                          ),
                        ),
                        errorWidget: (context, url, error) => const Icon(
                          Icons.broken_image_rounded,
                          color: AppThemeConstants.white70,
                          size: 64,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: IconButton.filledTonal(
                      tooltip: 'إغلاق',
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ),
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 18,
                    child: Text(
                      teacherName,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppThemeConstants.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _navigateToBookingMethod() {
    if (_isPublicView) {
      context.go('/login');
      return;
    }
    if (widget.previewMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('هذه معاينة لملفك كما يراه الطالب'),
        ),
      );
      return;
    }
    if (guardWriteInTour(ref, context)) return;
    if (selectedPricingPlan == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('اختر الباقة المناسبة أولًا'),
          backgroundColor: AppThemeConstants.warning,
        ),
      );
      _revealStep(_pricingStepKey);
      return;
    }
    if (selectedTimeSlot == null || selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('اختر موعداً من التقويم أولاً'),
          backgroundColor: AppThemeConstants.warning,
        ),
      );
      return;
    }
    final profileValue =
        ref.read(mohaffezProfileProvider(widget.mohaffezId)).value ?? {};
    final slotContext = _buildSlotContext(profileValue);
    final bookingFlow = ref.read(bookingFlowProvider.notifier);
    final plan = selectedPricingPlan!;
    bookingFlow.selectPlan(
      planId: plan.id ?? '',
      title: plan.title,
      price: plan.priceEGP,
      sessions: plan.sessionsCount,
      validityDays: plan.validityDays,
    );
    bookingFlow.setSlotContext(slotContext);
    context.push('/booking/method');
  }

  // ─── SlotContext builder ──────────────────────────────────────────────────

  SlotContext _buildSlotContext(Map<String, dynamic>? profileValue) {
    final startRaw = selectedTimeSlot!['startTime'] as String? ?? '0:0';
    final endRaw = selectedTimeSlot!['endTime'] as String? ?? '0:0';

    final startParts = startRaw.split(':');
    final endParts = endRaw.split(':');

    final startHour = int.tryParse(startParts.elementAtOrNull(0) ?? '') ?? 0;
    final startMin = int.tryParse(startParts.elementAtOrNull(1) ?? '') ?? 0;
    final endHour = int.tryParse(endParts.elementAtOrNull(0) ?? '') ?? 0;
    final endMin = int.tryParse(endParts.elementAtOrNull(1) ?? '') ?? 0;

    final slotStart = DateTime(
      selectedDate!.year,
      selectedDate!.month,
      selectedDate!.day,
      startHour,
      startMin,
    );
    final slotEnd = DateTime(
      selectedDate!.year,
      selectedDate!.month,
      selectedDate!.day,
      endHour,
      endMin,
    );

    return SlotContext(
      mohaffezId: widget.mohaffezId,
      mohaffezName: profileValue == null
          ? ''
          : _teacherNameFromProfile(profileValue, fallback: ''),
      mohaffezPhone: profileValue?['phoneNumber'] as String?,
      isFoundingTeacher: profileValue?['status'] == 'active' &&
          UserBadges.fromJson(profileValue?['badges']).foundingTeacher.enabled,
      sessionType: selectedSessionType,
      preferredTimeSlot: '$startRaw - $endRaw',
      slotDate: DateTime.utc(
        selectedDate!.year,
        selectedDate!.month,
        selectedDate!.day,
      ).toIso8601String(),
      slotStart: slotStart.toUtc().toIso8601String(),
      slotEnd: slotEnd.toUtc().toIso8601String(),
      imamAddressText: profileValue?['addressText'] as String?,
      // FIX Bug 2: Firestore stores coordinates as num, not double.
      // Direct cast 'as double?' throws TypeError at runtime.
      // Use (as num?)?.toDouble() which safely handles both int and double.
      imamAddressLat: (profileValue?['addressLat'] as num?)?.toDouble(),
      imamAddressLng: (profileValue?['addressLng'] as num?)?.toDouble(),
    );
  }

  Future<List<PricingPlanModel>> _loadPlansForExport() async {
    try {
      return await ref
          .read(activePricingPlansProvider(widget.mohaffezId).future);
    } catch (_) {
      return <PricingPlanModel>[];
    }
  }

  Future<List<Map<String, dynamic>>> _loadCredentialsForExport() async {
    try {
      return await ref.read(credentialsProvider(widget.mohaffezId).future);
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  Future<List<Map<String, dynamic>>> _loadAvailabilityForExport() async {
    try {
      return await ref.read(availabilityProvider(widget.mohaffezId).future);
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  Future<Map<String, dynamic>> _loadStatsForExport() async {
    try {
      return await ref.read(mohaffezStatsProvider(widget.mohaffezId).future);
    } catch (_) {
      return {'completedSessions': 0, 'uniqueStudents': 0};
    }
  }

  Future<void> _precacheExportImages(
    Map<String, dynamic> profile,
    List<Map<String, dynamic>> credentials,
  ) async {
    final urls = <String>[];
    final photoUrl = (profile['photoUrl'] as String?)?.trim();
    if (photoUrl != null && photoUrl.isNotEmpty) urls.add(photoUrl);

    final videoUrl = _teacherVideoUrl(profile);
    final youtubeId = videoUrl == null ? null : _youtubeVideoId(videoUrl);
    if (youtubeId != null) {
      urls.add('https://img.youtube.com/vi/$youtubeId/hqdefault.jpg');
    }

    for (final credential in credentials.take(6)) {
      final imageUrls = List<String>.from(
        credential['imageUrls'] as List? ?? const [],
      ).where((url) => url.trim().isNotEmpty);
      urls.addAll(imageUrls.take(1));
    }

    await Future.wait(
      urls.map(
        (url) => precacheImage(
          CachedNetworkImageProvider(url),
          context,
        )
            .timeout(
              const Duration(seconds: 3),
              onTimeout: () {},
            )
            .catchError((_) {}),
      ),
    );
  }

  String _exportFileName(Map<String, dynamic> profile) {
    final rawName = _teacherNameFromProfile(profile, fallback: 'mohaffez')
        .trim()
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '');
    final safeName = rawName.isEmpty ? 'mohaffez' : rawName;
    return 'mohafezy_profile_$safeName.png';
  }

  Future<void> _exportProfileAsImage() async {
    if (_isExportingProfile) return;
    setState(() => _isExportingProfile = true);

    final mediaQuery = MediaQuery.of(context);
    final overlay = Overlay.of(context, rootOverlay: true);
    final messenger = ScaffoldMessenger.of(context);

    OverlayEntry? overlayEntry;
    try {
      final profile = await ref.read(
        mohaffezProfileProvider(widget.mohaffezId).future,
      );
      final plans = await _loadPlansForExport();
      final credentials = await _loadCredentialsForExport();
      final availability = await _loadAvailabilityForExport();
      final stats = await _loadStatsForExport();
      if (!mounted) return;

      await _precacheExportImages(profile, credentials);
      if (!mounted) return;

      final screenWidth = mediaQuery.size.width;
      final exportWidth = screenWidth < 360
          ? 360.0
          : screenWidth > 430
              ? 430.0
              : screenWidth;

      overlayEntry = OverlayEntry(
        builder: (context) => IgnorePointer(
          child: Material(
            type: MaterialType.transparency,
            child: Align(
              alignment: Alignment.topCenter,
              child: OverflowBox(
                minWidth: exportWidth,
                maxWidth: exportWidth,
                minHeight: 0,
                maxHeight: double.infinity,
                alignment: Alignment.topCenter,
                child: Opacity(
                  opacity: 0.01,
                  child: SizedBox(
                    width: exportWidth,
                    child: RepaintBoundary(
                      key: _profileExportKey,
                      child: Directionality(
                        textDirection: ui.TextDirection.rtl,
                        child: _TeacherProfileExportCard(
                          profile: profile,
                          plans: plans,
                          credentials: credentials,
                          availability: availability,
                          stats: stats,
                          videoUrl: _teacherVideoUrl(profile),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      overlay.insert(overlayEntry);
      await WidgetsBinding.instance.endOfFrame;
      await Future<void>.delayed(const Duration(milliseconds: 700));
      await WidgetsBinding.instance.endOfFrame;

      final boundary = _profileExportKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        throw StateError('Profile export view was not ready');
      }

      final devicePixelRatio = mediaQuery.devicePixelRatio;
      final pixelRatio = devicePixelRatio < 2
          ? 2.0
          : devicePixelRatio > 3
              ? 3.0
              : devicePixelRatio;
      final image = await boundary.toImage(pixelRatio: pixelRatio);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final Uint8List? bytes = byteData?.buffer.asUint8List();
      if (bytes == null || bytes.isEmpty) {
        throw StateError('Profile export image was empty');
      }

      await shareExportedProfileImage(
        bytes,
        fileName: _exportFileName(profile),
        text: _teacherProfileShareText(profile),
      );

      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('تم تجهيز صورة الملف الشخصي'),
          backgroundColor: AppThemeConstants.success,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('تعذر تصدير الملف كصورة. يرجى المحاولة مرة أخرى'),
          backgroundColor: AppThemeConstants.error,
        ),
      );
    } finally {
      overlayEntry?.remove();
      if (mounted) setState(() => _isExportingProfile = false);
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final AsyncValue<PublicMohaffezProfileBundle>? publicBundleAsync =
        _isPublicView
            ? ref.watch(publicMohaffezProfileProvider(widget.mohaffezId))
            : null;
    final AsyncValue<Map<String, dynamic>> profileAsync;
    final AsyncValue<List<PricingPlanModel>> plansAsync;
    if (_isPublicView) {
      final bundleAsync = publicBundleAsync!;
      profileAsync = bundleAsync.whenData((bundle) => bundle.profile);
      plansAsync = bundleAsync.whenData((bundle) => bundle.plans);
    } else {
      profileAsync = ref.watch(mohaffezProfileProvider(widget.mohaffezId));
      plansAsync = ref.watch(activePricingPlansProvider(widget.mohaffezId));
    }

    // Reset selection if the currently-selected type loses its plan
    // (e.g. teacher deactivates it mid-session). We don't auto-pick a new
    // type — the student must tap one explicitly. Empty string = "none
    // selected"; the picker tiles render that as no-selection state.
    if (!_isPublicView) {
      ref.listen(activePricingPlansProvider(widget.mohaffezId), (_, next) {
        next.whenData((plans) {
          if (selectedSessionType.isNotEmpty &&
              !_hasPlanForType(plans, selectedSessionType) &&
              mounted) {
            setState(() {
              selectedSessionType = '';
              selectedPricingPlan = null;
              selectedTimeSlot = null;
              selectedDate = null;
              selectedDayOfWeek = null;
            });
            ref.read(bookingFlowProvider.notifier).clearSelectedPlan();
          } else if (selectedPricingPlan != null &&
              !plans.any((plan) =>
                  plan.isActive && plan.id == selectedPricingPlan!.id) &&
              mounted) {
            setState(() {
              selectedPricingPlan = null;
              selectedTimeSlot = null;
              selectedDate = null;
              selectedDayOfWeek = null;
            });
            ref.read(bookingFlowProvider.notifier).clearSelectedPlan();
          }
        });
      });
    }

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppThemeConstants.background,
        body: profileAsync.when(
          data: (profile) {
            final videoUrl = _teacherVideoUrl(profile);
            final publicBundle = publicBundleAsync?.valueOrNull;
            return RefreshIndicator(
              onRefresh: () async {
                if (_isPublicView) {
                  ref.invalidate(
                    publicMohaffezProfileProvider(widget.mohaffezId),
                  );
                  await ref
                      .read(
                        publicMohaffezProfileProvider(widget.mohaffezId).future,
                      )
                      .catchError(
                        (_) => throw Exception('public profile reload failed'),
                      );
                  return;
                }
                ref.invalidate(mohaffezProfileProvider(widget.mohaffezId));
                ref.invalidate(activePricingPlansProvider(widget.mohaffezId));
                ref.invalidate(credentialsProvider(widget.mohaffezId));
                ref.invalidate(availabilityProvider(widget.mohaffezId));
                await ref
                    .read(mohaffezProfileProvider(widget.mohaffezId).future)
                    .catchError((_) => <String, dynamic>{});
              },
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  _buildAppBar(context, profile),
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),
                        if (widget.previewMode && !_isPublicView) ...[
                          _buildOwnerPreviewPanel(profile),
                          const SizedBox(height: 16),
                        ],
                        _buildCompactTrustStrip(
                          ref,
                          profile,
                          publicBundle: publicBundle,
                        ),
                        if (videoUrl != null) ...[
                          const SizedBox(height: 20),
                          _buildPremiumVideoSection(videoUrl),
                        ],
                        if (profile['bio'] != null &&
                            (profile['bio'] as String).trim().isNotEmpty) ...[
                          const SizedBox(height: 20),
                          _buildModernBioSection(profile['bio'] as String),
                        ],
                        const SizedBox(height: 20),
                        _buildCredentialsSection(
                          ref,
                          publicCredentials: publicBundle?.credentials,
                        ),
                        if (!_isPublicView &&
                            profile['trialSessionEnabled'] == true) ...[
                          const SizedBox(height: 20),
                          _buildTrialSessionSection(profile, plansAsync),
                        ],
                        const SizedBox(height: 20),
                        _buildModernSessionSelector(plansAsync),
                        const SizedBox(height: 20),
                        KeyedSubtree(
                          key: _pricingStepKey,
                          child: _buildModernPricingSection(plansAsync),
                        ),
                        const SizedBox(height: 20),
                        KeyedSubtree(
                          key: _scheduleStepKey,
                          child: _buildModernAvailabilitySection(
                            ref,
                            profile,
                            plansAsync,
                            publicAvailability: publicBundle?.availability,
                          ),
                        ),
                        const SizedBox(height: 120),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline,
                    size: 64, color: AppThemeConstants.error),
                const SizedBox(height: 16),
                const Text(
                  'تعذر تحميل البيانات',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'يرجى التحقق من الاتصال بالإنترنت والمحاولة مرة أخرى',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppThemeConstants.grey500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                TextButton.icon(
                  onPressed: () {
                    ref.invalidate(mohaffezProfileProvider(widget.mohaffezId));
                    ref.invalidate(
                        activePricingPlansProvider(widget.mohaffezId));
                    ref.invalidate(credentialsProvider(widget.mohaffezId));
                    ref.invalidate(availabilityProvider(widget.mohaffezId));
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('إعادة المحاولة'),
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: _isPublicView
            ? _buildPublicBottomBar()
            : widget.previewMode
                ? _buildPreviewBottomBar()
                : selectedTimeSlot != null && selectedDate != null
                    ? SafeArea(
                        child: Container(
                          margin: const EdgeInsets.all(16),
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.12),
                                blurRadius: 30,
                                offset: const Offset(0, 10),
                              )
                            ],
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      selectedDate != null
                                          ? DateFormat(
                                              'EEEE، d MMM',
                                              'ar',
                                            ).format(selectedDate!)
                                          : '',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      formatTimeToArabicAmPm(
                                        selectedTimeSlot!['startTime'],
                                      ),
                                      style: const TextStyle(
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ElevatedButton(
                                onPressed: _navigateToBookingMethod,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1D9E75),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 28,
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                                child: const Text(
                                  'تأكيد الحجز',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : null,
      ),
    );
  }

  Uri _teacherPublicProfileUri() {
    return Uri.https(
      'app.mohafezy.com',
      '/p/t/${widget.mohaffezId}',
    );
  }

  String _teacherProfileShareText(Map<String, dynamic> profile) {
    final name = _teacherNameFromProfile(profile);
    final specialization =
        ((profile['specialization'] as String?) ?? 'تعليم القرآن').trim();
    return 'تعرف على $name على تطبيق محفظي - $specialization\n${_teacherPublicProfileUri()}';
  }

  Widget _buildOwnerPreviewPanel(Map<String, dynamic> profile) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7E2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: const Color(0xFFE8A020).withValues(alpha: 0.45),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.visibility_outlined,
                  color: Color(0xFF9A6500),
                ),
                SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'معاينة ملفك كما يراه الطالب',
                    style: TextStyle(
                      color: Color(0xFF684600),
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            const Text(
              'راجع المعلومات والصور والأسعار والمواعيد، ثم استخدم الاختصارات لتحسين أي جزء.',
              style: TextStyle(
                color: Color(0xFF765B22),
                height: 1.5,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 13),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _previewEditChip(
                  icon: Icons.edit_outlined,
                  label: 'البيانات والفيديو',
                  route: '/profile',
                ),
                _previewEditChip(
                  icon: Icons.workspace_premium_outlined,
                  label: 'الشهادات',
                  route: '/credentials',
                ),
                _previewEditChip(
                  icon: Icons.sell_outlined,
                  label: 'الأسعار',
                  route: '/pricing-management',
                ),
                _previewEditChip(
                  icon: Icons.calendar_month_outlined,
                  label: 'المواعيد',
                  route: '/availability',
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isExportingProfile ? null : _exportProfileAsImage,
                icon: _isExportingProfile
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.image_outlined),
                label: Text(
                  _isExportingProfile
                      ? 'جاري تجهيز الصورة...'
                      : 'تصدير الملف كصورة',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppThemeConstants.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      AppThemeConstants.primary.withValues(alpha: 0.55),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _copyPublicProfileLink,
                icon: const Icon(Icons.link_rounded),
                label: const Text('نسخ رابط الملف العام'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppThemeConstants.primary,
                  side: BorderSide(
                    color: AppThemeConstants.primary.withValues(alpha: 0.35),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _copyPublicProfileLink() async {
    await Clipboard.setData(
      ClipboardData(text: _teacherPublicProfileUri().toString()),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم نسخ رابط الملف العام')),
    );
  }

  Widget _previewEditChip({
    required IconData icon,
    required String label,
    required String route,
  }) {
    return ActionChip(
      onPressed: () => context.push(route),
      avatar: Icon(icon, size: 18, color: AppThemeConstants.primary),
      label: Text(label),
      backgroundColor: Colors.white,
      side: BorderSide(
        color: AppThemeConstants.primary.withValues(alpha: 0.22),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      labelStyle: const TextStyle(
        color: AppThemeConstants.primary,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _buildPreviewBottomBar() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(
            top: BorderSide(color: AppThemeConstants.grey200),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => context.push('/credentials'),
                icon: const Icon(Icons.workspace_premium_outlined),
                label: const Text('الشهادات'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => context.push('/profile'),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('تعديل الملف'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppThemeConstants.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPublicBottomBar() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(
            top: BorderSide(color: AppThemeConstants.grey200),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => context.go('/login'),
                icon: const Icon(Icons.login_rounded),
                label: const Text('تسجيل الدخول'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => context.go('/register'),
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: const Text('إنشاء حساب للحجز'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppThemeConstants.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrialSessionSection(
    Map<String, dynamic> profile,
    AsyncValue<List<PricingPlanModel>> plansAsync,
  ) {
    final student = ref.watch(currentUserProvider).valueOrNull;
    if (student == null || !isLearnerAccountRole(student.role)) {
      return const SizedBox.shrink();
    }
    final activeProfile = ref.watch(activeStudentProfileProvider).valueOrNull;

    final duration =
        (profile['trialSessionDurationMinutes'] as num?)?.toInt() ?? 30;
    final pair = TrialSessionPair(
      mohaffezId: widget.mohaffezId,
      studentId: student.uid,
      studentProfileId: activeProfile?.id,
    );
    final existingRequest = ref.watch(trialRequestForPairProvider(pair));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppThemeConstants.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: AppThemeConstants.secondary.withValues(alpha: 0.35),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.science_outlined,
                    color: AppThemeConstants.secondary),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'حلقة تجريبية مجانية',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'حدد الأوقات المناسبة لك اليوم أو غدًا أو بعد غد، ثم يقترح '
              'المحفظ موعدًا مدته $duration دقيقة لتأكيده.',
              style: const TextStyle(
                color: AppThemeConstants.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 14),
            existingRequest.when(
              loading: () => const Center(
                child: CircularProgressIndicator(),
              ),
              error: (_, __) => const Text('تعذر تحميل حالة الطلب'),
              data: (request) {
                if (request != null) {
                  return SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => context.push('/trial-requests'),
                      icon: const Icon(Icons.assignment_outlined),
                      label: Text(_trialRequestButtonLabel(
                        request['status'] as String? ?? '',
                      )),
                    ),
                  );
                }

                return SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _requestTrialSession(
                      plansAsync.valueOrNull ?? const [],
                      duration,
                    ),
                    icon: const Icon(Icons.science_outlined),
                    label: const Text('طلب حلقة تجريبية'),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _requestTrialSession(
    List<PricingPlanModel> plans,
    int duration,
  ) async {
    if (guardWriteInTour(ref, context)) return;
    final supportedTypes = plans
        .map((plan) => plan.mode?.name)
        .whereType<String>()
        .toSet()
        .toList();
    if (supportedTypes.isEmpty) supportedTypes.add('online');

    final sent = await RequestTrialSessionSheet.show(
      context,
      mohaffezId: widget.mohaffezId,
      durationMinutes: duration,
      supportedSessionTypes: supportedTypes,
    );
    if (sent == true && mounted) {
      final studentId = ref.read(currentUserProvider).valueOrNull?.uid;
      if (studentId != null) {
        final activeProfile =
            ref.read(activeStudentProfileProvider).valueOrNull;
        ref.invalidate(
          trialRequestForPairProvider(
            TrialSessionPair(
              mohaffezId: widget.mohaffezId,
              studentId: studentId,
              studentProfileId: activeProfile?.id,
            ),
          ),
        );
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إرسال طلب الحلقة التجريبية للمحفظ'),
          backgroundColor: AppThemeConstants.success,
        ),
      );
    }
  }

  String _trialRequestButtonLabel(String status) {
    switch (status) {
      case 'pending_teacher':
        return 'الطلب بانتظار المحفظ';
      case 'awaiting_student_confirmation':
        return 'لديك موعد يحتاج التأكيد';
      case 'confirmed':
        return 'تم تأكيد الحلقة التجريبية';
      default:
        return 'عرض طلب الحلقة التجريبية';
    }
  }

  // ─── Pricing section ──────────────────────────────────────────────────────

  Widget _buildReadOnlyPlanCard(PricingPlanModel plan) {
    final isBundle = plan.type == PlanType.bundle;
    final isSelected = selectedPricingPlan?.id == plan.id;
    final badgeColor = isBundle
        ? AppThemeConstants.accentPurpleDark
        : AppThemeConstants.accentAmberDark;
    final badgeBg = isBundle
        ? AppThemeConstants.accentPurpleLight
        : AppThemeConstants.accentAmberLight;
    return InkWell(
      onTap: () {
        setState(() {
          selectedPricingPlan = plan;
          selectedTimeSlot = null;
          selectedDate = null;
          selectedDayOfWeek = null;
        });
        ref.read(bookingFlowProvider.notifier).selectPlan(
              planId: plan.id ?? '',
              title: plan.title,
              price: plan.priceEGP,
              sessions: plan.sessionsCount,
              validityDays: plan.validityDays,
            );
        _revealStep(_scheduleStepKey);
      },
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppThemeConstants.primary.withValues(alpha: 0.06)
              : AppThemeConstants.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppThemeConstants.primary
                : AppThemeConstants.grey200,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppThemeConstants.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(
                isSelected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: isSelected
                    ? AppThemeConstants.primary
                    : AppThemeConstants.grey500,
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: badgeBg, borderRadius: BorderRadius.circular(20)),
                child: Text(isBundle ? 'باقة' : 'جلسة واحدة',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: badgeColor)),
              ),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(plan.title,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold))),
              Text(PricingCountryUtils.displayPriceText(plan),
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppThemeConstants.success)),
            ]),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 6, children: [
              _profileChip('${plan.sessionsCount} جلسة', Icons.event_available),
              _profileChip(plan.countryName, Icons.public),
              if (plan.sessionDurationMinutes != null)
                _profileChip('${plan.sessionDurationMinutes} دقيقة',
                    Icons.timer_outlined),
              if (plan.validityDays != null && plan.validityDays! > 0)
                _profileChip('${plan.validityDays} يوم', Icons.schedule),
              if (isBundle)
                _profileChip(
                  '${(PricingCountryUtils.displayAmount(plan) / plan.sessionsCount).toStringAsFixed(0)} ${plan.currencyLabel}/جلسة',
                  Icons.payments_outlined,
                ),
            ]),
            if (plan.description != null && plan.description!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(plan.description!,
                  style: const TextStyle(
                      fontSize: 12, color: AppThemeConstants.grey600)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _profileChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppThemeConstants.secondary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: AppThemeConstants.secondary.withValues(alpha: 0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: AppThemeConstants.secondary),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppThemeConstants.secondary.withValues(alpha: 0.9))),
      ]),
    );
  }

  Widget _buildModernPricingSection(
      AsyncValue<List<PricingPlanModel>> plansAsync) {
    return plansAsync.when(
      data: (plans) {
        if (plans.isEmpty) return const SizedBox.shrink();

        final relevantPlans = _relevantPlans(plans);

        if (selectedSessionType.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppThemeConstants.primary.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppThemeConstants.primary.withValues(alpha: 0.24),
                ),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.touch_app_outlined,
                    color: AppThemeConstants.primary,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'اختر نوع الجلسة لعرض الأسعار والمواعيد المناسبة.',
                      style: TextStyle(
                        color: AppThemeConstants.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        if (relevantPlans.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppThemeConstants.primary.withValues(alpha: 0.08),
                borderRadius: AppThemeConstants.borderRadiusMd,
                border: Border.all(
                    color: AppThemeConstants.primary.withValues(alpha: 0.4)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      color: AppThemeConstants.primary),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'لا توجد خطط تسعير متاحة لهذا النوع من الجلسات',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppThemeConstants.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: _BookingStepTitle(
                number: 2,
                title: 'اختر الباقة المناسبة',
                subtitle: 'حدد جلسة واحدة أو إحدى الباقات المتاحة',
              ),
            ),
            const SizedBox(height: 12),
            ...relevantPlans.map((plan) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildReadOnlyPlanCard(plan),
                )),
          ],
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'خطط التسعير المتاحة',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: SkeletonList(itemCount: 3, itemHeight: 70),
            ),
          ],
        ),
      ),
      error: (_, __) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppThemeConstants.errorLight,
            borderRadius: AppThemeConstants.borderRadiusMd,
            border: Border.all(color: AppThemeConstants.accentRed),
          ),
          child: const Row(
            children: [
              Icon(Icons.error_outline,
                  color: AppThemeConstants.error, size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'تعذر تحميل خطط التسعير',
                  style:
                      TextStyle(fontSize: 14, color: AppThemeConstants.error),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroBadge(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Compact Trust Strip ───────────────────────────────────────────────────

  Widget _buildCompactTrustStrip(
    WidgetRef ref,
    Map<String, dynamic> profile, {
    PublicMohaffezProfileBundle? publicBundle,
  }) {
    final rating = profile['rating'] as num? ?? 0.0;
    final reviewCount = (profile['reviewCount'] as num?)?.toInt() ?? 0;
    final stats = publicBundle == null
        ? ref.watch(mohaffezStatsProvider(widget.mohaffezId))
        : null;
    final credentials = publicBundle == null
        ? ref.watch(credentialsProvider(widget.mohaffezId))
        : null;
    final completedSessions = publicBundle != null
        ? (publicBundle.stats['completedSessions'] as num?)?.toInt() ?? 0
        : stats?.valueOrNull?['completedSessions'] as int? ?? 0;
    final uniqueStudents = publicBundle != null
        ? (publicBundle.stats['uniqueStudents'] as num?)?.toInt() ?? 0
        : stats?.valueOrNull?['uniqueStudents'] as int? ?? 0;
    final approvedCredentials = publicBundle?.credentials.length ??
        credentials?.valueOrNull?.length ??
        0;
    final statsAreLoading = publicBundle == null &&
        (stats?.isLoading ?? false) &&
        !(stats?.hasValue ?? false);
    final credentialsAreLoading = publicBundle == null &&
        (credentials?.isLoading ?? false) &&
        !(credentials?.hasValue ?? false);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 18,
              offset: const Offset(0, 6),
            )
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _miniTrust(
              Icons.star_rounded,
              reviewCount > 0 ? rating.toStringAsFixed(1) : 'جديد',
              reviewCount > 0 ? '$reviewCount تقييم' : 'التقييم',
            ),
            _miniTrust(
              Icons.people_alt_rounded,
              statsAreLoading ? '—' : '$uniqueStudents',
              'طالب',
            ),
            _miniTrust(
              Icons.task_alt_rounded,
              statsAreLoading ? '—' : '$completedSessions',
              'جلسة مكتملة',
            ),
            _miniTrust(
              Icons.workspace_premium_rounded,
              credentialsAreLoading ? '—' : '$approvedCredentials',
              'شهادة معتمدة',
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniTrust(IconData icon, String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF1D9E75), size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  // ─── AppBar ───────────────────────────────────────────────────────────────

  Widget _buildAppBar(BuildContext context, Map<String, dynamic> profile) {
    final name = _teacherNameFromProfile(profile, fallback: 'المحفّظ');
    final hasFoundingBadge = profile['status'] == 'active' &&
        UserBadges.fromJson(profile['badges']).foundingTeacher.enabled;
    final specialization = (profile['specialization'] as String?)?.trim();
    final rating = (profile['rating'] as num?)?.toDouble() ?? 0;
    final reviewCount = profile['reviewCount'] as int? ?? 0;
    final photoUrl = (profile['photoUrl'] as String?)?.trim();
    final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;

    return SliverAppBar(
      expandedHeight: 248,
      pinned: true,
      automaticallyImplyLeading: false,
      backgroundColor: AppThemeConstants.deepTeal,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppThemeConstants.primary,
                    AppThemeConstants.primaryVariant
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            Positioned(
              top: -40,
              left: -30,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppThemeConstants.white.withValues(alpha: 0.06),
                ),
              ),
            ),
            Positioned(
              bottom: 30,
              right: -20,
              child: Transform.rotate(
                angle: -0.35,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(36),
                    color: AppThemeConstants.secondary.withValues(alpha: 0.10),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 16,
              left: 16,
              bottom: 18,
              child: Container(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: LinearGradient(
                    colors: [
                      AppThemeConstants.white.withValues(alpha: 0.16),
                      AppThemeConstants.white.withValues(alpha: 0.09),
                    ],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                  border: Border.all(
                    color: AppThemeConstants.white.withValues(alpha: 0.18),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppThemeConstants.secondary
                                  .withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              'ملف محفّظ معتمد',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppThemeConstants.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppThemeConstants.white,
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (hasFoundingBadge) ...[
                            const SizedBox(height: 8),
                            const FoundingTeacherBadge(
                              compact: true,
                              showLabel: true,
                              useFullLabel: true,
                              size: 20,
                            ),
                          ],
                          if (specialization != null &&
                              specialization.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              specialization,
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppThemeConstants.white70,
                                height: 1.4,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _buildHeroBadge(
                                Icons.star_rounded,
                                reviewCount > 0
                                    ? rating.toStringAsFixed(1)
                                    : 'جديد',
                              ),
                              _buildHeroBadge(
                                Icons.rate_review_rounded,
                                reviewCount > 0 ? '$reviewCount تقييم' : 'جديد',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    GestureDetector(
                      onTap: hasPhoto
                          ? () => _openTeacherPhotoPreview(photoUrl, name)
                          : null,
                      child: MouseRegion(
                        cursor: hasPhoto
                            ? SystemMouseCursors.click
                            : SystemMouseCursors.basic,
                        child: Semantics(
                          button: hasPhoto,
                          label: hasPhoto ? 'تكبير صورة المحفظ' : null,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width: 96,
                                height: 96,
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppThemeConstants.white
                                        .withValues(alpha: 0.42),
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppThemeConstants.black
                                          .withValues(alpha: 0.20),
                                      blurRadius: 16,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: CircleAvatar(
                                  backgroundColor: AppThemeConstants.white,
                                  child: hasPhoto
                                      ? ClipOval(
                                          child: CachedNetworkImage(
                                            imageUrl: photoUrl,
                                            width: 88,
                                            height: 88,
                                            fit: BoxFit.cover,
                                            errorWidget:
                                                (context, url, error) =>
                                                    const Icon(
                                              Icons.person,
                                              size: 42,
                                            ),
                                          ),
                                        )
                                      : const Icon(
                                          Icons.person_rounded,
                                          size: 42,
                                          color: AppThemeConstants.primary,
                                        ),
                                ),
                              ),
                              if (hasPhoto)
                                Positioned(
                                  left: -2,
                                  bottom: -2,
                                  child: Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: AppThemeConstants.secondary,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: AppThemeConstants.white,
                                        width: 2,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.zoom_out_map_rounded,
                                      size: 14,
                                      color: AppThemeConstants.white,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Modern Bio Section ───────────────────────────────────────────────────

  Widget _buildModernBioSection(String bio) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, 6),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'نبذة عن المحفظ',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              bio,
              style: const TextStyle(
                fontSize: 14,
                height: 1.6,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Credentials Gallery ──────────────────────────────────────────────────

  Widget _buildCredentialsSection(
    WidgetRef ref, {
    List<Map<String, dynamic>>? publicCredentials,
  }) {
    final credsAsync = publicCredentials != null
        ? AsyncValue<List<Map<String, dynamic>>>.data(publicCredentials)
        : ref.watch(credentialsProvider(widget.mohaffezId));

    return credsAsync.when(
      data: (creds) {
        if (creds.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7E2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.workspace_premium_rounded,
                        color: Color(0xFFE8A020),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'الإجازات والشهادات',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'وثائق راجعتها واعتمدتها إدارة المنصة',
                            style: TextStyle(
                              color: AppThemeConstants.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color:
                            AppThemeConstants.success.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${creds.length}',
                        style: const TextStyle(
                          color: AppThemeConstants.success,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 254,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: creds.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) =>
                        _buildCredentialCard(creds[index]),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: SizedBox(
          height: 120,
          child: SkeletonCard(),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildCredentialCard(Map<String, dynamic> credential) {
    final title = (credential['title'] as String?)?.trim();
    final organization = (credential['organization'] as String?)?.trim();
    final type = credential['type'] as String? ?? 'ijazah';
    final imageUrls = List<String>.from(
      credential['imageUrls'] as List? ?? const [],
    ).where((url) => url.trim().isNotEmpty).toList();
    final issueDate = _credentialDate(credential['issueDate']);

    return SizedBox(
      width: 224,
      child: Material(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: imageUrls.isEmpty
              ? null
              : () => _openCredentialGallery(
                    imageUrls,
                    title ?? 'شهادة معتمدة',
                  ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: double.infinity,
                height: 132,
                child: imageUrls.isEmpty
                    ? Container(
                        color: const Color(0xFFFFF7E2),
                        child: const Icon(
                          Icons.workspace_premium_rounded,
                          size: 54,
                          color: Color(0xFFE8A020),
                        ),
                      )
                    : Stack(
                        fit: StackFit.expand,
                        children: [
                          CachedNetworkImage(
                            imageUrl: imageUrls.first,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            errorWidget: (_, __, ___) => const ColoredBox(
                              color: Color(0xFFFFF7E2),
                              child: Icon(
                                Icons.broken_image_outlined,
                                color: Color(0xFFE8A020),
                              ),
                            ),
                          ),
                          Positioned(
                            left: 8,
                            bottom: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.68),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.photo_library_outlined,
                                    size: 13,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${imageUrls.length}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title?.isNotEmpty == true ? title! : 'شهادة معتمدة',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        organization?.isNotEmpty == true
                            ? organization!
                            : _credentialTypeLabel(type),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppThemeConstants.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          const Icon(
                            Icons.verified_rounded,
                            size: 16,
                            color: AppThemeConstants.success,
                          ),
                          const SizedBox(width: 5),
                          const Text(
                            'معتمدة',
                            style: TextStyle(
                              color: AppThemeConstants.success,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (issueDate != null) ...[
                            const Spacer(),
                            Text(
                              DateFormat('yyyy/MM').format(issueDate),
                              style: const TextStyle(
                                color: AppThemeConstants.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  DateTime? _credentialDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    try {
      return value.toDate() as DateTime;
    } catch (_) {
      return null;
    }
  }

  String _credentialTypeLabel(String type) {
    return switch (type) {
      'education' => 'مؤهل تعليمي',
      'license' => 'ترخيص',
      'award' => 'جائزة',
      _ => 'إجازة',
    };
  }

  void _openCredentialGallery(List<String> imageUrls, String title) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.90),
      builder: (_) => _CredentialGalleryDialog(
        imageUrls: imageUrls,
        title: title,
      ),
    );
  }

  // ─── Premium Video Section ────────────────────────────────────────────────

  Widget _buildPremiumVideoSection(String url) {
    final youtubeId = _youtubeVideoId(url);
    final thumbnailUrl = youtubeId == null
        ? null
        : 'https://img.youtube.com/vi/$youtubeId/hqdefault.jpg';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF073F37),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1D9E75).withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _openTeacherVideo(url),
            child: SizedBox(
              height: 210,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (thumbnailUrl != null)
                    CachedNetworkImage(
                      imageUrl: thumbnailUrl,
                      fit: BoxFit.cover,
                      color: Colors.black.withValues(alpha: 0.30),
                      colorBlendMode: BlendMode.darken,
                      errorWidget: (_, __, ___) =>
                          const ColoredBox(color: Color(0xFF073F37)),
                    ),
                  if (thumbnailUrl == null)
                    const ColoredBox(color: Color(0xFF073F37)),
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          Color(0xE6073F37),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  Center(
                    child: Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.22),
                            blurRadius: 18,
                            offset: const Offset(0, 7),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        size: 38,
                        color: Color(0xFF0A806F),
                      ),
                    ),
                  ),
                  const Positioned(
                    right: 18,
                    left: 18,
                    bottom: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'الفيديو التعريفي',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'شاهد المحفّظ وتعرّف على أسلوبه قبل الحجز',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Session type selector ────────────────────────────────────────────────

  bool _hasPlanForType(List<PricingPlanModel> plans, String type) {
    return plans.any((p) {
      if (type == 'home') return p.mode == SessionMode.home;
      if (type == 'mosque') return p.mode == SessionMode.mosque;
      if (type == 'online') return p.mode == SessionMode.online;
      return false;
    });
  }

  Widget _buildModernSessionSelector(
    AsyncValue<List<PricingPlanModel>> plansAsync,
  ) {
    final plans = plansAsync.valueOrNull ?? [];

    Widget item({
      required String type,
      required String title,
      required IconData icon,
    }) {
      final hasPlan = _hasPlanForType(plans, type);
      final selected = selectedSessionType == type;

      return Expanded(
        child: GestureDetector(
          onTap: hasPlan
              ? () {
                  final hadSelectedSlot = selectedTimeSlot != null;
                  setState(() {
                    selectedSessionType = type;
                    selectedPricingPlan = null;
                    selectedTimeSlot = null;
                    selectedDate = null;
                    selectedDayOfWeek = null;
                  });
                  ref.read(bookingFlowProvider.notifier).clearSelectedPlan();
                  _revealStep(_pricingStepKey);
                  if (hadSelectedSlot && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('تم مسح الموعد المختار'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                }
              : () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content:
                          Text('لم يحدد المحفظ خطة سعر لهذا النوع من الجلسات'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: hasPlan && selected
                  ? const LinearGradient(
                      colors: [
                        Color(0xFF1D9E75),
                        Color(0xFF085041),
                      ],
                    )
                  : null,
              color: hasPlan && selected ? null : Colors.white,
              border: Border.all(
                color: hasPlan
                    ? (selected ? Colors.transparent : const Color(0xFFE5E7EB))
                    : Colors.grey.withValues(alpha: 0.3),
              ),
              boxShadow: hasPlan && selected
                  ? [
                      BoxShadow(
                        color: const Color(0xFF1D9E75).withValues(alpha: 0.24),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      )
                    ]
                  : [],
            ),
            child: Column(
              children: [
                Icon(
                  hasPlan ? icon : Icons.lock_outline_rounded,
                  color: hasPlan && selected
                      ? Colors.white
                      : (hasPlan ? const Color(0xFF1D9E75) : Colors.grey),
                  size: 26,
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  style: TextStyle(
                    color: hasPlan && selected ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _BookingStepTitle(
            number: 1,
            title: 'اختر نوع الجلسة',
            subtitle: 'أونلاين أو في المسجد أو زيارة منزلية',
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              item(
                type: 'online',
                title: 'أونلاين',
                icon: Icons.videocam_rounded,
              ),
              item(
                type: 'mosque',
                title: 'في المسجد',
                icon: Icons.mosque_rounded,
              ),
              item(
                type: 'home',
                title: 'زيارة منزلية',
                icon: Icons.home_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Modern Availability/Booking Section ───────────────────────────────────

  Widget _buildModernAvailabilitySection(
    WidgetRef ref,
    Map<String, dynamic> profile,
    AsyncValue<List<PricingPlanModel>> plansAsync, {
    List<Map<String, dynamic>>? publicAvailability,
  }) {
    if (selectedSessionType.isEmpty || selectedPricingPlan == null) {
      return const SizedBox.shrink();
    }

    final availability = publicAvailability != null
        ? AsyncValue<List<Map<String, dynamic>>>.data(publicAvailability)
        : ref.watch(
            availabilityProvider(widget.mohaffezId),
          );

    return availability.when(
      data: (slots) {
        if (slots.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  )
                ],
              ),
              child: const Row(
                children: [
                  Icon(Icons.calendar_today_rounded,
                      color: Colors.grey, size: 32),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'لا توجد أوقات متاحة',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // Pre-filter all slots to check if any exist for selected session type
        final hasAnyFilteredSlots = slots.any((slot) {
          final timeSlots =
              List<Map<String, dynamic>>.from(slot['timeSlots'] ?? []);
          return timeSlots.any((ts) =>
              ts['enabled'] == true &&
              ts['sessionType'] == selectedSessionType);
        });

        if (!hasAnyFilteredSlots) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  )
                ],
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      color: Colors.orange, size: 32),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'لا توجد أوقات متاحة لهذا النوع من الجلسات',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.orange,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _BookingStepTitle(
                  number: 3,
                  title: 'اختر الموعد',
                  subtitle: 'حدد اليوم والوقت المناسب لك',
                ),
                const SizedBox(height: 20),

                // Compact horizontal date strip + time slots
                ...(() {
                  const arabicDays = [
                    'الإثنين',
                    'الثلاثاء',
                    'الأربعاء',
                    'الخميس',
                    'الجمعة',
                    'السبت',
                    'الأحد',
                  ];

                  final now = serverNow(ref);
                  final today = DateTime(now.year, now.month, now.day);
                  final currentDayOfWeek = today.weekday;

                  final sortedSlots = [...slots]..sort((a, b) {
                      int dA =
                          ((a['dayOfWeek'] as int) - currentDayOfWeek + 7) % 7;
                      int dB =
                          ((b['dayOfWeek'] as int) - currentDayOfWeek + 7) % 7;
                      return dA.compareTo(dB);
                    });

                  // Build (date, enabledSlots) for each available day
                  final availableDays =
                      <({DateTime date, List<Map<String, dynamic>> slots})>[];

                  for (final slot in sortedSlots) {
                    final dayOfWeek = slot['dayOfWeek'] as int;
                    final timeSlots = List<Map<String, dynamic>>.from(
                        slot['timeSlots'] ?? []);
                    int daysUntil = dayOfWeek - currentDayOfWeek;
                    if (daysUntil < 0) daysUntil += 7;
                    final targetDate = DateTime(
                        today.year, today.month, today.day + daysUntil);
                    final isToday = daysUntil == 0;

                    final enabled = timeSlots.where((ts) {
                      if (ts['enabled'] != true) return false;
                      if (ts['sessionType'] != selectedSessionType) {
                        return false;
                      }
                      if (isToday) {
                        final parts =
                            (ts['startTime'] as String? ?? '0:0').split(':');
                        final hour =
                            int.tryParse(parts.elementAtOrNull(0) ?? '') ?? 0;
                        final minute =
                            int.tryParse(parts.elementAtOrNull(1) ?? '') ?? 0;
                        return DateTime(today.year, today.month, today.day,
                                hour, minute)
                            .isAfter(now);
                      }
                      return true;
                    }).toList();

                    if (enabled.isNotEmpty) {
                      availableDays.add((date: targetDate, slots: enabled));
                    }
                  }

                  if (availableDays.isEmpty) return <Widget>[];

                  // Which day is currently highlighted in the strip
                  final effectiveDate = (selectedDate != null &&
                          availableDays.any((d) =>
                              d.date.day == selectedDate!.day &&
                              d.date.month == selectedDate!.month))
                      ? selectedDate!
                      : availableDays.first.date;

                  final activeSlots = availableDays
                      .firstWhere(
                        (d) =>
                            d.date.day == effectiveDate.day &&
                            d.date.month == effectiveDate.month,
                        orElse: () => availableDays.first,
                      )
                      .slots;

                  String dayChipLabel(DateTime date) {
                    final diff = date.difference(today).inDays;
                    if (diff == 0) return 'اليوم';
                    if (diff == 1) return 'غداً';
                    return arabicDays[date.weekday - 1];
                  }

                  return [
                    // ── Horizontal date strip ──
                    SizedBox(
                      height: 72,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: EdgeInsets.zero,
                        itemCount: availableDays.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (_, i) {
                          final day = availableDays[i];
                          final isSelected =
                              day.date.day == effectiveDate.day &&
                                  day.date.month == effectiveDate.month;
                          return GestureDetector(
                            onTap: () => setState(() {
                              selectedDate = day.date;
                              selectedTimeSlot = null;
                            }),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 18, vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppThemeConstants.primary
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected
                                      ? Colors.transparent
                                      : const Color(0xFFE5E7EB),
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: AppThemeConstants.primary
                                              .withValues(alpha: 0.25),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        )
                                      ]
                                    : [],
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    dayChipLabel(day.date),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: isSelected
                                          ? Colors.white
                                          : Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    DateFormat('dd/MM', 'ar').format(day.date),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isSelected
                                          ? Colors.white.withValues(alpha: 0.75)
                                          : Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Time slots for the selected day ──
                    GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 3,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: activeSlots.map((ts) {
                        final startTime = ts['startTime'] as String?;
                        final endTime = ts['endTime'] as String?;
                        final timeText =
                            formatTimeToArabicAmPm('$startTime - $endTime');
                        final isSelected = selectedTimeSlot != null &&
                            selectedTimeSlot!['startTime'] == startTime &&
                            selectedTimeSlot!['endTime'] == endTime &&
                            selectedDate?.day == effectiveDate.day &&
                            selectedDate?.month == effectiveDate.month;

                        return GestureDetector(
                          onTap: () => setState(() {
                            selectedTimeSlot = {
                              'startTime': startTime,
                              'endTime': endTime,
                            };
                            selectedDate = effectiveDate;
                          }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppThemeConstants.primary
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected
                                    ? Colors.transparent
                                    : const Color(0xFFE5E7EB),
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: AppThemeConstants.primary
                                            .withValues(alpha: 0.25),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      )
                                    ]
                                  : [],
                            ),
                            child: Center(
                              child: Text(
                                timeText,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.black87,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ];
                }()),
              ],
            ),
          ),
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _BookingStepTitle extends StatelessWidget {
  const _BookingStepTitle({
    required this.number,
    required this.title,
    required this.subtitle,
  });

  final int number;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppThemeConstants.primary,
            shape: BoxShape.circle,
          ),
          child: Text(
            '$number',
            style: const TextStyle(
              color: AppThemeConstants.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppThemeConstants.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TeacherProfileExportCard extends StatelessWidget {
  const _TeacherProfileExportCard({
    required this.profile,
    required this.plans,
    required this.credentials,
    required this.availability,
    required this.stats,
    required this.videoUrl,
  });

  final Map<String, dynamic> profile;
  final List<PricingPlanModel> plans;
  final List<Map<String, dynamic>> credentials;
  final List<Map<String, dynamic>> availability;
  final Map<String, dynamic> stats;
  final String? videoUrl;

  @override
  Widget build(BuildContext context) {
    final name = _teacherNameFromProfile(profile);
    final specialization = _string(profile['specialization'], 'معلم قرآن');
    final bio = _string(profile['bio'], '');
    final rating = (profile['rating'] as num?)?.toDouble() ?? 0;
    final reviewCount = (profile['reviewCount'] as num?)?.toInt() ?? 0;
    final completedSessions =
        (stats['completedSessions'] as num?)?.toInt() ?? 0;
    final uniqueStudents = (stats['uniqueStudents'] as num?)?.toInt() ?? 0;
    final hasFoundingBadge = profile['status'] == 'active' &&
        UserBadges.fromJson(profile['badges']).foundingTeacher.enabled;
    final activePlans = plans.where((plan) => plan.isActive).toList();
    final availableSlots = _availableSlotSummaries(availability);

    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        color: AppThemeConstants.background,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ExportHero(
              name: name,
              specialization: specialization,
              photoUrl: _string(profile['photoUrl'], ''),
              hasFoundingBadge: hasFoundingBadge,
              rating: reviewCount > 0 ? rating.toStringAsFixed(1) : 'جديد',
              reviewCount: reviewCount,
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _ExportStat(
                    icon: Icons.star_rounded,
                    value: reviewCount > 0 ? rating.toStringAsFixed(1) : 'جديد',
                    label: 'التقييم',
                  ),
                  _ExportStat(
                    icon: Icons.people_alt_rounded,
                    value: '$uniqueStudents',
                    label: 'طالب',
                  ),
                  _ExportStat(
                    icon: Icons.task_alt_rounded,
                    value: '$completedSessions',
                    label: 'جلسة',
                  ),
                  _ExportStat(
                    icon: Icons.workspace_premium_rounded,
                    value: '${credentials.length}',
                    label: 'شهادة',
                  ),
                ],
              ),
            ),
            if (videoUrl != null && videoUrl!.trim().isNotEmpty) ...[
              const SizedBox(height: 14),
              _ExportSection(
                title: 'الفيديو التعريفي',
                icon: Icons.play_circle_outline_rounded,
                child: _ExportVideoPreview(url: videoUrl!),
              ),
            ],
            if (bio.isNotEmpty) ...[
              const SizedBox(height: 14),
              _ExportSection(
                title: 'نبذة عن المحفظ',
                icon: Icons.info_outline_rounded,
                child: Text(
                  bio,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.55,
                    color: AppThemeConstants.textPrimary,
                  ),
                ),
              ),
            ],
            if (credentials.isNotEmpty) ...[
              const SizedBox(height: 14),
              _ExportSection(
                title: 'الإجازات والشهادات',
                icon: Icons.workspace_premium_rounded,
                child: Column(
                  children: credentials
                      .map((credential) => _ExportCredentialRow(
                            credential: credential,
                          ))
                      .toList(),
                ),
              ),
            ],
            if (activePlans.isNotEmpty) ...[
              const SizedBox(height: 14),
              _ExportSection(
                title: 'الجلسات والأسعار',
                icon: Icons.sell_outlined,
                child: Column(
                  children: activePlans
                      .map((plan) => _ExportPlanRow(plan: plan))
                      .toList(),
                ),
              ),
            ],
            if (availableSlots.isNotEmpty) ...[
              const SizedBox(height: 14),
              _ExportSection(
                title: 'مواعيد متاحة',
                icon: Icons.calendar_month_outlined,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: availableSlots
                      .take(8)
                      .map((slot) => _ExportChip(
                            icon: Icons.schedule_rounded,
                            label: slot,
                          ))
                      .toList(),
                ),
              ),
            ],
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppThemeConstants.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'محفظي | mohafezy.com',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppThemeConstants.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _string(Object? value, String fallback) {
    if (value is! String) return fallback;
    final trimmed = value.trim();
    return trimmed.isEmpty ? fallback : trimmed;
  }

  static List<String> _availableSlotSummaries(
    List<Map<String, dynamic>> availability,
  ) {
    const dayNames = [
      'الإثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
      'السبت',
      'الأحد',
    ];
    final items = <String>[];
    for (final day in availability) {
      final dayIndex = ((day['dayOfWeek'] as num?)?.toInt() ?? 1) - 1;
      final dayName = dayNames[dayIndex.clamp(0, 6)];
      final slots = List<Map<String, dynamic>>.from(day['timeSlots'] ?? []);
      for (final slot in slots) {
        if (slot['enabled'] != true) continue;
        final start = _string(slot['startTime'], '');
        final end = _string(slot['endTime'], '');
        if (start.isEmpty || end.isEmpty) continue;
        items.add('$dayName ${formatTimeToArabicAmPm('$start - $end')}');
      }
    }
    return items;
  }
}

class _ExportHero extends StatelessWidget {
  const _ExportHero({
    required this.name,
    required this.specialization,
    required this.photoUrl,
    required this.hasFoundingBadge,
    required this.rating,
    required this.reviewCount,
  });

  final String name;
  final String specialization;
  final String photoUrl;
  final bool hasFoundingBadge;
  final String rating;
  final int reviewCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 28, 18, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppThemeConstants.primary,
            AppThemeConstants.primaryVariant,
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -40,
            left: -40,
            child: Container(
              width: 170,
              height: 170,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 92,
                height: 92,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.45),
                    width: 2,
                  ),
                ),
                child: CircleAvatar(
                  backgroundColor: Colors.white,
                  child: photoUrl.isNotEmpty
                      ? ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: photoUrl,
                            width: 84,
                            height: 84,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => const Icon(
                              Icons.person_rounded,
                              size: 42,
                              color: AppThemeConstants.primary,
                            ),
                          ),
                        )
                      : const Icon(
                          Icons.person_rounded,
                          size: 42,
                          color: AppThemeConstants.primary,
                        ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ملف محفظ معتمد',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      specialization,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    if (hasFoundingBadge) ...[
                      const SizedBox(height: 8),
                      const FoundingTeacherBadge(
                        compact: true,
                        showLabel: true,
                        useFullLabel: true,
                        size: 20,
                      ),
                    ],
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _ExportHeroBadge(
                          icon: Icons.star_rounded,
                          label: rating,
                        ),
                        _ExportHeroBadge(
                          icon: Icons.rate_review_rounded,
                          label:
                              reviewCount > 0 ? '$reviewCount تقييم' : 'جديد',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExportHeroBadge extends StatelessWidget {
  const _ExportHeroBadge({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExportStat extends StatelessWidget {
  const _ExportStat({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppThemeConstants.primary, size: 20),
            const SizedBox(height: 6),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                color: AppThemeConstants.textSecondary,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExportSection extends StatelessWidget {
  const _ExportSection({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppThemeConstants.grey200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppThemeConstants.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: AppThemeConstants.primary, size: 19),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _ExportVideoPreview extends StatelessWidget {
  const _ExportVideoPreview({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final youtubeId = _youtubeVideoId(url);
    final thumbnailUrl = youtubeId == null
        ? null
        : 'https://img.youtube.com/vi/$youtubeId/hqdefault.jpg';

    return Container(
      height: 150,
      decoration: BoxDecoration(
        color: const Color(0xFF073F37),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (thumbnailUrl != null)
            CachedNetworkImage(
              imageUrl: thumbnailUrl,
              fit: BoxFit.cover,
              color: Colors.black.withValues(alpha: 0.30),
              colorBlendMode: BlendMode.darken,
              errorWidget: (_, __, ___) =>
                  const ColoredBox(color: Color(0xFF073F37)),
            ),
          const Center(
            child: Icon(
              Icons.play_circle_fill_rounded,
              color: Colors.white,
              size: 56,
            ),
          ),
          const Positioned(
            right: 14,
            left: 14,
            bottom: 12,
            child: Text(
              'شاهد الفيديو التعريفي قبل الحجز',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String? _youtubeVideoId(String value) {
    final trimmed = value.trim();
    if (RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(trimmed)) return trimmed;
    final withScheme =
        trimmed.startsWith('http://') || trimmed.startsWith('https://')
            ? trimmed
            : 'https://$trimmed';
    final uri = Uri.tryParse(withScheme);
    if (uri == null) return null;
    final host = uri.host.toLowerCase().replaceFirst('www.', '');
    if (host == 'youtu.be' && uri.pathSegments.isNotEmpty) {
      return uri.pathSegments.first;
    }
    if (host.endsWith('youtube.com')) {
      final queryId = uri.queryParameters['v'];
      if (queryId != null && queryId.isNotEmpty) return queryId;
      final segments = uri.pathSegments;
      if (segments.length >= 2 &&
          const {'embed', 'shorts', 'live'}.contains(segments.first)) {
        return segments[1];
      }
    }
    return null;
  }
}

class _ExportCredentialRow extends StatelessWidget {
  const _ExportCredentialRow({required this.credential});

  final Map<String, dynamic> credential;

  @override
  Widget build(BuildContext context) {
    final title = _string(credential['title'], 'شهادة معتمدة');
    final organization = _string(credential['organization'], '');
    final imageUrls = List<String>.from(
      credential['imageUrls'] as List? ?? const [],
    ).where((url) => url.trim().isNotEmpty).toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7E2),
              borderRadius: BorderRadius.circular(8),
            ),
            clipBehavior: Clip.antiAlias,
            child: imageUrls.isEmpty
                ? const Icon(
                    Icons.workspace_premium_rounded,
                    color: Color(0xFFE8A020),
                  )
                : CachedNetworkImage(
                    imageUrl: imageUrls.first,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => const Icon(
                      Icons.workspace_premium_rounded,
                      color: Color(0xFFE8A020),
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (organization.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    organization,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppThemeConstants.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Icon(
            Icons.verified_rounded,
            color: AppThemeConstants.success,
            size: 18,
          ),
        ],
      ),
    );
  }

  String _string(Object? value, String fallback) {
    if (value is! String) return fallback;
    final trimmed = value.trim();
    return trimmed.isEmpty ? fallback : trimmed;
  }
}

class _ExportPlanRow extends StatelessWidget {
  const _ExportPlanRow({required this.plan});

  final PricingPlanModel plan;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppThemeConstants.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppThemeConstants.grey200),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppThemeConstants.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _modeIcon(plan.mode),
                color: AppThemeConstants.primary,
                size: 19,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plan.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${_modeLabel(plan.mode)} • ${plan.sessionsCount} جلسة',
                    style: const TextStyle(
                      color: AppThemeConstants.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              PricingCountryUtils.displayPriceText(plan),
              style: const TextStyle(
                color: AppThemeConstants.primary,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _modeIcon(SessionMode? mode) {
    return switch (mode) {
      SessionMode.online => Icons.videocam_rounded,
      SessionMode.mosque => Icons.mosque_rounded,
      SessionMode.home => Icons.home_rounded,
      _ => Icons.menu_book_rounded,
    };
  }

  String _modeLabel(SessionMode? mode) {
    return switch (mode) {
      SessionMode.online => 'أونلاين',
      SessionMode.mosque => 'في المسجد',
      SessionMode.home => 'زيارة منزلية',
      _ => 'جلسة',
    };
  }
}

class _ExportChip extends StatelessWidget {
  const _ExportChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppThemeConstants.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppThemeConstants.primary),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: AppThemeConstants.primary,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _CredentialGalleryDialog extends StatefulWidget {
  const _CredentialGalleryDialog({
    required this.imageUrls,
    required this.title,
  });

  final List<String> imageUrls;
  final String title;

  @override
  State<_CredentialGalleryDialog> createState() =>
      _CredentialGalleryDialogState();
}

class _CredentialGalleryDialogState extends State<_CredentialGalleryDialog> {
  late final PageController _controller;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Dialog.fullscreen(
        backgroundColor: const Color(0xFF071F1B),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      '${_currentIndex + 1} / ${widget.imageUrls.length}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: 'إغلاق',
                      icon: const Icon(Icons.close_rounded),
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: widget.imageUrls.length,
                  onPageChanged: (index) =>
                      setState(() => _currentIndex = index),
                  itemBuilder: (context, index) => InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 4,
                    child: Center(
                      child: CachedNetworkImage(
                        imageUrl: widget.imageUrls[index],
                        fit: BoxFit.contain,
                        placeholder: (_, __) => const Center(
                          child: CircularProgressIndicator(
                            color: Colors.white,
                          ),
                        ),
                        errorWidget: (_, __, ___) => const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.broken_image_outlined,
                              color: Colors.white70,
                              size: 56,
                            ),
                            SizedBox(height: 12),
                            Text(
                              'تعذر تحميل صورة الشهادة',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
