import 'dart:ui';

import 'package:fitlog/core/theme/app_colors.dart';
import 'package:flutter_test/flutter_test.dart';

/// The colour a muscle group is drawn in.
void main() {
  test('the ones the app knows keep their own colour', () {
    expect(AppColors.forMuscle('borst'), AppColors.muscleColors['borst']);
    expect(AppColors.forMuscle('Borst'), AppColors.muscleColors['borst']);
  });

  test('one you added gets a colour of its own, not grey', () {
    const grijs = Color(0xFF8A8F98);
    expect(AppColors.forMuscle('serratus'), isNot(grijs));
  });

  test('and the same one every time', () {
    // A muscle that changes colour when you reopen the app is worse than
    // grey, so this may never lean on hashCode.
    expect(AppColors.forMuscle('serratus'), AppColors.forMuscle('serratus'));
  });

  test('and it is one of the palette the app already uses', () {
    // Not "all different": there are seven colours, so two names can land on
    // the same one. That is a collision, not a bug - what matters is that it
    // is a colour from the app and never the grey that means "none".
    const grijs = Color(0xFF8A8F98);
    for (final naam in ['serratus', 'rotator cuff', 'schuine buikspieren']) {
      final kleur = AppColors.forMuscle(naam);
      expect(AppColors.routinePalette, contains(kleur));
      expect(kleur, isNot(grijs));
    }
  });

  test('nothing at all is still grey', () {
    const grijs = Color(0xFF8A8F98);
    expect(AppColors.forMuscle(null), grijs);
    expect(AppColors.forMuscle(''), grijs);
  });
}
