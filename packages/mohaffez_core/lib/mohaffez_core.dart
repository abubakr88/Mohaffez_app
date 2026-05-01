// Core exports for Mohaffez
// This file exports all platform-agnostic code shared across mobile and web

// ═══════════════════════════════════════════════════════════════════════════════
// MODELS
// ═══════════════════════════════════════════════════════════════════════════════
export 'src/models/booking_result.dart';
export 'src/models/broadcast_model.dart';
export 'src/models/challenge_question.dart';
export 'src/models/dev_mode_model.dart';
export 'src/models/direct_payment_model.dart';
export 'src/models/exam_question_model.dart';
export 'src/models/mohaffez_model.dart';
export 'src/models/mohaffez_student_summary.dart';
export 'src/models/notification_model.dart';
export 'src/models/pagination_state.dart';
export 'src/models/payment_model.dart';
export 'src/models/pricing_plan_model.dart' hide TimestampConverter;
export 'src/models/promo_code_model.dart';
export 'src/models/quran_mistake_model.dart';
export 'src/models/request_status.dart';
export 'src/models/session_model.dart';
export 'src/models/session_request_model.dart';
export 'src/models/slot_context.dart';
export 'src/models/subscription_model.dart';
export 'src/models/suspension_model.dart';
export 'src/models/system_config_model.dart';
export 'src/models/user_model.dart' hide TimestampConverter;

// ═══════════════════════════════════════════════════════════════════════════════
// REPOSITORIES
// ═══════════════════════════════════════════════════════════════════════════════
export 'src/repositories/admin_repository.dart';
export 'src/repositories/notification_repository.dart';
export 'src/repositories/payment_repository.dart';
export 'src/repositories/pricing_repository.dart' hide pricingRepositoryProvider;
export 'src/repositories/promo_code_repository.dart';
export 'src/repositories/session_repository.dart';
export 'src/repositories/subscription_repository.dart';
export 'src/repositories/system_config_repository.dart';
export 'src/repositories/user_repository.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// PROVIDERS
// ═══════════════════════════════════════════════════════════════════════════════
export 'src/providers/admin_provider.dart';
export 'src/providers/auth_provider.dart';
export 'src/providers/booking_flow_provider.dart';
export 'src/providers/booking_provider.dart';
export 'src/providers/challenge_questions_provider.dart';
export 'src/providers/mohaffez_provider.dart';
export 'src/providers/notification_provider_paginated.dart';
export 'src/providers/payment_provider.dart';
export 'src/providers/pricing_provider.dart';
export 'src/providers/promo_code_provider.dart';
export 'src/providers/session_provider_paginated.dart';
export 'src/providers/student_rewards_provider.dart';
export 'src/providers/subscription_provider.dart';
export 'src/providers/suspension_provider.dart';
export 'src/providers/system_config_provider.dart';
export 'src/providers/teacher_setup_provider.dart';
export 'src/providers/user_provider.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// SERVICES
// ═══════════════════════════════════════════════════════════════════════════════
export 'src/services/cache_service.dart';
export 'src/services/connectivity_service.dart';
export 'src/services/direct_payment_service.dart';
export 'src/services/follow_service.dart';
export 'src/services/prayer_time_service.dart';
export 'src/services/pricing_service.dart';
export 'src/services/quran_service.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// THEME
// ═══════════════════════════════════════════════════════════════════════════════
export 'src/theme/app_theme_constants.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════
export 'src/constants/app_theme.dart';
export 'src/constants/schedule_constants.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// UTILS
// ═══════════════════════════════════════════════════════════════════════════════
export 'src/utils/accessibility_utils.dart';
export 'src/utils/arabic_labels.dart';
export 'src/utils/date_utils.dart';
export 'src/utils/debouncer.dart';
export 'src/utils/error_handler.dart';
export 'src/utils/location_utils.dart';
export 'src/utils/performance_monitor.dart';
export 'src/utils/quran_mistake_utils.dart';
export 'src/utils/specialization_constants.dart';
export 'src/utils/status_utils.dart';
export 'src/utils/validation_utils.dart';
