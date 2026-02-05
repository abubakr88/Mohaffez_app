import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../shared/constants/app_theme.dart';
import '../shared/widgets/cached_avatar.dart';
import '../shared/widgets/empty_state.dart';
import '../shared/widgets/error_widgets.dart';
import '../providers/mohaffez_provider.dart';
import '../models/mohaffez_model.dart';

class NearbyMohaffezScreen extends ConsumerStatefulWidget {
  const NearbyMohaffezScreen({super.key});

  @override
  ConsumerState<NearbyMohaffezScreen> createState() => _NearbyMohaffezScreenState();
}

class _NearbyMohaffezScreenState extends ConsumerState<NearbyMohaffezScreen> {
  SortType selectedFilter = SortType.distance;
  double? userLat;
  double? userLng;
  bool isLoadingLocation = true;
  String? locationError;
  double radiusKm = 50.0;

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

  @override
  Widget build(BuildContext context) {
    final params = NearbyParams(
      userLat: userLat,
      userLng: userLng,
      radiusKm: radiusKm,
      sortBy: selectedFilter,
    );

    final mohaffezAsync = ref.watch(nearbyMohaffezProvider(params));

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: CustomScrollView(
          slivers: [
            _buildAppBar(context),
            if (isLoadingLocation || locationError != null)
              SliverToBoxAdapter(
                child: _buildLocationBanner(),
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
                        final distance = mohaffez.getDistanceFrom(userLat, userLng);

                        return MohaffezCard(
                          mohaffez: mohaffez,
                          distance: distance,
                          onTap: () => context.go('/mohaffez/${mohaffez.id}', extra: {
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
              loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, stack) => SliverFillRemaining(
                child: ErrorDisplay.dataLoad(
                  onRetry: () => ref.invalidate(nearbyMohaffezProvider),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 120,
      floating: true,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.primaryAmber, AppTheme.lightAmber],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 16, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.location_searching,
                          size: 28,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'المحفظون القريبون',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'ابحث عن محفظ قريب منك',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.my_location, color: Colors.white),
                        onPressed: _getCurrentLocation,
                        tooltip: 'تحديث الموقع',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLocationBanner() {
    if (isLoadingLocation) {
      return Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue.shade200),
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
              'جاري تحديد موقعك...',
              style: TextStyle(fontSize: 14, color: Colors.blue),
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
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber, color: Colors.orange),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'تعذر تحديد موقعك. يرجى التحقق من إعدادات الموقع.',
                style: TextStyle(fontSize: 13, color: Colors.orange),
              ),
            ),
            TextButton(
              onPressed: _getCurrentLocation,
              child: const Text('إعادة المحاولة'),
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryAmber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${radiusKm.round()} كم',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryAmber,
                  ),
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppTheme.primaryAmber,
              inactiveTrackColor: Colors.grey.shade300,
              thumbColor: AppTheme.primaryAmber,
              overlayColor: AppTheme.primaryAmber.withValues(alpha: 0.2),
            ),
            child: Slider(
              value: radiusKm,
              min: 5,
              max: 100,
              divisions: 19,
              label: '${radiusKm.round()} كم',
              onChanged: (value) {
                setState(() {
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
            _FilterChip(
              label: 'الأقرب',
              icon: Icons.location_on,
              isSelected: selectedFilter == SortType.distance,
              onTap: () => _updateFilter(SortType.distance),
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: 'الأعلى تقييماً',
              icon: Icons.star,
              isSelected: selectedFilter == SortType.rating,
              onTap: () => _updateFilter(SortType.rating),
            ),
            const SizedBox(width: 8),
            _FilterChip(
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

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
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
          color: isSelected ? AppTheme.primaryAmber : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppTheme.primaryAmber : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.primaryAmber.withValues(alpha: 0.3),
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
              color: isSelected ? Colors.white : Colors.grey.shade700,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.white : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MohaffezCard extends StatelessWidget {
  final MohaffezModel mohaffez;
  final double? distance;
  final VoidCallback onTap;

  const MohaffezCard({
    super.key,
    required this.mohaffez,
    this.distance,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
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
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (distance != null) ...[
                          _InfoBadge(
                            icon: Icons.location_on,
                            label: distance! < 1
                                ? '${(distance! * 1000).round()} م'
                                : '${distance!.toStringAsFixed(1)} كم',
                            color: Colors.blue,
                          ),
                          const SizedBox(width: 12),
                        ],
                        _InfoBadge(
                          icon: Icons.star,
                          label: mohaffez.rating.toStringAsFixed(1),
                          color: Colors.amber,
                        ),
                        const SizedBox(width: 12),
                        _InfoBadge(
                          icon: Icons.people,
                          label: '${mohaffez.followerCount}',
                          color: Colors.green,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey.shade400,
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
