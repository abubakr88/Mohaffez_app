// repositories/user_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import '../models/user_model.dart';
import '../services/cache_service.dart';
import '../services/image_service.dart';

class UserRepository {
  final FirebaseFirestore firestore;
  final FirebaseStorage storage;

  // ✅ In-Memory Cache للمستخدمين
  final Map<String, UserModel> _userMemoryCache = {};
  
  // ✅ Cache Expiry Duration (اختياري - لتحديث الكاش بعد فترة)
  final Map<String, DateTime> _cacheTimestamps = {};
  final Duration _cacheExpiry = const Duration(minutes: 10);

  UserRepository(this.firestore, this.storage);

  /// الحصول على مستخدم بواسطة ID مع الكاش
  Future<UserModel?> getUser(String userId) async {
    try {
      // 1. التحقق من الكاش أولاً
      if (_userMemoryCache.containsKey(userId)) {
        // التحقق من صلاحية الكاش (اختياري)
        final cachedTime = _cacheTimestamps[userId];
        if (cachedTime != null && 
            DateTime.now().difference(cachedTime) < _cacheExpiry) {
          print('📦 User $userId loaded from memory cache');
          return _userMemoryCache[userId];
        } else {
          // الكاش منتهي الصلاحية
          _invalidateUser(userId);
        }
      }

      // 2. جلب من Firestore
      print('🔄 Fetching user $userId from Firestore');
      final doc = await firestore.collection('users').doc(userId).get();
      
      if (!doc.exists) return null;

      final user = UserModel.fromJson({
        ...doc.data()!,
        'uid': doc.id,
      });

      // 3. حفظ في الكاش
      _cacheUser(user);

      // 4. حفظ في CacheService (SharedPreferences)
      await CacheService.saveUserRole(user.role);
      await CacheService.saveUserName(user.name);
      await CacheService.saveUserId(user.uid);

      return user;
    } catch (e) {
      print('❌ Error getting user: $e');
      return null;
    }
  }

  /// مراقبة تغييرات المستخدم في الوقت الفعلي
  Stream<UserModel?> watchUser(String userId) {
    return firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;

      final user = UserModel.fromJson({
        ...doc.data()!,
        'uid': doc.id,
      });

      // تحديث الكاش عند كل تغيير
      _cacheUser(user);

      return user;
    });
  }

  /// تحديث بيانات المستخدم
  Future<void> updateProfile({
    required String userId,
    required Map<String, dynamic> updates,
  }) async {
    try {
      await firestore.collection('users').doc(userId).update(updates);

      // ✅ تحديث الكاش المحلي
      if (_userMemoryCache.containsKey(userId)) {
        // إزالة من الكاش ليتم جلبه محدثاً في المرة القادمة
        _invalidateUser(userId);
        print('🔄 Cache invalidated for user $userId after update');
      }
    } catch (e) {
      print('❌ Error updating profile: $e');
      rethrow;
    }
  }

  /// رفع وتحديث صورة الملف الشخصي مع الضغط
  Future<String> uploadProfilePhoto(String userId, File imageFile) async {
    try {
      // 1. ضغط الصورة قبل الرفع (توفير bandwidth وتسريع)
      print('🖼️ Compressing image...');
      final compressedFile = await ImageService.compressImage(
        imageFile,
        quality: 75, // جودة 75% مناسبة للصور الشخصية
      );

      // 2. رفع إلى Firebase Storage
      print('☁️ Uploading to Firebase Storage...');
      final storageRef = storage.ref().child('user_photos').child('$userId.jpg');
      await storageRef.putFile(compressedFile);
      
      // 3. الحصول على URL
      final url = await storageRef.getDownloadURL();

      // 4. تحديث في Firestore
      await updateProfile(
        userId: userId,
        updates: {'photoUrl': url},
      );

      print('✅ Profile photo uploaded successfully');
      return url;
    } catch (e) {
      print('❌ Error uploading profile photo: $e');
      rethrow;
    }
  }

  /// تحديث موقع المستخدم
  Future<void> updateLocation({
    required String userId,
    required String addressText,
    required double lat,
    required double lng,
  }) async {
    try {
      await firestore.collection('users').doc(userId).update({
        'addressText': addressText,
        'addressLat': lat,
        'addressLng': lng,
      });

      // حفظ في الكاش المحلي
      await CacheService.saveLastLocation(lat, lng);

      // إبطال كاش المستخدم
      _invalidateUser(userId);

      print('✅ Location updated successfully');
    } catch (e) {
      print('❌ Error updating location: $e');
      rethrow;
    }
  }

  /// تحديث البيانات في الخلفية (Silent Refresh)
  Future<void> refreshUser(String userId) async {
    try {
      await getUser(userId);
    } catch (e) {
      print('⚠️ Background refresh failed: $e');
      // لا نرمي الخطأ لأنه تحديث صامت
    }
  }

  // ==================== Private Helper Methods ====================

  /// حفظ المستخدم في الكاش
  void _cacheUser(UserModel user) {
    _userMemoryCache[user.uid] = user;
    _cacheTimestamps[user.uid] = DateTime.now();
    print('💾 User ${user.uid} cached in memory');
  }

  /// إبطال كاش المستخدم (إزالة من الذاكرة)
  void _invalidateUser(String userId) {
    _userMemoryCache.remove(userId);
    _cacheTimestamps.remove(userId);
    print('🗑️ Cache invalidated for user $userId');
  }

  /// مسح كل الكاش (عند تسجيل الخروج)
  void clearCache() {
    _userMemoryCache.clear();
    _cacheTimestamps.clear();
    print('🧹 All user cache cleared');
  }

  /// الحصول على حجم الكاش الحالي
  int getCacheSize() {
    return _userMemoryCache.length;
  }

  /// التحقق من وجود مستخدم في الكاش
  bool isUserCached(String userId) {
    return _userMemoryCache.containsKey(userId);
  }

  /// إعادة تحميل مستخدم معين من Firestore (تجاهل الكاش)
  Future<UserModel?> forceRefreshUser(String userId) async {
    _invalidateUser(userId);
    return await getUser(userId);
  }

  // ==================== Batch Operations ====================

  /// جلب عدة مستخدمين دفعة واحدة
  Future<Map<String, UserModel>> getUsersBatch(List<String> userIds) async {
    final Map<String, UserModel> results = {};

    // 1. جمع المستخدمين من الكاش أولاً
    final List<String> idsToFetch = [];
    for (final id in userIds) {
      if (_userMemoryCache.containsKey(id)) {
        results[id] = _userMemoryCache[id]!;
      } else {
        idsToFetch.add(id);
      }
    }

    // 2. جلب الباقي من Firestore
    if (idsToFetch.isNotEmpty) {
      try {
        // Firestore limitation: max 10 items in whereIn
        final chunks = _chunkList(idsToFetch, 10);
        
        for (final chunk in chunks) {
          final snapshot = await firestore
              .collection('users')
              .where(FieldPath.documentId, whereIn: chunk)
              .get();

          for (final doc in snapshot.docs) {
            if (doc.exists) {
              final user = UserModel.fromJson({
                ...doc.data(),
                'uid': doc.id,
              });
              results[doc.id] = user;
              _cacheUser(user);
            }
          }
        }
      } catch (e) {
        print('❌ Error fetching users batch: $e');
      }
    }

    return results;
  }

  /// تقسيم قائمة إلى أجزاء (Helper للـ Batch Operations)
  List<List<T>> _chunkList<T>(List<T> list, int chunkSize) {
    final List<List<T>> chunks = [];
    for (var i = 0; i < list.length; i += chunkSize) {
      chunks.add(
        list.sublist(i, i + chunkSize > list.length ? list.length : i + chunkSize),
      );
    }
    return chunks;
  }

  // ==================== Analytics & Monitoring ====================

  /// طباعة إحصائيات الكاش (للتطوير والتصحيح)
  void printCacheStats() {
    print('''
    📊 User Cache Statistics:
    - Total cached users: ${_userMemoryCache.length}
    - Cache expiry duration: ${_cacheExpiry.inMinutes} minutes
    - Users in cache: ${_userMemoryCache.keys.join(', ')}
    ''');
  }
}
