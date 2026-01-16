import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../shared/constants/app_theme.dart';
import '../shared/widgets/cached_avatar.dart';

class NearbyMohaffezScreen extends ConsumerStatefulWidget {
  final double? userLat;
  final double? userLng;

  const NearbyMohaffezScreen({super.key, this.userLat, this.userLng});

  @override
  ConsumerState<NearbyMohaffezScreen> createState() => _NearbyMohaffezScreenState();
}

class _NearbyMohaffezScreenState extends ConsumerState<NearbyMohaffezScreen> {
  String selectedFilter = 'distance'; // distance, rating, followers

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: CustomScrollView(
          slivers: [
            // Search AppBar
            SliverAppBar(
              expandedHeight: 120,
              floating: true,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppTheme.primaryAmber, AppTheme.lightAmber],
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          const Text(
                            'ابحث عن محفظ قريب',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'اعثر على معلم القرآن المناسب',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Filter Chips
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChip(
                        label: 'الأقرب',
                        icon: Icons.location_on,
                        isSelected: selectedFilter == 'distance',
                        onTap: () => setState(() => selectedFilter = 'distance'),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'الأعلى تقييماً',
                        icon: Icons.star,
                        isSelected: selectedFilter == 'rating',
                        onTap: () => setState(() => selectedFilter = 'rating'),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'الأكثر متابعة',
                        icon: Icons.people,
                        isSelected: selectedFilter == 'followers',
                        onTap: () => setState(() => selectedFilter = 'followers'),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Mohaffez List
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    // Mock data - replace with actual provider
                    return _MohaffezCard(
                      name: 'الشيخ محمد أحمد',
                      specialization: 'متخصص في التجويد والقراءات',
                      distance: 2.5,
                      rating: 4.8,
                      followerCount: 120,
                      photoUrl: null,
                      onTap: () {
                        // Navigate to profile
                      },
                    );
                  },
                  childCount: 5, // Replace with actual count
                ),
              ),
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
      onTap: onTap,
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
                    color: AppTheme.primaryAmber.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
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

class _MohaffezCard extends StatelessWidget {
  final String name;
  final String? specialization;
  final double distance;
  final double rating;
  final int followerCount;
  final String? photoUrl;
  final VoidCallback onTap;

  const _MohaffezCard({
    required this.name,
    this.specialization,
    required this.distance,
    required this.rating,
    required this.followerCount,
    this.photoUrl,
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
                tag: 'mohaffez_$name',
                child: CachedAvatar(
                  imageUrl: photoUrl,
                  radius: 36,
                  semanticLabel: name,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (specialization?.isNotEmpty ?? false) ...[
                      const SizedBox(height: 4),
                      Text(
                        specialization!,
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
                        _InfoBadge(
                          icon: Icons.location_on,
                          label: distance < 1
                              ? '${(distance * 1000).round()} م'
                              : '${distance.toStringAsFixed(1)} كم',
                          color: Colors.blue,
                        ),
                        const SizedBox(width: 12),
                        _InfoBadge(
                          icon: Icons.star,
                          label: rating.toStringAsFixed(1),
                          color: Colors.amber,
                        ),
                        const SizedBox(width: 12),
                        _InfoBadge(
                          icon: Icons.people,
                          label: '$followerCount',
                          color: Colors.green,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey.shade400),
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
        color: color.withOpacity(0.1),
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
