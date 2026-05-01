// lib/shared/utils/performance_monitor.dart - NEW FILE
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

class PerformanceMonitor {
  static final PerformanceMonitor _instance = PerformanceMonitor._internal();
  factory PerformanceMonitor() => _instance;
  PerformanceMonitor._internal();

  final List<Duration> _frameDurations = [];
  int _droppedFrames = 0;

  /// Start monitoring frame rate
  void startMonitoring() {
    if (kDebugMode) {
      SchedulerBinding.instance.addTimingsCallback((timings) {
        for (final timing in timings) {
          _frameDurations.add(timing.totalSpan);
          
          // Count dropped frames (> 16ms = 60fps threshold)
          if (timing.totalSpan.inMilliseconds > 16) {
            _droppedFrames++;
          }
        }

        // Keep only last 100 frames
        if (_frameDurations.length > 100) {
          _frameDurations.removeRange(0, _frameDurations.length - 100);
        }
      });
    }
  }

  /// Get average FPS
  double get averageFPS {
    if (_frameDurations.isEmpty) return 0;
    
    final avgDuration = _frameDurations
            .map((d) => d.inMicroseconds)
            .reduce((a, b) => a + b) /
        _frameDurations.length;
    
    return 1000000 / avgDuration; // Convert to FPS
  }

  /// Get dropped frame percentage
  double get droppedFramePercentage {
    if (_frameDurations.isEmpty) return 0;
    return (_droppedFrames / _frameDurations.length) * 100;
  }

  /// Print performance report
  void printReport() {
    if (kDebugMode) {
      debugPrint('📊 Performance Report:');
      debugPrint('   Average FPS: ${averageFPS.toStringAsFixed(1)}');
      debugPrint('   Dropped frames: ${droppedFramePercentage.toStringAsFixed(1)}%');
    }
  }

  /// Reset metrics
  void reset() {
    _frameDurations.clear();
    _droppedFrames = 0;
  }
}
