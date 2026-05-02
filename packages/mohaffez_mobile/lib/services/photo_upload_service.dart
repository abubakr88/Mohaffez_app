// lib/services/photo_upload_service.dart
// Service for uploading profile photos with image compression
// This is platform-specific and belongs in the mobile package

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class PhotoUploadService {
  /// Upload profile photo to Firebase Storage with compression
  static Future<String> uploadProfilePhoto(
    String userId,
    File imageFile,
    FirebaseFirestore firestore,
  ) async {
    final storageRef = FirebaseStorage.instance
        .ref()
        .child('profile_photos')
        .child('$userId.jpg');

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

    final downloadUrl = await storageRef.getDownloadURL();

    // Update user document directly
    await firestore.collection('users').doc(userId).update({'photoUrl': downloadUrl});

    return downloadUrl;
  }
}
