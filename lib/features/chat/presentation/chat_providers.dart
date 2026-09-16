/// Everything the coach screen needs, and the switch that keeps it asleep.
///
/// Without a key in the settings there is no coach: [coachEnabled] is false,
/// the screen is unreachable, and nothing here ever builds a client.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

import '../../../core/app/app_controller.dart';
import '../../../core/db/database.dart';
import '../../../core/db/models.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/util/paths.dart';
import '../../exercises/presentation/exercise_providers.dart';
import '../../photos/data/photo_store.dart';
import '../data/ai_client.dart';
import '../data/coach.dart';
import '../data/coach_tools.dart';
import '../domain/coach_budget.dart';
import '../domain/coach_prompt.dart';
import '../domain/coach_proposal.dart';

part 'chat_providers.g.dart';

const _uuid = Uuid();

/// The two drawings of one exercise share a seed. Which number it is does not
/// matter - only that it is the same one twice.
final _random = Random();
const _seedCeiling = 1 << 31;

/// How a client is made, so a test can hand over one that answers from
/// memory instead of from the network.
///
/// The service is passed in rather than read off the key: the app decides
/// which one it offers, and the client should not quietly disagree.
typedef CoachClientFactory = AiClient Function(
  String apiKey,
  CoachProvider provider,
);

@riverpod
CoachClientFactory coachClientFactory(Ref ref) =>
    (apiKey, provider) => AiClient(apiKey: apiKey, provider: provider);

@riverpod
String? coachApiKey(Ref ref) {
  final key = ref.watch(settingsProvider).value?.anthropicApiKey;
  return key == null || key.isEmpty ? null : key;
}

/// Whether the user has switched the coach on by entering a key.
@riverpod
bool coachEnabled(Ref ref) => ref.watch(coachApiKeyProvider) != null;

/// Which service the coach talks to.
///
/// Only one is offered at the moment, so there is nothing to guess and nothing
/// to choose. A stored choice from when there were two is honoured as long as
/// that service is still on offer, and otherwise ignored rather than used.
@riverpod
CoachProvider coachProvider(Ref ref) {
  final chosen = CoachProvider.fromWire(
    ref.watch(settingsProvider).value?.chatProvider,
  );
  if (chosen != null && kOfferedProviders.contains(chosen)) return chosen;
  return kOfferedProviders.first;
}

/// Which model to ask, as the service names it.
///
/// A plain string, not one of the names this app was built with: the picker
/// lists what the key can really use, and that list outlives this version.
@riverpod
String coachModel(Ref ref) => CoachModel.resolveWire(
  ref.watch(settingsProvider).value?.chatModel,
  ref.watch(coachProviderProvider),
);

/// What that model is called on screen.
@riverpod
String coachModelLabel(Ref ref) => CoachModel.labelFor(
  ref.watch(coachModelProvider),
  ref.watch(coachProviderProvider),
);

/// Every model this key may use, asked of the service itself.
///
/// Kept out of the settings screen's build: it is a network call, and the
/// screen has to work without one.
@riverpod
Future<List<CoachModelInfo>> coachModels(Ref ref) async {
  final key = ref.watch(coachApiKeyProvider);
  if (key == null) return const [];

  final client = ref.watch(coachClientFactoryProvider)(
    key,
    ref.watch(coachProviderProvider),
  );
  try {
    return await client.listModels();
  } finally {
    client.close();
  }
}

@riverpod
Stream<List<ChatThreadRow>> chatThreads(Ref ref) =>
    ref.watch(databaseProvider).chatDao.watchThreads();

@riverpod
Stream<List<ChatMessageRow>> chatMessages(Ref ref, String threadId) =>
    ref.watch(databaseProvider).chatDao.watchMessages(threadId);

/// The Hugging Face token, or null when there is none.
@riverpod
String? coachImageKey(Ref ref) {
  final key = ref.watch(settingsProvider).value?.imageApiKey;
  return key == null || key.isEmpty ? null : key;
}

/// Whether an illustration can be drawn at all.
///
/// Without this token nothing is ever generated, whatever else is switched
/// on - it is a separate service and separate money.
@riverpod
bool canDrawImages(Ref ref) => ref.watch(coachImageKeyProvider) != null;

/// How a drawing is made, so a test can hand over one that draws from memory.
typedef ImageGeneratorFactory = ImageGenerator Function(String apiKey);

@riverpod
ImageGeneratorFactory imageGeneratorFactory(Ref ref) =>
    (apiKey) => ImageGenerator(apiKey: apiKey);

/// What the user allows themselves in a day, in calls to the service.
@riverpod
int coachDailyLimit(Ref ref) =>
    ref.watch(settingsProvider).value?.coachDailyLimit ?? kDefaultDailyLimit;

/// What has been spent since this service's day began.
///
/// A count of what this app sent, not a reading of what is left over there:
/// no API tells a client that.
@riverpod
Stream<CoachDayUsage> coachUsageToday(Ref ref) {
  final since = coachDayStart(DateTime.now(), ref.watch(coachProviderProvider));
  return ref
      .watch(databaseProvider)
      .chatDao
      .watchUsageSince(since)
      .map(
        (row) => CoachDayUsage(
          requests: row.requests,
          answers: row.answers,
          inputTokens: row.inputTokens,
          outputTokens: row.outputTokens,
          since: since,
        ),
      );
}

/// Where the conversation stands: waiting for an answer, or holding a failure.
class CoachState {
  const CoachState({
    this.sending = false,
    this.error,
    this.keyRejected = false,
  });

  final bool sending;

  /// The last failure, in Dutch, or null. Shown under the conversation with a
  /// button to try again.
  final String? error;

  /// The failure was the key itself, so the answer is in the settings.
  final bool keyRejected;
}

/// Asking a question, from the first keystroke to the answer on screen.
@Riverpod(keepAlive: true)
class CoachController extends _$CoachController {
  @override
  CoachState build() => const CoachState();

  /// Starts a conversation named after the question that begins it.
  Future<String> startThread(String firstQuestion) async {
    final id = _uuid.v4();
    await ref.read(databaseProvider).chatDao.createThread(id, firstQuestion);
    return id;
  }

  /// The long edge a photo is scaled to before it is sent.
  ///
  /// Smaller than a progress photo on purpose: this one is paid for by the
  /// token, and a picture of a machine in a gym does not need 1440 pixels to
  /// be recognisable.
  static const int photoLongEdge = 768;

  /// Copies a picked photo into the photo directory, scaled down.
  ///
  /// It is stored before anything is sent, so what you asked about is still
  /// there in the conversation a month later.
  Future<String?> importPhoto(File source) async {
    final paths = await ref.read(appPathsProvider.future);
    return PhotoStore(paths).import(source, maxLongEdge: photoLongEdge);
  }

  /// Sends [question] in [threadId] and writes both sides down.
  ///
  /// The question is stored before it is sent: an answer that never arrives
  /// should not take the question with it.
  Future<void> ask({
    required String threadId,
    required String question,
    String? imageFile,
  }) async {
    final text = question.trim();
    if (text.isEmpty || state.sending) return;

    final db = ref.read(databaseProvider);
    // Straight from the database rather than from the stream: on a cold start
    // the first question can arrive before the settings have been delivered,
    // and "geen sleutel" would then be wrong rather than true.
    final stored = await db.settingsDao.apiKey();
    final key = stored == null || stored.isEmpty ? null : stored;
    if (key == null) {
      state = const CoachState(
        error: 'Er staat geen API-sleutel in de instellingen.',
        keyRejected: true,
      );
      return;
    }

    state = const CoachState(sending: true);
    await db.chatDao.addMessage(
      id: _uuid.v4(),
      threadId: threadId,
      role: 'user',
      content: text,
      imageFile: imageFile,
    );

    final paths = await ref.read(appPathsProvider.future);
    final earlier = [
      for (final row in await db.chatDao.messages(threadId))
        if (row.content != text || row.role != 'user') row,
    ];

    // Only the newest photo of a conversation rides along with a follow-up
    // question. Sending every picture again on every turn is what makes a
    // long thread quietly expensive, and the one being talked about is nearly
    // always the last one.
    final lastWithPhoto = earlier.lastIndexWhere((r) => r.imageFile != null);
    final history = <CoachTurn>[];
    for (var i = 0; i < earlier.length; i++) {
      final row = earlier[i];
      history.add(
        CoachTurn(
          role: row.role,
          text: row.content,
          image: i == lastWithPhoto && imageFile == null
              ? await _encode(paths, row.imageFile!)
              : null,
        ),
      );
    }

    final image = imageFile == null ? null : await _encode(paths, imageFile);

    final client = ref.read(coachClientFactoryProvider)(
      key,
      ref.read(coachProviderProvider),
    );
    try {
      final settings = ref.read(settingsProvider).value;
      final profile = ref.read(userProfileProvider).value;
      final coach = Coach(
        client: client,
        tools: CoachTools(db),
        model: ref.read(coachModelProvider),
        system: buildCoachPrompt(
          now: DateTime.now(),
          weightUnit: settings?.unitWeight ?? 'kg',
          displayName: profile?.displayName,
          exerciseCount: await db.exercisesDao.countExercises(),
        ),
      );

      final answer = await coach.ask(
        history: history,
        question: text,
        image: image,
      );

      // The photo is part of what left the device, so it belongs on the same
      // line as the lookups.
      final reported = [
        if (image != null) 'de foto die je meestuurde',
        ...answer.lookups,
      ];
      await db.chatDao.addMessage(
        id: _uuid.v4(),
        threadId: threadId,
        role: 'assistant',
        content: answer.text,
        lookups: reported.isEmpty ? null : reported.join('\n'),
        requests: answer.requests,
        proposals: answer.proposals.isEmpty
            ? null
            : encodeProposals(answer.proposals),
        inputTokens: answer.usage.inputTokens,
        outputTokens: answer.usage.outputTokens,
      );
      state = const CoachState();
    } on CoachException catch (error) {
      state = CoachState(error: error.message, keyRejected: error.badKey);
    } finally {
      client.close();
    }
  }

  /// Reads a stored photo back as something that can be sent.
  ///
  /// A file that is gone is not an error worth stopping for: the question
  /// still makes sense without the picture, and saying "dat bestand is weg"
  /// helps nobody mid-conversation.
  Future<CoachImage?> _encode(AppPaths paths, String fileName) async {
    final file = PhotoStore(paths).fileFor(fileName);
    if (!await file.exists()) return null;
    return CoachImage(base64: base64Encode(await file.readAsBytes()));
  }

  /// Creates what a proposal describes, and remembers that it was taken up.
  ///
  /// This is the only place in the coach that writes anything to the logbook,
  /// and it runs because the user tapped a button - never because the model
  /// asked for it.
  Future<String?> accept({
    required ChatMessageRow message,
    required int index,
    bool withImages = false,
  }) async {
    final proposals = parseProposals(message.proposals);
    if (index >= proposals.length) return null;

    final proposal = proposals[index];
    if (proposal.isApplied) return proposal.appliedId;

    final db = ref.read(databaseProvider);
    final String id;
    switch (proposal.kind) {
      case ProposalKind.exercise:
        id = await _createExercise(
          db,
          proposal.exercise!,
          withImages: withImages,
        );
      case ProposalKind.routine:
        id = await _createRoutine(db, proposal.routine!);
    }

    proposals[index] = proposal.applied(id);
    await db.chatDao.setProposals(message.id, encodeProposals(proposals));
    return id;
  }

  Future<String> _createExercise(
    AppDatabase db,
    ExerciseProposal proposal, {
    bool withImages = false,
  }) async {
    // A muscle or a piece of kit the app has never seen is added to the
    // pickers too, or the exercise would point at a name nothing else knows.
    final muscles = await db.exercisesDao.distinctPrimaryMuscles();
    for (final muscle in [
      proposal.primaryMuscle,
      ...proposal.secondaryMuscles,
    ]) {
      if (!muscles.contains(muscle)) {
        await db.exercisesDao.addCustomMuscle(muscle);
      }
    }
    if (proposal.equipment case final equipment?) {
      final known = await db.exercisesDao.distinctEquipment();
      if (!known.contains(equipment)) {
        await db.exercisesDao.addCustomEquipment(equipment);
      }
    }

    // A category the user already made keeps its own name; anything else is
    // read as one of the built-in eight.
    final own = await db.exercisesDao.customCategories();
    final match = own.where((c) => c.name == proposal.category).firstOrNull;
    final choice = match == null
        ? CategoryChoice(ExerciseCategory.fromWire(proposal.category))
        : CategoryChoice.of(match.base, match.name);

    // Two drawings, and they are paid for - so only when the user asked for
    // them by tapping that button, and only with the coach's own descriptions
    // of what start and end look like.
    String? startImage;
    String? endImage;
    if (withImages && proposal.canBeDrawn) {
      final editor = ref.read(exerciseEditorProvider);
      // One seed for both, so the two drawings are the same person in the
      // same room and the only thing that changes is the posture.
      final seed = _random.nextInt(_seedCeiling);
      startImage = await editor.drawFrame(
        name: proposal.name,
        muscle: proposal.primaryMuscle,
        start: true,
        equipment: proposal.equipment,
        prompt: proposal.startImagePrompt,
        seed: seed,
      );
      endImage = await editor.drawFrame(
        name: proposal.name,
        muscle: proposal.primaryMuscle,
        start: false,
        equipment: proposal.equipment,
        prompt: proposal.endImagePrompt,
        seed: seed,
      );
    }

    return ref
        .read(exerciseEditorProvider)
        .create(
          name: proposal.name,
          primaryMuscle: proposal.primaryMuscle,
          secondaryMuscles: proposal.secondaryMuscles,
          category: choice,
          equipment: proposal.equipment,
          instructions: proposal.instructions,
          startImageFile: startImage,
          endImageFile: endImage,
          imagesGenerated: startImage != null || endImage != null,
        );
  }

  Future<String> _createRoutine(AppDatabase db, RoutineProposal proposal) {
    return db.routinesDao.createRoutine(
      RoutineDraft(
        name: proposal.name,
        notes: proposal.notes,
        exercises: [
          for (final exercise in proposal.exercises)
            RoutineExerciseDraft(
              exerciseId: exercise.exerciseId,
              sets: [
                for (var i = 0; i < exercise.sets; i++)
                  RoutineSetDraft(targetReps: exercise.targetReps),
              ],
            ),
        ],
      ),
    );
  }

  void clearError() => state = const CoachState();

  /// One cheap call, to find out whether a key works before the user types a
  /// question and waits for a failure.
  Future<String?> testKey(String key) async {
    final client = ref.read(coachClientFactoryProvider)(
      key.trim(),
      ref.read(coachProviderProvider),
    );
    try {
      await client.send(
        system: 'Antwoord met het woord ok.',
        messages: [CoachMessage.user('ok')],
        tools: const [],
        model: ref.read(coachModelProvider),
        maxTokens: 8,
      );
      return null;
    } on CoachException catch (error) {
      return error.message;
    } finally {
      client.close();
    }
  }
}
