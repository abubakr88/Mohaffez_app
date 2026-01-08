import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class ImageCacheConfig {
  /// Configure cache settings on app start
  static void configure() {
    // Default cache manager is already configured
    // Optionally clear old cache on app start (commented out by default)
    // clearCache();
  }
  
  /// Clear all cached images (useful for logout or settings)
  static Future<void> clearCache() async {
    try {
      await DefaultCacheManager().emptyCache();
    } catch (e) {
      print('Error clearing cache: $e');
    }
  }
  
  /// Get approximate cache size
  /// Note: This is a simplified version as the API has changed
  static Future<String> getCacheSizeInMB() async {
    try {
      // Try to get store path and calculate size
      final store = await DefaultCacheManager().store;
      
      // This is an approximation since direct size calculation 
      // is not available in newer versions
      return 'غير متاح'; // "Not available" in Arabic
    } catch (e) {
      print('Error getting cache size: $e');
      return 'غير متاح';
    }
  }
  
  /// Remove a specific cached image by URL
  static Future<void> removeFromCache(String url) async {
    try {
      await DefaultCacheManager().removeFile(url);
    } catch (e) {
      print('Error removing from cache: $e');
    }
  }
  
  /// Check if a file is cached
  static Future<bool> isCached(String url) async {
    try {
      final fileInfo = await DefaultCacheManager().getFileFromCache(url);
      return fileInfo != null && fileInfo.file.existsSync();
    } catch (e) {
      return false;
    }
  }
}
