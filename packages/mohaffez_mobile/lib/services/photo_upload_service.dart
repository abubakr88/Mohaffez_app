// lib/services/photo_upload_service.dart
// Service for uploading profile photos with image compression
// This is platform-specific and belongs in the mobile package

import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class PhotoUploadService {
  static Reference _profilePhotoRef(String userId) {
    return FirebaseStorage.instance
        .ref()
        .child('profile_photos')
        .child('$userId.jpg');
  }

  static Future<String> _saveDownloadUrl(
    String userId,
    FirebaseFirestore firestore,
  ) async {
    final downloadUrl = await _profilePhotoRef(userId).getDownloadURL();
    await firestore.collection('users').doc(userId).update({
      'photoUrl': downloadUrl,
    });
    return downloadUrl;
  }

  /// Upload profile photo to Firebase Storage with compression
  static Future<String> uploadProfilePhoto(
    String userId,
    File imageFile,
    FirebaseFirestore firestore,
  ) async {
    final storageRef = _profilePhotoRef(userId);

    final compressed = await FlutterImageCompress.compressWithFile(
      imageFile.absolute.path,
      minWidth: 400,
      minHeight: 400,
      quality: 85,
    );

    if (compressed != null) {
      await storageRef.putData(compressed);
    } else {
      await storageRef.putFile(imageFile);
    }

    return _saveDownloadUrl(userId, firestore);
  }

  /// Upload profile photo bytes on web, where dart:io File upload is unavailable.
  static Future<String> uploadProfilePhotoBytes(
    String userId,
    Uint8List imageBytes,
    FirebaseFirestore firestore, {
    String contentType = 'image/jpeg',
  }) async {
    final storageRef = _profilePhotoRef(userId);
    final safeContentType =
        contentType.startsWith('image/') ? contentType : 'image/jpeg';

    await storageRef.putData(
      imageBytes,
      SettableMetadata(contentType: safeContentType),
    );

    return _saveDownloadUrl(userId, firestore);
  }
}
