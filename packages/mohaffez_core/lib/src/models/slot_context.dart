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
    };
  }
}
