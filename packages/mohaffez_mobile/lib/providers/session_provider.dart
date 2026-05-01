// lib/providers/session_provider.dart

import 'session_provider_paginated.dart';

// ============================================================================
// RE-EXPORT PAGINATED PROVIDERS (for backward compatibility)
// ============================================================================

// Redirect old imports to new providers
final mohaffezSessionCountProvider = completedSessionsCountProvider;
final completedSessionsProvider = upcomingSessionsProvider; // Alias
final pendingSessionRequestsProvider = pendingRequestsFirstPageProvider;

// Session actions - redirect to paginated provider
// final sessionActionsProvider = sessionActionsProvider; // Already defined in paginated

// ============================================================================
// DEPRECATED - Use session_provider_paginated.dart instead
// ============================================================================
