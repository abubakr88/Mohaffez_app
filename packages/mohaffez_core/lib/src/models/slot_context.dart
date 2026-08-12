// lib/models/slot_context.dart

class SlotContext {
  final String mohaffezId;
  final String mohaffezName;
  final String? mohaffezPhone;
  final bool isFoundingTeacher;
  final String sessionType; // 'online', 'home', 'mosque'
  final String?
      preferredProvider; // 'zoom' | 'googleMeet' | 'teams' | 'phoneCall'
  final String preferredTimeSlot; // e.g. "10:00-11:00"
  final String slotDate; // ISO8601 string
  final String slotStart; // ISO8601 string
  final String slotEnd; // ISO8601 string
  final double? imamAddressLat;
  final double? imamAddressLng;
  final String? imamAddressText;
  final String? slotLockId;
  final int bookingTimeZoneVersion;
  final String? scheduleTimeZoneId;
  final String? teacherLocalDate;
  final String? teacherLocalTimeSlot;
  final String? availabilityDocId;

  const SlotContext({
    required this.mohaffezId,
    required this.mohaffezName,
    this.mohaffezPhone,
    this.isFoundingTeacher = false,
    required this.sessionType,
    this.preferredProvider,
    required this.preferredTimeSlot,
    required this.slotDate,
    required this.slotStart,
    required this.slotEnd,
    this.imamAddressLat,
    this.imamAddressLng,
    this.imamAddressText,
    this.slotLockId,
    this.bookingTimeZoneVersion = 0,
    this.scheduleTimeZoneId,
    this.teacherLocalDate,
    this.teacherLocalTimeSlot,
    this.availabilityDocId,
  });

  SlotContext copyWith({
    String? mohaffezId,
    String? mohaffezName,
    String? mohaffezPhone,
    bool? isFoundingTeacher,
    String? sessionType,
    String? preferredProvider,
    String? preferredTimeSlot,
    String? slotDate,
    String? slotStart,
    String? slotEnd,
    double? imamAddressLat,
    double? imamAddressLng,
    String? imamAddressText,
    String? slotLockId,
    int? bookingTimeZoneVersion,
    String? scheduleTimeZoneId,
    String? teacherLocalDate,
    String? teacherLocalTimeSlot,
    String? availabilityDocId,
  }) {
    return SlotContext(
      mohaffezId: mohaffezId ?? this.mohaffezId,
      mohaffezName: mohaffezName ?? this.mohaffezName,
      mohaffezPhone: mohaffezPhone ?? this.mohaffezPhone,
      isFoundingTeacher: isFoundingTeacher ?? this.isFoundingTeacher,
      sessionType: sessionType ?? this.sessionType,
      preferredProvider: preferredProvider ?? this.preferredProvider,
      preferredTimeSlot: preferredTimeSlot ?? this.preferredTimeSlot,
      slotDate: slotDate ?? this.slotDate,
      slotStart: slotStart ?? this.slotStart,
      slotEnd: slotEnd ?? this.slotEnd,
      imamAddressLat: imamAddressLat ?? this.imamAddressLat,
      imamAddressLng: imamAddressLng ?? this.imamAddressLng,
      imamAddressText: imamAddressText ?? this.imamAddressText,
      slotLockId: slotLockId ?? this.slotLockId,
      bookingTimeZoneVersion:
          bookingTimeZoneVersion ?? this.bookingTimeZoneVersion,
      scheduleTimeZoneId: scheduleTimeZoneId ?? this.scheduleTimeZoneId,
      teacherLocalDate: teacherLocalDate ?? this.teacherLocalDate,
      teacherLocalTimeSlot: teacherLocalTimeSlot ?? this.teacherLocalTimeSlot,
      availabilityDocId: availabilityDocId ?? this.availabilityDocId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'mohaffezId': mohaffezId,
      'mohaffezName': mohaffezName,
      'mohaffezPhone': mohaffezPhone,
      'isFoundingTeacher': isFoundingTeacher,
      'sessionType': sessionType,
      if (preferredProvider != null) 'preferredProvider': preferredProvider,
      'preferredTimeSlot': preferredTimeSlot,
      'slotDate': slotDate,
      'slotStart': slotStart,
      'slotEnd': slotEnd,
      'imamAddressLat': imamAddressLat,
      'imamAddressLng': imamAddressLng,
      'imamAddressText': imamAddressText,
      if (slotLockId != null) 'slotLockId': slotLockId,
      'bookingTimeZoneVersion': bookingTimeZoneVersion,
      if (scheduleTimeZoneId != null) 'scheduleTimeZoneId': scheduleTimeZoneId,
      if (teacherLocalDate != null) 'teacherLocalDate': teacherLocalDate,
      if (teacherLocalTimeSlot != null)
        'teacherLocalTimeSlot': teacherLocalTimeSlot,
      if (availabilityDocId != null) 'availabilityDocId': availabilityDocId,
    };
  }
}
