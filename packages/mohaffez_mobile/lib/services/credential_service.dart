// lib/services/credential_service.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;

class CredentialService {
  static const int _maxOriginalBytes = 5 * 1024 * 1024;
  static const int _maxUploadBytes = 3 * 1024 * 1024;
  static const int _maxImagesPerCredential = 3;
  static const Set<String> _allowedExtensions = {'.jpg', '.jpeg', '.png'};

  /// Upload credential images to Firebase Storage
  /// ✅ UPDATED: Now optional - can upload zero images
  static Future<List<String>> uploadCredentialImages(
    List<XFile> images,
    String userId,
  ) async {
    if (images.length > _maxImagesPerCredential) {
      throw Exception('يمكنك اختيار $_maxImagesPerCredential صور كحد أقصى');
    }

    List<String> imageUrls = [];

    for (var image in images) {
      final file = File(image.path);
      final extension = path.extension(image.path).toLowerCase();

      if (!_allowedExtensions.contains(extension)) {
        throw Exception('الصيغة المسموحة: JPG, PNG فقط');
      }

      // Validate original file size before spending time compressing.
      final fileSize = await file.length();
      if (fileSize > _maxOriginalBytes) {
        throw Exception('حجم الملف يجب أن يكون أقل من 5 ميجابايت');
      }

      final compressed = await _compressCredentialImage(file);
      Uint8List uploadBytes;
      String uploadExtension;
      String contentType;

      if (compressed != null && compressed.isNotEmpty) {
        uploadBytes = compressed;
        uploadExtension = '.jpg';
        contentType = 'image/jpeg';
      } else {
        if (fileSize > _maxUploadBytes) {
          throw Exception('تعذر ضغط الصورة. يرجى اختيار صورة أوضح بحجم أصغر');
        }
        uploadBytes = await file.readAsBytes();
        uploadExtension = extension == '.png' ? '.png' : '.jpg';
        contentType = extension == '.png' ? 'image/png' : 'image/jpeg';
      }

      if (uploadBytes.length > _maxUploadBytes) {
        throw Exception('حجم الصورة بعد الضغط يجب أن يكون أقل من 3 ميجابايت');
      }

      // Upload to Firebase Storage
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'credential_$timestamp$uploadExtension';
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('credentials')
          .child(userId)
          .child(fileName);

      await storageRef.putData(
        uploadBytes,
        SettableMetadata(
          contentType: contentType,
          customMetadata: {
            'originalName': path.basename(image.path),
            'originalSize': fileSize.toString(),
            'compressedSize': uploadBytes.length.toString(),
          },
        ),
      );
      final downloadUrl = await storageRef.getDownloadURL();
      imageUrls.add(downloadUrl);
    }

    return imageUrls;
  }

  static Future<Uint8List?> _compressCredentialImage(File file) async {
    final bytes = await FlutterImageCompress.compressWithFile(
      file.absolute.path,
      minWidth: 1600,
      minHeight: 1600,
      quality: 82,
      format: CompressFormat.jpeg,
    );
    return bytes == null ? null : Uint8List.fromList(bytes);
  }

  /// Add a new credential
  /// ✅ UPDATED: Status is now 'approved' directly, imageUrls can be empty
  static Future<void> addCredential({
    required String type,
    required String title,
    required String organization,
    required DateTime issueDate,
    DateTime? expiryDate,
    required List<String> imageUrls, // ✅ Can be empty now
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
      'userId': user.uid, // required by Firestore security rule
      'type': type,
      'title': sanitizedTitle,
      'organization': sanitizedOrg,
      'issueDate': Timestamp.fromDate(issueDate),
      'expiryDate': expiryDate != null ? Timestamp.fromDate(expiryDate) : null,
      'imageUrls': imageUrls,
      'status': 'pending', // admin must review before activation
      'uploadedAt': FieldValue.serverTimestamp(),
      'reviewedAt': null,
      'reviewedBy': null,
      'rejectionReason': null,
    });
  }

  /// Delete credential and its images from storage
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
      final imageUrls =
          List<String>.from(credentialDoc.data()?['imageUrls'] ?? []);

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

  /// Pick images using image picker
  static Future<List<XFile>> pickImages(
      {int maxImages = _maxImagesPerCredential}) async {
    final ImagePicker picker = ImagePicker();
    final List<XFile> images = await picker.pickMultiImage(
      maxWidth: 1600,
      imageQuality: 90,
    );

    if (images.length > maxImages) {
      throw Exception('يمكنك اختيار $maxImages صور كحد أقصى');
    }

    return images;
  }
}
