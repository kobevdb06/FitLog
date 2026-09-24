import 'package:fitlog/features/progress/presentation/sleep_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Two clock times, turned into a night.
///
/// A person knows "half twelve" and "ten past seven". Which date each of those
/// belongs to is the app's job, and getting it wrong makes a seven-hour night
/// thirty-one hours long.
void main() {
  final thursday = DateTime(2026, 3, 5);

  group('twee tijden worden een nacht', () {
    test('voor middernacht in slaap is de avond ervoor', () {
      final night = nightFromTimes(
        wakeDay: thursday,
        asleep: const TimeOfDay(hour: 23, minute: 40),
        woke: const TimeOfDay(hour: 7, minute: 10),
      );

      expect(night.fellAsleepAt, DateTime(2026, 3, 4, 23, 40));
      expect(night.wokeAt, DateTime(2026, 3, 5, 7, 10));
      expect(
        night.wokeAt.difference(night.fellAsleepAt),
        const Duration(hours: 7, minutes: 30),
      );
    });

    test('na middernacht is dezelfde dag', () {
      final night = nightFromTimes(
        wakeDay: thursday,
        asleep: const TimeOfDay(hour: 0, minute: 30),
        woke: const TimeOfDay(hour: 7, minute: 10),
      );

      expect(night.fellAsleepAt, DateTime(2026, 3, 5, 0, 30));
    });

    test('ook over het begin van een maand heen', () {
      final night = nightFromTimes(
        wakeDay: DateTime(2026, 3, 1),
        asleep: const TimeOfDay(hour: 22, minute: 0),
        woke: const TimeOfDay(hour: 6, minute: 0),
      );

      expect(night.fellAsleepAt, DateTime(2026, 2, 28, 22));
    });
  });

  group('een fase zoals een horloge ze toont', () {
    test('uren en minuten, op de gebruikelijke manieren', () {
      expect(parseStageMinutes('1:20'), 80);
      expect(parseStageMinutes('1u20'), 80);
      expect(parseStageMinutes('1.20'), 80);
      expect(parseStageMinutes('1 u 20'), 80);
      expect(parseStageMinutes('0:45'), 45);
    });

    test('of gewoon minuten', () {
      expect(parseStageMinutes('80'), 80);
      expect(parseStageMinutes('80 min'), 80);
    });

    test('leeg is niet ingevuld, en dat is iets anders dan nul', () {
      expect(parseStageMinutes(''), isNull);
      expect(parseStageMinutes('  '), isNull);
      expect(parseStageMinutes('0'), 0);
    });

    test('en onzin is geen lengte', () {
      expect(parseStageMinutes('abc'), isNull);
      expect(parseStageMinutes('1:75'), isNull);
    });
  });

  test('een nacht leest zoals je hem zegt', () {
    expect(nightLength(const Duration(hours: 7, minutes: 30)), '7 u 30');
    expect(nightLength(const Duration(hours: 8)), '8 u');
  });
}
