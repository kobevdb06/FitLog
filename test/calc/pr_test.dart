import 'package:fitlog/core/calc/pr.dart';
import 'package:fitlog/core/db/enums.dart';
import 'package:flutter_test/flutter_test.dart';

double? _valueOf(List<PrCandidate> list, PrType type) {
  for (final c in list) {
    if (c.type == type) return c.value;
  }
  return null;
}

void main() {
  group('prCandidatesForSet', () {
    test('produces all four record types for a normal set', () {
      final candidates = prCandidatesForSet(
        setType: SetType.normal,
        isCompleted: true,
        weightKg: 100,
        reps: 5,
      );
      expect(candidates.map((c) => c.type).toSet(), {
        PrType.maxWeight,
        PrType.maxReps,
        PrType.est1rm,
        PrType.maxSetVolume,
      });
      expect(_valueOf(candidates, PrType.maxWeight), 100);
      expect(_valueOf(candidates, PrType.maxReps), 5);
      expect(_valueOf(candidates, PrType.maxSetVolume), 500);
      expect(
        _valueOf(candidates, PrType.est1rm),
        closeTo(116.6667, 0.0001),
      );
    });

    test('ignores a set that was not checked off', () {
      expect(
        prCandidatesForSet(
          setType: SetType.normal,
          isCompleted: false,
          weightKg: 200,
          reps: 10,
        ),
        isEmpty,
      );
    });

    test('ignores warm-up sets', () {
      expect(
        prCandidatesForSet(
          setType: SetType.warmup,
          isCompleted: true,
          weightKg: 200,
          reps: 10,
        ),
        isEmpty,
      );
    });

    test('a bodyweight set without weight still gives a rep record', () {
      final candidates = prCandidatesForSet(
        setType: SetType.normal,
        isCompleted: true,
        weightKg: null,
        reps: 15,
      );
      expect(candidates.map((c) => c.type), [PrType.maxReps]);
    });
  });

  group('newRecords', () {
    test('everything is a record when there is no history', () {
      final records = detectRecordsForSet(
        setType: SetType.normal,
        isCompleted: true,
        weightKg: 100,
        reps: 5,
        currentBests: const {},
      );
      expect(records, hasLength(4));
    });

    test('only the beaten categories come back', () {
      final records = detectRecordsForSet(
        setType: SetType.normal,
        isCompleted: true,
        weightKg: 100,
        reps: 5,
        currentBests: {
          PrType.maxWeight: 100, // equalled, not beaten
          PrType.maxReps: 12,
          PrType.est1rm: 110,
          PrType.maxSetVolume: 600,
        },
      );
      expect(records.map((r) => r.type), [PrType.est1rm]);
      expect(records.single.value, closeTo(116.6667, 0.0001));
    });

    test('equalling a record is not a record', () {
      final records = detectRecordsForSet(
        setType: SetType.normal,
        isCompleted: true,
        weightKg: 100,
        reps: 5,
        currentBests: {
          PrType.maxWeight: 100,
          PrType.maxReps: 5,
          PrType.est1rm: 100 * (1 + 5 / 30),
          PrType.maxSetVolume: 500,
        },
      );
      expect(records, isEmpty);
    });

    test('a heavier single beats the weight record but not the volume', () {
      final records = detectRecordsForSet(
        setType: SetType.normal,
        isCompleted: true,
        weightKg: 130,
        reps: 1,
        currentBests: {
          PrType.maxWeight: 120,
          PrType.maxReps: 10,
          PrType.est1rm: 125,
          PrType.maxSetVolume: 600,
        },
      );
      expect(records.map((r) => r.type).toSet(), {
        PrType.maxWeight,
        PrType.est1rm,
      });
    });

    test('a long light set beats reps and volume only', () {
      final records = detectRecordsForSet(
        setType: SetType.normal,
        isCompleted: true,
        weightKg: 60,
        reps: 20,
        currentBests: {
          PrType.maxWeight: 120,
          PrType.maxReps: 15,
          PrType.est1rm: 130,
          PrType.maxSetVolume: 1000,
        },
      );
      expect(records.map((r) => r.type).toSet(), {
        PrType.maxReps,
        PrType.maxSetVolume,
      });
    });
  });
}
