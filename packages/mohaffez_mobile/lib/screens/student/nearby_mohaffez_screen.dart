import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../shared/theme/app_theme_constants.dart';
import '../../shared/widgets/skeleton_card.dart';
import '../../shared/widgets/cached_avatar.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/error_widgets.dart';
import '../../providers/mohaffez_provider.dart';
import '../../models/mohaffez_model.dart';
import '../../shared/utils/arabic_labels.dart';
import '../../shared/utils/specialization_constants.dart';

class NearbyMohaffezScreen extends ConsumerStatefulWidget {
  const NearbyMohaffezScreen({super.key});

  @override
  ConsumerState<NearbyMohaffezScreen> createState() =>
      _NearbyMohaffezScreenState();
}

class _NearbyMohaffezScreenState extends ConsumerState<NearbyMohaffezScreen> {
  SortType selectedFilter = SortType.distance;
  double? userLat;
  double? userLng;
  bool isLoadingLocation = true;
  String? locationError;
  double radiusKm = 50.0;
  double _displayRadius = 50.0;
  String searchQuery = '';
  String? selectedSpecialization;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _searchDebounce;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  // FIXED: Check mounted before calling setState
  Future<void> _getCurrentLocation() async {
    try {
      if (!mounted) return;

      setState(() {
        isLoadingLocation = true;
        locationError = null;
      });

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('خدمات الموقع غير مفعلة');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('تم رفض إذن الموقع');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('تم رفض إذن الموقع بشكل دائم');
      }

      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 0,
          timeLimit: Duration(seconds: 10),
        ),
      );

      // FIXED: Check mounted before setState
      if (!mounted) return;

      setState(() {
        userLat = position.latitude;
        userLng = position.longitude;
        isLoadingLocation = false;
      });
    } catch (e) {
      // FIXED: Check mounted before setState
      if (!mounted) return;

      setState(() {
        locationError = e.toString();
        isLoadingLocation = false;
      });
    }
  }

  void _updateFilter(SortType newFilter) {
    if (selectedFilter != newFilter) {
      setState(() {
        selectedFilter = newFilter;
      });
    }
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      searchQuery = '';
    });
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
        body: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(nearbyMohaffezProvider(params));
            await ref
                .read(nearbyMohaffezProvider(params).future)
                .catchError((_) => <MohaffezModel>[]);
          },
          child: CustomScrollView(
            slivers: [
              _buildAppBar(context, ref, params),
              if (isLoadingLocation || locationError != null)
                SliverToBoxAdapter(
                  child: _buildLocationBanner(),
                ),
              SliverToBoxAdapter(
                child: _buildSearchBar(),
              ),
              SliverToBoxAdapter(
                child: _buildSpecializationChips(),
              ),
              SliverToBoxAdapter(
                child: _buildRadiusSlider(),
              ),
              SliverToBoxAdapter(
                child: _buildFilterChips(),
              ),
              mohaffezAsync.when(
                data: (mohaffezList) {
                  if (mohaffezList.isEmpty) {
                    return const SliverFillRemaining(
                      child: EmptyState(
                        icon: Icons.search_off,
                        title: 'لا يوجد محفظون',
                        message: 'لم نتمكن من العثور على محفظين في منطقتك',
                      ),
                    );
                  }

                  return SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final mohaffez = mohaffezList[index];
                          final distance =
                              mohaffez.getDistanceFrom(userLat, userLng);

                          return _MohaffezCard(
                            mohaffez: mohaffez,
                            distance: distance,
                            onTap: () =>
                                context.go('/mohaffez/${mohaffez.id}', extra: {
                              'lat': userLat?.toString(),
                              'lng': userLng?.toString(),
                            }),
                          );
                        },
                        childCount: mohaffezList.length,
                      ),
                    ),
                  );
                },
                loading: () => const SliverToBoxAdapter(
                  child: Column(
                    children: [
                      SkeletonList(itemCount: 6, itemHeight: 90),
                      Padding(
                        padding: EdgeInsets.only(top: 8, bottom: 16),
                        child: Text(
                          'جاري البحث عن محفظين بالقرب منك...',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppThemeConstants.textMuted,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
                error: (error, stack) => SliverFillRemaining(
                  child: ErrorDisplay.dataLoad(
                    onRetry: () => ref.invalidate(nearbyMohaffezProvider(params)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(
    BuildContext context,
    WidgetRef ref,
    NearbyParams params,
  ) {
    return SliverAppBar(
      expandedHeight: 100,
      floating: true,
      pinned: true,
      automaticallyImplyLeading: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: AppThemeConstants.deepTeal,
      surfaceTintColor: AppThemeConstants.transparent,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: AppThemeConstants.tealGradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppThemeConstants.surface.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.location_searching,
                      size: 24,
                      color: AppThemeConstants.surface,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'ابحث عن محفظ',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppThemeConstants.surface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'محفظون معتمدون بالقرب منك',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppThemeConstants.surface.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.my_location, color: AppThemeConstants.surface),
                    onPressed: _getCurrentLocation,
                    tooltip: 'تحديث الموقع',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        textDirection: TextDirection.rtl,
        decoration: InputDecoration(
          hintText: 'ابحث باسم المحفظ...',
          hintTextDirection: TextDirection.rtl,
          prefixIcon: const Icon(Icons.search, color: AppThemeConstants.textSecondary),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: AppThemeConstants.textSecondary),
                  onPressed: _clearSearch,
                )
              : null,
          filled: true,
          fillColor: AppThemeConstants.background,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppThemeConstants.outline),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppThemeConstants.outline),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppThemeConstants.secondary, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        onChanged: (value) {
          _searchDebounce?.cancel();
          _searchDebounce = Timer(const Duration(milliseconds: 400), () {
            if (mounted) {
              setState(() {
                searchQuery = value.trim();
              });
            }
          });
        },
      ),
    );
  }

  Widget _buildSpecializationChips() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'التخصص',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppThemeConstants.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _SpecializationChip(
                  label: 'الكل',
                  isSelected: selectedSpecialization == null,
                  onTap: () {
                    setState(() {
                      selectedSpecialization = null;
                    });
                  },
                ),
                ...SpecializationConstants.specializations.map((spec) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _SpecializationChip(
                    label: spec,
                    isSelected: selectedSpecialization == spec,
                    onTap: () {
                      setState(() {
                        selectedSpecialization = spec;
                      });
                    },
                  ),
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationBanner() {
    if (isLoadingLocation) {
      return Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: AppThemeConstants.info.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppThemeConstants.info.withValues(alpha: 0.3)),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text(
              '${ArabicLabels.loading} ${ArabicLabels.location}...',
              style: TextStyle(fontSize: 14, color: AppThemeConstants.info),
            ),
          ],
        ),
      );
    }

    if (locationError != null) {
      return Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: AppThemeConstants.warningBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppThemeConstants.warning.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber, color: AppThemeConstants.warning),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'تعذر تحديد موقعك. يرجى التحقق من إعدادات الموقع.',
                style: TextStyle(fontSize: 13, color: AppThemeConstants.warning),
              ),
            ),
            TextButton(
              onPressed: _getCurrentLocation,
              child: const Text(ArabicLabels.retry),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildRadiusSlider() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'نطاق البحث',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppThemeConstants.secondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_displayRadius.round()} كم',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppThemeConstants.secondary,
                  ),
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppThemeConstants.secondary,
              inactiveTrackColor: AppThemeConstants.divider,
              thumbColor: AppThemeConstants.secondary,
              overlayColor: AppThemeConstants.secondary.withValues(alpha: 0.2),
            ),
            child: Slider(
              value: _displayRadius,
              min: 5,
              max: 100,
              divisions: 19,
              label: '${_displayRadius.round()} كم',
              onChanged: (value) {
                setState(() {
                  _displayRadius = value;
                });
              },
              onChangeEnd: (value) {
                setState(() {
                  _displayRadius = value;
                  radiusKm = value;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _SortChip(
              label: 'الأقرب',
              icon: Icons.location_on,
              isSelected: selectedFilter == SortType.distance,
              onTap: () => _updateFilter(SortType.distance),
            ),
            const SizedBox(width: 8),
            _SortChip(
              label: 'الأعلى تقييماً',
              icon: Icons.star,
              isSelected: selectedFilter == SortType.rating,
              onTap: () => _updateFilter(SortType.rating),
            ),
            const SizedBox(width: 8),
            _SortChip(
              label: 'الأكثر متابعة',
              icon: Icons.people,
              isSelected: selectedFilter == SortType.followers,
              onTap: () => _updateFilter(SortType.followers),
            ),
          ],
        ),
      ),
    );
  }
}

class _SortChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _SortChip({
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
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppThemeConstants.secondary : AppThemeConstants.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppThemeConstants.secondary : AppThemeConstants.outline,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppThemeConstants.secondary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? AppThemeConstants.surface : AppThemeConstants.textPrimary,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? AppThemeConstants.surface : AppThemeConstants.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpecializationChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SpecializationChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isSelected ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppThemeConstants.primary.withValues(alpha: 0.15) : AppThemeConstants.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppThemeConstants.primary : AppThemeConstants.outline,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? AppThemeConstants.primary : AppThemeConstants.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _MohaffezCard extends ConsumerWidget {
  final MohaffezModel mohaffez;
  final double? distance;
  final VoidCallback onTap;

  const _MohaffezCard({
    required this.mohaffez,
    this.distance,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionCountAsync = ref.watch(mohaffezSessionCountProvider(mohaffez.id));

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: AppThemeConstants.elevationSm,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Hero(
                tag: 'mohaffez-${mohaffez.id}',
                child: CachedAvatar(
                  imageUrl: mohaffez.photoUrl,
                  radius: 36,
                  semanticLabel: mohaffez.name,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mohaffez.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (mohaffez.specialization?.isNotEmpty ?? false) ...[
                      const SizedBox(height: 4),
                      Text(
                        mohaffez.specialization!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppThemeConstants.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        if (distance != null) ...[
                          _InfoBadge(
                            icon: Icons.location_on,
                            label: distance! < 1
                                ? '${(distance! * 1000).round()} م'
                                : '${distance!.toStringAsFixed(1)} كم',
                            color: AppThemeConstants.info,
                          ),
                        ],
                        _InfoBadge(
                          icon: Icons.star,
                          label: mohaffez.rating.toStringAsFixed(1),
                          color: AppThemeConstants.secondary,
                        ),
                        _InfoBadge(
                          icon: Icons.people,
                          label: '${mohaffez.followerCount}',
                          color: AppThemeConstants.success,
                        ),
                        sessionCountAsync.when(
                          data: (count) => _InfoBadge(
                            icon: Icons.check_circle,
                            label: '$count جلسة',
                            color: AppThemeConstants.primary,
                          ),
                          loading: () => const SizedBox.shrink(),
                          error: (_, __) => const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: AppThemeConstants.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
