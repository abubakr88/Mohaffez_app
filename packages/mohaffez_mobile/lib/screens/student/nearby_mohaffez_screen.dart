import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
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
  static const LatLng _fallbackCenter = LatLng(30.0444, 31.2357);
  static const String _osmTileUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  SortType selectedFilter = SortType.distance;
  TeacherAvailabilityFilter availabilityFilter =
      TeacherAvailabilityFilter.availableOnly;
  double? userLat;
  double? userLng;
  bool isLoadingLocation = true;
  String? locationError;
  double radiusKm = 50.0;
  double _displayRadius = 50.0;
  String searchQuery = '';
  String? selectedSpecialization;
  MohaffezModel? _selectedTeacher;
  final MapController _mapController = MapController();
  bool _hasFitInitialBounds = false;
  bool _showMapView = false;

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
      _animateToUser();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        locationError = 'تعذّر تحديد موقعك. تحقق من إذن الموقع وحاول مجدداً';
        isLoadingLocation = false;
      });
    }
  }

  double? _distanceFor(MohaffezModel teacher) =>
      teacher.getDistanceFrom(userLat, userLng);

  @override
  Widget build(BuildContext context) {
    final params = NearbyParams(
      userLat: userLat,
      userLng: userLng,
      radiusKm: radiusKm,
      sortBy: selectedFilter,
      searchQuery: searchQuery.isNotEmpty ? searchQuery : null,
      specialization: selectedSpecialization,
      availabilityFilter: availabilityFilter,
    );
    final mohaffezAsync = ref.watch(nearbyMohaffezProvider(params));

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: mohaffezAsync.when(
          data: (teachers) => _buildMainExperience(context, teachers),
          loading: _buildLoading,
          error: (_, __) => ErrorDisplay.dataLoad(
            onRetry: () => ref.invalidate(nearbyMohaffezProvider(params)),
          ),
        ),
      ),
    );
  }

  Widget _buildMainExperience(
    BuildContext context,
    List<MohaffezModel> teachers,
  ) {
    return SafeArea(
      child: Column(
        children: [
          _buildHeader(teachers.length),
          Expanded(
            child: Stack(
              children: [
                IndexedStack(
                  index: _showMapView ? 0 : 1,
                  children: [
                    _buildMapPane(teachers),
                    _buildResultsPane(context, teachers),
                  ],
                ),
                Positioned(
                  bottom: 20,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: _showMapView
                        ? _ViewToggleButton(
                            label: 'عرض القائمة',
                            icon: Icons.format_list_bulleted_rounded,
                            onTap: () => setState(() => _showMapView = false),
                          )
                        : _ViewToggleButton(
                            label: 'عرض على الخريطة',
                            icon: Icons.map_rounded,
                            onTap: () {
                              setState(() => _showMapView = true);
                              _fitInitialBounds(teachers, force: true);
                            },
                          ),
                  ),
                ),
              ],
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
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _initialCenter(teachers),
                initialZoom: 12.5,
                onTap: (_, __) => setState(() => _selectedTeacher = null),
                onMapReady: () => _fitInitialBounds(teachers, force: true),
              ),
              children: [
                TileLayer(
                  urlTemplate: _osmTileUrl,
                  userAgentPackageName: 'app.mohafezy',
                  maxNativeZoom: 19,
                  tileProvider: kIsWeb
                      ? CancellableNetworkTileProvider()
                      : NetworkTileProvider(),
                ),
                if (userLat != null && userLng != null)
                  CircleLayer(
                    circles: [
                      CircleMarker(
                        point: LatLng(userLat!, userLng!),
                        radius: radiusKm * 1000,
                        useRadiusInMeter: true,
                        color: AppThemeConstants.primaryVariant
                            .withValues(alpha: 0.08),
                        borderColor: AppThemeConstants.primaryVariant
                            .withValues(alpha: 0.28),
                        borderStrokeWidth: 2,
                      ),
                    ],
                  ),
                MarkerLayer(markers: _buildMarkers(teachers)),
                const RichAttributionWidget(
                  attributions: [
                    TextSourceAttribution('© OpenStreetMap contributors'),
                  ],
                ),
              ],
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.center,
                      colors: [
                        AppThemeConstants.deepTeal.withValues(alpha: 0.24),
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
                distance: _distanceFor(_selectedTeacher!),
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
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 72),
                    itemCount: teachers.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final teacher = teachers[index];
                      return _TeacherResultTile(
                        teacher: teacher,
                        distance: _distanceFor(teacher),
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
              'جاري تجهيز النتائج...',
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

  LatLng _initialCenter(List<MohaffezModel> teachers) {
    if (userLat != null && userLng != null) {
      return LatLng(userLat!, userLng!);
    }
    final first = teachers.where(_hasLocation).firstOrNull;
    if (first != null) {
      return LatLng(first.addressLat!, first.addressLng!);
    }
    return _fallbackCenter;
  }

  List<Marker> _buildMarkers(List<MohaffezModel> teachers) {
    final pulse = 0.82 + (_pulseController.value * 0.18);

    final markers = teachers.where(_hasLocation).map((teacher) {
      final isSelected = _selectedTeacher?.id == teacher.id;
      final initials = teacher.name.trim().isEmpty
          ? 'م'
          : teacher.name.trim().characters.take(2).toString();
      return Marker(
        point: LatLng(teacher.addressLat!, teacher.addressLng!),
        width: isSelected ? 64 : 52,
        height: isSelected ? 64 : 52,
        alignment: Alignment.topCenter,
        child: GestureDetector(
          onTap: () => _selectTeacher(teacher),
          child: Opacity(
            opacity: isSelected ? pulse : 0.96,
            child: _TeacherPin(initials: initials, selected: isSelected),
          ),
        ),
      );
    }).toList();

    if (userLat != null && userLng != null) {
      markers.add(
        Marker(
          point: LatLng(userLat!, userLng!),
          width: 56,
          height: 56,
          child: const _UserLocationPin(),
        ),
      );
    }

    return markers;
  }

  void _selectTeacher(MohaffezModel teacher) {
    setState(() => _selectedTeacher = teacher);
    _mapController.move(
      LatLng(teacher.addressLat!, teacher.addressLng!),
      14.5,
    );
  }

  void _animateToUser() {
    if (userLat == null || userLng == null) return;
    _mapController.move(LatLng(userLat!, userLng!), 13);
  }

  void _fitInitialBounds(List<MohaffezModel> teachers, {bool force = false}) {
    if (_hasFitInitialBounds && !force) return;
    final points = <LatLng>[
      if (userLat != null && userLng != null) LatLng(userLat!, userLng!),
      ...teachers
          .where(_hasLocation)
          .map((teacher) => LatLng(teacher.addressLat!, teacher.addressLng!)),
    ];
    if (points.length < 2) return;
    _hasFitInitialBounds = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(points),
          padding: const EdgeInsets.all(48),
        ),
      );
    });
  }

  bool _hasLocation(MohaffezModel teacher) =>
      teacher.addressLat != null && teacher.addressLng != null;

  Widget _buildHeader(int teacherCount) {
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
                    'المحفظون القريبون',
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
                _MapChip(
                  label: 'المتاحون',
                  icon: Icons.event_available_rounded,
                  isSelected: availabilityFilter ==
                      TeacherAvailabilityFilter.availableOnly,
                  onTap: () => _updateAvailabilityFilter(
                    TeacherAvailabilityFilter.availableOnly,
                  ),
                ),
                const SizedBox(width: 8),
                _MapChip(
                  label: 'الكل',
                  icon: Icons.groups_rounded,
                  isSelected:
                      availabilityFilter == TeacherAvailabilityFilter.all,
                  onTap: () => _updateAvailabilityFilter(
                    TeacherAvailabilityFilter.all,
                  ),
                ),
                const SizedBox(width: 8),
                _MapChip(
                  label: 'بدون مواعيد',
                  icon: Icons.event_busy_rounded,
                  isSelected: availabilityFilter ==
                      TeacherAvailabilityFilter.unavailableOnly,
                  onTap: () => _updateAvailabilityFilter(
                    TeacherAvailabilityFilter.unavailableOnly,
                  ),
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
    context.push(uri.toString());
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

  void _updateAvailabilityFilter(TeacherAvailabilityFilter newFilter) {
    if (availabilityFilter != newFilter) {
      setState(() {
        availabilityFilter = newFilter;
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

// ─── Map pins ───────────────────────────────────────────────────────────────

class _TeacherPin extends StatelessWidget {
  final String initials;
  final bool selected;

  const _TeacherPin({required this.initials, required this.selected});

  @override
  Widget build(BuildContext context) {
    final size = selected ? 56.0 : 44.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFF0B7A75), Color(0xFF14B8A6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: selected
              ? AppThemeConstants.secondary
              : AppThemeConstants.white.withValues(alpha: 0.92),
          width: selected ? 3 : 2,
        ),
        boxShadow: [
          BoxShadow(
            color: (selected
                    ? AppThemeConstants.secondary
                    : AppThemeConstants.primaryVariant)
                .withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: AppThemeConstants.white,
            fontSize: selected ? 16 : 13,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _UserLocationPin extends StatelessWidget {
  const _UserLocationPin();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFFD4A44A), Color(0xFFF5C842)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: AppThemeConstants.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: AppThemeConstants.secondary.withValues(alpha: 0.4),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Center(
        child: Text(
          'أنت',
          style: TextStyle(
            color: Color(0xFF062B3F),
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

// ─── View toggle button ─────────────────────────────────────────────────────

class _ViewToggleButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _ViewToggleButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppThemeConstants.primary,
      elevation: 10,
      shadowColor: AppThemeConstants.primary.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(30),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: AppThemeConstants.white, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: AppThemeConstants.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Teacher preview card (map selection) ───────────────────────────────────

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

// ─── Teacher list tile ───────────────────────────────────────────────────────

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

// ─── Shared sub-widgets ──────────────────────────────────────────────────────

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
