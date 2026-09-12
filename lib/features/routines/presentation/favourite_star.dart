/// The star that puts a routine on your home screen.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app/app_controller.dart';
import '../../../core/db/database.dart';
import '../../../core/theme/app_colors.dart';

class FavouriteStar extends ConsumerWidget {
  const FavouriteStar({super.key, required this.routine});

  final RoutineRow routine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final starred = routine.isFavourite;
    return IconButton(
      tooltip: starred ? 'Uit favorieten halen' : 'Favoriet maken',
      icon: Icon(
        starred ? Icons.star : Icons.star_border,
        color: starred ? AppColors.record : null,
      ),
      onPressed: () async {
        await ref
            .read(databaseProvider)
            .routinesDao
            .setFavourite(routine.id, favourite: !starred);
      },
    );
  }
}
