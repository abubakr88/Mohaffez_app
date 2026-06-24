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
  TeacherGenderFilter genderFilter = TeacherGenderFilter.all;
  TeacherTrialSessionFilter trialSessionFilter = TeacherTrialSessionFilter.all;
  double? userLat;
  double? userLng;
  bool isLoadingLocation = true;
  String? locationError;
  double radiusKm = 50.0;
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
      genderFilter: genderFilter,
      trialSessionFilter: trialSessionFilter,
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
    final selectedTeacher = _selectedTeacher;

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
            if (selectedTeacher != null)
              Positioned(
                left: 14,
                right: 14,
                bottom: 82,
                child: _MapTeacherPreviewCard(
                  teacher: selectedTeacher,
                  distance: _distanceFor(selectedTeacher),
                  pulseValue: _pulseController.value,
                  onClose: () => setState(() => _selectedTeacher = null),
                  onOpenProfile: () => _openTeacherProfile(selectedTeacher),
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
      return Marker(
        point: LatLng(teacher.addressLat!, teacher.addressLng!),
        width: isSelected ? 64 : 54,
        height: isSelected ? 64 : 54,
        alignment: Alignment.bottomCenter,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _selectTeacher(teacher),
          child: Opacity(
            opacity: isSelected ? pulse : 0.96,
            child: _TeacherPin(selected: isSelected),
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
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
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _FilterSheetButton(
                activeCount: _activeFilterCount,
                onTap: _openFiltersSheet,
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _ActiveFilterPill(
                  icon: Icons.event_available_rounded,
                  label: _availabilityLabel(availabilityFilter),
                ),
                if (genderFilter != TeacherGenderFilter.all) ...[
                  const SizedBox(width: 8),
                  _ActiveFilterPill(
                    icon: genderFilter == TeacherGenderFilter.male
                        ? Icons.male_rounded
                        : Icons.female_rounded,
                    label: _genderLabel(genderFilter),
                  ),
                ],
                if (trialSessionFilter ==
                    TeacherTrialSessionFilter.enabledOnly) ...[
                  const SizedBox(width: 8),
                  const _ActiveFilterPill(
                    icon: Icons.school_outlined,
                    label: 'الحلقة التجريبية',
                  ),
                ],
                if (selectedSpecialization != null) ...[
                  const SizedBox(width: 8),
                  _ActiveFilterPill(
                    icon: Icons.auto_awesome_rounded,
                    label: selectedSpecialization!,
                  ),
                ],
                const SizedBox(width: 8),
                _ActiveFilterPill(
                  icon: Icons.radar_rounded,
                  label: '${radiusKm.round()} كم',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openFiltersSheet() {
    var tempAvailabilityFilter = availabilityFilter;
    var tempGenderFilter = genderFilter;
    var tempTrialSessionFilter = trialSessionFilter;
    var tempSpecialization = selectedSpecialization;
    var tempRadius = radiusKm;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              top: false,
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.82,
                ),
                decoration: const BoxDecoration(
                  color: AppThemeConstants.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        margin: const EdgeInsets.only(top: 12, bottom: 10),
                        decoration: BoxDecoration(
                          color:
                              AppThemeConstants.outline.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.of(sheetContext).pop(),
                            icon: const Icon(Icons.close_rounded),
                            tooltip: 'إغلاق',
                          ),
                          const Spacer(),
                          const Text(
                            'فلترة المحفظين',
                            style: TextStyle(
                              color: AppThemeConstants.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const _SheetSectionTitle(
                              icon: Icons.event_available_rounded,
                              title: 'التوفر',
                            ),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _FilterOptionChip(
                                  label: 'المتاحون',
                                  icon: Icons.event_available_rounded,
                                  isSelected: tempAvailabilityFilter ==
                                      TeacherAvailabilityFilter.availableOnly,
                                  onTap: () => setSheetState(() {
                                    tempAvailabilityFilter =
                                        TeacherAvailabilityFilter.availableOnly;
                                  }),
                                ),
                                _FilterOptionChip(
                                  label: 'الكل',
                                  icon: Icons.groups_rounded,
                                  isSelected: tempAvailabilityFilter ==
                                      TeacherAvailabilityFilter.all,
                                  onTap: () => setSheetState(() {
                                    tempAvailabilityFilter =
                                        TeacherAvailabilityFilter.all;
                                  }),
                                ),
                                _FilterOptionChip(
                                  label: 'غير المتاحين',
                                  icon: Icons.event_busy_rounded,
                                  isSelected: tempAvailabilityFilter ==
                                      TeacherAvailabilityFilter.unavailableOnly,
                                  onTap: () => setSheetState(() {
                                    tempAvailabilityFilter =
                                        TeacherAvailabilityFilter
                                            .unavailableOnly;
                                  }),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            const _SheetSectionTitle(
                              icon: Icons.school_outlined,
                              title: 'الحلقة التجريبية',
                            ),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _FilterOptionChip(
                                  label: 'الكل',
                                  icon: Icons.groups_rounded,
                                  isSelected: tempTrialSessionFilter ==
                                      TeacherTrialSessionFilter.all,
                                  onTap: () => setSheetState(() {
                                    tempTrialSessionFilter =
                                        TeacherTrialSessionFilter.all;
                                  }),
                                ),
                                _FilterOptionChip(
                                  label: 'متاحة',
                                  icon: Icons.school_outlined,
                                  isSelected: tempTrialSessionFilter ==
                                      TeacherTrialSessionFilter.enabledOnly,
                                  onTap: () => setSheetState(() {
                                    tempTrialSessionFilter =
                                        TeacherTrialSessionFilter.enabledOnly;
                                  }),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            const _SheetSectionTitle(
                              icon: Icons.person_search_rounded,
                              title: 'نوع المحفظ',
                            ),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _FilterOptionChip(
                                  label: 'الكل',
                                  icon: Icons.groups_rounded,
                                  isSelected: tempGenderFilter ==
                                      TeacherGenderFilter.all,
                                  onTap: () => setSheetState(() {
                                    tempGenderFilter = TeacherGenderFilter.all;
                                  }),
                                ),
                                _FilterOptionChip(
                                  label: 'معلم',
                                  icon: Icons.male_rounded,
                                  isSelected: tempGenderFilter ==
                                      TeacherGenderFilter.male,
                                  onTap: () => setSheetState(() {
                                    tempGenderFilter = TeacherGenderFilter.male;
                                  }),
                                ),
                                _FilterOptionChip(
                                  label: 'معلمة',
                                  icon: Icons.female_rounded,
                                  isSelected: tempGenderFilter ==
                                      TeacherGenderFilter.female,
                                  onTap: () => setSheetState(() {
                                    tempGenderFilter =
                                        TeacherGenderFilter.female;
                                  }),
                                ),
                              ],
                            ),
                            if (SpecializationConstants
                                .specializations.isNotEmpty) ...[
                              const SizedBox(height: 18),
                              const _SheetSectionTitle(
                                icon: Icons.auto_awesome_rounded,
                                title: 'التخصص',
                              ),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _FilterOptionChip(
                                    label: 'كل التخصصات',
                                    icon: Icons.apps_rounded,
                                    isSelected: tempSpecialization == null,
                                    onTap: () => setSheetState(() {
                                      tempSpecialization = null;
                                    }),
                                  ),
                                  ...SpecializationConstants.specializations
                                      .map(
                                    (spec) => _FilterOptionChip(
                                      label: spec,
                                      icon: Icons.auto_awesome_rounded,
                                      isSelected: tempSpecialization == spec,
                                      onTap: () => setSheetState(() {
                                        tempSpecialization =
                                            tempSpecialization == spec
                                                ? null
                                                : spec;
                                      }),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 18),
                            const _SheetSectionTitle(
                              icon: Icons.radar_rounded,
                              title: 'نطاق البحث',
                            ),
                            Container(
                              padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                              decoration: BoxDecoration(
                                color: AppThemeConstants.infoLight,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: AppThemeConstants.primaryVariant
                                      .withValues(alpha: 0.22),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    '${tempRadius.round()} كم',
                                    style: const TextStyle(
                                      color: AppThemeConstants.primary,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  Expanded(
                                    child: Slider(
                                      value: tempRadius,
                                      min: 5,
                                      max: 100,
                                      divisions: 19,
                                      label: '${tempRadius.round()} كم',
                                      activeColor: AppThemeConstants.secondary,
                                      inactiveColor: AppThemeConstants.outline,
                                      onChanged: (value) {
                                        setSheetState(() {
                                          tempRadius = value;
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                      decoration: BoxDecoration(
                        color: AppThemeConstants.white,
                        border: Border(
                          top: BorderSide(
                            color: AppThemeConstants.outline
                                .withValues(alpha: 0.75),
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          TextButton.icon(
                            onPressed: () => setSheetState(() {
                              tempAvailabilityFilter =
                                  TeacherAvailabilityFilter.availableOnly;
                              tempGenderFilter = TeacherGenderFilter.all;
                              tempTrialSessionFilter =
                                  TeacherTrialSessionFilter.all;
                              tempSpecialization = null;
                              tempRadius = 50;
                            }),
                            icon: const Icon(Icons.restart_alt_rounded),
                            label: const Text('إعادة ضبط'),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                _applyDetailedFilters(
                                  availability: tempAvailabilityFilter,
                                  gender: tempGenderFilter,
                                  trialSession: tempTrialSessionFilter,
                                  specialization: tempSpecialization,
                                  radius: tempRadius,
                                );
                                Navigator.of(sheetContext).pop();
                              },
                              icon: const Icon(Icons.check_rounded),
                              label: const Text('تطبيق الفلترة'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppThemeConstants.primary,
                                foregroundColor: AppThemeConstants.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
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

  int get _activeFilterCount {
    var count = 0;
    if (availabilityFilter != TeacherAvailabilityFilter.availableOnly) count++;
    if (genderFilter != TeacherGenderFilter.all) count++;
    if (trialSessionFilter != TeacherTrialSessionFilter.all) count++;
    if (selectedSpecialization != null) count++;
    if (radiusKm.round() != 50) count++;
    return count;
  }

  String _availabilityLabel(TeacherAvailabilityFilter filter) {
    switch (filter) {
      case TeacherAvailabilityFilter.availableOnly:
        return 'المتاحون';
      case TeacherAvailabilityFilter.all:
        return 'الكل';
      case TeacherAvailabilityFilter.unavailableOnly:
        return 'غير المتاحين';
    }
  }

  String _genderLabel(TeacherGenderFilter filter) {
    switch (filter) {
      case TeacherGenderFilter.all:
        return 'كل المحفظين';
      case TeacherGenderFilter.male:
        return 'معلم';
      case TeacherGenderFilter.female:
        return 'معلمة';
    }
  }

  void _applyDetailedFilters({
    required TeacherAvailabilityFilter availability,
    required TeacherGenderFilter gender,
    required TeacherTrialSessionFilter trialSession,
    required String? specialization,
    required double radius,
  }) {
    final normalizedRadius = radius.clamp(5.0, 100.0).toDouble();

    setState(() {
      availabilityFilter = availability;
      genderFilter = gender;
      trialSessionFilter = trialSession;
      selectedSpecialization = specialization;
      radiusKm = normalizedRadius;
      _selectedTeacher = null;
      _hasFitInitialBounds = false;
    });
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
  final bool selected;

  const _TeacherPin({required this.selected});

  @override
  Widget build(BuildContext context) {
    final size = selected ? 58.0 : 48.0;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Positioned(
            bottom: 2,
            child: Container(
              width: selected ? 28 : 22,
              height: selected ? 8 : 6,
              decoration: BoxDecoration(
                color: AppThemeConstants.black.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Icon(
            Icons.location_on_rounded,
            size: size,
            color: selected
                ? AppThemeConstants.secondary
                : AppThemeConstants.primary,
            shadows: [
              Shadow(
                color: AppThemeConstants.black.withValues(alpha: 0.24),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
              Shadow(
                color: selected
                    ? AppThemeConstants.secondary.withValues(alpha: 0.38)
                    : AppThemeConstants.primaryVariant.withValues(alpha: 0.32),
                blurRadius: selected ? 20 : 12,
              ),
            ],
          ),
        ],
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

class _MapTeacherPreviewCard extends StatelessWidget {
  final MohaffezModel teacher;
  final double? distance;
  final double pulseValue;
  final VoidCallback onClose;
  final VoidCallback onOpenProfile;

  const _MapTeacherPreviewCard({
    required this.teacher,
    required this.distance,
    required this.pulseValue,
    required this.onClose,
    required this.onOpenProfile,
  });

  @override
  Widget build(BuildContext context) {
    final bio = teacher.bio?.trim();
    final glow = 0.10 + (pulseValue * 0.14);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppThemeConstants.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppThemeConstants.primaryVariant.withValues(alpha: 0.28),
        ),
        boxShadow: [
          BoxShadow(
            color: AppThemeConstants.primary.withValues(alpha: glow),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: AppThemeConstants.black.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: AppThemeConstants.textPrimary,
                      ),
                    ),
                    if (teacher.badges.foundingTeacher.enabled) ...[
                      const SizedBox(height: 5),
                      const FoundingTeacherBadge(
                        compact: true,
                        showLabel: true,
                        useFullLabel: true,
                        size: 20,
                      ),
                    ],
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
                  ],
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
          if (bio != null && bio.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              bio,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                height: 1.35,
                color: AppThemeConstants.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            height: 44,
            child: ElevatedButton.icon(
              onPressed: onOpenProfile,
              icon: const Icon(Icons.person_rounded, size: 18),
              label: const Text(
                'عرض الملف الكامل',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppThemeConstants.primary,
                foregroundColor: AppThemeConstants.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
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
                    if (teacher.badges.foundingTeacher.enabled) ...[
                      const SizedBox(height: 5),
                      const FoundingTeacherBadge(
                        compact: true,
                        showLabel: true,
                        useFullLabel: true,
                        size: 20,
                      ),
                    ],
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
                    if (teacher.badges.foundingTeacher.enabled) ...[
                      const SizedBox(height: 5),
                      const FoundingTeacherBadge(
                        compact: true,
                        showLabel: true,
                        useFullLabel: true,
                        size: 20,
                      ),
                    ],
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

class _FilterSheetButton extends StatelessWidget {
  final int activeCount;
  final VoidCallback onTap;

  const _FilterSheetButton({
    required this.activeCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'فلترة النتائج',
      child: Material(
        color: AppThemeConstants.primary,
        elevation: 7,
        shadowColor: AppThemeConstants.primary.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(13),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(13),
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 11),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.tune_rounded,
                  color: AppThemeConstants.white,
                  size: 18,
                ),
                const SizedBox(width: 6),
                const Text(
                  'فلترة',
                  style: TextStyle(
                    color: AppThemeConstants.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (activeCount > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    width: 20,
                    height: 20,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: AppThemeConstants.secondary,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$activeCount',
                      style: const TextStyle(
                        color: AppThemeConstants.deepTeal,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActiveFilterPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ActiveFilterPill({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppThemeConstants.infoLight,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppThemeConstants.primaryVariant.withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppThemeConstants.primary),
          const SizedBox(width: 5),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppThemeConstants.textPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetSectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SheetSectionTitle({
    required this.icon,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppThemeConstants.primary),
          const SizedBox(width: 7),
          Text(
            title,
            style: const TextStyle(
              color: AppThemeConstants.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterOptionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterOptionChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final foreground =
        isSelected ? AppThemeConstants.deepTeal : AppThemeConstants.textPrimary;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected
              ? AppThemeConstants.secondary
              : AppThemeConstants.white,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: isSelected
                ? AppThemeConstants.secondary
                : AppThemeConstants.outline,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: foreground),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: foreground,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
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
