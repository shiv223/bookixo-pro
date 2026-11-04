import 'package:bookixo_pro/features/queue/data/booking_workspace_dto.dart';
import 'package:bookixo_pro/features/queue/domain/booking_service_group.dart';
import 'package:bookixo_pro/features/queue/domain/booking_workspace.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('optional service parentId DTO', () {
    for (final parentId in [null, 0, -1, '', false, <String, Object?>{}, 1.5]) {
      test('invalid/missing parent $parentId remains a root', () {
        final services = BookingWorkspaceDto.services({
          'services': [
            {'id': 2, 'name': 'Cut', 'parentId': parentId},
            {'id': 3, 'name': 'Trim'},
          ],
        });
        expect(services.first.parentId, isNull);
        expect(services.last.parentId, isNull);
        expect(services.every((service) => service.isBookable), isTrue);
      });
    }

    for (final parentId in [1, '1', 1.0, ' 1 ']) {
      test('maps parent $parentId without dropping non-bookable heading', () {
        final services = BookingWorkspaceDto.services({
          'services': [
            {'id': 1, 'name': 'Hair', 'isBookable': false, 'price': 999},
            {'id': 2, 'name': 'Cut', 'parentId': parentId, 'price': 999},
          ],
        });
        expect(services.first.isBookable, isFalse);
        expect(services.last.parentId, '1');
        final groups = BookingServiceGroup.filter(
          services,
          usual: false,
          search: 'hair',
        );
        expect(groups.single.name, 'Hair');
        expect(groups.single.services.map((service) => service.id), ['2']);
      });
    }
  });

  group('service grouping', () {
    const catalogue = [
      BookingService(id: '1', name: 'Hair'),
      BookingService(id: '2', name: 'Cut', parentId: '1', usual: true),
      BookingService(id: '3', name: 'Style', parentId: '1'),
      BookingService(id: '4', name: 'Massage'),
      BookingService(id: '5', name: 'Orphan', parentId: 'missing'),
      BookingService(id: '6', name: 'Self', parentId: '6'),
    ];

    test('bookable parent and children share group; roots are ungrouped', () {
      final groups = BookingServiceGroup.filter(
        catalogue,
        usual: false,
        search: '',
      );
      expect(groups.first.name, 'Hair');
      expect(groups.first.services.map((service) => service.name), [
        'Hair',
        'Style',
      ]);
      expect(groups.last.name, isNull);
      expect(groups.last.services.map((service) => service.name), [
        'Massage',
        'Orphan',
        'Self',
      ]);
    });

    test('parent search preserves both usual and other options', () {
      for (final usual in [true, false]) {
        final groups = BookingServiceGroup.filter(
          catalogue,
          usual: usual,
          search: ' HAIR ',
        );
        expect(groups.single.name, 'Hair');
        expect(groups.single.services.length, usual ? 1 : 2);
      }
    });

    test('child search retains heading and removes nonmatching siblings', () {
      final groups = BookingServiceGroup.filter(
        catalogue,
        usual: false,
        search: 'STYLE',
      );
      expect(groups.single.name, 'Hair');
      expect(groups.single.services.single.id, '3');
      expect(
        BookingServiceGroup.filter(catalogue, usual: true, search: 'absent'),
        isEmpty,
      );
    });
  });
}
