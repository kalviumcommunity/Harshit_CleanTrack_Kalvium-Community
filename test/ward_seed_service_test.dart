import 'package:flutter_test/flutter_test.dart';
import 'package:cleantrack/services/firestore_service.dart';

void main() {
  group('Default Hospital Wards Tests', () {
    test('defaultHospitalWards contains 6 standard hospital wards', () {
      final wards = FirestoreService.defaultHospitalWards;
      expect(wards.length, 6);

      final names = wards.map((w) => w.name).toList();
      expect(names, [
        'ICU 1',
        'ICU 2',
        'ICU 3',
        'Minor OT',
        'OT 1',
        'OT 2',
      ]);
    });

    test('All defaultHospitalWards have clean names without "Ward" suffix', () {
      for (final ward in FirestoreService.defaultHospitalWards) {
        expect(
          ward.name.toLowerCase().contains('ward'),
          isFalse,
          reason: 'Ward name "${ward.name}" should not contain the word "Ward"',
        );
        expect(
          ward.toJson().containsKey('wardName'),
          isFalse,
          reason: 'JSON should not have legacy "wardName" key',
        );
      }
    });

    test('Ward IDs match standard hospital convention', () {
      final wardIds = FirestoreService.defaultHospitalWards.map((w) => w.wardId).toList();
      expect(wardIds, [
        'ward_icu_1',
        'ward_icu_2',
        'ward_icu_3',
        'ward_minor_ot',
        'ward_ot_1',
        'ward_ot_2',
      ]);
    });
  });
}
