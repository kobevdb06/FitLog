import 'dart:convert';

import 'package:fitlog/features/dashboard/domain/home_layout.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Start tab as a grid: places and sizes in cells, and nothing ever
/// shifting on its own.
void main() {
  HomeLayout grid(Map<HomeBlock, HomeSpot> spots) => HomeLayout(spots);

  group('de standaard', () {
    test('de blokken onder elkaar op hun beginmaat, Vandaag bovenaan', () {
      final layout = defaultHomeLayout();

      expect(layout.visible.first, HomeBlock.today);
      expect(layout.spotOf(HomeBlock.today), const HomeSpot(0, 0, 4, 3));
      expect(layout.spotOf(HomeBlock.week), const HomeSpot(0, 3, 4, 2));
      expect(layout.shows(HomeBlock.favourites), isFalse);
    });

    test('stappen alleen met een horloge, de coach alleen met een sleutel', () {
      expect(defaultHomeLayout().shows(HomeBlock.steps), isFalse);
      expect(defaultHomeLayout().shows(HomeBlock.coach), isFalse);
      final both = defaultHomeLayout(health: true, coach: true);
      expect(both.shows(HomeBlock.steps), isTrue);
      expect(both.shows(HomeBlock.coach), isTrue);
    });

    test('is wat een app krijgt die nooit iets anders hoorde', () {
      expect(parseHomeLayout(null).spots, defaultHomeLayout().spots);
      expect(parseHomeLayout('', coach: true).shows(HomeBlock.coach), isTrue);
    });
  });

  group('verplaatsen', () {
    final layout = grid({
      HomeBlock.today: const HomeSpot(0, 0, 4, 3),
      HomeBlock.recovery: const HomeSpot(0, 3, 2, 2),
      HomeBlock.records: const HomeSpot(2, 3, 2, 2),
      HomeBlock.week: const HomeSpot(0, 5, 4, 2),
    });

    test('naar een vrije plek: de oude plek blijft leeg, niets anders '
        'beweegt', () {
      final moved = layout.moved(HomeBlock.records, 2, 7);

      expect(moved.spotOf(HomeBlock.records), const HomeSpot(2, 7, 2, 2));
      for (final block in [
        HomeBlock.today,
        HomeBlock.recovery,
        HomeBlock.week,
      ]) {
        expect(moved.spotOf(block), layout.spotOf(block), reason: '$block');
      }
      // Where it was is free now.
      expect(moved.fits(HomeBlock.volume, const HomeSpot(2, 3, 2, 2)), isTrue);
    });

    test('op een blok van dezelfde grootte: ze wisselen van plaats', () {
      expect(layout.dropAt(HomeBlock.records, 0, 3), (
        HomeDrop.swaps,
        HomeBlock.recovery,
      ));

      final swapped = layout.moved(HomeBlock.records, 0, 3);

      expect(swapped.spotOf(HomeBlock.records), const HomeSpot(0, 3, 2, 2));
      expect(swapped.spotOf(HomeBlock.recovery), const HomeSpot(2, 3, 2, 2));
    });

    test('half over een ander blok, of over een groter: terug, niets wordt '
        'weggeduwd', () {
      expect(layout.dropAt(HomeBlock.records, 1, 3).$1, HomeDrop.blocked);
      expect(layout.dropAt(HomeBlock.records, 0, 5).$1, HomeDrop.blocked);
      expect(layout.moved(HomeBlock.records, 1, 3).spots, layout.spots);
    });

    test('niet van het raster af', () {
      expect(layout.dropAt(HomeBlock.records, 3, 8).$1, HomeDrop.blocked);
      expect(layout.dropAt(HomeBlock.records, -1, 8).$1, HomeDrop.blocked);
    });
  });

  group('aan een rand slepen', () {
    final layout = grid({
      HomeBlock.recovery: const HomeSpot(0, 0, 2, 2),
      HomeBlock.records: const HomeSpot(3, 0, 1, 2),
    });

    test('groeit per vakje, en stopt tegen een buurblok', () {
      expect(
        layout.stretched(HomeBlock.recovery, HomeEdge.right, 1),
        const HomeSpot(0, 0, 3, 2),
      );
      // One more would cover Records: it stops at three.
      expect(
        layout.stretched(HomeBlock.recovery, HomeEdge.right, 5),
        const HomeSpot(0, 0, 3, 2),
      );
    });

    test('naar beneden en terug, niet kleiner dan het mag', () {
      expect(
        layout.stretched(HomeBlock.recovery, HomeEdge.bottom, 2),
        const HomeSpot(0, 0, 2, 4),
      );
      expect(
        layout.stretched(HomeBlock.recovery, HomeEdge.bottom, -1),
        const HomeSpot(0, 0, 2, 2),
      );
    });

    test('links en boven verschuiven de hoek mee', () {
      final lower = grid({HomeBlock.recovery: const HomeSpot(2, 2, 2, 2)});

      expect(
        lower.stretched(HomeBlock.recovery, HomeEdge.left, 2),
        const HomeSpot(0, 2, 4, 2),
      );
      expect(
        lower.stretched(HomeBlock.recovery, HomeEdge.top, 1),
        const HomeSpot(2, 1, 2, 3),
      );
    });

    test('nooit breder of hoger dan het blok mag zijn', () {
      final week = grid({HomeBlock.week: const HomeSpot(0, 0, 4, 2)});
      expect(
        week.stretched(HomeBlock.week, HomeEdge.bottom, 4),
        const HomeSpot(0, 0, 4, 3),
      );
    });
  });

  group('weghalen en terugzetten', () {
    test('weg laat een lege plek; terug komt op de eerste vrije plek', () {
      final layout = defaultHomeLayout();
      final without = layout.without(HomeBlock.week);

      expect(without.shows(HomeBlock.week), isFalse);
      expect(without.hidden, contains(HomeBlock.week));
      expect(
        without.spotOf(HomeBlock.recovery),
        layout.spotOf(HomeBlock.recovery),
      );

      final back = without.withShown(HomeBlock.week);
      expect(back.spotOf(HomeBlock.week), const HomeSpot(0, 3, 4, 2));
    });

    test('of op de plek waar je het naartoe sleepte', () {
      final layout = defaultHomeLayout();
      final at = HomeSpot(0, layout.rows + 1, 4, 3);

      expect(
        layout
            .withShown(HomeBlock.favourites, at: at)
            .spotOf(HomeBlock.favourites),
        at,
      );
    });
  });

  group('opschrijven en teruglezen', () {
    test('elke plek en elk verborgen blok overleeft het', () {
      final layout = defaultHomeLayout()
          .moved(HomeBlock.records, 0, 20)
          .without(HomeBlock.volume);

      final read = parseHomeLayout(encodeHomeLayout(layout));

      expect(read.spots, layout.spots);
      expect(read.shows(HomeBlock.volume), isFalse);
      expect(read.shows(HomeBlock.favourites), isFalse);
    });

    test('een lege rij tussen twee blokken blijft leeg', () {
      final layout = grid({
        HomeBlock.today: const HomeSpot(0, 0, 4, 3),
        HomeBlock.week: const HomeSpot(0, 6, 4, 2),
      });

      final read = parseHomeLayout(encodeHomeLayout(layout));

      expect(read.spotOf(HomeBlock.week), const HomeSpot(0, 6, 4, 2));
      expect(read.rows, 8);
    });
  });

  group('een indeling van voor het raster', () {
    test('ziet eruit zoals ze eruitzag: breed onder elkaar, twee halve naast '
        'elkaar', () {
      final read = parseHomeLayout(
        jsonEncode({
          'order': [
            'vandaag',
            'herstel',
            'records',
            'deze-week',
            'favorieten',
            'volume',
            'stappen',
            'coach',
          ],
          'hidden': ['favorieten'],
          'small': ['herstel', 'records'],
        }),
      );

      expect(read.spotOf(HomeBlock.today), const HomeSpot(0, 0, 4, 3));
      expect(read.spotOf(HomeBlock.recovery), const HomeSpot(0, 3, 2, 3));
      expect(read.spotOf(HomeBlock.records), const HomeSpot(2, 3, 2, 3));
      expect(read.spotOf(HomeBlock.week), const HomeSpot(0, 6, 4, 2));
      expect(read.shows(HomeBlock.favourites), isFalse);
      // What it showed, it shows: steps and coach were in the list.
      expect(read.shows(HomeBlock.steps), isTrue);
      expect(read.shows(HomeBlock.coach), isTrue);
    });
  });

  group('een opgeslagen waarde die niet te vertrouwen is', () {
    test('onzin valt terug op de standaard', () {
      expect(parseHomeLayout('{{{').spots, defaultHomeLayout().spots);
      expect(parseHomeLayout('[1, 2]').spots, defaultHomeLayout().spots);
    });

    test('een plek van het raster af, te groot of over een ander blok wordt '
        'hersteld', () {
      final read = parseHomeLayout(
        jsonEncode({
          'v': 2,
          'spots': {
            'vandaag': [0, 0, 4, 3],
            'deze-week': [3, 1, 9, 9],
            'herstel': [-2, 40, 1, 1],
          },
          'hidden': ['favorieten', 'records', 'volume', 'stappen', 'coach'],
        }),
      );

      for (final block in read.visible) {
        final spot = read.spotOf(block)!;
        expect(read.fits(block, spot), isTrue, reason: '$block op $spot');
      }
      expect(read.spotOf(HomeBlock.week)!.w, 4);
      expect(read.spotOf(HomeBlock.week)!.h, 3);
      expect(read.spotOf(HomeBlock.recovery), const HomeSpot(0, 40, 2, 2));
    });

    test('een blok dat er toen nog niet was, komt onderaan bij', () {
      final read = parseHomeLayout(
        jsonEncode({
          'v': 2,
          'spots': {
            'vandaag': [0, 0, 4, 3],
          },
          'hidden': ['deze-week'],
        }),
      );

      expect(read.shows(HomeBlock.week), isFalse);
      expect(read.shows(HomeBlock.recovery), isTrue);
      expect(read.shows(HomeBlock.favourites), isFalse);
      expect(read.spotOf(HomeBlock.recovery)!.y, greaterThanOrEqualTo(3));
    });
  });
}
