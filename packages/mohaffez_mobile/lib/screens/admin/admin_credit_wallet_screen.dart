// lib/screens/admin/admin_credit_wallet_screen.dart
//
// Admin tool: credit a user's wallet directly. Two flavors:
//  - 'adjustment'   → general refund/correction (sourced from system_topups)
//  - 'promo_credit' → marketing/reward (sourced from system_promos)
//
// Both create a positive ledger entry on the target user's wallet, fully
// audited via reason + admin UID.

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mohaffez_core/mohaffez_core.dart';

import '../../shared/widgets/admin_app_bar.dart';

enum _CreditType { adjustment, promoCredit }

class AdminCreditWalletScreen extends ConsumerStatefulWidget {
  /// Optional: prefill UID + role when navigating from a user detail screen.
  final String? prefilledUserId;
  final String? prefilledUserName;
  final String? prefilledRole;

  const AdminCreditWalletScreen({
    super.key,
    this.prefilledUserId,
    this.prefilledUserName,
    this.prefilledRole,
  });

  @override
  ConsumerState<AdminCreditWalletScreen> createState() =>
      _AdminCreditWalletScreenState();
}

class _AdminCreditWalletScreenState
    extends ConsumerState<AdminCreditWalletScreen> {
  final _formKey = GlobalKey<FormState>();
  final _searchCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  WalletOwnerType _ownerType = WalletOwnerType.student;
  _CreditType _type = _CreditType.adjustment;
  bool _submitting = false;
  bool _searching = false;

  // Search state
  Timer? _searchDebounce;
  List<Map<String, dynamic>> _results = [];

  // Currently selected target
  String? _selectedUserId;
  String? _selectedUserName;
  String? _selectedUserEmail;
  String? _selectedUserRole;

  @override
  void initState() {
    super.initState();
    if (widget.prefilledUserId != null) {
      _selectedUserId = widget.prefilledUserId;
      _selectedUserName = widget.prefilledUserName;
      _selectedUserRole = widget.prefilledRole;
    }
    if (widget.prefilledRole == 'mohaffez') {
      _ownerType = WalletOwnerType.mohaffez;
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    _amountCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    if (value.trim().length < 2) {
      setState(() => _results = []);
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 350), _runSearch);
  }

  /// Fetches up to 50 users, filters client-side by name/email/phone/UID
  /// (Firestore has no native partial-text search). Good enough for early
  /// scale; swap to Algolia/typesense later if user count grows.
  Future<void> _runSearch() async {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) {
      setState(() => _results = []);
      return;
    }
    setState(() => _searching = true);
    try {
      // If the query LOOKS like a UID (>= 20 chars, no spaces), try a direct
      // doc lookup first — much cheaper than a list scan.
      if (q.length >= 20 && !q.contains(' ')) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(q)
            .get();
        if (doc.exists) {
          setState(() {
            _results = [{'id': doc.id, ...doc.data()!}];
            _searching = false;
          });
          return;
        }
      }
      // Otherwise, list scan limited to 50.
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .orderBy('name')
          .limit(50)
          .get();
      final filtered = snap.docs.map((d) => {'id': d.id, ...d.data()}).where((u) {
        final name = (u['name'] as String? ?? '').toLowerCase();
        final email = (u['email'] as String? ?? '').toLowerCase();
        final phone = (u['phone'] as String? ?? '').toLowerCase();
        final id = (u['id'] as String? ?? '').toLowerCase();
        return name.contains(q) ||
            email.contains(q) ||
            phone.contains(q) ||
            id.contains(q);
      }).toList();
      setState(() {
        _results = filtered.take(15).toList();
        _searching = false;
      });
    } catch (e) {
      setState(() => _searching = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppThemeConstants.error,
            content: Text('خطأ في البحث: $e'),
          ),
        );
      }
    }
  }

  void _selectUser(Map<String, dynamic> user) {
    final role = user['role'] as String?;
    setState(() {
      _selectedUserId = user['id'] as String?;
      _selectedUserName = user['name'] as String? ?? '(بدون اسم)';
      _selectedUserEmail = user['email'] as String?;
      _selectedUserRole = role;
      if (role == 'mohaffez') _ownerType = WalletOwnerType.mohaffez;
      if (role == 'student') _ownerType = WalletOwnerType.student;
      _results = [];
      _searchCtrl.clear();
    });
    FocusScope.of(context).unfocus();
  }

  void _clearSelectedUser() {
    setState(() {
      _selectedUserId = null;
      _selectedUserName = null;
      _selectedUserEmail = null;
      _selectedUserRole = null;
    });
  }

  Future<void> _submit() async {
    if (_selectedUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppThemeConstants.warning,
          content: Text('اختر المستخدم أولًا'),
        ),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      await ref.read(walletRepositoryProvider).adminCreditWallet(
            userId: _selectedUserId!,
            ownerType: _ownerType,
            amountEgp: double.parse(_amountCtrl.text.trim()),
            reason: _reasonCtrl.text.trim(),
            type: _type == _CreditType.promoCredit
                ? 'promo_credit'
                : 'adjustment',
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppThemeConstants.success,
          content: Text(
              'تم إضافة ${_amountCtrl.text.trim()} ج.م إلى محفظة ${_selectedUserName ?? _selectedUserId!}'),
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppThemeConstants.error,
          content: Text('تعذر الإضافة: $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppThemeConstants.background,
        appBar: const AdminAppBar(title: 'إضافة رصيد لمحفظة'),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(AppThemeConstants.spaceLg),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Card(
                  title: 'المستخدم',
                  child: Column(
                    children: [
                      if (_selectedUserId == null) ...[
                        TextField(
                          controller: _searchCtrl,
                          onChanged: _onSearchChanged,
                          decoration: InputDecoration(
                            labelText: 'ابحث بالاسم أو البريد أو الهاتف',
                            hintText: 'أو الصق المعرف (UID)',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _searching
                                ? const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    ),
                                  )
                                : null,
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        if (_results.isNotEmpty) ...[
                          const SizedBox(height: AppThemeConstants.spaceSm),
                          _ResultsList(
                            results: _results,
                            onPick: _selectUser,
                          ),
                        ] else if (_searchCtrl.text.trim().length >= 2 &&
                            !_searching) ...[
                          const SizedBox(height: AppThemeConstants.spaceSm),
                          const Text(
                            'لا توجد نتائج',
                            style: TextStyle(
                              color: AppThemeConstants.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ] else ...[
                        _SelectedUserPill(
                          name: _selectedUserName ?? '(بدون اسم)',
                          email: _selectedUserEmail,
                          role: _selectedUserRole,
                          onClear: _clearSelectedUser,
                        ),
                      ],
                      const SizedBox(height: AppThemeConstants.spaceMd),
                      Row(
                        children: [
                          Expanded(
                            child: RadioListTile<WalletOwnerType>(
                              value: WalletOwnerType.student,
                              groupValue: _ownerType,
                              onChanged: (v) =>
                                  setState(() => _ownerType = v!),
                              title: const Text('طالب'),
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              activeColor: AppThemeConstants.primary,
                            ),
                          ),
                          Expanded(
                            child: RadioListTile<WalletOwnerType>(
                              value: WalletOwnerType.mohaffez,
                              groupValue: _ownerType,
                              onChanged: (v) =>
                                  setState(() => _ownerType = v!),
                              title: const Text('محفظ'),
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              activeColor: AppThemeConstants.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppThemeConstants.spaceLg),
                _Card(
                  title: 'نوع الإضافة',
                  child: Column(
                    children: [
                      RadioListTile<_CreditType>(
                        value: _CreditType.adjustment,
                        groupValue: _type,
                        onChanged: (v) => setState(() => _type = v!),
                        title: const Text('استرداد / تسوية'),
                        subtitle: const Text(
                            'لاسترداد مبلغ أو تصحيح خطأ سابق'),
                        contentPadding: EdgeInsets.zero,
                        activeColor: AppThemeConstants.primary,
                      ),
                      RadioListTile<_CreditType>(
                        value: _CreditType.promoCredit,
                        groupValue: _type,
                        onChanged: (v) => setState(() => _type = v!),
                        title: const Text('مكافأة / رصيد ترويجي'),
                        subtitle: const Text(
                            'هدية ترحيب، مكافأة إحالة، عرض ترويجي'),
                        contentPadding: EdgeInsets.zero,
                        activeColor: AppThemeConstants.primary,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppThemeConstants.spaceLg),
                _Card(
                  title: 'المبلغ والسبب',
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _amountCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9.]')),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'المبلغ (ج.م)',
                          prefixIcon: Icon(Icons.payments),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          final n = double.tryParse(v?.trim() ?? '');
                          if (n == null || n <= 0) return 'أدخل مبلغًا صحيحًا';
                          return null;
                        },
                      ),
                      const SizedBox(height: AppThemeConstants.spaceMd),
                      TextFormField(
                        controller: _reasonCtrl,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'سبب الإضافة',
                          hintText:
                              'سجَّل سبب الإضافة بوضوح للمراجعة المستقبلية',
                          alignLabelWithHint: true,
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) =>
                            (v == null || v.trim().length < 3)
                                ? 'السبب مطلوب'
                                : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppThemeConstants.spaceXl),
                SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _submitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppThemeConstants.primary,
                      foregroundColor: AppThemeConstants.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: _submitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppThemeConstants.white),
                          )
                        : const Icon(Icons.add_circle_outline),
                    label: const Text(
                      'إضافة الرصيد',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final String title;
  final Widget child;
  const _Card({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppThemeConstants.spaceMd),
      decoration: BoxDecoration(
        color: AppThemeConstants.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppThemeConstants.grey200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: AppThemeConstants.spaceMd),
          child,
        ],
      ),
    );
  }
}

class _ResultsList extends StatelessWidget {
  final List<Map<String, dynamic>> results;
  final void Function(Map<String, dynamic>) onPick;
  const _ResultsList({required this.results, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppThemeConstants.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppThemeConstants.grey200),
      ),
      child: Column(
        children: [
          for (var i = 0; i < results.length; i++) ...[
            if (i > 0)
              const Divider(height: 1, color: AppThemeConstants.grey200),
            _ResultTile(user: results[i], onTap: () => onPick(results[i])),
          ],
        ],
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  final Map<String, dynamic> user;
  final VoidCallback onTap;
  const _ResultTile({required this.user, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = user['name'] as String? ?? '(بدون اسم)';
    final email = user['email'] as String? ?? '';
    final role = user['role'] as String? ?? '';
    final (roleLabel, roleColor) = switch (role) {
      'student' => ('طالب', AppThemeConstants.primary),
      'mohaffez' => ('محفظ', AppThemeConstants.secondary),
      'admin' => ('أدمن', AppThemeConstants.warning),
      _ => (role, AppThemeConstants.textSecondary),
    };
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppThemeConstants.spaceSm),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                  if (email.isNotEmpty)
                    Text(email,
                        style: const TextStyle(
                            color: AppThemeConstants.textSecondary,
                            fontSize: 12)),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: roleColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(roleLabel,
                  style: TextStyle(
                      color: roleColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 11)),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectedUserPill extends StatelessWidget {
  final String name;
  final String? email;
  final String? role;
  final VoidCallback onClear;
  const _SelectedUserPill({
    required this.name,
    required this.email,
    required this.role,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppThemeConstants.spaceSm),
      decoration: BoxDecoration(
        color: AppThemeConstants.success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: AppThemeConstants.success.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle,
              color: AppThemeConstants.success, size: 22),
          const SizedBox(width: AppThemeConstants.spaceSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14)),
                if (email != null && email!.isNotEmpty)
                  Text(email!,
                      style: const TextStyle(
                          color: AppThemeConstants.textSecondary,
                          fontSize: 12)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            tooltip: 'تغيير',
            onPressed: onClear,
          ),
        ],
      ),
    );
  }
}
