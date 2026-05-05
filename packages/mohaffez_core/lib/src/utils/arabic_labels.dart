/// Arabic labels and localization strings for the Al-Mohaffez app.
///
/// IMPORTANT: This file must be saved with UTF-8 encoding.
/// In VS Code: Click bottom-right encoding → Select "UTF-8"
/// In Android Studio: File → Settings → Editor → File Encodings → UTF-8
class ArabicLabels {
  ArabicLabels._(); // Private constructor to prevent instantiation

  // ============================================
  // NAVIGATION & MAIN SCREENS
  // ============================================
  static const String home = 'الرئيسية';
  static const String search = 'البحث';
  static const String notifications = 'الإشعارات';
  static const String profile = 'الملف الشخصي';
  static const String menu = 'القائمة';
  static const String settings = 'الإعدادات';
  static const String privacy = 'الخصوصية';

  // ============================================
  // USER TYPES & ROLES
  // ============================================
  static const String student = 'طالب';
  static const String mohaffez = 'محفظ';
  static const String teacher = 'معلم';
  static const String admin = 'مدير';

  // ============================================
  // SESSION TYPES
  // ============================================
  static const String homeSession = 'منزل';
  static const String mosqueSession = 'مسجد';
  static const String onlineSession = 'أونلاين';

  // Backward compatible session names
  static const String sessionHome = homeSession;
  static const String sessionMosque = mosqueSession;
  static const String sessionOnline = onlineSession;

  // ============================================
  // SESSION STATUS
  // ============================================
  static const String pending = 'معلق';
  static const String awaitingPayment = 'في انتظار الدفع';
  static const String accepted = 'مقبول';
  static const String rejected = 'مرفوض';
  static const String cancelled = 'ملغي';
  static const String expired = 'منتهي';
  static const String completed = 'مكتمل';
  static const String inProgress = 'قيد التنفيذ';
  static const String scheduled = 'مجدول';

  // Backward compatible status names
  static const String statusPending = pending;
  static const String statusAwaitingPayment = awaitingPayment;
  static const String statusAccepted = accepted;
  static const String statusRejected = rejected;
  static const String statusCancelled = cancelled;
  static const String statusExpired = expired;
  static const String statusCompleted = completed;

  // ============================================
  // REQUESTS & SESSIONS
  // ============================================
  static const String allRequests = 'الكل';
  static const String acceptedRequests = 'مقبول';
  static const String rejectedRequests = 'مرفوض';
  static const String cancelledRequests = 'ملغي';

  // Actions
  static const String cancelRequest = 'إلغاء الطلب';
  static const String confirmCancel = 'تأكيد الإلغاء';
  static const String cancelWarning = 'هل أنت متأكد من إلغاء هذا الطلب؟';

  static const String myRequests = 'طلباتي';
  static const String pendingRequests = 'الطلبات المعلقة';
  static const String upcomingSessions = 'الجلسات القادمة';
  static const String completedSessions = 'الجلسات المكتملة';
  static const String sessionDetails = 'تفاصيل الجلسة';
  static const String sessionHistory = 'سجل الجلسات';
  static const String bookSession = 'حجز جلسة';
  static const String rescheduleSession = 'إعادة جدولة الجلسة';

  // NEW: Additional session-related labels
  static const String sessionInfo = 'معلومات الجلسة';
  static const String lockedSessionDetails = 'تفاصيل الجلسة المحجوزة';
  static const String lockedSlot = 'الوقت محجوز';
  static const String sessionDate = 'تاريخ الجلسة';
  static const String sessionTime = 'وقت الجلسة';
  static const String sessionLocation = 'موقع الجلسة';
  static const String sessionType = 'نوع الجلسة';
  static const String mohaffezName = 'اسم المحفظ';
  static const String studentName = 'اسم الطالب';

  // ============================================
  // PAYMENT & PRICING
  // ============================================
  static const String payment = 'الدفع';
  static const String singleSession = 'جلسة واحدة';
  static const String sessionPackage = 'باقة جلسات';
  static const String sessionBundle = sessionPackage;
  static const String subscription = 'اشتراك';
  static const String currency = 'جنيه';
  static const String egp = 'ج.م';
  static const String sar = 'ر.س';
  static const String price = 'السعر';
  static const String total = 'المجموع';
  static const String subtotal = 'المبلغ الفرعي';
  static const String discount = 'خصم';
  static const String promoCode = 'كود الخصم';
  static const String applyPromoCode = 'تطبيق كود الخصم';
  static const String enterPromoCode = 'أدخل كود الخصم (اختياري)';
  static const String paymentMethod = 'طريقة الدفع';
  static const String cardPayment = 'الدفع بالبطاقة';
  static const String cashPayment = 'الدفع نقداً';
  static const String completePayment = 'إتمام الدفع';
  static const String paymentDetails = 'تفاصيل الدفع';
  static const String paymentDeadline = 'موعد انتهاء الدفع';
  static const String paymentExpired = 'انتهت صلاحية الدفع';
  static const String timeRemaining = 'الوقت المتبقي';
  static const String paymentSuccess = 'تم الدفع بنجاح';
  static const String paymentFailed = 'فشل الدفع';
  static const String freeSession = 'جلسة مجانية';

  // ============================================
  // COMMON FORM FIELDS
  // ============================================
  static const String name = 'الاسم';
  static const String fullName = 'الاسم الكامل';
  static const String firstName = 'الاسم الأول';
  static const String lastName = 'اسم العائلة';
  static const String email = 'البريد الإلكتروني';
  static const String password = 'كلمة المرور';
  static const String confirmPassword = 'تأكيد كلمة المرور';
  static const String phone = 'رقم الهاتف';
  static const String phoneNumber = 'رقم الهاتف';
  static const String address = 'العنوان';
  static const String city = 'المدينة';
  static const String country = 'الدولة';
  static const String zipCode = 'الرمز البريدي';
  static const String date = 'التاريخ';
  static const String time = 'الوقت';
  static const String type = 'النوع';
  static const String location = 'المكان';
  static const String status = 'الحالة';
  static const String description = 'الوصف';
  static const String notes = 'ملاحظات';
  static const String bio = 'نبذة تعريفية';
  static const String specialization = 'التخصص';

  // ============================================
  // COMMON ACTIONS
  // ============================================
  static const String login = 'تسجيل الدخول';
  static const String logout = 'تسجيل الخروج';
  static const String register = 'تسجيل';
  static const String signUp = 'إنشاء حساب';
  static const String save = 'حفظ';
  static const String cancel = 'إلغاء';
  static const String confirm = 'تأكيد';
  static const String apply = 'تطبيق';
  static const String continue_ = 'متابعة';
  static const String back = 'رجوع';
  static const String close = 'إغلاق';
  static const String next = 'التالي';
  static const String previous = 'السابق';
  static const String done = 'تم';
  static const String ok = 'حسناً';
  static const String yes = 'نعم';
  static const String no = 'لا';
  static const String edit = 'تعديل';
  static const String delete = 'حذف';
  static const String remove = 'إزالة';
  static const String add = 'إضافة';
  static const String update = 'تحديث';
  static const String refresh = 'تحديث';
  static const String retry = 'إعادة المحاولة';
  static const String submit = 'إرسال';
  static const String send = 'إرسال';
  static const String share = 'مشاركة';
  static const String download = 'تحميل';
  static const String upload = 'رفع';
  static const String view = 'عرض';
  static const String viewAll = 'عرض الكل';
  static const String seeMore = 'عرض المزيد';
  static const String seeLess = 'عرض أقل';

  // ============================================
  // ACTION SPECIFIC TO APP
  // ============================================
  static const String payNow = 'ادفع الآن';
  static const String cancelSession = 'إلغاء الجلسة';
  static const String accept = 'قبول';
  static const String reject = 'رفض';
  static const String acceptRequest = 'قبول الطلب';
  static const String rejectRequest = 'رفض الطلب';
  static const String markAsCompleted = 'تعليم كمكتمل';
  static const String rateSession = 'تقييم الجلسة';
  static const String writeReview = 'كتابة مراجعة';
  static const String completeSession = 'إكمال الجلسة';
  static const String viewDetails = 'عرض التفاصيل';

  // ============================================
  // COMMON MESSAGES
  // ============================================
  static const String noData = 'لا توجد بيانات';
  static const String notSpecified = 'غير محدد';
  static const String notAvailable = 'غير متاح';
  static const String comingSoon = 'قريباً';
  static const String loading = 'جاري التحميل...';
  static const String pleaseWait = 'الرجاء الانتظار...';
  static const String processing = 'جاري المعالجة...';
  static const String error = 'حدث خطأ';
  static const String success = 'تم بنجاح';
  static const String warning = 'تحذير';
  static const String info = 'معلومة';
  static const String areYouSure = 'هل أنت متأكد؟';
  static const String confirmAction = 'تأكيد الإجراء';

  // ============================================
  // ERROR MESSAGES
  // ============================================
  static const String errorLoading = 'حدث خطأ أثناء التحميل';
  static const String errorSaving = 'حدث خطأ أثناء الحفظ';
  static const String errorDeleting = 'حدث خطأ أثناء الحذف';
  static const String errorUpdating = 'حدث خطأ أثناء التحديث';
  static const String errorNetwork = 'خطأ في الاتصال بالإنترنت';
  static const String errorServer = 'خطأ في الخادم';
  static const String errorUnknown = 'خطأ غير معروف';
  static const String fillAllFields = 'الرجاء ملء جميع الحقول';
  static const String fillRequiredFields = 'الرجاء ملء الحقول المطلوبة';
  static const String invalidEmail = 'البريد الإلكتروني غير صالح';
  static const String invalidPhone = 'رقم الهاتف غير صالح';
  static const String invalidPassword = 'كلمة المرور غير صالحة';
  static const String weakPassword = 'كلمة المرور ضعيفة';
  static const String passwordsDoNotMatch = 'كلمتا المرور غير متطابقتين';
  static const String connectionFailed = 'فشل الاتصال بالخادم';
  static const String userNotFound = 'المستخدم غير موجود';
  static const String accountDisabled = 'الحساب معطل';
  static const String emailAlreadyInUse = 'البريد الإلكتروني مستخدم بالفعل';
  static const String wrongPassword = 'كلمة المرور خاطئة';
  static const String tooManyRequests = 'طلبات كثيرة جداً. حاول لاحقاً';
  static const String sessionExpired = 'انتهت صلاحية الجلسة';
  static const String unauthorized = 'غير مصرح';
  static const String forbidden = 'محظور';
  static const String notFound = 'غير موجود';

  // ============================================
  // SUCCESS MESSAGES
  // ============================================
  static const String successSaved = 'تم الحفظ بنجاح';
  static const String successDeleted = 'تم الحذف بنجاح';
  static const String successUpdated = 'تم التحديث بنجاح';
  static const String successSent = 'تم الإرسال بنجاح';
  static const String successCopied = 'تم النسخ بنجاح';
  static const String requestSentSuccessfully = 'تم إرسال الطلب بنجاح';
  static const String sessionBookedSuccessfully = 'تم حجز الجلسة بنجاح';
  static const String sessionCancelledSuccessfully = 'تم إلغاء الجلسة بنجاح';

  // ============================================
  // TIME & DATE
  // ============================================
  static const String today = 'اليوم';
  static const String tomorrow = 'غداً';
  static const String yesterday = 'أمس';
  static const String now = 'الآن';
  static const String morning = 'صباحاً';
  static const String afternoon = 'ظهراً';
  static const String evening = 'مساءً';
  static const String night = 'ليلاً';
  static const String hour = 'ساعة';
  static const String hours = 'ساعات';
  static const String minute = 'دقيقة';
  static const String minutes = 'دقائق';
  static const String second = 'ثانية';
  static const String seconds = 'ثواني';
  static const String day = 'يوم';
  static const String days = 'أيام';
  static const String week = 'أسبوع';
  static const String weeks = 'أسابيع';
  static const String month = 'شهر';
  static const String months = 'أشهر';
  static const String year = 'سنة';
  static const String years = 'سنوات';
  static const String ago = 'منذ';
  static const String remaining = 'متبقي';
  static const String remainingTime = 'الوقت المتبقي';

  // Days of the week
  static const String saturday = 'السبت';
  static const String sunday = 'الأحد';
  static const String monday = 'الاثنين';
  static const String tuesday = 'الثلاثاء';
  static const String wednesday = 'الأربعاء';
  static const String thursday = 'الخميس';
  static const String friday = 'الجمعة';

  // ============================================
  // RATINGS & REVIEWS
  // ============================================
  static const String rating = 'التقييم';
  static const String ratings = 'التقييمات';
  static const String review = 'مراجعة';
  static const String reviews = 'المراجعات';
  static const String stars = 'نجوم';
  static const String followers = 'متابعين';
  static const String following = 'متابَعين';

  // NEW: Additional rating labels
  static const String sessionRating = 'تقييم الجلسة';
  static const String performanceNotes = 'ملاحظات الأداء';

  // ============================================
  // SEARCH & FILTERS
  // ============================================
  static const String searchForMohaffez = 'ابحث عن محفظ';
  static const String searchResults = 'نتائج البحث';
  static const String noResults = 'لا توجد نتائج';
  static const String filter = 'تصفية';
  static const String filters = 'الفلاتر';
  static const String sortBy = 'ترتيب حسب';
  static const String nearby = 'قريب منك';
  static const String distance = 'المسافة';
  static const String priceRange = 'نطاق السعر';

  // NEW: Additional search labels
  static const String searchRequests = 'ابحث عن طلب...';
  static const String searchStudents = 'ابحث عن طالب...';
  static const String noSearchResults = 'لا توجد نتائج للبحث';
  static const String clearSearch = 'مسح البحث';

  // ============================================
  // EMPTY STATES
  // ============================================
  static const String noNotifications = 'لا توجد إشعارات';
  static const String noSessions = 'لا توجد جلسات';
  static const String noRequests = 'لا توجد طلبات';
  static const String noMessages = 'لا توجد رسائل';
  static const String noAvailableSlots = 'لا توجد مواعيد متاحة';
  static const String emptyList = 'القائمة فارغة';

  // NEW: Additional empty state messages
  static const String noRequestsMessage = 'لم تقم بإرسال أي طلبات بعد';
  static const String noSessionsMessage = 'لا توجد جلسات حالياً';
  static const String noCompletedSessions = 'لا توجد جلسات مكتملة';
  static const String noUpcomingSessions = 'لا توجد جلسات قادمة';

  // ============================================
  // AVAILABILITY & SCHEDULING
  // ============================================
  static const String availability = 'المواعيد المتاحة';
  static const String schedule = 'الجدول';
  static const String selectDate = 'اختر التاريخ';
  static const String selectTime = 'اختر الوقت';
  static const String selectSlot = 'اختر موعد';
  static const String availableSlots = 'المواعيد المتاحة';
  static const String bookedSlots = 'المواعيد المحجوزة';

  // ============================================
  // ASSIGNMENTS & QURAN STUDY
  // ============================================
  static const String hifz = 'حفظ';
  static const String muraja = 'مراجعة';
  static const String myAssignments = 'واجباتي';
  static const String pleaseLoginFirst = 'الرجاء تسجيل الدخول';
  static const String noCompletedAssignments = 'لا توجد واجبات مكتملة';
  static const String completeAssignmentsToAppear = 'أكمل واجباتك لتظهر هنا';
  static const String assignmentPerformanceInPreviousTask =
      'تقييم أدائك في التكليف السابق:';
  static const String performanceNotesOnYourWork = 'ملاحظات على أدائك:';
  static const String newAssignmentForNextSession =
      'التكليف الجديد للجلسة القادمة:';
  static const String messageFromMohaffez = 'رسالة من المحفّظ:';
  static const String reviewMistakes = 'مراجعة الأخطاء';
  static const String sessionMistakes = 'أخطاء الجلسة';
  static const String reviewMistakesInMushaf = 'مراجعة الأخطاء في المصحف';
  static const String hifzAssignment = 'واجب الحفظ';
  static const String murajaAssignment = 'واجب المراجعة';
  static const String previousAssignments = 'الواجبات السابقة';
  static const String nextAssignments = 'الواجبات القادمة';
  static const String assignmentCompleted = 'تم إكمال الواجب';
  static const String assignmentNotCompleted = 'لم يتم الإكمال';
  static const String previousHifz = 'الحفظ السابق';
  static const String previousMuraja = 'المراجعة السابقة';

  // ============================================
  // FILTERS & CATEGORIES
  // ============================================
  static const String all = 'الكل';
  static const String thisWeek = 'هذا الأسبوع';
  static const String thisMonth = 'هذا الشهر';
  static const String filterBy = 'تصفية حسب';

  // ============================================
  // HELPER METHODS
  // ============================================

  // ============================================
  // ADMIN DASHBOARD
  // ============================================
  static const String adminDashboard = 'لوحة التحكم';
  static const String totalUsers = 'إجمالي المستخدمين';
  static const String totalSessions = 'إجمالي الجلسات';
  static const String pendingVerification = 'بانتظار التحقق';
  static const String failedOperationsCount = 'عمليات فاشلة';

  // ============================================
  // ADMIN NAV TILES
  // ============================================
  static const String manageUsers = 'إدارة المستخدمين';
  static const String teacherCredentials = 'شهادات المعلمين';
  static const String failedOperations = 'العمليات الفاشلة';
  static const String promoCodes = 'أكواد الخصم';
  static const String systemSettings = 'إعدادات النظام';
  static const String devMode = 'وضع المطور';
  static const String broadcastNotifications = 'إشعارات جماعية';
  static const String slotLocksManagement = 'إدارة قفل الفترات';
  static const String paymentEvents = 'أحداث المدفوعات';
  static const String commissionsBoard = 'لوحة العمولات';
  static const String teacherCommissions = 'عمولات المحفظين';
  static const String adminWalletNumbers = 'أرقام محافظ المنصة';

  // ============================================
  // ADMIN BROADCAST
  // ============================================
  static const String notificationTitle = 'عنوان الإشعار';
  static const String notificationBody = 'نص الإشعار';
  static const String students = 'الطلاب';
  static const String mohaffezin = 'المحفظين';
  static const String sendHistory = 'سجل الإرسال';
  static const String unexpectedError = 'حدث خطأ غير متوقع';
  static const String sentToCount = 'أُرسل إلى';
  static const String recipients = 'مستلم';

  // ============================================
  // ADMIN CREDENTIALS
  // ============================================
  static const String noCredentialsPending = 'لا توجد شهادات قيد المراجعة';
  static const String rejectCredential = 'رفض الشهادة';
  static const String rejectionReason = 'سبب الرفض';
  static const String approve = 'قبول';
  static const String submittedAt = 'وقت الرفع';
  static const String userId = 'معرّف المستخدم';

  // ============================================
  // ADMIN DEV MODE
  // ============================================
  static const String devModeWarning = 'تحذير: هذا الوضع للمطورين فقط';
  static const String enableDevMode = 'تفعيل وضع التطوير';
  static const String bypassPayment = 'تجاوز الدفع';
  static const String bypassPromoValidation = 'تجاوز التحقق من الكوبون';
  static const String bypassSlotLock = 'تجاوز قفل الفترة';
  static const String mockNotifications = 'إشعارات وهمية';
  static const String skipVersionCheck = 'تجاوز التحقق من الإصدار';
  static const String enableFakeGps = 'تفعيل GPS وهمي';
  static const String latitude = 'خط العرض';
  static const String longitude = 'خط الطول';
  static const String showDebugOverlay = 'إظهار طبقة التصحيح';
  static const String logFirestoreWrites = 'تسجيل كتابات Firestore';
  static const String simulateSlowNetwork = 'محاكاة شبكة بطيئة';
  static const String devModeUsers = 'المستخدمون في وضع التطوير';
  static const String addUid = 'أضف UID';
  static const String saveSettings = 'حفظ الإعدادات';
  static const String settingsSaved = 'تم حفظ الإعدادات';

  // ============================================
  // ADMIN FAILED OPERATIONS
  // ============================================
  static const String runCleanupJob = 'تشغيل مهمة التنظيف';
  static const String dismiss = 'تجاهل';
  static const String unknownError = 'خطأ غير معروف';
  static const String operationAt = 'تاريخ العملية';
  static const String retryCount = 'عدد المحاولات';
  // WHY: Dedicated labels for failed-operations screen empty state and actions.
  static const String noFailedOperations =
      'لا توجد عمليات فاشلة — كل شيء يعمل بشكل صحيح ✓';
  static const String retryOperation = 'إعادة المحاولة';
  static const String dismissOperation = 'تجاهل';

  // ============================================
  // ADMIN PROMO CODES
  // ============================================
  static const String createPromoCode = 'إنشاء كود خصم';
  static const String promoCodeValue = 'الكود';
  static const String discountPercent = 'نسبة الخصم';
  static const String usageLimit = 'حد الاستخدام';
  static const String expiryDate = 'تاريخ انتهاء الصلاحية';
  static const String noExpirySet = 'بدون تاريخ انتهاء - اضغط لتحديد';
  static const String isActive = 'نشط';
  static const String deleteCode = 'حذف هذا الكود';
  static const String confirmDelete = 'هل أنت متأكد من الحذف؟';
  static const String usedCount = 'مرات الاستخدام';

  // ============================================
  // ADMIN SLOT LOCKS
  // ============================================
  static const String releaseExpiredLocks = 'تحرير الأقفال المنتهية';
  static const String slotOf = 'فترة المحفظ';

  // ============================================
  // ADMIN SYSTEM SETTINGS
  // ============================================
  static const String maintenanceMode = 'وضع الصيانة';
  static const String maintenanceModeActive =
      '⚠️ التطبيق في وضع الصيانة حالياً';
  static const String maintenanceMessage = 'رسالة الصيانة';
  static const String enableMaintenance = 'تفعيل وضع الصيانة';
  static const String appVersionSettings = 'إعدادات الإصدار';
  static const String forceVersion = 'الإصدار الإجباري';
  static const String recommendedVersion = 'الإصدار الموصى به';
  static const String sessionSettings = 'إعدادات الجلسات';
  static const String paymentSettings = 'إعدادات الدفع';
  static const String commissionRate = 'نسبة العمولة';
  static const String sessionPrices = 'أسعار الجلسات';
  static const String paymentDeadlineHours = 'مهلة الدفع (ساعات)';
  static const String slotLockDurationMinutes = 'مدة قفل الفترة (دقائق)';

  // ============================================
  // ADMIN USERS
  // ============================================
  static const String allUsers = 'جميع المستخدمين';
  static const String filterByRole = 'تصفية حسب الدور';
  static const String banUser = 'حظر المستخدم';
  static const String unbanUser = 'رفع الحظر';
  static const String userDetails = 'تفاصيل المستخدم';
  static const String userBanned = 'محظور';
  static const String userActive = 'نشط';
  static const String joined = 'تاريخ الانضمام';
  static const String lastSeen = 'آخر ظهور';

  // ============================================
  // MAINTENANCE SCREEN
  // ============================================
  static const String maintenanceTitle = 'التطبيق تحت الصيانة';
  static const String maintenanceSubtitle =
      'نعمل على تحسين خدمتك، يرجى المحاولة لاحقاً';
  static const String checkAgain = 'تحقق مجدداً';


  static const String setBanExpiryOptional  = 'تحديد تاريخ انتهاء الحظر (اختياري)';
  static const String changeRole            = 'تغيير الدور';
  static const String resetPassword         = 'إعادة تعيين كلمة المرور';
  static const String passwordResetSent     = 'تم إرسال رابط إعادة تعيين كلمة المرور';
  static const String deleteAccount         = 'حذف الحساب';
  static const String finalConfirmation     = 'تأكيد نهائي';
  static const String actionIrreversible    = 'هذا الإجراء لا يمكن التراجع عنه';
  static const String sessions              = 'الجلسات';
  static const String subscriptions         = 'الاشتراكات';
  static const String credentials           = 'الشهادات';
  static const String rejectedByAdmin       = 'تم الرفض من الإدارة';
  static const String role                  = 'الدور';
  static const String banUserWarning        = 'هل أنت متأكد من حظر هذا المستخدم؟';
  static const String unbanUserWarning      = 'هل أنت متأكد من رفع الحظر عن هذا المستخدم؟';
  static const String deleteUserWarning     = 'هل أنت متأكد من حذف هذا المستخدم؟';
  static const String changeRoleWarning     = 'هل أنت متأكد من تغيير دور هذا المستخدم؟';
  static const String resetPasswordWarning  = 'هل أنت متأكد من إعادة تعيين كلمة المرور لهذا المستخدم؟';
  static const String userDetailsTitle      = 'تفاصيل المستخدم';
  static const String userDetailsSessions   = 'جلسات المستخدم';
  static const String userDetailsSubscriptions = 'اشتراكات المستخدم';
  static const String userDetailsCredentials = 'شهادات المستخدم';
  static const String noSubscriptions      = 'لا توجد اشتراكات لهذا المستخدم';
  static const String noCredentials        = 'لا توجد شهادات لهذا المستخدم';
  static const String bannedUntil           = 'محظور حتى';  

  // ============================================
  // SHARED ADMIN
  // ============================================
  static const String operationSuccess = 'تمت العملية بنجاح';
  static const String operationFailed = 'فشلت العملية';

  // ============================================
  // ADMIN AUDIT LOG
  // ============================================
  static const String auditLogTitle = 'سجل العمليات الإدارية';
  static const String noAuditLogs = 'لا توجد عمليات مسجلة';
  static const String auditAction = 'الإجراء';
  static const String performedBy = 'المشرف';
  static const String targetUser = 'المستخدم المستهدف';
  static const String auditData = 'البيانات';
  static const String operationsLog = 'سجل العمليات';

  /// Get localized status label from status code
  static String getStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return statusPending;
      case 'awaitingpayment':
        return statusAwaitingPayment;
      case 'accepted':
        return statusAccepted;
      case 'rejected':
        return statusRejected;
      case 'cancelled':
      case 'canceled':
        return statusCancelled;
      case 'expired':
        return statusExpired;
      case 'completed':
        return statusCompleted;
      case 'in_progress':
      case 'inprogress':
        return inProgress;
      case 'scheduled':
        return scheduled;
      default:
        return status;
    }
  }

  /// Get localized session type label from type code
  static String getSessionTypeLabel(String type) {
    switch (type.toLowerCase()) {
      case 'home':
        return sessionHome;
      case 'mosque':
        return sessionMosque;
      case 'online':
        return sessionOnline;
      default:
        return type;
    }
  }

  /// Get localized day of week
  static String getDayOfWeek(int weekday) {
    switch (weekday) {
      case 1:
        return monday;
      case 2:
        return tuesday;
      case 3:
        return wednesday;
      case 4:
        return thursday;
      case 5:
        return friday;
      case 6:
        return saturday;
      case 7:
        return sunday;
      default:
        return '';
    }
  }

  /// Format time remaining (e.g., "3 ساعات و 45 دقيقة متبقي")
  static String formatTimeRemaining(Duration duration) {
    if (duration.isNegative) {
      return expired;
    }

    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    if (hours > 0 && minutes > 0) {
      return '$hours ${hours > 1 ? hours : hour} و $minutes ${minutes > 1 ? minutes : minute} $remaining';
    } else if (hours > 0) {
      return '$hours ${hours > 1 ? hours : hour} $remaining';
    } else if (minutes > 0) {
      return '$minutes ${minutes > 1 ? minutes : minute} $remaining';
    } else {
      return '${duration.inSeconds} ${duration.inSeconds > 1 ? seconds : second} $remaining';
    }
  }

  /// Format price with currency
  static String formatPrice(double price, {String currency = egp}) {
    return '${price.toStringAsFixed(2)} $currency';
  }

  /// Format distance
  static String formatDistance(double distanceInKm) {
    if (distanceInKm < 1) {
      return '${(distanceInKm * 1000).toStringAsFixed(0)} متر';
    } else {
      return '${distanceInKm.toStringAsFixed(1)} كم';
    }
  }
  // WHY: Centralized suspension labels for lockout UX and admin actions.
  static const String accountSuspended = '\u062A\u0645 \u062A\u0642\u064A\u064A\u062F \u062D\u0633\u0627\u0628\u0643';
  static const String accountSuspendedSubtitle =
      '\u0644\u0627 \u064A\u0645\u0643\u0646\u0643 \u0627\u0633\u062A\u062E\u062F\u0627\u0645 \u0627\u0644\u062A\u0637\u0628\u064A\u0642 \u062D\u0627\u0644\u064A\u0627\u064B. \u062A\u0648\u0627\u0635\u0644 \u0645\u0639 \u0627\u0644\u062F\u0639\u0645 \u0644\u0645\u0632\u064A\u062F \u0645\u0646 \u0627\u0644\u0645\u0639\u0644\u0648\u0645\u0627\u062A.';
  static const String suspensionReason = '\u0633\u0628\u0628 \u0627\u0644\u062A\u0642\u064A\u064A\u062F';
  static const String suspensionExpiry = '\u064A\u0646\u062A\u0647\u064A \u0627\u0644\u062A\u0642\u064A\u064A\u062F \u0641\u064A';
  static const String permanentSuspension = '\u062A\u0642\u064A\u064A\u062F \u062F\u0627\u0626\u0645';
  static const String contactSupport = '\u062A\u0648\u0627\u0635\u0644 \u0645\u0639 \u0627\u0644\u062F\u0639\u0645';
  static const String suspensionLifted = '\u062A\u0645 \u0631\u0641\u0639 \u0627\u0644\u062A\u0642\u064A\u064A\u062F \u0639\u0646 \u062D\u0633\u0627\u0628\u0643';
  static const String restrictUser = '\u062A\u0642\u064A\u064A\u062F \u0627\u0644\u0645\u0633\u062A\u062E\u062F\u0645';
  static const String liftRestriction = '\u0631\u0641\u0639 \u0627\u0644\u062A\u0642\u064A\u064A\u062F';
  static const String suspensionType = '\u0646\u0648\u0639 \u0627\u0644\u062A\u0642\u064A\u064A\u062F';
}
