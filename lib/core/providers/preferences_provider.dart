import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Provides the SharedPreferences instance synchronously.
// We override this provider in the top-level ProviderScope.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider must be overridden');
});

// A notifier to manage the set of reviewed AssetEntity ids.
class ReviewedIdsNotifier extends Notifier<Set<String>> {
  static const _key = 'reviewed_ids';

  @override
  Set<String> build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final storedList = prefs.getStringList(_key) ?? [];
    return storedList.toSet();
  }

  void addIds(Iterable<String> ids) {
    if (ids.isEmpty) return;
    final prefs = ref.read(sharedPreferencesProvider);
    final nextSet = Set<String>.from(state)..addAll(ids);
    state = nextSet;
    prefs.setStringList(_key, nextSet.toList());
  }

  void removeIds(Iterable<String> ids) {
    if (ids.isEmpty) return;
    final prefs = ref.read(sharedPreferencesProvider);
    final nextSet = Set<String>.from(state)..removeAll(ids);
    state = nextSet;
    prefs.setStringList(_key, nextSet.toList());
  }
}

final reviewedIdsProvider = NotifierProvider<ReviewedIdsNotifier, Set<String>>(
  ReviewedIdsNotifier.new,
);
