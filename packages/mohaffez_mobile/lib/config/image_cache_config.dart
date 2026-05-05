import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class ImageCacheConfig {
  /// Configure cache settings on app start
  static void configure() {
    // Default cache manager is already configured
    // CachedNetworkImage will use this automatically
  }
  
  /// Clear all cached images (useful for logout or settings)
  static Future<void> clearCache() async {
    try {
      await DefaultCacheManager().emptyCache();
      debugPrint('Cache cleared successfully');
    } catch (e) {
      debugPrint('Error clearing cache: $e');
    }
  }
  
  /// Get approximate cache size (simplified - returns "غير متاح")
  /// Note: Direct cache size calculation is not available in newer versions
  static Future<String> getCacheSizeInMB() async {
    try {
      // The new API doesn't expose direct file size calculation
      // You would need to implement custom cache manager for this
      return 'غير متاح'; // "Not available" in Arabic
    } catch (e) {
      debugPrint('Error getting cache size: $e');
      return 'غير متاح';
    }
  }
  
  /// Remove a specific cached image by URL
  static Future<void> removeFromCache(String url) async {
    try {
      await DefaultCacheManager().removeFile(url);
      debugPrint('File removed from cache: $url');
    } catch (e) {
      debugPrint('Error removing from cache: $e');
    }
  }
  
  /// Check if a file is cached
  static Future<bool> isCached(String url) async {
    try {
      final fileInfo = await DefaultCacheManager().getFileFromCache(url);
      return fileInfo != null && fileInfo.file.existsSync();
    } catch (e) {
      debugPrint('Error checking cache: $e');
      return false;
    }
  }
  
  /// Download and cache a file
  static Future<void> preloadImage(String url) async {
    try {
      await DefaultCacheManager().downloadFile(url);
      debugPrint('Image preloaded: $url');
    } catch (e) {
      debugPrint('Error preloading image: $e');
    }
  }
  
  /// Get cached file info
  static Future<String?> getCachedFilePath(String url) async {
    try {
      final fileInfo = await DefaultCacheManager().getFileFromCache(url);
      return fileInfo?.file.path;
    } catch (e) {
      debugPrint('Error getting cached file: $e');
      return null;
    }
  }
}
