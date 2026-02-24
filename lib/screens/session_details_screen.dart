// lib/screens/session_details_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../models/session_model.dart' hide MistakeTypeExtensions;
import '../models/quran_mistake_model.dart';
import '../utils/quran_mistake_utils.dart';
import '../shared/constants/app_theme.dart';
import '../providers/user_provider.dart';
import '../providers/session_provider_paginated.dart';
import '../shared/widgets/interactive_quran_page.dart';
import 'rate_session_screen.dart';

class SessionDetailsScreen extends ConsumerStatefulWidget {
  final SessionModel session;

  const SessionDetailsScreen({super.key, required this.session});

  @override
  ConsumerState<SessionDetailsScreen> createState() =>
      _SessionDetailsScreenState();
}

class _SessionDetailsScreenState extends ConsumerState<SessionDetailsScreen> {
  // â”€â”€ Quran mistakes state â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  List<QuranMistake> _loadedMistakes = [];
  bool _mistakesLoading = true;
  int _moshafStartPage = 1;

  @override
  void initState() {
    super.initState();
    _loadQuranMistakes();
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // LOAD MISTAKES FROM FIRESTORE
  // Mistakes may already be embedded in session.mistakes (teacher view) or need
  // to be fetched from the hafizSessions doc (student view reads them fresh).
  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<void> _loadQuranMistakes() async {
    // Use in-model list first (avoids an extra read when teacher opens the screen)
    if (widget.session.mistakes.isNotEmpty) {
      setState(() {
        _loadedMistakes = widget.session.mistakes;
        _moshafStartPage = widget.session.mistakes.first.pageNumber;
        _mistakesLoading = false;
      });
      return;
    }

    final sessionId = widget.session.id;
    if (sessionId == null || sessionId.isEmpty) {
      setState(() => _mistakesLoading = false);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('hafizSessions')
          .doc(sessionId)
          .get();

      final data = doc.data();
      if (data == null) {
        setState(() => _mistakesLoading = false);
        return;
      }

      final raw = data['quranMistakes'];
      if (raw is List && raw.isNotEmpty) {
        final mistakes = raw
            .whereType<Map<String, dynamic>>()
            .map(QuranMistake.fromMap)
            .toList();
        setState(() {
          _loadedMistakes = mistakes;
          _moshafStartPage = mistakes.first.pageNumber;
          _mistakesLoading = false;
        });
      } else {
        setState(() => _mistakesLoading = false);
      }
    } catch (e) {
      debugPrint('SessionDetails: failed to load quran mistakes: $e');
      setState(() => _mistakesLoading = false);
    }
  }

  Future<void> _refreshScreen() async {
    ref.invalidate(currentUserProvider);
    await ref.read(currentUserProvider.future).catchError((_) => null);
    await _loadQuranMistakes();
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // OPEN READ-ONLY MOSHAF
  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  void _openReadOnlyMoshaf() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            appBar: AppBar(
              leading: context.canPop()
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back_ios),
                      onPressed: () => context.pop(),
                      tooltip: 'Ø±Ø¬ÙˆØ¹',
                    )
                  : null,
              title: const Text('Ù…Ø±Ø§Ø¬Ø¹Ø© Ø§Ù„ØªÙ„Ø§ÙˆØ©'),
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
            ),
            body: InteractiveQuranPage(
              pageNumber: _moshafStartPage,
              existingMistakes: _loadedMistakes,
              onMistakeAdded: (_) {}, // read-only â€” no-op
              isEditable: false,
              onPageChanged: (p) => setState(() => _moshafStartPage = p),
            ),
          ),
        ),
      ),
    );
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // BUILD
  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildMoshafButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _openReadOnlyMoshaf,
        icon: const Icon(Icons.menu_book),
        label: const Text('فتح المصحف'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green.shade700,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider).value;
    final isMohaffez = currentUser?.role == 'mohaffez';
    final isStudent = currentUser?.role == 'student';
    final session = widget.session;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: RefreshIndicator(
          onRefresh: _refreshScreen,
          child: CustomScrollView(
            slivers: [
              // â”€â”€ App Bar â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
              SliverAppBar(
                expandedHeight: 130,
                pinned: true,
                leading: context.canPop()
                    ? IconButton(
                        icon: const Icon(Icons.arrow_back_ios),
                        onPressed: () => context.pop(),
                        tooltip: 'Ø±Ø¬ÙˆØ¹',
                      )
                    : null,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: 'ØªØ­Ø¯ÙŠØ«',
                    onPressed: _refreshScreen,
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppTheme.primaryAmber, AppTheme.lightAmber],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 16, 12),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Hero(
                                  tag: 'session_${session.id}',
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: const Icon(Icons.school,
                                        size: 32, color: Colors.white),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        isMohaffez
                                            ? session.studentName
                                            : session.mohaffezName,
                                        style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.2),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          _getStatusLabel(session.status ?? ''),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // â”€â”€ Content â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Session Info
                    _SectionCard(
                      title: 'Ù…Ø¹Ù„ÙˆÙ…Ø§Øª Ø§Ù„Ø¬Ù„Ø³Ø©',
                      icon: Icons.info_outline,
                      color: Colors.blue,
                      child: Column(
                        children: [
                          _InfoRow(
                            icon: Icons.event,
                            label: 'Ø§Ù„Ù†ÙˆØ¹',
                            value: _getSessionTypeLabel(session.sessionType),
                          ),
                          if (session.preferredTimeSlot != null) ...[
                            const Divider(height: 24),
                            _InfoRow(
                              icon: Icons.access_time,
                              label: 'Ø§Ù„ÙˆÙ‚Øª',
                              value: session.preferredTimeSlot!,
                            ),
                          ],
                          if (session.sessionDate != null) ...[
                            const Divider(height: 24),
                            _InfoRow(
                              icon: Icons.calendar_today,
                              label: 'Ø§Ù„ØªØ§Ø±ÙŠØ®',
                              value: DateFormat('dd MMMM yyyy', 'ar')
                                  .format(session.sessionDate!),
                            ),
                          ],
                          if (session.location.isNotEmpty) ...[
                            const Divider(height: 24),
                            _InfoRow(
                              icon: Icons.location_on,
                              label: 'Ø§Ù„Ù…ÙƒØ§Ù†',
                              value: session.location,
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Assignments
                    if ((session.hifzAssignment?.isNotEmpty ?? false) ||
                        (session.murajaAssignment?.isNotEmpty ?? false))
                      _SectionCard(
                        title: 'Ø§Ù„ÙˆØ§Ø¬Ø¨Ø§Øª',
                        icon: Icons.assignment,
                        color: AppTheme.accentGreen,
                        child: Column(
                          children: [
                            if (session.hifzAssignment?.isNotEmpty ?? false)
                              _AssignmentCard(
                                title: 'Ø­ÙØ¸',
                                content: session.hifzAssignment!,
                                color: Colors.green,
                                icon: Icons.book,
                              ),
                            if ((session.hifzAssignment?.isNotEmpty ?? false) &&
                                (session.murajaAssignment?.isNotEmpty ?? false))
                              const SizedBox(height: 12),
                            if (session.murajaAssignment?.isNotEmpty ?? false)
                              _AssignmentCard(
                                title: 'Ù…Ø±Ø§Ø¬Ø¹Ø©',
                                content: session.murajaAssignment!,
                                color: Colors.blue,
                                icon: Icons.refresh,
                              ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 16),

                    // Rating
                    if (session.sessionRating > 0)
                      _SectionCard(
                        title: 'Ø§Ù„ØªÙ‚ÙŠÙŠÙ…',
                        icon: Icons.star,
                        color: Colors.amber,
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '${session.sessionRating}/10',
                                  style: const TextStyle(
                                    fontSize: 48,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(10, (index) {
                                return Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 2),
                                  child: Icon(
                                    index < session.sessionRating
                                        ? Icons.star
                                        : Icons.star_border,
                                    color: Colors.amber,
                                    size: 28,
                                  ),
                                );
                              }),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 16),

                    // Performance notes
                    if (session.performanceNotes?.isNotEmpty ?? false)
                      _SectionCard(
                        title: 'Ù…Ù„Ø§Ø­Ø¸Ø§Øª Ø¹Ù„Ù‰ Ø§Ù„ØªÙƒÙ„ÙŠÙ Ø§Ù„Ø³Ø§Ø¨Ù‚',
                        icon: Icons.fact_check,
                        color: Colors.teal,
                        child: Text(
                          session.performanceNotes!,
                          style: const TextStyle(fontSize: 15, height: 1.6),
                        ),
                      ),

                    const SizedBox(height: 16),

                    // Session notes
                    if (session.sessionNotes?.isNotEmpty ?? false)
                      _SectionCard(
                        title: 'Ù…Ù„Ø§Ø­Ø¸Ø§Øª',
                        icon: Icons.notes,
                        color: Colors.purple,
                        child: Text(
                          session.sessionNotes!,
                          style: const TextStyle(fontSize: 15, height: 1.6),
                        ),
                      ),

                    const SizedBox(height: 16),

                    // â”€â”€ Quran Mistakes Section â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                    _buildQuranMistakesSection(isMohaffez: isMohaffez),

                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildMoshafButton(),
                    ),

                    const SizedBox(height: 32),
                  ]),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: _buildBottomNavigationBar(
          isMohaffez: isMohaffez,
          isStudent: isStudent,
          session: session,
        ),
      ),
    );
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // QURAN MISTAKES SECTION
  // Teacher: full list grouped by page + open-on-moshaf button
  // Student: stat summary + open-on-moshaf button (loads from Firestore)
  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildQuranMistakesSection({required bool isMohaffez}) {
    // Still fetching
    if (_mistakesLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    // Nothing recorded
    if (_loadedMistakes.isEmpty) return const SizedBox.shrink();

    return _SectionCard(
      title: 'ØªÙ„Ø§ÙˆØ© Ø§Ù„Ø¬Ù„Ø³Ø©',
      icon: Icons.menu_book,
      color: Colors.green.shade700,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // â”€â”€ Stats row â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          _buildMistakeStatsRow(),

          const SizedBox(height: 16),

          // â”€â”€ Type breakdown chips â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          _buildTypeBreakdownChips(),

          const Divider(height: 28),

          // â”€â”€ Teacher: full list grouped by page â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          if (isMohaffez) _buildGroupedMistakeList(),

          // â”€â”€ Student: summary tiles (tap to see detail) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          if (!isMohaffez) _buildStudentMistakeTiles(),
        ],
      ),
    );
  }

  // Stats: total + with-comment count
  Widget _buildMistakeStatsRow() {
    final withComment = countWithComments(_loadedMistakes);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _StatCell(
            icon: Icons.warning_amber_rounded,
            color: Colors.orange,
            label: 'Ø¥Ø¬Ù…Ø§Ù„ÙŠ Ø§Ù„Ù…Ù„Ø§Ø­Ø¸Ø§Øª',
            value: '${_loadedMistakes.length}',
          ),
          Container(width: 1, height: 36, color: Colors.green.shade200),
          _StatCell(
            icon: Icons.chat_bubble,
            color: Colors.blue.shade700,
            label: 'Ù…Ø¹ ØªØ¹Ù„ÙŠÙ‚',
            value: '$withComment',
          ),
          Container(width: 1, height: 36, color: Colors.green.shade200),
          _StatCell(
            icon: Icons.auto_stories,
            color: Colors.green.shade700,
            label: 'ØµÙØ­Ø§Øª Ù…Ø®ØªÙ„ÙØ©',
            value: '${_loadedMistakes.map((m) => m.pageNumber).toSet().length}',
          ),
        ],
      ),
    );
  }

  // Chips: one per mistake type with count
  Widget _buildTypeBreakdownChips() {
    final groups = groupMistakesByType(_loadedMistakes);
    if (groups.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: groups.entries.map((e) {
        return Chip(
          avatar: Icon(getMistakeIcon(e.key), size: 14, color: Colors.white),
          label: Text(
            '${e.key.arabicLabel}: ${e.value}',
            style: const TextStyle(fontSize: 11, color: Colors.white),
          ),
          backgroundColor: getMistakeColor(e.key),
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
        );
      }).toList(),
    );
  }

  // Teacher: ExpansionTile grouped by page, using buildSummaryTile()
  Widget _buildGroupedMistakeList() {
    final pages = _loadedMistakes.map((m) => m.pageNumber).toSet().toList()
      ..sort();

    return Column(
      children: pages.map((page) {
        final pageMistakes = getMistakesOnPage(_loadedMistakes, page);
        return Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            leading: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Øµ $page',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.green.shade800),
              ),
            ),
            title: Text(
              '${pageMistakes.length} ${pageMistakes.length == 1 ? 'Ù…Ù„Ø§Ø­Ø¸Ø©' : 'Ù…Ù„Ø§Ø­Ø¸Ø§Øª'}',
              style: const TextStyle(fontSize: 14),
            ),
            children: pageMistakes.map((m) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: m.buildSummaryTile(
                  onTap: () => _showMistakeDetailDialog(m),
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }

  // Student: flat list of summary tiles (no expansion needed)
  Widget _buildStudentMistakeTiles() {
    // Show max 5 inline, rest behind "show all" expansion
    final preview = _loadedMistakes.take(5).toList();
    final rest = _loadedMistakes.skip(5).toList();

    return Column(
      children: [
        ...preview.map((m) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: m.buildSummaryTile(
                onTap: () => _showMistakeDetailDialog(m),
              ),
            )),
        if (rest.isNotEmpty)
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(
                'Ø¹Ø±Ø¶ ${rest.length} Ù…Ù„Ø§Ø­Ø¸Ø§Øª Ø¥Ø¶Ø§ÙÙŠØ©...',
                style: TextStyle(fontSize: 13, color: Colors.green.shade700),
              ),
              children: rest
                  .map((m) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: m.buildSummaryTile(
                          onTap: () => _showMistakeDetailDialog(m),
                        ),
                      ))
                  .toList(),
            ),
          ),
      ],
    );
  }

  // Shared detail dialog (tap on tile)
  void _showMistakeDetailDialog(QuranMistake mistake) {
    final hasComment = mistake.hasComment;

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: mistake.color.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(mistake.icon, color: mistake.color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  mistake.label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: mistake.color,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Location
              _dialogRow(Icons.menu_book, 'Ø§Ù„ØµÙØ­Ø©', '${mistake.pageNumber}'),
              _dialogRow(
                  Icons.format_list_numbered, 'Ø§Ù„Ø¢ÙŠØ©', '${mistake.ayahNumber}'),

              // Word text
              if (mistake.wordText?.isNotEmpty ?? false) ...[
                const SizedBox(height: 12),
                const Text('Ø§Ù„ÙƒÙ„Ù…Ø© / Ø§Ù„Ù…ÙˆØ¶Ø¹',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Text(
                    mistake.wordText!,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],

              // Teacher comment
              if (hasComment) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Icon(Icons.chat_bubble,
                        size: 16, color: Colors.blue.shade700),
                    const SizedBox(width: 6),
                    Text(
                      'ØªØ¹Ù„ÙŠÙ‚ Ø§Ù„Ù…Ø¹Ù„Ù…',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.blue.shade800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Text(
                    mistake.correctionNote!,
                    style: TextStyle(
                        fontSize: 14, color: Colors.blue.shade900, height: 1.6),
                  ),
                ),
              ],

              if (!hasComment) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.chat_bubble_outline,
                        size: 14, color: Colors.grey.shade400),
                    const SizedBox(width: 6),
                    Text(
                      'Ù„Ø§ ÙŠÙˆØ¬Ø¯ ØªØ¹Ù„ÙŠÙ‚ Ù„Ù‡Ø°Ø§ Ø§Ù„Ø®Ø·Ø£',
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Ø¥ØºÙ„Ø§Ù‚'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dialogRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade600),
          const SizedBox(width: 6),
          Text('$label: ',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          Text(value,
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // BOTTOM NAV BAR
  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget? _buildBottomNavigationBar({
    required bool isMohaffez,
    required bool isStudent,
    required SessionModel session,
  }) {
    // Mohaffez: complete / edit buttons
    if (isMohaffez && session.status == 'accepted') {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: OutlinedButton.icon(
            onPressed: () => context.push('/complete-session/${session.id}',
                extra: {
                  'studentName': session.studentName,
                  'previousHifz': session.hifzAssignment,
                  'previousMuraja': session.murajaAssignment,
                }),
            icon: const Icon(Icons.check_circle),
            label: const Text('Ø¥Ù†Ù‡Ø§Ø¡ Ø§Ù„Ø¬Ù„Ø³Ø©'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: const BorderSide(color: AppTheme.accentGreen, width: 2),
              foregroundColor: AppTheme.accentGreen,
            ),
          ),
        ),
      );
    }

    // Student: cancel button (with refund policy)
    if (isStudent &&
        session.status == 'accepted' &&
        session.sessionDate != null &&
        session.sessionDate!.isAfter(DateTime.now())) {
      final hoursUntil =
          session.sessionDate!.difference(DateTime.now()).inHours;

      final String refundPolicy;
      final Color policyColor;
      if (hoursUntil > 24) {
        refundPolicy = 'âœ… Ø§Ø³ØªØ±Ø¯Ø§Ø¯ ÙƒØ§Ù…Ù„';
        policyColor = Colors.green;
      } else if (hoursUntil > 2) {
        refundPolicy = 'âš ï¸ Ø§Ø³ØªØ±Ø¯Ø§Ø¯ 50%';
        policyColor = Colors.orange;
      } else {
        refundPolicy = 'âŒ Ù„Ø§ Ø§Ø³ØªØ±Ø¯Ø§Ø¯';
        policyColor = Colors.red;
      }

      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              color: policyColor.withOpacity(0.1),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.info_outline, color: policyColor, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    'Ø³ÙŠØ§Ø³Ø© Ø§Ù„Ø¥Ù„ØºØ§Ø¡: $refundPolicy',
                    style: TextStyle(color: policyColor, fontSize: 12),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () =>
                      _showCancellationDialog(session, refundPolicy),
                  icon: const Icon(Icons.cancel),
                  label: const Text('Ø¥Ù„ØºØ§Ø¡ Ø§Ù„Ø¬Ù„Ø³Ø©'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Student: rate button for unrated completed sessions
    if (isStudent &&
        session.status == 'completed' &&
        (session.sessionRating == null || session.sessionRating == 0)) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _navigateToRating(session),
              icon: const Icon(Icons.star, color: Colors.white),
              label: const Text('Ù‚ÙŠÙ‘Ù… Ø§Ù„Ø¬Ù„Ø³Ø©', style: TextStyle(fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ),
      );
    }

    return null;
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // CANCELLATION DIALOG
  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<void> _showCancellationDialog(SessionModel session,
      [String? precalculatedRefundPolicy]) async {
    final hoursUntilSession =
        session.sessionDate!.difference(DateTime.now()).inHours;

    final String refundPolicy;
    final Color policyColor;
    if (hoursUntilSession > 24) {
      refundPolicy = 'âœ… Ø§Ø³ØªØ±Ø¯Ø§Ø¯ ÙƒØ§Ù…Ù„ Ø§Ù„Ù…Ø¨Ù„Øº';
      policyColor = Colors.green;
    } else if (hoursUntilSession > 2) {
      refundPolicy = 'âš ï¸ Ø§Ø³ØªØ±Ø¯Ø§Ø¯ 50% Ù…Ù† Ø§Ù„Ù…Ø¨Ù„Øº';
      policyColor = Colors.orange;
    } else {
      refundPolicy = 'âŒ Ù„Ø§ ÙŠÙ…ÙƒÙ† Ø§Ù„Ø§Ø³ØªØ±Ø¯Ø§Ø¯';
      policyColor = Colors.red;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning, color: Colors.red),
              SizedBox(width: 8),
              Text('ØªØ£ÙƒÙŠØ¯ Ø§Ù„Ø¥Ù„ØºØ§Ø¡'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Ù‡Ù„ ØªØ±ÙŠØ¯ Ø¥Ù„ØºØ§Ø¡ Ù‡Ø°Ù‡ Ø§Ù„Ø¬Ù„Ø³Ø©ØŸ',
                  style: TextStyle(fontSize: 16)),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: policyColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: policyColor),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: policyColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        refundPolicy,
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: policyColor),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Ù„Ø§'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Ù†Ø¹Ù…ØŒ Ø¥Ù„ØºØ§Ø¡ Ø§Ù„Ø¬Ù„Ø³Ø©'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Ø¬Ø§Ø±ÙŠ Ø¥Ù„ØºØ§Ø¡ Ø§Ù„Ø¬Ù„Ø³Ø©...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final sessionId = session.id;
      if (sessionId == null) throw Exception('Ù…Ø¹Ø±Ù Ø§Ù„Ø¬Ù„Ø³Ø© ØºÙŠØ± Ù…ØªØ§Ø­');

      await ref.read(sessionActionsProvider.notifier).cancelSession(sessionId);

      if (mounted) {
        Navigator.pop(context); // close loading
        Navigator.pop(context); // close details
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ØªÙ… Ø¥Ù„ØºØ§Ø¡ Ø§Ù„Ø¬Ù„Ø³Ø© Ø¨Ù†Ø¬Ø§Ø­'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ø­Ø¯Ø« Ø®Ø·Ø£: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // NAVIGATE TO RATING
  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<void> _navigateToRating(SessionModel session) async {
    final sessionId = session.id;
    if (sessionId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Ù…Ø¹Ø±Ù Ø§Ù„Ø¬Ù„Ø³Ø© ØºÙŠØ± Ù…ØªØ§Ø­'),
              backgroundColor: Colors.red),
        );
      }
      return;
    }

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => RateSessionScreen(
          sessionId: sessionId,
          mohaffezName: session.mohaffezName,
        ),
      ),
    );

    if (result == true && mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Ø´ÙƒØ±Ø§Ù‹ Ù„ØªÙ‚ÙŠÙŠÙ…Ùƒ!'), backgroundColor: Colors.green),
      );
    }
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // LABEL HELPERS
  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  String _getStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
        return 'Ù…Ù‚Ø¨ÙˆÙ„Ø©';
      case 'pending':
        return 'Ù‚ÙŠØ¯ Ø§Ù„Ø§Ù†ØªØ¸Ø§Ø±';
      case 'completed':
        return 'Ù…ÙƒØªÙ…Ù„Ø©';
      case 'cancelled':
        return 'Ù…Ù„ØºÙŠØ©';
      default:
        return status;
    }
  }

  String _getSessionTypeLabel(String type) {
    switch (type.toLowerCase()) {
      case 'home':
        return 'ÙÙŠ Ø§Ù„Ù…Ù†Ø²Ù„';
      case 'mosque':
        return 'ÙÙŠ Ø§Ù„Ù…Ø³Ø¬Ø¯';
      case 'online':
        return 'Ø¹Ù† Ø¨ÙØ¹Ø¯';
      default:
        return type;
    }
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// PRIVATE WIDGETS
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _StatCell extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _StatCell({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(value,
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.child,
  });
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 12),
                Text(title,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 20),
            child,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        const SizedBox(width: 12),
        Text('$label: ',
            style: TextStyle(
                fontSize: 15,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600)),
        Expanded(
          child: Text(value,
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}

class _AssignmentCard extends StatelessWidget {
  final String title;
  final String content;
  final Color color;
  final IconData icon;

  const _AssignmentCard({
    required this.title,
    required this.content,
    required this.color,
    required this.icon,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(title,
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
          const SizedBox(height: 12),
          Text(content, style: const TextStyle(fontSize: 15, height: 1.6)),
        ],
      ),
    );
  }
}



