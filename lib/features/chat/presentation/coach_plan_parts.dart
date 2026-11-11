import 'package:flutter/widgets.dart';

import '../../../core/db/database.dart';
import '../domain/coach_proposal.dart';

/// What the coach shows of the schema's.
///
/// A schema is made and changed in a conversation with the coach, so the
/// coach screen shows its cards and the strip above that conversation, and
/// the drawer lists the schema's. The coach does not know schema's, though:
/// the schema's fill this in (`PlanCoachParts`), and the router hands it to
/// the coach screen. That way the schema's build on the coach, and not the
/// other way round as well (DECISIONS 301).
abstract interface class CoachPlanParts {
  /// The card for [proposal], the [index]th in [message]; null for one
  /// that is not about a schema.
  Widget? card(ChatMessageRow message, int index, CoachProposal proposal);

  /// Above the conversation of [planId]; [onOpen] opens its panel.
  Widget strip(String planId, {required VoidCallback onOpen});

  /// The panel of [planId]. [onStart] starts one of its sessions, [onOpen]
  /// opens one to change, and [onDiscuss] brings one into the conversation.
  Future<void> showPanel(
    BuildContext context,
    String planId, {
    required ValueChanged<String> onStart,
    required ValueChanged<String> onOpen,
    required ValueChanged<RoutineRow> onDiscuss,
  });

  /// The schema's in the drawer, each with the conversation it was made
  /// in. [shown] is the conversation on screen, [onOpen] opens one, and
  /// [heading] sets a heading the way the drawer sets its own.
  Widget shelf({
    required String? shown,
    required ValueChanged<ChatThreadRow> onOpen,
    required Widget Function(String label) heading,
  });
}
