import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/ward_model.dart';

/// Standalone service dedicated to hospital wards initialization and seeding.
/// Can be imported and called anywhere in the app, admin panel, or background runners.
class WardSeedService {
  WardSeedService._();

  /// Default clean hospital wards without redundant 'Ward' suffixes
  static List<WardModel> get defaultHospitalWards => [
    WardModel(wardId: 'ward_icu_1', name: 'ICU 1'),
    WardModel(wardId: 'ward_icu_2', name: 'ICU 2'),
    WardModel(wardId: 'ward_icu_3', name: 'ICU 3'),
    WardModel(wardId: 'ward_minor_ot', name: 'Minor OT'),
    WardModel(wardId: 'ward_ot_1', name: 'OT 1'),
    WardModel(wardId: 'ward_ot_2', name: 'OT 2'),
  ];

  /// Checks if Firebase is initialized and available
  static bool get isFirebaseAvailable {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Seeds hospital wards into Cloud Firestore.
  /// If [wards] is not provided, defaults to [defaultHospitalWards].
  /// Overwrites documents cleanly so no legacy properties (like 'wardName') remain.
  static Future<bool> seedWards({
    List<WardModel>? wards,
    bool overwrite = true,
    FirebaseFirestore? firestoreInstance,
  }) async {
    if (!isFirebaseAvailable) {
      debugPrint('[WardSeedService] Firebase not initialized. Skipping Firestore write.');
      return false;
    }

    final targetWards = wards ?? defaultHospitalWards;
    final firestore = firestoreInstance ?? FirebaseFirestore.instance;
    final wardsCollection = firestore.collection('wards');

    try {
      final existing = await wardsCollection.get();
      final needsUpdate = existing.docs.isEmpty ||
          overwrite ||
          existing.docs.any((d) =>
              (d.data()['name'] ?? '').toString().contains('Ward') ||
              d.data().containsKey('wardName') ||
              d.data().containsKey('id'));

      if (needsUpdate) {
        final batch = firestore.batch();
        for (final ward in targetWards) {
          final docRef = wardsCollection.doc(ward.wardId);
          final data = <String, dynamic>{
            'wardId': ward.wardId,
            'name': ward.name,
            'createdAt': ward.createdAt.toIso8601String(),
          };
          batch.set(docRef, data);
        }

        await batch.commit();
        debugPrint('[WardSeedService] Successfully seeded/updated ${targetWards.length} clean wards in Firestore.');
        return true;
      }

      debugPrint('[WardSeedService] Wards are already up-to-date in Firestore.');
      return true;
    } catch (e) {
      debugPrint('[WardSeedService] Batch commit error: $e. Falling back to individual set operations.');
      bool anySuccess = false;
      for (final ward in targetWards) {
        try {
          await wardsCollection.doc(ward.wardId).set({
            'wardId': ward.wardId,
            'name': ward.name,
            'createdAt': ward.createdAt.toIso8601String(),
          });
          anySuccess = true;
        } catch (inner) {
          debugPrint('[WardSeedService] Error writing ward ${ward.wardId}: $inner');
        }
      }
      return anySuccess;
    }
  }

  /// Deletes all documents in the 'wards' collection if a complete reset is required.
  static Future<bool> clearAllWards({FirebaseFirestore? firestoreInstance}) async {
    if (!isFirebaseAvailable) return false;
    final firestore = firestoreInstance ?? FirebaseFirestore.instance;
    try {
      final snapshot = await firestore.collection('wards').get();
      final batch = firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      debugPrint('[WardSeedService] Cleared ${snapshot.docs.length} wards from Firestore.');
      return true;
    } catch (e) {
      debugPrint('[WardSeedService] Error clearing wards: $e');
      return false;
    }
  }
}
