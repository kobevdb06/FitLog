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
import '../../../core/formatting/formatters.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/util/paths.dart';
import '../../exercises/presentation/exercise_providers.dart';
import '../../photos/data/photo_store.dart';
import '../../plans/data/plan_prompt.dart';
import '../../workout/presentation/workout_providers.dart';
import '../data/ai_client.dart';
import '../data/coach.dart';
import '../data/coach_tools.dart';
import '../data/links.dart';
import '../data/local_suggester.dart';
import '../domain/coach_budget.dart';
import '../domain/coach_prompt.dart';
import '../domain/coach_proposal.dart';
import '../domain/coach_suggestions.dart';

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

/// What the coach remembers about you, the oldest first.
@riverpod
Stream<List<CoachNoteRow>> coachNotes(Ref ref) =>
    ref.watch(databaseProvider).coachNotesDao.watchNotes();

/// Who makes the questions an empty conversation offers. The phone, for now
/// (DECISIONS 217): override this to let the coach write them.
@Riverpod(keepAlive: true)
CoachSuggester coachSuggester(Ref ref) =>
    LocalCoachSuggester(ref.watch(databaseProvider));

/// The questions for the conversation that is empty now - made again each
/// time one is, so they are about today, and when a workout starts or ends:
/// the empty conversation on screen is then that workout's, or no longer.
@riverpod
Future<List<CoachSuggestion>> coachSuggestions(Ref ref) {
  ref.watch(runningWorkoutIdProvider);
  return ref.watch(coachSuggesterProvider).suggest();
}

/// The id of the workout running, or null: what changes when one starts or
/// ends, and not with every set of it.
@riverpod
String? runningWorkoutId(Ref ref) =>
    ref.watch(activeWorkoutProvider).value?.workout.id;

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

/// Which service draws, of the two on offer.
@riverpod
DrawingService coachDrawingService(Ref ref) =>
    DrawingService.fromWire(ref.watch(settingsProvider).value?.imageProvider);

/// The account a Cloudflare token belongs to.
@riverpod
String? coachImageAccount(Ref ref) {
  final id = ref.watch(settingsProvider).value?.imageAccountId;
  return id == null || id.isEmpty ? null : id;
}

/// Whether a drawing may try to show the kit as well as the movement.
///
/// Null - every database that predates the switch - is yes, which is what
/// every drawing until now attempted.
@riverpod
bool coachImageEquipment(Ref ref) =>
    ref.watch(settingsProvider).value?.imageEquipment ?? true;

/// Drawing exercise pictures with a model, for the whole app.
///
/// Off. A month of drawings, and nearly every one had to be redone by hand.
/// The code stays - the two services, the tokens, the buttons - so a paid
/// tier can switch it back on. While it is off nobody sees any of it: no
/// section in the settings, no button on a card, no option under a photo,
/// and nothing is drawn whoever asks.
const bool kImageGeneration = false;

/// What opens an address in another app - Gemini, for the photos of an
/// exercise - or null where there is nothing to hand it to.
@Riverpod(keepAlive: true)
LinkOpener? linkOpener(Ref ref) =>
    Platform.isAndroid ? const AndroidLinkOpener() : null;

/// [kImageGeneration], as a provider so a test can switch it on.
@Riverpod(keepAlive: true)
bool imageGeneration(Ref ref) => kImageGeneration;

/// Whether an illustration can be drawn at all.
///
/// Not while drawing is switched off for the app ([kImageGeneration]).
/// Without a token nothing is ever generated, whatever else is switched on -
/// it is a separate service and separate money. And a service that wants an
/// account as well is not set up until both are there: half of it drawn is
/// nothing drawn.
@riverpod
bool canDrawImages(Ref ref) {
  if (!ref.watch(imageGenerationProvider)) return false;
  if (ref.watch(coachImageKeyProvider) == null) return false;
  if (!ref.watch(coachDrawingServiceProvider).needsAccount) return true;
  return ref.watch(coachImageAccountProvider) != null;
}

/// How a drawing is made, so a test can hand over one that draws from memory.
typedef ImageGeneratorFactory = ImageGenerator Function(
  String apiKey, {
  DrawingService provider,
  String? accountId,
});

@riverpod
ImageGeneratorFactory imageGeneratorFactory(Ref ref) =>
    (apiKey, {provider = DrawingService.huggingFace, accountId}) =>
        ImageGenerator(
          apiKey: apiKey,
          provider: provider,
          accountId: accountId,
        );

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
    this.answer = '',
    this.looking,
  });

  final bool sending;

  /// What the coach has written so far, while it is still writing. Not
  /// stored: the answer is written down once it is whole.
  final String answer;

  /// What it is looking up in the logbook right now, before it answers.
  final String? looking;

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

  /// The conversation of a workout: the one the Chat tab and the coach in
  /// the island share. Made on its first question, named after the workout
  /// rather than after that question - "Push A · 19 okt." says which one it
  /// was where the question would not.
  Future<String> workoutThread(String workoutId) async {
    final db = ref.read(databaseProvider);
    final workout = (await db.workoutsDao.getWorkoutDetail(workoutId))?.workout;
    final title = workout == null
        ? 'Workout'
        : '${workout.name} · ${Formatters.dayMonth(DateTime.fromMillisecondsSinceEpoch(workout.startedAt))}';
    return db.chatDao.workoutThread(
      workoutId: workoutId,
      id: _uuid.v4(),
      title: title,
    );
  }

  /// The long edge a photo is scaled to before it is sent.
  ///
  /// Smaller than a progress photo on purpose: this one is paid for by the
  /// token, and a picture of a machine in a gym does not need 1440 pixels to
  /// be recognisable.
  static const int photoLongEdge = 768;

  /// How many photos go with one question.
  ///
  /// Enough for a start and an end position, and a picture of the machine or
  /// a second try besides. Each one is paid for in tokens.
  static const int photosPerQuestion = 4;

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
  ///
  /// [situation] is where the user is asking from - in the middle of a set,
  /// from the panel over another app - told to the coach and not stored with
  /// the question.
  Future<void> ask({
    required String threadId,
    required String question,
    List<String> imageFiles = const [],
    String? situation,
  }) async {
    final text = question.trim();
    final photos = imageFiles.take(photosPerQuestion).toList();
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
      imageFiles: photos,
    );

    final paths = await ref.read(appPathsProvider.future);
    final earlier = [
      for (final row in await db.chatDao.messages(threadId))
        if (row.content != text || row.role != 'user') row,
    ];

    // Only the newest photos of a conversation ride along with a follow-up
    // question - those of the last message that had any. Sending every
    // picture again on every turn is what makes a long thread quietly
    // expensive, and the ones being talked about are nearly always the last.
    final lastWithPhotos = earlier.lastIndexWhere((r) => r.photos.isNotEmpty);
    final history = <CoachTurn>[];
    for (var i = 0; i < earlier.length; i++) {
      final row = earlier[i];
      history.add(
        CoachTurn(
          role: row.role,
          text: row.content,
          images: i == lastWithPhotos && photos.isEmpty
              ? await _encodeAll(paths, row.photos)
              : const [],
        ),
      );
    }

    final images = await _encodeAll(paths, photos);
    // The ones the coach may put on an exercise: those it is shown with this
    // question, numbered the same way.
    final inPlay = photos.isNotEmpty
        ? photos
        : lastWithPhotos >= 0
        ? earlier[lastWithPhotos].photos
        : const <String>[];

    final client = ref.read(coachClientFactoryProvider)(
      key,
      ref.read(coachProviderProvider),
    );
    try {
      // From the database, not from the streams: on a cold start these can
      // still be on their way, and an unshared profile must not be shared,
      // nor a shared one dropped, because a stream was late.
      final settings = await db.settingsDao.getSettings();
      final profile = await db.settingsDao.getProfile();
      final now = DateTime.now();
      final deload = await db.deloadDao.currentAt(now);
      final memory = settings.coachMemory;
      final notes = memory
          ? await db.coachNotesDao.notes()
          : const <CoachNoteRow>[];
      // The conversation of a schema: the coach can read and lay out that
      // one, and is told what it is for.
      final plan = switch ((await db.chatDao.thread(threadId))?.planId) {
        final id? => await db.plansDao.plan(id),
        null => null,
      };
      final planBrief = plan == null
          ? null
          : await describePlanOf(db, plan, now);
      final coach = Coach(
        client: client,
        tools: CoachTools(
          db,
          photos: inPlay,
          health: settings.coachSeesHealth,
          memory: memory,
          planId: plan?.id,
        ),
        model: ref.read(coachModelProvider),
        system: buildCoachPrompt(
          now: now,
          weightUnit: settings.unitWeight,
          displayName: profile?.displayName,
          exerciseCount: await db.exercisesDao.countExercises(),
          seesHealth: settings.coachSeesHealth,
          notes: describeNotes([
            for (final note in notes)
              (id: note.id, kind: note.kind, text: note.note),
          ]),
          deload: deload == null
              ? null
              : describeDeload(
                  day: deload.isOnAt(now) ? deload.dayAt(now) : null,
                  days: deload.days,
                  from: deload.from,
                  lastDay: deload.lastDay,
                ),
          situation: situation,
          plan: planBrief,
          aboutUser: settings.coachSeesProfile && profile != null
              ? describeProfile(
                  now: now,
                  birthDate: switch (profile.birthDate) {
                    final at? => DateTime.fromMillisecondsSinceEpoch(at),
                    null => null,
                  },
                  sex: Sex.fromWire(profile.sex),
                  heightCm: profile.heightCm,
                )
              : null,
        ),
      );

      final answer = await coach.ask(
        history: history,
        question: text,
        images: images,
        onText: (piece) =>
            state = CoachState(sending: true, answer: state.answer + piece),
        // A round that looks something up was not the answer: what it
        // wrote on the way goes, and what it is looking at shows instead.
        onLookup: (lookup) =>
            state = CoachState(sending: true, looking: lookup),
      );

      // The photos are part of what left the device, so they belong on the
      // same line as the lookups - and so does the deload the prompt named.
      final reported = [
        if (images.length == 1) 'de foto die je meestuurde',
        if (images.length > 1) "de ${images.length} foto's die je meestuurde",
        if (deload != null)
          deload.isOnAt(now)
              ? 'dat je in een deload zit'
              : 'dat er een deload gepland staat',
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
      state = CoachState(error: _say(error), keyRejected: error.badKey);
    } finally {
      client.close();
    }
  }

  /// What a failure says on screen. A spent daily limit says when it comes
  /// back: at the service's midnight, which here is in the morning.
  String _say(CoachException error) {
    if (error.limit != CoachLimit.perDay) return error.message;
    final back = coachDayEnd(DateTime.now(), ref.read(coachProviderProvider));
    return '${error.message} Vanaf '
        '${Formatters.relativeDayTime(back).toLowerCase()} kan het weer.';
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

  /// [_encode] for each, leaving out the ones that are gone.
  Future<List<CoachImage>> _encodeAll(
    AppPaths paths,
    List<String> fileNames,
  ) async => [for (final name in fileNames) ?await _encode(paths, name)];

  /// Creates what a proposal describes, and remembers that it was taken up.
  ///
  /// This is the only place in the coach that writes anything to the logbook,
  /// and it runs because the user tapped a button - never because the model
  /// asked for it.
  Future<String?> accept({
    required ChatMessageRow message,
    required int index,
    bool withImages = false,
    String? startPrompt,
    String? endPrompt,
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
          startPrompt: startPrompt,
          endPrompt: endPrompt,
        );
      case ProposalKind.routine:
        id = await _createRoutine(db, proposal.routine!);
      // Made by the coach itself, so already there; isApplied caught it.
      case ProposalKind.coachRoutine ||
          ProposalKind.note ||
          ProposalKind.plan ||
          ProposalKind.planOutline ||
          ProposalKind.planSession:
        return proposal.appliedId;
      case ProposalKind.exerciseChange:
        id = await _applyChange(db, proposal.exerciseChange!);
      case ProposalKind.planChange:
        // What the coach wrote is laid out as it would have been by the
        // coach itself; it is checked again, as things may have changed.
        final lookup = await CoachTools(
          db,
          planId: proposal.planId,
        ).applyPlanLayout(proposal.planChange!.input);
        final result = jsonDecode(lookup.json) as Map<String, Object?>;
        if (result['ok'] != true) {
          throw CoachException(
            'Het voorstel kan niet meer: ${result['error'] ?? 'onbekend'}.',
          );
        }
        id = proposal.planId!;
      case ProposalKind.deload:
        final deload = proposal.deload!;
        final started = await db.deloadDao.start(
          from: deload.startAt(DateTime.now()),
          days: deload.days,
          plan: deload.plan,
          source: 'coach',
        );
        await noteDeloadStarted(message: message, index: index, id: started);
        return started;
    }

    proposals[index] = proposal.applied(id);
    await db.chatDao.setProposals(message.id, encodeProposals(proposals));
    return id;
  }

  /// Houden: a proposed change to a schema is put aside, and the schema
  /// stays as it was.
  Future<void> keepPlan({
    required ChatMessageRow message,
    required int index,
  }) async {
    final proposals = parseProposals(message.proposals);
    if (index >= proposals.length) return;
    proposals[index] = proposals[index].kept();
    await ref
        .read(databaseProvider)
        .chatDao
        .setProposals(message.id, encodeProposals(proposals));
  }

  /// Marks a proposed deload as started - with Starten, or from the sheet
  /// behind Aanpassen - and keeps on the card what was started: the day it
  /// began and how light, which need not be what was proposed.
  Future<void> noteDeloadStarted({
    required ChatMessageRow message,
    required int index,
    required String id,
  }) async {
    final db = ref.read(databaseProvider);
    final proposals = parseProposals(message.proposals);
    if (index >= proposals.length) return;
    final proposed = proposals[index].deload;
    final row = await db.deloadDao.byId(id);
    if (proposed == null || row == null) return;

    proposals[index] = CoachProposal.ofDeload(
      DeloadProposal(
        from: row.from,
        days: row.days,
        plan: row.plan,
        reason: proposed.reason,
      ),
      appliedId: id,
    );
    await db.chatDao.setProposals(message.id, encodeProposals(proposals));
  }

  Future<String> _createExercise(
    AppDatabase db,
    ExerciseProposal proposal, {
    bool withImages = false,
    String? startPrompt,
    String? endPrompt,
  }) async {
    await _learnNames(
      db,
      muscles: [proposal.primaryMuscle, ...proposal.secondaryMuscles],
      equipment: proposal.equipment,
    );

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
    // The photos the user sent along, when the coach said which is which.
    final editor = ref.read(exerciseEditorProvider);
    if (proposal.startPhoto case final photo?) {
      startImage = await editor.frameFromChat(photo);
    }
    if (proposal.endPhoto case final photo?) {
      endImage = await editor.frameFromChat(photo);
    }
    if (withImages &&
        proposal.hasFramePrompts &&
        ref.read(imageGenerationProvider)) {
      // One seed for both, so the two drawings are the same person in the
      // same room and the only thing that changes is the posture.
      final seed = _random.nextInt(_seedCeiling);
      startImage = await editor.drawFrame(
        name: proposal.name,
        start: true,
        equipment: proposal.equipment,
        prompt: startPrompt ?? proposal.startImagePrompt,
        seed: seed,
      );
      endImage = await editor.drawFrame(
        name: proposal.name,
        start: false,
        equipment: proposal.equipment,
        prompt: endPrompt ?? proposal.endImagePrompt,
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
          imagesGenerated:
              !proposal.hasPhotos && (startImage != null || endImage != null),
        );
  }

  /// A muscle or a piece of kit the app has never seen is added to the
  /// pickers too, or the exercise would point at a name nothing else knows.
  Future<void> _learnNames(
    AppDatabase db, {
    required List<String> muscles,
    String? equipment,
  }) async {
    final known = await db.exercisesDao.distinctPrimaryMuscles();
    for (final muscle in muscles) {
      if (!known.contains(muscle)) {
        await db.exercisesDao.addCustomMuscle(muscle);
      }
    }
    if (equipment != null) {
      final kit = await db.exercisesDao.distinctEquipment();
      if (!kit.contains(equipment)) {
        await db.exercisesDao.addCustomEquipment(equipment);
      }
    }
  }

  /// Makes the change a card describes to one of the user's own exercises.
  ///
  /// Checked again here, not only when the coach proposed it: the card can
  /// be tapped days later, after the exercise was archived or renamed.
  Future<String> _applyChange(
    AppDatabase db,
    ExerciseChangeProposal change,
  ) async {
    final row = await db.exercisesDao.getById(change.exerciseId);
    if (row == null || row.isArchived) {
      throw const CoachException('Die oefening bestaat niet meer.');
    }
    if (!row.isCustom) {
      throw const CoachException(
        'Een ingebouwde oefening past de coach niet aan.',
      );
    }

    final secondary =
        change.secondaryMuscles ?? decodeSecondaryMuscles(row.secondaryMuscles);
    await _learnNames(
      db,
      muscles: [change.primaryMuscle ?? row.primaryMuscle, ...secondary],
      equipment: change.equipment,
    );

    final editor = ref.read(exerciseEditorProvider);
    String? start;
    String? end;
    if (change.startPhoto case final photo?) {
      start = await editor.frameFromChat(photo);
      if (start == null) throw const CoachException(_photoGone);
    }
    if (change.endPhoto case final photo?) {
      end = await editor.frameFromChat(photo);
      if (end == null) throw const CoachException(_photoGone);
    }

    // The line "getekend door AI" stays only while a drawn picture does.
    final drawnLeft =
        row.imagesGenerated &&
        ((start == null && row.startImageFile != null) ||
            (end == null && row.endImageFile != null));

    await editor.update(
      id: row.id,
      name: change.name ?? row.name,
      primaryMuscle: change.primaryMuscle ?? row.primaryMuscle,
      secondaryMuscles: secondary,
      category: row.categoryChoice,
      equipment: change.equipment ?? row.equipment,
      instructions: change.instructions ?? row.instructions,
      startImageFile: start ?? row.startImageFile,
      endImageFile: end ?? row.endImageFile,
      imagesGenerated: drawnLeft,
    );

    // Only now, with the row pointing at the new ones, are the old frames
    // nobody's.
    if (start != null && row.startImageFile != null) {
      await editor.discardFrame(row.startImageFile!);
    }
    if (end != null && row.endImageFile != null) {
      await editor.discardFrame(row.endImageFile!);
    }
    return row.id;
  }

  static const String _photoGone =
      'Die foto staat niet meer in het gesprek. Stuur ze opnieuw.';

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

  /// Asks the coach for the two sentences a pair of drawings is made from.
  ///
  /// A separate call with only that job in it: the rules for these sentences
  /// were bought one failed drawing at a time, and a model that is also
  /// inventing an exercise reads them past. What it costs is added to the
  /// answer that carried the proposal, so the daily bar keeps telling the
  /// truth.
  Future<(String, String)> writeFramePrompts({
    required String messageId,
    required String name,
    String? equipment,
    String? instructions,
  }) async {
    final db = ref.read(databaseProvider);
    final stored = await db.settingsDao.apiKey();
    final key = stored == null || stored.isEmpty ? null : stored;
    if (key == null) {
      throw const CoachException(
        'Er staat geen API-sleutel in de instellingen.',
      );
    }

    final client = ref.read(coachClientFactoryProvider)(
      key,
      ref.read(coachProviderProvider),
    );
    final CoachReply reply;
    try {
      reply = await client.send(
        system: ref.read(coachImageEquipmentProvider)
            ? kFramePromptSystem
            : '$kFramePromptSystem\n$kFramePromptNoKit',
        messages: [
          CoachMessage.user(
            [
              'Oefening: $name',
              if (equipment != null && equipment.isNotEmpty)
                'Materiaal: $equipment',
              if (instructions != null && instructions.trim().isNotEmpty)
                'Uitvoering: ${instructions.trim()}',
            ].join('\n'),
          ),
        ],
        tools: const [],
        model: ref.read(coachModelProvider),
        maxTokens: 256,
      );
    } finally {
      client.close();
    }

    await db.chatDao.addUsage(
      messageId,
      inputTokens: reply.usage.inputTokens,
      outputTokens: reply.usage.outputTokens,
    );

    final pair = parseFramePrompts(reply.text);
    if (pair == null) {
      throw const CoachException(
        'De coach gaf geen bruikbare beschrijving terug.',
      );
    }
    return pair;
  }

  /// Whether [key] works, found out before the user types a question and
  /// waits for a failure: null when it does, the reason when it does not.
  ///
  /// By asking for the list of models. That costs nothing of the day's
  /// asking; a question to test with - which is what this did - spent one of
  /// a free tier's few hundred calls a day on the word "ok".
  Future<CoachException?> checkKey(String key) async {
    final client = ref.read(coachClientFactoryProvider)(
      key.trim(),
      ref.read(coachProviderProvider),
    );
    try {
      await client.listModels();
      return null;
    } on CoachException catch (error) {
      return error;
    } finally {
      client.close();
    }
  }

  /// [checkKey], as the line the settings show.
  Future<String?> testKey(String key) async => (await checkKey(key))?.message;
}

/// A question another screen has put ready for the coach, not sent yet.
///
/// The coach screen takes it into the field of a new conversation and
/// clears it. It is never sent from here: a question costs the user money,
/// so the user is the one who sends it.
@Riverpod(keepAlive: true)
class CoachDraft extends _$CoachDraft {
  @override
  String? build() => null;

  void put(String question) => state = question;

  void clear() => state = null;
}
