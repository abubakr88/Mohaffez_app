import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/dev_mode_model.dart';
import '../models/system_config_model.dart';

class SystemConfigRepository {
  final FirebaseFirestore _firestore;

  SystemConfigRepository(this._firestore);

  Stream<SystemConfigModel> watchGlobalConfig() {
    return _firestore
        .collection('systemConfig')
        .doc('global')
        .snapshots()
        .map((doc) {
      if (!doc.exists || doc.data() == null) {
        return SystemConfigModel.defaults();
      }
      return SystemConfigModel.fromFirestore(doc);
    }).handleError((Object e) {
      debugPrint('⚠️ systemConfig stream error: $e');
      return SystemConfigModel.defaults();
    });
  }

  Future<SystemConfigModel> getGlobalConfig() async {
    final doc = await _firestore.collection('systemConfig').doc('global').get();
    if (!doc.exists || doc.data() == null) {
      return SystemConfigModel.defaults();
    }
    return SystemConfigModel.fromFirestore(doc);
  }

  Stream<DevModeModel> watchDevMode() {
    return _firestore
        .collection('systemConfig')
        .doc('devMode')
        .snapshots()
        .map((doc) {
      if (!doc.exists || doc.data() == null) {
        return DevModeModel.defaults();
      }
      return DevModeModel.fromFirestore(doc);
    }).handleError((Object e) {
      debugPrint('⚠️ devMode stream error: $e');
      return DevModeModel.defaults();
    });
  }

  Future<void> updateGlobalConfig(
      Map<String, dynamic> updates, String adminUid) {
    return _firestore.collection('systemConfig').doc('global').set(
      {
        ...updates,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': adminUid,
      },
      SetOptions(merge: true),
    );
  }

  Future<void> updateDevMode(Map<String, dynamic> updates, String adminUid) {
    return _firestore.collection('systemConfig').doc('devMode').set(
      {
        ...updates,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': adminUid,
      },
      SetOptions(merge: true),
    );
  }
}
