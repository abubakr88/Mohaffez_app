// lib/models/slot_context.dart

class SlotContext {
  final String mohaffezId;
  final String mohaffezName;
  final String? mohaffezPhone;
  final String sessionType; // 'online', 'home', 'mosque'
  final String preferredTimeSlot; // e.g. "10:00-11:00"
  final String slotDate; // ISO8601 string
  final String slotStart; // ISO8601 string
  final String slotEnd; // ISO8601 string
  final double? imamAddressLat;
  final double? imamAddressLng;
  final String? imamAddressText;

  const SlotContext({
    required this.mohaffezId,
    required this.mohaffezName,
    this.mohaffezPhone,
    required this.sessionType,
    required this.preferredTimeSlot,
    required this.slotDate,
    required this.slotStart,
    required this.slotEnd,
    this.imamAddressLat,
    this.imamAddressLng,
    this.imamAddressText,
  });

  SlotContext copyWith({
    String? mohaffezId,
    String? mohaffezName,
    String? mohaffezPhone,
    String? sessionType,
    String? preferredTimeSlot,
    String? slotDate,
    String? slotStart,
    String? slotEnd,
    double? imamAddressLat,
    double? imamAddressLng,
    String? imamAddressText,
  }) {
    return SlotContext(
      mohaffezId: mohaffezId ?? this.mohaffezId,
      mohaffezName: mohaffezName ?? this.mohaffezName,
      mohaffezPhone: mohaffezPhone ?? this.mohaffezPhone,
      sessionType: sessionType ?? this.sessionType,
      preferredTimeSlot: preferredTimeSlot ?? this.preferredTimeSlot,
      slotDate: slotDate ?? this.slotDate,
      slotStart: slotStart ?? this.slotStart,
      slotEnd: slotEnd ?? this.slotEnd,
      imamAddressLat: imamAddressLat ?? this.imamAddressLat,
      imamAddressLng: imamAddressLng ?? this.imamAddressLng,
      imamAddressText: imamAddressText ?? this.imamAddressText,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'mohaffezId': mohaffezId,
      'mohaffezName': mohaffezName,
      'mohaffezPhone': mohaffezPhone,
      'sessionType': sessionType,
      'preferredTimeSlot': preferredTimeSlot,
      'slotDate': slotDate,
      'slotStart': slotStart,
      'slotEnd': slotEnd,
      'imamAddressLat': imamAddressLat,
      'imamAddressLng': imamAddressLng,
      'imamAddressText': imamAddressText,
    };
  }
}
