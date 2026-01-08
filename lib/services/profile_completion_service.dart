import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileCompletionService {
  // Calculate profile completion percentage for Mohaffez
  static Future<ProfileCompletionData> calculateCompletion(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      if (!userDoc.exists) {
        return ProfileCompletionData(percentage: 0, missingFields: []);
      }

      final data = userDoc.data() ?? {};
      final List<String> missingFields = [];
      double percentage = 0;

      // Basic info (name, email, photo): 20%
      final hasBasicInfo = (data['name'] as String?)?.isNotEmpty == true &&
          (data['email'] as String?)?.isNotEmpty == true &&
          (data['photoUrl'] as String?)?.isNotEmpty == true;
      if (hasBasicInfo) {
        percentage += 20;
      } else {
        if ((data['name'] as String?)?.isEmpty != false) missingFields.add('الاسم');
        if ((data['email'] as String?)?.isEmpty != false) missingFields.add('البريد الإلكتروني');
        if ((data['photoUrl'] as String?)?.isEmpty != false) missingFields.add('الصورة الشخصية');
      }

      // Bio/description: 10%
      final hasBio = (data['bio'] as String?)?.isNotEmpty == true;
      if (hasBio) {
        percentage += 10;
      } else {
        missingFields.add('نبذة تعريفية');
      }

      // Location/address: 15%
      final hasLocation = (data['addressText'] as String?)?.isNotEmpty == true &&
          data['addressLat'] != null &&
          data['addressLng'] != null;
      if (hasLocation) {
        percentage += 15;
      } else {
        missingFields.add('الموقع');
      }

      // Specialization: 10%
      final hasSpecialization = (data['specialization'] as String?)?.isNotEmpty == true;
      if (hasSpecialization) {
        percentage += 10;
      } else {
        missingFields.add('التخصص');
      }

      // Credentials/certificates (at least 1): 20%
      final credentialsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('credentials')
          .where('status', isEqualTo: 'approved')
          .limit(1)
          .get();
      
      if (credentialsSnapshot.docs.isNotEmpty) {
        percentage += 20;
      } else {
        missingFields.add('شهادات معتمدة');
      }

      // Availability schedule set: 15%
      final availabilitySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('availability')
          .limit(1)
          .get();
      
      if (availabilitySnapshot.docs.isNotEmpty) {
        percentage += 15;
      } else {
        missingFields.add('جدول المواعيد');
      }

      // Phone number verified: 10%
      final badges = data['badges'] as Map<String, dynamic>?;
      final phoneVerified = badges?['phoneVerified'] == true;
      if (phoneVerified) {
        percentage += 10;
      } else {
        missingFields.add('التحقق من رقم الهاتف');
      }

      return ProfileCompletionData(
        percentage: percentage,
        missingFields: missingFields,
      );
    } catch (e) {
      return ProfileCompletionData(percentage: 0, missingFields: []);
    }
  }

  // Check and award automatic badges
  static Future<void> checkAndAwardBadges(String userId) async {
    try {
      final userRef = FirebaseFirestore.instance.collection('users').doc(userId);
      final userDoc = await userRef.get();
      final data = userDoc.data() ?? {};

      final badges = Map<String, bool>.from(data['badges'] as Map? ?? {});
      final rating = (data['rating'] as num?)?.toDouble() ?? 0;

      // Check for Experienced Badge (50+ sessions with 4.5+ rating)
      final completedSessions = await FirebaseFirestore.instance
          .collection('hafizSessions')
          .where('mohaffezId', isEqualTo: userId)
          .get();

      if (completedSessions.docs.length >= 50 && rating >= 4.5) {
        badges['experienced'] = true;
      }

      // Update badges if changed
      if (badges.isNotEmpty) {
        await userRef.update({'badges': badges});
      }
    } catch (e) {
      // Handle error silently
    }
  }
}

class ProfileCompletionData {
  final double percentage;
  final List<String> missingFields;

  ProfileCompletionData({
    required this.percentage,
    required this.missingFields,
  });
}
