import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mohaffez_core/mohaffez_core.dart';

import '../../shared/widgets/cached_avatar.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/error_widgets.dart';

class NearbyMohaffezScreen extends ConsumerStatefulWidget {
  const NearbyMohaffezScreen({super.key});

  @override
  ConsumerState<NearbyMohaffezScreen> createState() =>
      _NearbyMohaffezScreenState();
}

class _NearbyMohaffezScreenState extends ConsumerState<NearbyMohaffezScreen>
    with SingleTickerProviderStateMixin {
  static const CameraPosition _fallbackCamera = CameraPosition(
    target: LatLng(30.0444, 31.2357),
    zoom: 11,
  );

  static const String _premiumMapStyle = '''
[
  {"elementType":"geometry","stylers":[{"color":"#0b2530"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#b7d8d2"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#072027"}]},
  {"featureType":"administrative","elementType":"geometry.stroke","stylers":[{"color":"#155e63"}]},
  {"featureType":"landscape.natural","elementType":"geometry","stylers":[{"color":"#123b39"}]},
  {"featureType":"poi","elementType":"geometry","stylers":[{"color":"#0f3a42"}]},
  {"featureType":"poi.park","elementType":"geometry","stylers":[{"color":"#0f4d43"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#164653"}]},
  {"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#08252e"}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#1f6c70"}]},
  {"featureType":"transit","elementType":"geometry","stylers":[{"color":"#0d3945"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#062b3f"}]},
  {"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#68d8d6"}]}
]
''';

  SortType selectedFilter = SortType.distance;
  double? userLat;
  double? userLng;
  bool isLoadingLocation = true;
  String? locationError;
  double radiusKm = 50.0;
  double _displayRadius = 50.0;
  String searchQuery = '';
  String? selectedSpecialization;
  MohaffezModel? _selectedTeacher;
  GoogleMapController? _mapController;
  bool _hasFitInitialBounds = false;

  final Map<String, BitmapDescriptor> _markerIcons = {};
  final Map<String, BitmapDescriptor> _selectedMarkerIcons = {};
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _searchDebounce;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseController.addListener(() {
      if (mounted) setState(() {});
    });
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _pulseController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      if (!mounted) return;
      setState(() {
        isLoadingLocation = true;
        locationError = null;
      });

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('خدمات الموقع غير مفعلة');
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('تم رفض إذن الموقع');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('تم رفض إذن الموقع بشكل دائم');
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 0,
          timeLimit: Duration(seconds: 10),
        ),
      );

      if (!mounted) return;
      setState(() {
        userLat = position.latitude;
        userLng = position.longitude;
        isLoadingLocation = false;
        _hasFitInitialBounds = false;
      });
      await _animateToUser();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        locationError = e.toString();
        isLoadingLocation = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final params = NearbyParams(
      userLat: userLat,
      userLng: userLng,
      radiusKm: radiusKm,
      sortBy: selectedFilter,
      searchQuery: searchQuery.isNotEmpty ? searchQuery : null,
      specialization: selectedSpecialization,
    );
    final mohaffezAsync = ref.watch(nearbyMohaffezProvider(params));

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: mohaffezAsync.when(
          data: (teachers) => _buildMapExperience(context, teachers),
          loading: _buildLoading,
          error: (_, __) => ErrorDisplay.dataLoad(
            onRetry: () => ref.invalidate(nearbyMohaffezProvider(params)),
          ),
        ),
      ),
    );
  }

  Widget _buildMapExperience(
    BuildContext context,
    List<MohaffezModel> teachers,
  ) {
    _ensureMarkerIcons(teachers);
    _fitInitialBounds(teachers);

    return SafeArea(
      child: Column(
        children: [
          _buildMapHeader(teachers.length),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 720;
                final mapPane = _buildMapPane(teachers);
                final resultsPane = _buildResultsPane(context, teachers);

                if (isWide) {
                  return Row(
                    children: [
                      SizedBox(
                        width: math.min(430, constraints.maxWidth * 0.42),
                        child: resultsPane,
                      ),
                      Expanded(child: mapPane),
                    ],
                  );
                }

                return Column(
                  children: [
                    Expanded(flex: 5, child: mapPane),
                    Expanded(flex: 6, child: resultsPane),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapPane(List<MohaffezModel> teachers) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            GoogleMap(
              initialCameraPosition: _initialCamera(teachers),
              myLocationEnabled: userLat != null && userLng != null,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              compassEnabled: false,
              mapToolbarEnabled: false,
              style: _premiumMapStyle,
              markers: _buildMarkers(teachers),
              circles: _buildRadiusCircle(),
              onMapCreated: (controller) {
                _mapController = controller;
                _fitInitialBounds(teachers, force: true);
              },
              onTap: (_) => setState(() => _selectedTeacher = null),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.center,
                      colors: [
                        AppThemeConstants.deepTeal.withValues(alpha: 0.36),
                        AppThemeConstants.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 14,
              bottom: 14,
              child: _FloatingMapButton(
                icon: Icons.my_location,
                onTap: _getCurrentLocation,
                tooltip: 'تحديث الموقع',
              ),
            ),
            Positioned(
              right: 14,
              top: 14,
              child: _MapCounterBadge(
                count: teachers.length,
                radiusKm: radiusKm.round(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsPane(BuildContext context, List<MohaffezModel> teachers) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      decoration: BoxDecoration(
        color: AppThemeConstants.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppThemeConstants.outline),
        boxShadow: [
          BoxShadow(
            color: AppThemeConstants.black.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildSearchBar(),
          _buildFilterRail(),
          if (isLoadingLocation || locationError != null)
            _buildLocationBanner(),
          if (_selectedTeacher != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: _TeacherPreviewCard(
                teacher: _selectedTeacher!,
                distance: _selectedTeacher!.getDistanceFrom(userLat, userLng),
                pulseValue: _pulseController.value,
                onClose: () => setState(() => _selectedTeacher = null),
                onBook: () => _openTeacherProfile(_selectedTeacher!),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                const Icon(
                  Icons.format_list_bulleted_rounded,
                  size: 18,
                  color: AppThemeConstants.primary,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'نتائج البحث',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: AppThemeConstants.textPrimary,
                    ),
                  ),
                ),
                Text(
                  '${teachers.length}',
                  style: const TextStyle(
                    color: AppThemeConstants.textSecondary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: teachers.isEmpty && !isLoadingLocation
                ? const EmptyState(
                    icon: Icons.travel_explore,
                    title: 'لا يوجد محفظون',
                    message: 'لم نتمكن من العثور على محفظين في نطاق البحث',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
                    itemCount: teachers.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final teacher = teachers[index];
                      return _TeacherResultTile(
                        teacher: teacher,
                        distance: teacher.getDistanceFrom(userLat, userLng),
                        isSelected: _selectedTeacher?.id == teacher.id,
                        onTap: () => _selectTeacher(teacher),
                        onBook: () => _openTeacherProfile(teacher),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF08252E), Color(0xFF0B7A75)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppThemeConstants.secondary),
            SizedBox(height: 16),
            Text(
              'جاري تجهيز الخريطة...',
              style: TextStyle(
                color: AppThemeConstants.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  CameraPosition _initialCamera(List<MohaffezModel> teachers) {
    if (userLat != null && userLng != null) {
      return CameraPosition(target: LatLng(userLat!, userLng!), zoom: 12.5);
    }
    final first = teachers.where(_hasLocation).firstOrNull;
    if (first != null) {
      return CameraPosition(
        target: LatLng(first.addressLat!, first.addressLng!),
        zoom: 12,
      );
    }
    return _fallbackCamera;
  }

  Set<Marker> _buildMarkers(List<MohaffezModel> teachers) {
    final pulse = 0.82 + (_pulseController.value * 0.18);

    return teachers.where(_hasLocation).map((teacher) {
      final isSelected = _selectedTeacher?.id == teacher.id;
      return Marker(
        markerId: MarkerId(teacher.id),
        position: LatLng(teacher.addressLat!, teacher.addressLng!),
        icon: isSelected
            ? (_selectedMarkerIcons[teacher.id] ??
                BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueYellow))
            : (_markerIcons[teacher.id] ??
                BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueAzure)),
        alpha: isSelected ? pulse : 0.95,
        zIndexInt: isSelected ? 20 : 10,
        anchor: const Offset(0.5, 0.92),
        onTap: () => _selectTeacher(teacher),
      );
    }).toSet();
  }

  Set<Circle> _buildRadiusCircle() {
    if (userLat == null || userLng == null) return const {};
    return {
      Circle(
        circleId: const CircleId('student-search-radius'),
        center: LatLng(userLat!, userLng!),
        radius: radiusKm * 1000,
        fillColor: AppThemeConstants.primaryVariant.withValues(alpha: 0.08),
        strokeColor: AppThemeConstants.primaryVariant.withValues(alpha: 0.28),
        strokeWidth: 2,
      ),
    };
  }

  void _selectTeacher(MohaffezModel teacher) {
    setState(() => _selectedTeacher = teacher);
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(teacher.addressLat!, teacher.addressLng!),
        14.5,
      ),
    );
  }

  Future<void> _animateToUser() async {
    if (_mapController == null || userLat == null || userLng == null) return;
    await _mapController!.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(userLat!, userLng!), 13),
    );
  }

  void _fitInitialBounds(List<MohaffezModel> teachers, {bool force = false}) {
    if (_mapController == null || (_hasFitInitialBounds && !force)) return;
    final points = <LatLng>[
      if (userLat != null && userLng != null) LatLng(userLat!, userLng!),
      ...teachers
          .where(_hasLocation)
          .map((teacher) => LatLng(teacher.addressLat!, teacher.addressLng!)),
    ];
    if (points.length < 2) return;

    _hasFitInitialBounds = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _mapController == null) return;
      _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(_boundsFrom(points), 84),
      );
    });
  }

  LatLngBounds _boundsFrom(List<LatLng> points) {
    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLng = points.first.longitude;
    var maxLng = points.first.longitude;
    for (final point in points.skip(1)) {
      minLat = math.min(minLat, point.latitude);
      maxLat = math.max(maxLat, point.latitude);
      minLng = math.min(minLng, point.longitude);
      maxLng = math.max(maxLng, point.longitude);
    }
    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  bool _hasLocation(MohaffezModel teacher) =>
      teacher.addressLat != null && teacher.addressLng != null;

  Future<void> _ensureMarkerIcons(List<MohaffezModel> teachers) async {
    final missing = teachers
        .where(_hasLocation)
        .where((teacher) => !_markerIcons.containsKey(teacher.id))
        .toList();
    if (missing.isEmpty) return;

    for (final teacher in missing) {
      final initials = teacher.name.trim().isEmpty
          ? 'م'
          : teacher.name.trim().characters.take(2).toString();
      _markerIcons[teacher.id] =
          await _teacherMarker(initials, selected: false);
      _selectedMarkerIcons[teacher.id] =
          await _teacherMarker(initials, selected: true);
    }
    if (mounted) setState(() {});
  }

  Future<BitmapDescriptor> _teacherMarker(
    String initials, {
    required bool selected,
  }) async {
    final size = selected ? 142.0 : 118.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final center = Offset(size / 2, size / 2);
    final glowPaint = Paint()
      ..color = (selected
              ? AppThemeConstants.secondary
              : AppThemeConstants.primaryVariant)
          .withValues(alpha: selected ? 0.26 : 0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
    final shellPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF0B7A75), Color(0xFF14B8A6)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromCircle(center: center, radius: size * 0.34));
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = selected ? 7 : 5
      ..color = selected
          ? AppThemeConstants.secondary
          : AppThemeConstants.white.withValues(alpha: 0.92);

    canvas.drawCircle(center.translate(0, 4), size * 0.34, glowPaint);
    canvas.drawCircle(center, size * 0.31, shellPaint);
    canvas.drawCircle(center, size * 0.31, borderPaint);
    canvas.drawCircle(
      center.translate(0, 2),
      size * 0.19,
      Paint()..color = AppThemeConstants.white.withValues(alpha: 0.16),
    );

    final textPainter = TextPainter(
      text: TextSpan(
        text: initials,
        style: TextStyle(
          color: AppThemeConstants.white,
          fontSize: selected ? 34 : 28,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.rtl,
      textAlign: TextAlign.center,
    )..layout(maxWidth: size);
    textPainter.paint(
      canvas,
      Offset(center.dx - textPainter.width / 2,
          center.dy - textPainter.height / 2),
    );

    final pinPath = Path()
      ..moveTo(center.dx - 14, center.dy + size * 0.26)
      ..quadraticBezierTo(center.dx, center.dy + size * 0.44, center.dx + 14,
          center.dy + size * 0.26)
      ..close();
    canvas.drawPath(pinPath, shellPaint);
    canvas.drawCircle(
      center.translate(size * 0.22, -size * 0.22),
      selected ? 12 : 9,
      Paint()..color = AppThemeConstants.success,
    );

    final image =
        await recorder.endRecording().toImage(size.round(), size.round());
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(data!.buffer.asUint8List());
  }

  Widget _buildMapHeader(int teacherCount) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF062B3F).withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppThemeConstants.primaryVariant.withValues(alpha: 0.35),
          ),
          boxShadow: [
            BoxShadow(
              color: AppThemeConstants.black.withValues(alpha: 0.22),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppThemeConstants.primaryVariant.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color:
                      AppThemeConstants.primaryVariant.withValues(alpha: 0.4),
                ),
              ),
              child: const Icon(
                Icons.explore_rounded,
                color: AppThemeConstants.primaryVariant,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'خريطة المحفظين',
                    style: TextStyle(
                      color: AppThemeConstants.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$teacherCount محفظ ضمن ${radiusKm.round()} كم',
                    style: TextStyle(
                      color: AppThemeConstants.white.withValues(alpha: 0.72),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => context.pop(),
              icon: const Icon(Icons.arrow_forward_ios_rounded),
              color: AppThemeConstants.white,
              tooltip: 'رجوع',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: AppThemeConstants.white.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppThemeConstants.black.withValues(alpha: 0.14),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          textDirection: TextDirection.rtl,
          decoration: InputDecoration(
            hintText: 'ابحث باسم المحفظ...',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: _clearSearch,
                  )
                : null,
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          onChanged: (value) {
            _searchDebounce?.cancel();
            _searchDebounce = Timer(const Duration(milliseconds: 350), () {
              if (mounted) {
                setState(() {
                  searchQuery = value.trim();
                  _selectedTeacher = null;
                  _hasFitInitialBounds = false;
                });
              }
            });
          },
        ),
      ),
    );
  }

  Widget _buildFilterRail() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _MapChip(
                  label: 'الأقرب',
                  icon: Icons.near_me_rounded,
                  isSelected: selectedFilter == SortType.distance,
                  onTap: () => _updateFilter(SortType.distance),
                ),
                const SizedBox(width: 8),
                _MapChip(
                  label: 'الأعلى تقييماً',
                  icon: Icons.star_rounded,
                  isSelected: selectedFilter == SortType.rating,
                  onTap: () => _updateFilter(SortType.rating),
                ),
                const SizedBox(width: 8),
                _MapChip(
                  label: 'الأكثر متابعة',
                  icon: Icons.people_alt_rounded,
                  isSelected: selectedFilter == SortType.followers,
                  onTap: () => _updateFilter(SortType.followers),
                ),
                const SizedBox(width: 8),
                ...SpecializationConstants.specializations.map(
                  (spec) => Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: _MapChip(
                      label: spec,
                      icon: Icons.auto_awesome_rounded,
                      isSelected: selectedSpecialization == spec,
                      onTap: () {
                        setState(() {
                          selectedSpecialization =
                              selectedSpecialization == spec ? null : spec;
                          _selectedTeacher = null;
                          _hasFitInitialBounds = false;
                        });
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
            decoration: BoxDecoration(
              color: const Color(0xFF062B3F).withValues(alpha: 0.84),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppThemeConstants.primaryVariant.withValues(alpha: 0.22),
              ),
            ),
            child: Row(
              children: [
                Text(
                  '${_displayRadius.round()} كم',
                  style: const TextStyle(
                    color: AppThemeConstants.secondary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: AppThemeConstants.secondary,
                      inactiveTrackColor:
                          AppThemeConstants.white.withValues(alpha: 0.18),
                      thumbColor: AppThemeConstants.secondary,
                      overlayColor:
                          AppThemeConstants.secondary.withValues(alpha: 0.2),
                    ),
                    child: Slider(
                      value: _displayRadius,
                      min: 5,
                      max: 100,
                      divisions: 19,
                      label: '${_displayRadius.round()} كم',
                      onChanged: (value) {
                        setState(() => _displayRadius = value);
                      },
                      onChangeEnd: (value) {
                        setState(() {
                          _displayRadius = value;
                          radiusKm = value;
                          _selectedTeacher = null;
                          _hasFitInitialBounds = false;
                        });
                      },
                    ),
                  ),
                ),
                const Icon(
                  Icons.radar_rounded,
                  color: AppThemeConstants.primaryVariant,
                  size: 20,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationBanner() {
    final isError = locationError != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isError
              ? AppThemeConstants.warningBackground
              : AppThemeConstants.infoLight,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppThemeConstants.black.withValues(alpha: 0.12),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            if (isLoadingLocation)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              const Icon(Icons.warning_amber_rounded,
                  color: AppThemeConstants.warning),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isLoadingLocation
                    ? 'جاري تحديد موقعك...'
                    : 'تعذر تحديد موقعك. يمكنك رؤية المحفظين المتاحين أو إعادة المحاولة.',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isError
                      ? AppThemeConstants.warning
                      : AppThemeConstants.infoDark,
                ),
              ),
            ),
            if (isError)
              TextButton(
                onPressed: _getCurrentLocation,
                child: const Text(ArabicLabels.retry),
              ),
          ],
        ),
      ),
    );
  }

  void _openTeacherProfile(MohaffezModel teacher) {
    final uri = Uri(
      path: '/mohaffez/${teacher.id}',
      queryParameters: {
        if (userLat != null) 'lat': userLat!.toString(),
        if (userLng != null) 'lng': userLng!.toString(),
      },
    );
    context.go(uri.toString());
  }

  void _updateFilter(SortType newFilter) {
    if (selectedFilter != newFilter) {
      setState(() {
        selectedFilter = newFilter;
        _selectedTeacher = null;
        _hasFitInitialBounds = false;
      });
    }
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      searchQuery = '';
      _selectedTeacher = null;
      _hasFitInitialBounds = false;
    });
  }
}

class _TeacherPreviewCard extends StatelessWidget {
  final MohaffezModel teacher;
  final double? distance;
  final double pulseValue;
  final VoidCallback onClose;
  final VoidCallback onBook;

  const _TeacherPreviewCard({
    required this.teacher,
    required this.distance,
    required this.pulseValue,
    required this.onClose,
    required this.onBook,
  });

  @override
  Widget build(BuildContext context) {
    final glow = 0.10 + (pulseValue * 0.18);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppThemeConstants.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppThemeConstants.primaryVariant.withValues(alpha: 0.24),
        ),
        boxShadow: [
          BoxShadow(
            color: AppThemeConstants.primaryVariant.withValues(alpha: glow),
            blurRadius: 28,
            spreadRadius: 3,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: AppThemeConstants.black.withValues(alpha: 0.16),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CachedAvatar(
                imageUrl: teacher.photoUrl,
                radius: 34,
                semanticLabel: teacher.name,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            teacher.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: AppThemeConstants.textPrimary,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: onClose,
                          icon: const Icon(Icons.close_rounded),
                          visualDensity: VisualDensity.compact,
                          tooltip: 'إغلاق',
                        ),
                      ],
                    ),
                    if (teacher.specialization?.isNotEmpty ?? false)
                      Text(
                        teacher.specialization!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppThemeConstants.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _MetricPill(
                          icon: Icons.star_rounded,
                          label: teacher.rating.toStringAsFixed(1),
                          color: AppThemeConstants.secondary,
                        ),
                        _MetricPill(
                          icon: Icons.people_alt_rounded,
                          label: '${teacher.followerCount} متابع',
                          color: AppThemeConstants.success,
                        ),
                        if (distance != null)
                          _MetricPill(
                            icon: Icons.near_me_rounded,
                            label: distance! < 1
                                ? '${(distance! * 1000).round()} م'
                                : '${distance!.toStringAsFixed(1)} كم',
                            color: AppThemeConstants.info,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (teacher.bio?.isNotEmpty ?? false) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                teacher.bio!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: AppThemeConstants.textSecondary,
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: onBook,
              icon: const Icon(Icons.event_available_rounded),
              label: const Text(
                'احجز الآن',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppThemeConstants.primary,
                foregroundColor: AppThemeConstants.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TeacherResultTile extends StatelessWidget {
  final MohaffezModel teacher;
  final double? distance;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onBook;

  const _TeacherResultTile({
    required this.teacher,
    required this.distance,
    required this.isSelected,
    required this.onTap,
    required this.onBook,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected
          ? AppThemeConstants.primary.withValues(alpha: 0.08)
          : AppThemeConstants.grey50,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? AppThemeConstants.primary
                  : AppThemeConstants.outline,
              width: isSelected ? 1.6 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppThemeConstants.primary.withValues(alpha: 0.14),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              CachedAvatar(
                imageUrl: teacher.photoUrl,
                radius: 28,
                semanticLabel: teacher.name,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      teacher.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: AppThemeConstants.textPrimary,
                      ),
                    ),
                    if (teacher.specialization?.isNotEmpty ?? false) ...[
                      const SizedBox(height: 3),
                      Text(
                        teacher.specialization!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppThemeConstants.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _MetricPill(
                          icon: Icons.star_rounded,
                          label: teacher.rating.toStringAsFixed(1),
                          color: AppThemeConstants.secondary,
                        ),
                        if (distance != null)
                          _MetricPill(
                            icon: Icons.near_me_rounded,
                            label: distance! < 1
                                ? '${(distance! * 1000).round()} م'
                                : '${distance!.toStringAsFixed(1)} كم',
                            color: AppThemeConstants.info,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: onBook,
                icon: const Icon(Icons.event_available_rounded, size: 18),
                tooltip: 'احجز الآن',
                style: IconButton.styleFrom(
                  backgroundColor: isSelected
                      ? AppThemeConstants.primary
                      : AppThemeConstants.primary.withValues(alpha: 0.12),
                  foregroundColor: isSelected
                      ? AppThemeConstants.white
                      : AppThemeConstants.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
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

class _MetricPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _MetricPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _MapCounterBadge extends StatelessWidget {
  final int count;
  final int radiusKm;

  const _MapCounterBadge({
    required this.count,
    required this.radiusKm,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFF062B3F).withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: AppThemeConstants.primaryVariant.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: AppThemeConstants.black.withValues(alpha: 0.16),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.groups_rounded,
            color: AppThemeConstants.primaryVariant,
            size: 17,
          ),
          const SizedBox(width: 6),
          Text(
            '$count / $radiusKm كم',
            style: const TextStyle(
              color: AppThemeConstants.white,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _MapChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _MapChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isSelected ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected
              ? AppThemeConstants.secondary
              : const Color(0xFF062B3F).withValues(alpha: 0.86),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: isSelected
                ? AppThemeConstants.secondary
                : AppThemeConstants.primaryVariant.withValues(alpha: 0.24),
          ),
          boxShadow: [
            BoxShadow(
              color: AppThemeConstants.black.withValues(alpha: 0.16),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 17,
              color: isSelected
                  ? AppThemeConstants.deepTeal
                  : AppThemeConstants.primaryVariant,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: isSelected
                    ? AppThemeConstants.deepTeal
                    : AppThemeConstants.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FloatingMapButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  const _FloatingMapButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppThemeConstants.primary,
        elevation: 8,
        shadowColor: AppThemeConstants.primary.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            width: 52,
            height: 52,
            child: Icon(icon, color: AppThemeConstants.white),
          ),
        ),
      ),
    );
  }
}
