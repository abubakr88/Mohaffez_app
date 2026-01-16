import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/mohaffez_model.dart';

// Provider للحصول على قائمة المحفظين
final nearbyMohaffezProvider = FutureProvider.autoDispose
    .family<List<MohaffezModel>, NearbyParams>((ref, params) async {
  try {
    final firestore = FirebaseFirestore.instance;

    // استعلام للحصول على المحفظين فقط
    final snapshot = await firestore
        .collection('users')
        .where('role', isEqualTo: 'mohaffez')
        .where('addressLat', isNotEqualTo: null)
        .limit(50) // حد أقصى للنتائج
        .get()
        .timeout(const Duration(seconds: 15));

    List<MohaffezModel> mohaffezList = snapshot.docs
        .map((doc) => MohaffezModel.fromFirestore(doc))
        .where((mohaffez) {
          // تصفية المحفظين الذين لديهم إحداثيات صحيحة
          return mohaffez.addressLat != null && mohaffez.addressLng != null;
        })
        .toList();

    // تصفية حسب نطاق المسافة إذا كان موقع المستخدم متاحاً
    if (params.userLat != null && params.userLng != null) {
      mohaffezList = mohaffezList.where((mohaffez) {
        final distance = mohaffez.getDistanceFrom(params.userLat, params.userLng);
        return distance != null && distance <= params.radiusKm;
      }).toList();
    }

    // ترتيب حسب نوع الفلتر
    switch (params.sortBy) {
      case SortType.distance:
        if (params.userLat != null && params.userLng != null) {
          mohaffezList.sort((a, b) {
            final distA = a.getDistanceFrom(params.userLat, params.userLng) ?? double.infinity;
            final distB = b.getDistanceFrom(params.userLat, params.userLng) ?? double.infinity;
            return distA.compareTo(distB);
          });
        }
        break;
      case SortType.rating:
        mohaffezList.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      case SortType.followers:
        mohaffezList.sort((a, b) => b.followerCount.compareTo(a.followerCount));
        break;
    }

    return mohaffezList;
  } catch (e) {
    throw Exception('خطأ في جلب المحفظين القريبين: $e');
  }
});

// معاملات البحث
class NearbyParams {
  final double? userLat;
  final double? userLng;
  final double radiusKm;
  final SortType sortBy;

  NearbyParams({
    this.userLat,
    this.userLng,
    this.radiusKm = 50.0, // 50 كم افتراضياً
    this.sortBy = SortType.distance,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NearbyParams &&
          runtimeType == other.runtimeType &&
          userLat == other.userLat &&
          userLng == other.userLng &&
          radiusKm == other.radiusKm &&
          sortBy == other.sortBy;

  @override
  int get hashCode => Object.hash(userLat, userLng, radiusKm, sortBy);
}

enum SortType { distance, rating, followers }
