import 'package:fitlog/core/calc/volume.dart';
import 'package:fitlog/core/db/enums.dart';
import 'package:flutter_test/flutter_test.dart';

SetVolumeInput _set({
  double? weight = 100,
  int? reps = 5,
  bool completed = true,
  SetType type = SetType.normal,
}) {
  return SetVolumeInput(
    weightKg: weight,
    reps: reps,
    isCompleted: completed,
    setType: type,
  );
}

void main() {
  group('setVolumeKg', () {
    test('is weight times reps', () {
      expect(setVolumeKg(weightKg: 80, reps: 8), 640);
    });

    test('is zero when a value is missing or non-positive', () {
      expect(setVolumeKg(weightKg: null, reps: 8), 0);
      expect(setVolumeKg(weightKg: 80, reps: null), 0);
      expect(setVolumeKg(weightKg: 0, reps: 8), 0);
      expect(setVolumeKg(weightKg: 80, reps: 0), 0);
    });
  });

  group('workoutVolumeKg', () {
    test('sums completed working sets', () {
      final volume = workoutVolumeKg([
        _set(weight: 100, reps: 5),
        _set(weight: 100, reps: 5),
        _set(weight: 60, reps: 10),
      ]);
      expect(volume, 1600);
    });

    test('ignores sets that were never checked off', () {
      final volume = workoutVolumeKg([
        _set(weight: 100, reps: 5),
        _set(weight: 100, reps: 5, completed: false),
      ]);
      expect(volume, 500);
    });

    test('ignores warm-up sets', () {
      final volume = workoutVolumeKg([
        _set(weight: 40, reps: 5, type: SetType.warmup),
        _set(weight: 100, reps: 5),
      ]);
      expect(volume, 500);
    });

    test('counts drop and failure sets', () {
      final volume = workoutVolumeKg([
        _set(weight: 100, reps: 5, type: SetType.drop),
        _set(weight: 100, reps: 5, type: SetType.failure),
      ]);
      expect(volume, 1000);
    });

    test('is zero for an empty workout', () {
      expect(workoutVolumeKg(const []), 0);
    });
  });

  group('countedSets and totalReps', () {
    test('count only completed working sets', () {
      final sets = [
        _set(reps: 5),
        _set(reps: 5, type: SetType.warmup),
        _set(reps: 3, completed: false),
        _set(reps: 8),
      ];
      expect(countedSets(sets), 2);
      expect(totalReps(sets), 13);
    });
  });
}
