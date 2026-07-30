import 'dart:developer' as developer;

/// Measures selected user workflows during performance testing.
///
/// Each measurement creates an asynchronous event in Flutter DevTools and
/// writes the elapsed duration to the console in milliseconds. Run the app in
/// profile mode when collecting results:
///
/// ```bash
/// flutter run --profile
/// ```
///
/// Cold startup is deliberately not measured here. Record it separately with
/// Android Time to Initial Display (TTID) from the Logcat `Displayed` value.
///
/// Example:
/// ```dart
/// await PerformanceTracker.measure(
///   'DASHBOARD_LOAD',
///   () async {
///     await loadDashboardData();
///     loading.value = false;
///     await WidgetsBinding.instance.endOfFrame;
///   },
/// );
/// ```
class PerformanceTracker {
  PerformanceTracker._();

  /// Executes [action], then records its elapsed duration.
  ///
  /// The action must include the complete user-visible workflow. For screen
  /// loading, set the loading state to false and wait for the next frame before
  /// the action returns so the measured result represents displayed content.
  static Future<T> measure<T>(
    String label,
    Future<T> Function() action,
  ) async {
    final stopwatch = Stopwatch()..start();
    final timelineTask = developer.TimelineTask()..start(label);

    try {
      return await action();
    } finally {
      timelineTask.finish();
      stopwatch.stop();

      final result = '${stopwatch.elapsedMilliseconds} ms';

      developer.log(
        '${stopwatch.elapsedMilliseconds} ms',
        name: 'PERF_$label',
      );
      // Temporary console output for performance-test evidence.
      print('PERF_$label: $result');

      
    }
  }
}
