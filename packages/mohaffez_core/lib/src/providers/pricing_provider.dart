import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/pricing_plan_model.dart';
import '../repositories/pricing_repository.dart';
import 'auth_provider.dart';

// Repository provider (already exists)
final pricingRepositoryProvider = Provider<PricingRepository>((ref) {
  return PricingRepository(FirebaseFirestore.instance);
});

// Plans stream providers (already exist)
final pricingPlansProvider = StreamProvider.autoDispose
    .family<List<PricingPlanModel>, String>((ref, mohaffezId) {
  final authAsync = ref.watch(authStateProvider);
  if (authAsync.isLoading || authAsync.value == null) {
    return const Stream.empty();
  }

  final repository = ref.watch(pricingRepositoryProvider);
  return repository.watchMohaffezPlans(mohaffezId);
});

final activePricingPlansProvider = StreamProvider.autoDispose
    .family<List<PricingPlanModel>, String>((ref, mohaffezId) {
  final authAsync = ref.watch(authStateProvider);
  if (authAsync.isLoading || authAsync.value == null) {
    return const Stream.empty();
  }

  final repository = ref.watch(pricingRepositoryProvider);
  return repository.watchActivePlans(mohaffezId);
});

// **ADD THIS: Actions Provider (StateNotifierProvider)**
final pricingActionsProvider =
    StateNotifierProvider<PricingActionsNotifier, AsyncValue<void>>((ref) {
  return PricingActionsNotifier(ref);
});

// **ADD THIS: Actions Notifier Class**
class PricingActionsNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref ref;

  PricingActionsNotifier(this.ref) : super(const AsyncValue.data(null));

  Future<void> createPlan(PricingPlanModel plan) async {
    state = const AsyncValue.loading();
    try {
      await ref.read(pricingRepositoryProvider).createPlan(plan);
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> updatePlan(PricingPlanModel plan) async {
    state = const AsyncValue.loading();
    try {
      await ref.read(pricingRepositoryProvider).updatePlan(plan);
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> deletePlan(String planId, String mohaffezId) async {
    state = const AsyncValue.loading();
    try {
      await ref.read(pricingRepositoryProvider).deletePlan(mohaffezId, planId);
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> updatePlanStatus(
      String mohaffezId, String planId, bool isActive) async {
    state = const AsyncValue.loading();
    try {
      await ref
          .read(pricingRepositoryProvider)
          .togglePlanStatus(mohaffezId, planId, isActive);
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }
}
