import 'dart:async';

/// Debouncer utility for delaying function execution
class Debouncer {
  final Duration delay;
  Timer? _timer;

  Debouncer({required this.delay});

  /// Run the callback after delay
  void run(void Function() action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  /// Cancel the current timer
  void cancel() {
    _timer?.cancel();
  }

  /// Dispose the debouncer
  void dispose() {
    _timer?.cancel();
  }
}

/// EXAMPLE USAGE:
///
/// ```dart
/// class SearchScreen extends StatefulWidget {
///   const SearchScreen({super.key});
///
///   @override
///   State<SearchScreen> createState() => _SearchScreenState();
/// }
///
/// class _SearchScreenState extends State<SearchScreen> {
///   final _debouncer = Debouncer(delay: const Duration(milliseconds: 500));
///   final _searchController = TextEditingController();
///
///   @override
///   void dispose() {
///     _debouncer.dispose();
///     _searchController.dispose();
///     super.dispose();
///   }
///
///   void _onSearchChanged(String query) {
///     _debouncer.run(() {
///       // Perform search after 500ms of no typing
///       print('Searching for: $query');
///     });
///   }
///
///   @override
///   Widget build(BuildContext context) {
///     return TextField(
///       controller: _searchController,
///       onChanged: _onSearchChanged,
///       decoration: const InputDecoration(
///         labelText: 'Search',
///       ),
///     );
///   }
/// }
/// ```
