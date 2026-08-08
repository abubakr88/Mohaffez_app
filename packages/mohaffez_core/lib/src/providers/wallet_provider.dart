// lib/providers/wallet_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/payout_request_model.dart';
import '../models/wallet_model.dart';
import '../models/wallet_transaction_model.dart';
import '../repositories/wallet_repository.dart';

/// Wallet balance stream for the given user.
/// Caller passes [WalletOwnerType] so a missing-wallet placeholder can be
/// constructed without round-tripping to Firestore.
final walletProvider = StreamProvider.autoDispose
    .family<WalletModel, ({String userId, WalletOwnerType ownerType})>(
  (ref, params) => ref
      .read(walletRepositoryProvider)
      .watchWallet(params.userId, params.ownerType),
);

/// Recent ledger entries for the user's wallet, newest first.
final walletTransactionsProvider =
    StreamProvider.autoDispose.family<List<WalletTransactionModel>, String>(
  (ref, userId) => ref.read(walletRepositoryProvider).watchTransactions(userId),
);

/// All payout requests for a teacher (any status).
final payoutRequestsProvider =
    StreamProvider.autoDispose.family<List<PayoutRequestModel>, String>(
  (ref, mohaffezId) =>
      ref.read(walletRepositoryProvider).watchPayoutRequests(mohaffezId),
);

// ──────────────── admin queues ────────────────

/// Pending top-up requests for the admin verification queue.
/// Each entry is the raw doc as a Map (no model — fields are admin-facing
/// metadata: userId, amountEgp, method, referenceNumber, proofUrl, etc).
final pendingTopUpsProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>(
  (ref) => ref.read(walletRepositoryProvider).watchPendingTopUps(),
);

/// Active payouts (requested + processing) for the admin queue.
final activePayoutsProvider =
    StreamProvider.autoDispose<List<PayoutRequestModel>>(
  (ref) => ref.read(walletRepositoryProvider).watchActivePayouts(),
);
