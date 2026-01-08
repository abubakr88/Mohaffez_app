import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;

class CredentialService {
  // Upload credential images to Firebase Storage
  static Future<List<String>> uploadCredentialImages(List<XFile> images, String userId) async {
    List<String> imageUrls = [];
    
    for (var image in images) {
      // Validate file size (max 5MB)
      final file = File(image.path);
      final fileSize = await file.length();
      if (fileSize > 5 * 1024 * 1024) {
        throw Exception('حجم الملف يجب أن يكون أقل من 5 ميجابايت');
      }

      // Validate file type
      final extension = path.extension(image.path).toLowerCase();
      if (extension != '.jpg' && extension != '.jpeg' && extension != '.png') {
        throw Exception('الصيغة المسموحة: JPG, PNG فقط');
      }

      // Upload to Firebase Storage
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'credential_${timestamp}_${path.basename(image.path)}';
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('credentials')
          .child(userId)
          .child(fileName);

      await storageRef.putFile(file);
      final downloadUrl = await storageRef.getDownloadURL();
      imageUrls.add(downloadUrl);
    }

    return imageUrls;
  }

  // Add a new credential
  static Future<void> addCredential({
    required String type,
    required String title,
    required String organization,
    required DateTime issueDate,
    DateTime? expiryDate,
    required List<String> imageUrls,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('يجب تسجيل الدخول');

    // Sanitize inputs
    final sanitizedTitle = title.trim();
    final sanitizedOrg = organization.trim();

    if (sanitizedTitle.isEmpty || sanitizedOrg.isEmpty) {
      throw Exception('يرجى ملء جميع الحقول المطلوبة');
    }

    final credentialRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('credentials')
        .doc();

    await credentialRef.set({
      'id': credentialRef.id,
      'type': type,
      'title': sanitizedTitle,
      'organization': sanitizedOrg,
      'issueDate': Timestamp.fromDate(issueDate),
      'expiryDate': expiryDate != null ? Timestamp.fromDate(expiryDate) : null,
      'imageUrls': imageUrls,
      'status': 'pending', // pending, approved, rejected
      'uploadedAt': FieldValue.serverTimestamp(),
      'reviewedAt': null,
      'reviewedBy': null,
      'rejectionReason': null,
    });
  }

  // Delete credential
  static Future<void> deleteCredential(String credentialId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Get credential to delete images from storage
    final credentialDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('credentials')
        .doc(credentialId)
        .get();

    if (credentialDoc.exists) {
      final imageUrls = List<String>.from(credentialDoc.data()?['imageUrls'] ?? []);
      
      // Delete images from storage
      for (var url in imageUrls) {
        try {
          final ref = FirebaseStorage.instance.refFromURL(url);
          await ref.delete();
        } catch (e) {
          // Continue even if delete fails
        }
      }
    }

    // Delete credential document
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('credentials')
        .doc(credentialId)
        .delete();
  }

  // Pick images using image picker
  static Future<List<XFile>> pickImages({int maxImages = 3}) async {
    final ImagePicker picker = ImagePicker();
    final List<XFile> images = await picker.pickMultiImage(
      maxWidth: 1200,
      imageQuality: 85,
    );

    if (images.length > maxImages) {
      throw Exception('يمكنك اختيار $maxImages صور كحد أقصى');
    }

    return images;
  }
}
