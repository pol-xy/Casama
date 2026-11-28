import 'package:casama/core/utils/date_time_utils.dart';
import 'package:casama/data/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UTC & Local Timestamp Standardization', () {
    test('toSupabaseUtcIso always converts to UTC ending in Z', () {
      final local = DateTime(2026, 11, 26, 23, 35, 12);
      final iso = toSupabaseUtcIso(local);

      expect(iso.endsWith('Z'), isTrue);
      expect(DateTime.parse(iso).toLocal(), local);
      expect(toSupabaseUtcIsoOrNull(null), isNull);
      expect(nowSupabaseUtcIso().endsWith('Z'), isTrue);
    });

    test('parseSupabaseTimestamp handles Z, +00, offset, and timezone-less UTC strings cleanly', () {
      final expectedEpoch =
          DateTime.utc(2026, 11, 26, 15, 35).millisecondsSinceEpoch;

      for (final raw in [
        '2026-11-26T15:35:00Z',
        '2026-11-26 15:35:00+00',
        '2026-11-26T23:35:00+08:00',
        '2026-11-26 15:35:00',
      ]) {
        final parsed = parseSupabaseTimestamp(raw);
        expect(parsed.isUtc, isFalse, reason: 'Failed local check for $raw');
        expect(
          parsed.millisecondsSinceEpoch,
          expectedEpoch,
          reason: 'Epoch mismatch for $raw',
        );
      }

      expect(parseSupabaseTimestampOrNull(null), isNull);
      expect(parseSupabaseTimestampOrNull('   '), isNull);
    });

    test('profiles.birthday stays strictly date-only YYYY-MM-DD without UTC shift', () {
      final parsed = parseSupabaseDateOnly('2000-05-15');
      expect(parsed, DateTime(2000, 5, 15));
      expect(parsed!.isUtc, isFalse);
      expect(formatSupabaseDateOnly(parsed), '2000-05-15');

      final profile = UserProfile.fromJson({
        'id': 'u1',
        'display_name': 'JP',
        'birthday': '2000-05-15',
      });
      expect(profile.birthday, DateTime(2000, 5, 15));
      expect(profile.toJson()['birthday'], '2000-05-15');
    });

    test('Models serialize all timestamptz fields in UTC (Z) and hydrate in local time', () {
      final localTime = DateTime(2026, 11, 26, 23, 35);

      // HousematesAgendaInvitation
      final agenda = HousematesAgendaInvitation(
        id: 'm1',
        activity: 'Dinner',
        location: 'Kitchen',
        scheduledTime: localTime,
      );
      final agendaJson = agenda.toJson();
      expect((agendaJson['scheduled_time'] as String).endsWith('Z'), isTrue);
      final parsedAgenda = HousematesAgendaInvitation.fromJson(agendaJson);
      expect(parsedAgenda.scheduledTime.isUtc, isFalse);
      expect(
        parsedAgenda.scheduledTime.millisecondsSinceEpoch,
        localTime.millisecondsSinceEpoch,
      );

      // ParcelItem
      final parcel = ParcelItem(
        id: 'p1',
        householdId: 'h1',
        buyerId: 'u1',
        buyerName: 'JP',
        courier: 'J&T Express',
        expectedArrival: localTime,
        paymentType: ParcelPaymentType.paid,
        status: ParcelStatus.expected,
      );
      final parcelJson = parcel.toJson();
      expect((parcelJson['expected_arrival'] as String).endsWith('Z'), isTrue);
      final parsedParcel = ParcelItem.fromJson(parcelJson);
      expect(parsedParcel.expectedArrival.isUtc, isFalse);
      expect(
        parsedParcel.expectedArrival.millisecondsSinceEpoch,
        localTime.millisecondsSinceEpoch,
      );

      // MaintenanceTask
      final task = MaintenanceTask(
        id: 't1',
        householdId: 'h1',
        title: 'Clean',
        description: 'Sweep',
        category: TaskCategory.cleaning,
        urgency: TaskUrgency.low,
        status: TaskStatus.done,
        createdBy: 'u1',
        createdByName: 'JP',
        createdAt: localTime,
        completedAt: localTime,
      );
      final taskJson = task.toJson();
      expect((taskJson['created_at'] as String).endsWith('Z'), isTrue);
      expect((taskJson['completed_at'] as String).endsWith('Z'), isTrue);
      expect(taskJson.containsKey('due_date'), isFalse);
      final parsedTask = MaintenanceTask.fromJson(taskJson);
      expect(parsedTask.createdAt.isUtc, isFalse);
      expect(parsedTask.completedAt!.isUtc, isFalse);

      // ChatMessage & QuickSnapComment & ChoreRouletteRecord
      final msg = ChatMessage(
        id: 'c1',
        senderId: 'u1',
        senderName: 'JP',
        content: 'Hi',
        createdAt: localTime,
        isCurrentUser: true,
      );
      expect((msg.toJson()['created_at'] as String).endsWith('Z'), isTrue);
      expect(ChatMessage.fromJson(msg.toJson()).createdAt.isUtc, isFalse);

      final comment = QuickSnapComment(
        id: 'qc1',
        userId: 'u1',
        userName: 'JP',
        text: 'Nice',
        createdAt: localTime,
      );
      expect((comment.toJson()['created_at'] as String).endsWith('Z'), isTrue);
      expect(QuickSnapComment.fromJson(comment.toJson()).createdAt.isUtc, isFalse);

      final roulette = ChoreRouletteRecord(
        id: 'r1',
        householdId: 'h1',
        taskId: 't1',
        choreTitle: 'Trash',
        selectedUserId: 'u1',
        selectedUserName: 'JP',
        spunByUserId: 'u2',
        spunByName: 'Maria',
        status: 'completed',
        bonusPoints: 4,
        createdAt: localTime,
        completedAt: localTime,
      );
      final rouletteJson = roulette.toJson();
      expect((rouletteJson['created_at'] as String).endsWith('Z'), isTrue);
      expect((rouletteJson['completed_at'] as String).endsWith('Z'), isTrue);
      final parsedRoulette = ChoreRouletteRecord.fromJson(rouletteJson);
      expect(parsedRoulette.createdAt.isUtc, isFalse);
      expect(parsedRoulette.completedAt!.isUtc, isFalse);
    });
  });
}
