import 'package:fitlog/core/calc/set_numbering.dart';
import 'package:fitlog/core/db/enums.dart';
import 'package:flutter_test/flutter_test.dart';

List<String> labelsOf(List<SetType> types) =>
    labelSets(types).map((l) => l.text).toList();

List<int?> workingOf(List<SetType> types) =>
    labelSets(types).map((l) => l.workingIndex).toList();

void main() {
  group('labelSets', () {
    test('numbers plain working sets from one', () {
      expect(
        labelsOf([SetType.normal, SetType.normal, SetType.normal]),
        ['1', '2', '3'],
      );
    });

    test('warm-ups show W and are skipped in the numbering', () {
      expect(
        labelsOf([
          SetType.warmup,
          SetType.warmup,
          SetType.normal,
          SetType.normal,
        ]),
        ['W', 'W', '1', '2'],
      );
    });

    test('drop and failure show their letter but still take a position', () {
      expect(
        labelsOf([
          SetType.normal,
          SetType.normal,
          SetType.drop,
          SetType.normal,
        ]),
        ['1', '2', 'D', '4'],
      );
      expect(
        labelsOf([SetType.normal, SetType.failure, SetType.normal]),
        ['1', 'F', '3'],
      );
    });

    test('a warm-up in the middle does not consume a number', () {
      expect(
        labelsOf([
          SetType.normal,
          SetType.warmup,
          SetType.normal,
          SetType.normal,
        ]),
        ['1', 'W', '2', '3'],
      );
    });

    test('changing a type in the middle renumbers everything below it', () {
      final before = [
        SetType.normal,
        SetType.normal,
        SetType.normal,
        SetType.normal,
      ];
      expect(labelsOf(before), ['1', '2', '3', '4']);

      // The user taps set 2 and makes it a warm-up.
      final after = [...before]..[1] = SetType.warmup;
      expect(labelsOf(after), ['1', 'W', '2', '3']);
    });

    test('turning a warm-up back into a working set renumbers again', () {
      final types = [SetType.warmup, SetType.normal, SetType.normal];
      expect(labelsOf(types), ['W', '1', '2']);

      final promoted = [...types]..[0] = SetType.normal;
      expect(labelsOf(promoted), ['1', '2', '3']);
    });

    test('only warm-ups are left without a working index', () {
      expect(
        workingOf([
          SetType.warmup,
          SetType.normal,
          SetType.drop,
          SetType.warmup,
          SetType.normal,
        ]),
        [null, 0, 1, null, 2],
      );
    });

    test('an empty exercise gives no labels', () {
      expect(labelSets(const []), isEmpty);
    });

    test('an exercise of only warm-ups never shows a number', () {
      expect(labelsOf([SetType.warmup, SetType.warmup]), ['W', 'W']);
      expect(workingOf([SetType.warmup, SetType.warmup]), [null, null]);
    });

    test('the warm-up flag matches the set type', () {
      final labels = labelSets([SetType.warmup, SetType.normal]);
      expect(labels.first.isWarmup, isTrue);
      expect(labels.last.isWarmup, isFalse);
    });
  });
}
