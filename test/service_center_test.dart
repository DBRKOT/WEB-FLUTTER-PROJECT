import 'package:flutter_test/flutter_test.dart';
import 'package:tech_store/models/order.dart';
import 'package:tech_store/models/order_item.dart';
import 'package:tech_store/models/repair_order.dart';
import 'package:tech_store/models/service.dart';

RepairOrder repair({
  String id = 'rep0000000000001',
  String masterId = 'mst0000000000001',
  required int startHour,
  required int endHour,
  RepairStatus status = RepairStatus.inWork,
}) => RepairOrder(
  id: id,
  clientId: 'usr0000000000001',
  masterId: masterId,
  problem: 'Не включается устройство.',
  startAt: DateTime(2026, 9, 16, startHour),
  endAt: DateTime(2026, 9, 16, endHour),
  status: status,
);

void main() {
  group('занятость мастера', () {
    test('пересечение интервалов у одного мастера запрещено', () {
      final existing = repair(startHour: 10, endHour: 13);
      final planned = repair(
        id: 'rep0000000000002',
        startHour: 12,
        endHour: 15,
      );

      expect(planned.conflictsWith(existing), isTrue);
    });

    test('заявки подряд не считаются пересечением', () {
      final existing = repair(startHour: 10, endHour: 12);
      final planned = repair(
        id: 'rep0000000000002',
        startHour: 12,
        endHour: 14,
      );

      expect(planned.conflictsWith(existing), isFalse);
    });

    test('у разных мастеров одно и то же время допустимо', () {
      final existing = repair(startHour: 10, endHour: 13);
      final planned = repair(
        id: 'rep0000000000002',
        masterId: 'mst0000000000002',
        startHour: 10,
        endHour: 13,
      );

      expect(planned.conflictsWith(existing), isFalse);
    });

    test('завершённая заявка время мастера не занимает', () {
      final existing = repair(
        startHour: 10,
        endHour: 13,
        status: RepairStatus.issued,
      );
      final planned = repair(
        id: 'rep0000000000002',
        startHour: 11,
        endHour: 12,
      );

      expect(planned.conflictsWith(existing), isFalse);
    });

    test('изменение той же заявки не конфликтует с собой', () {
      final existing = repair(startHour: 10, endHour: 13);
      final same = repair(startHour: 11, endHour: 14);

      expect(same.conflictsWith(existing), isFalse);
    });

    test('без выбранного мастера проверка не срабатывает', () {
      final existing = repair(masterId: '', startHour: 10, endHour: 13);
      final planned = repair(
        id: 'rep0000000000002',
        masterId: '',
        startHour: 11,
        endHour: 12,
      );

      expect(planned.conflictsWith(existing), isFalse);
    });
  });

  group('статусы', () {
    test('русские названия статусов заявки', () {
      expect(RepairStatus.newRequest.label, 'Новая');
      expect(RepairStatus.inWork.label, 'В работе');
      expect(RepairStatus.issued.isClosed, isTrue);
      expect(RepairStatus.rejected.isClosed, isTrue);
      expect(RepairStatus.ready.isClosed, isFalse);
    });

    test('значение статуса заявки читается из ответа сервера', () {
      expect(RepairStatus.fromApi('in_work'), RepairStatus.inWork);
      expect(RepairStatus.fromApi(null), RepairStatus.newRequest);
      expect(RepairStatus.inWork.apiValue, 'in_work');
    });

    test('статус заказа переводится в оба направления', () {
      expect(OrderStatus.fromApi('paid'), OrderStatus.paid);
      expect(OrderStatus.created.apiValue, 'new');
      expect(OrderStatus.cancelled.label, 'Отменён');
    });
  });

  group('расчёты', () {
    test('стоимость услуги включает норма-часы по ставке', () {
      const service = Service(
        id: 'srv0000000000001',
        name: 'Замена аккумулятора',
        price: 3200,
        normHours: 1.5,
      );

      expect(service.costFor(hourlyRate: 1200), 3200 + 1800);
    });

    test('сумма позиции заказа считается по количеству и цене', () {
      const item = OrderItem(
        id: 'itm0000000000001',
        orderId: 'ord0000000000001',
        productId: 'prd0000000000001',
        quantity: 3,
        price: 4990,
      );

      expect(item.sum, 14970);
    });
  });
}
