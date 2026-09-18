/// The one place in this app that can reach the network.
///
/// Everything else in FitLog works on the device and nowhere else. The coach
/// is the single exception, and the user switches it on by pasting an API key
/// of their own. This file is the whole of that exception: two possible
/// hosts, one key, no analytics, no second request. A test walks `lib/` and
/// fails if any other file so much as imports an HTTP client.
///
/// Two services, because a key is a key: whoever has one from Google should
/// not have to go and buy one from Anthropic to ask how their bench is going.
/// Which service a key belongs to is read off the key itself.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// The services the coach can talk to, and the only addresses this app knows.
enum CoachProvider {
  anthropic('anthropic', 'Anthropic', 'https://api.anthropic.com/v1/messages', [
    'sk-ant-',
  ]),
  gemini(
    'gemini',
    'Google Gemini',
    'https://generativelanguage.googleapis.com/v1beta/models',
    ['AIza', 'AQ.'],
  );

  const CoachProvider(this.wire, this.label, this.endpoint, this.keyPrefixes);

  final String wire;
  final String label;

  /// Where a request goes. For Gemini the model and the method are appended,
  /// which is how that API is shaped.
  final String endpoint;

  /// How a key of this service announces itself. Google has handed out at
  /// least two shapes: the older `AIza...` and the newer `AQ....`.
  final List<String> keyPrefixes;

  /// Where the service says which models this key may use.
  ///
  /// Asking beats guessing: model names change faster than this app ships, and
  /// a name hard-coded here that no longer exists is a 404 the user gets to
  /// see for something they never chose.
  String get modelsEndpoint => switch (this) {
    CoachProvider.anthropic => 'https://api.anthropic.com/v1/models?limit=100',
    CoachProvider.gemini =>
      'https://generativelanguage.googleapis.com/v1beta/models?pageSize=200',
  };

  static CoachProvider? fromWire(String? wire) {
    for (final provider in values) {
      if (provider.wire == wire) return provider;
    }
    return null;
  }

  /// Which service a pasted key most likely belongs to.
  ///
  /// A guess, not a fact, and it says so: the settings screen shows what was
  /// recognised and lets the user set it straight, because key formats change
  /// and this app cannot ship a new release every time one does.
  ///
  /// Anthropic's prefix is the only unmistakable one, so it decides; anything
  /// else is taken for Google, whose formats are the ones that vary.
  static CoachProvider forKey(String key) {
    final trimmed = key.trim();
    for (final prefix in CoachProvider.anthropic.keyPrefixes) {
      if (trimmed.startsWith(prefix)) return CoachProvider.anthropic;
    }
    return CoachProvider.gemini;
  }
}

/// Which services the app offers to the user right now.
///
/// Anthropic is written, tested and working, but switched off as a choice
/// while the coach is made to work properly on Google's free tier: one service
/// done right beats two done half. Everything else reads this list, so putting
/// `CoachProvider.anthropic` back is this one line.
const List<CoachProvider> kOfferedProviders = [CoachProvider.gemini];

/// Whether a model is one this app can hold a conversation with.
///
/// Google's list is everything its API can do, and most of that is not a
/// coach: embeddings, speech, video, and the image models - the "Nano Banana"
/// family - which answer a question with a picture. They speak the same
/// endpoint, so the name is what gives them away.
bool isChatModel(String wire, [String label = '']) {
  final name = '$wire $label'.toLowerCase();
  const notAChat = [
    'embedding',
    'imagen',
    'image',
    'banana',
    'veo',
    'tts',
    'audio',
    'aqa',
    'live',
  ];
  return !notAChat.any(name.contains);
}

/// Which models the app puts at the top of the picker.
///
/// A rule rather than a list of names, for the same reason the list itself is
/// fetched instead of shipped: the light Gemini 3 models are the ones with
/// room to spare in the free tier, and there will be more of them than the
/// two that exist while this is being written.
bool isRecommendedModel(String wire, [String label = '']) {
  final name = wire.toLowerCase();
  return isChatModel(wire, label) &&
      name.startsWith('gemini-3') &&
      name.contains('flash-lite');
}

/// The wire version of the Anthropic messages API this client speaks.
const String kAnthropicVersion = '2023-06-01';

/// How long an answer may take before we stop waiting.
const Duration kCoachTimeout = Duration(seconds: 90);

/// The models the coach may be pointed at.
///
/// A short list rather than a text field: a typo in a model name is a 404 from
/// a server the user cannot see, and this is a fitness app.
enum CoachModel {
  sonnet(
    CoachProvider.anthropic,
    'claude-sonnet-5',
    'Sonnet 5',
    'Het beste evenwicht. Aanbevolen.',
  ),
  opus(
    CoachProvider.anthropic,
    'claude-opus-5',
    'Opus 5',
    'Slimste antwoorden, duurder per vraag.',
  ),
  haiku(
    CoachProvider.anthropic,
    'claude-haiku-4-5-20251001',
    'Haiku 4.5',
    'Snelst en goedkoopst, korter van stof.',
  ),
  geminiFlash(
    CoachProvider.gemini,
    'gemini-2.5-flash',
    'Gemini 2.5 Flash',
    'Snel, en zit in de gratis laag. Aanbevolen.',
  ),
  geminiFlashLite(
    CoachProvider.gemini,
    'gemini-2.5-flash-lite',
    'Gemini 2.5 Flash Lite',
    'Nog sneller en goedkoper, korter van stof.',
  ),
  geminiPro(
    CoachProvider.gemini,
    'gemini-2.5-pro',
    'Gemini 2.5 Pro',
    'Slimste antwoorden, trager en niet gratis.',
  );

  const CoachModel(this.provider, this.wire, this.label, this.description);

  final CoachProvider provider;
  final String wire;
  final String label;
  final String description;

  /// What this service offers.
  static List<CoachModel> forProvider(CoachProvider provider) =>
      values.where((m) => m.provider == provider).toList();

  /// The first one on the list is the one to start with.
  static CoachModel defaultFor(CoachProvider provider) =>
      forProvider(provider).first;

  /// The stored choice, or this service's default when the stored name belongs
  /// to the other service - which is exactly what happens when someone swaps
  /// their key.
  ///
  /// Only for the names this app happens to know. Which model is actually used
  /// is a string, not a member of this enum: [AiClient.listModels] asks the
  /// service what a key may use, and that list is longer and newer than this
  /// one will ever be.
  static CoachModel resolve(String? wire, CoachProvider provider) {
    for (final model in values) {
      if (model.wire == wire && model.provider == provider) return model;
    }
    return defaultFor(provider);
  }

  /// What to send, given what is stored: the stored name if there is one, and
  /// otherwise this service's default.
  ///
  /// A name this app does not know is kept as it is. That is the whole point:
  /// a model released after this version still works.
  static String resolveWire(String? wire, CoachProvider provider) {
    final stored = wire?.trim();
    if (stored == null || stored.isEmpty) return defaultFor(provider).wire;
    return stored;
  }

  /// How a model name reads when the app has never heard of it.
  static String labelFor(String wire, CoachProvider provider) {
    for (final model in values) {
      if (model.wire == wire && model.provider == provider) return model.label;
    }
    return wire;
  }
}

/// One model as the service itself describes it.
class CoachModelInfo {
  const CoachModelInfo({
    required this.wire,
    required this.label,
    this.description,
  });

  final String wire;
  final String label;
  final String? description;
}

/// What one answer cost, as the service counted it.
class CoachUsage {
  const CoachUsage({required this.inputTokens, required this.outputTokens});

  static const CoachUsage none = CoachUsage(inputTokens: 0, outputTokens: 0);

  final int inputTokens;
  final int outputTokens;

  CoachUsage plus(CoachUsage other) => CoachUsage(
    inputTokens: inputTokens + other.inputTokens,
    outputTokens: outputTokens + other.outputTokens,
  );
}

/// The model asking the app to look something up in the user's own database.
class CoachToolCall {
  const CoachToolCall({
    required this.id,
    required this.name,
    required this.input,
    this.signature,
  });

  /// Anthropic matches a result to its request by id. Gemini matches by name
  /// and leaves this empty.
  final String id;
  final String name;
  final Map<String, Object?> input;

  /// Google's thought signature for this call, to be handed back exactly as
  /// it came.
  ///
  /// The Gemini 3 models refuse a conversation that returns a functionCall
  /// without it: "Function call is missing a thought_signature". It is theirs,
  /// not ours - we carry it, we do not read it.
  final String? signature;
}

/// The answer to one such request, on its way back.
class CoachToolResult {
  const CoachToolResult({required this.call, required this.json});

  final CoachToolCall call;

  /// What the lookup found, as JSON text.
  final String json;
}

/// One turn of the conversation, in the app's own words.
///
/// Neither service's shape: both are translated on the way out, so the loop
/// that runs the lookups does not have to know which one it is talking to.
class CoachMessage {
  const CoachMessage.user(String this.text, {this.image})
    : role = 'user',
      toolCalls = const [],
      toolResults = const [],
      textSignature = null;

  const CoachMessage.assistant({
    this.text,
    this.toolCalls = const [],
    this.textSignature,
  }) : role = 'assistant',
       image = null,
       toolResults = const [];

  const CoachMessage.results(this.toolResults)
    : role = 'user',
      text = null,
      image = null,
      toolCalls = const [],
      textSignature = null;

  final String role;
  final String? text;
  final List<CoachToolCall> toolCalls;
  final List<CoachToolResult> toolResults;

  /// A photo the user sent with this question.
  final CoachImage? image;

  /// Google's thought signature on the text part, carried back untouched for
  /// the same reason as [CoachToolCall.signature].
  final String? textSignature;
}

/// A photo on its way out, already scaled down and encoded.
class CoachImage {
  const CoachImage({required this.base64, this.mediaType = 'image/jpeg'});

  final String base64;
  final String mediaType;
}

/// One turn back from the service.
class CoachReply {
  const CoachReply({
    required this.text,
    required this.toolCalls,
    required this.usage,
    this.textSignature,
  });

  /// Google's thought signature on the text part of this answer, if it sent
  /// one.
  final String? textSignature;

  /// What it said, with the tool requests left out.
  final String text;

  /// What it wants looked up before it can finish.
  final List<CoachToolCall> toolCalls;

  final CoachUsage usage;

  bool get wantsTools => toolCalls.isNotEmpty;
}

/// Something went wrong on the way out or on the way back.
///
/// [message] is Dutch, meant to be shown as it is, and never contains the key:
/// everything that goes into it passes through [_redact] first.
class CoachException implements Exception {
  const CoachException(this.message, {this.badKey = false});

  final String message;

  /// The key itself is the problem, so the settings screen is where the user
  /// has to go.
  final bool badKey;

  @override
  String toString() => message;
}

/// Never let an API key travel out of this file inside an error message.
String _redact(String text) => text
    .replaceAll(RegExp(r'sk-ant-[A-Za-z0-9_\-]+'), 'sk-ant-...')
    .replaceAll(RegExp(r'AIza[A-Za-z0-9_\-]+'), 'AIza...');

/// Draws one picture, for an exercise the user is making.
///
/// A second service and a second key, and both of those are a cost: this is
/// the only thing in the app that spends someone's credit on a single tap. So
/// it exists only where an exercise is being made, never in the chat, and not
/// at all without a token of its own.
///
/// What comes out is a drawing, not a photograph of the movement. It looks
/// convincing and is regularly wrong about how a machine actually works, which
/// is why the app marks such pictures and says so.
/// Who draws the illustrations.
///
/// Two services rather than one, because they are free in different ways and
/// good at different things. Hugging Face gives a small monthly credit and
/// draws with FLUX.1 schnell; Cloudflare gives an allowance that comes back
/// every day and draws with FLUX.2 Klein, which - tested side by side on the
/// same sentence - is the first model here that put the arms where the words
/// said they should be.
enum DrawingService {
  huggingFace(
    'hugging_face',
    'Hugging Face',
    'FLUX.1 schnell. Ongeveer \$0,10 aan tegoed per maand, daarna op tot '
        'de volgende maand.',
  ),
  cloudflare(
    'cloudflare',
    'Cloudflare',
    'FLUX.2 Klein 9B. Elke dag opnieuw een gratis portie, goed voor een stuk '
        'of drie oefeningen per dag.',
  );

  const DrawingService(this.wire, this.label, this.blurb);

  final String wire;
  final String label;

  /// What you are choosing between, in one line.
  final String blurb;

  /// Null - every database from before there was a choice - is Hugging Face,
  /// because that was the only one there was.
  static DrawingService fromWire(String? wire) {
    for (final provider in values) {
      if (provider.wire == wire) return provider;
    }
    return DrawingService.huggingFace;
  }

  /// Whether this service needs an account of its own next to the token.
  bool get needsAccount => this == DrawingService.cloudflare;
}

class ImageGenerator {
  ImageGenerator({
    required this.apiKey,
    this.provider = DrawingService.huggingFace,
    this.accountId,
    http.Client? client,
    this.timeout,
  }) : _client = client ?? http.Client();

  /// Hugging Face routes the call to whoever still runs the model and bills it
  /// to the token's own account.
  static const String endpoint =
      'https://router.huggingface.co/nscale/v1/images/generations';

  /// Cloudflare runs the model itself, on the account the token belongs to.
  static String cloudflareEndpoint(String accountId) =>
      'https://api.cloudflare.com/client/v4/accounts/$accountId/ai/run/'
      '@cf/black-forest-labs/flux-2-klein-9b';

  /// The model behind it. One name per service, because unlike the coach's
  /// models this is not a choice the user makes - it is the button's
  /// behaviour.
  static const String model = 'black-forest-labs/FLUX.1-schnell';

  /// The shape the two frame slots have.
  ///
  /// Without it the service draws a square, which the slot then crops to 3:4 -
  /// and a standing person loses their head or their feet to that crop.
  /// Asking for the shape we show costs nothing and wastes no pixels.
  static const String size = '768x1024';

  /// The same shape, for a service that wants it as two numbers.
  static const int width = 768;
  static const int height = 1024;

  /// Drawing takes seconds, not milliseconds, and a phone on mobile data takes
  /// longer than a desk did.
  static const Duration defaultTimeout = Duration(seconds: 60);

  final String apiKey;
  final DrawingService provider;

  /// Whose daily allowance is spent, for a service that asks.
  final String? accountId;

  final Duration? timeout;
  final http.Client _client;

  void close() => _client.close();

  /// What every prompt ends with, whoever wrote the rest of it.
  ///
  /// The two pictures of an exercise are a start and an end position, so there
  /// has to be a person in them - that is the whole point of the pair. The
  /// tail keeps them usable and comparable: one person, dressed for a gym,
  /// whole body in frame, same plain background both times.
  ///
  /// It asks for a drawing, not a photograph. A photoreal render of a machine
  /// the model does not know comes out convincingly wrong; a plain
  /// illustration of the same guess reads as what it is, and the posture -
  /// the part that has to be right - survives the simplification.
  ///
  /// And it no longer fixes the camera: which side you have to stand on to
  /// see a movement differs per exercise, and on a seated machine the side
  /// view is exactly the one where the machine hides the person. Whoever
  /// writes the prompt says where the camera stands.
  static const String style =
      ' Clean instructional fitness illustration, simple flat shapes, one '
      'person in a grey tank top and black shorts, whole body in frame, plain '
      'light grey background, correct posture and joint angles, no text, no '
      'watermark.';

  /// The prompt an exercise turns into when nobody wrote a better one, ready
  /// to send.
  static String promptFor({
    required String name,
    String? equipment,
    required bool start,
    bool withEquipment = true,
  }) => stylise(
    describe(
      name: name,
      equipment: withEquipment ? equipment : null,
      start: start,
    ),
    withEquipment: withEquipment,
  );

  /// The same description without the style on it: what a person is shown
  /// when they are asked what the picture should contain.
  ///
  /// English, because that is what the models are trained on. It names the
  /// movement rather than spelling out the joints - tested side by side, the
  /// name got the posture right and a careful description of upper and lower
  /// arms produced someone flexing their biceps. And it says which of the two
  /// moments it is, because "start" and "end" are the difference between a
  /// useful pair and two pictures of the same thing.
  static String describe({
    required String name,
    String? equipment,
    required bool start,
  }) {
    final kit = equipment == null || equipment.isEmpty
        ? ''
        : ' with $equipment';
    final moment = start ? 'at the start' : 'at the end';
    return 'Side view of a person doing $name$kit, $moment of the movement';
  }

  /// How much of the description reaches the service.
  ///
  /// The measurement behind it: the same model drew a useless picture from a
  /// 450-character description full of "shoulder blades squeezed together,
  /// seen from a high three-quarter angle" and a usable one from a single
  /// 92-character sentence with one movement in it. A four-step model drowns
  /// in detail - what it cannot weigh, it averages away.
  ///
  /// But that was two points, and the ceiling was set at the low one. Nothing
  /// was ever measured in between, and the sentence that did work best -
  /// naming the movement and then the joints - runs to about 140. Room for
  /// twice that leaves space for the joints without room for a list. What
  /// does not fit is cut, and whoever types it is shown the count while they
  /// do, because a sentence that is quietly shortened is worse than a long
  /// one.
  static const int maxPromptLength = 320;

  /// What is added when the kit is not allowed in the picture.
  ///
  /// Saying nothing about it is not enough: asked for a triceps extension the
  /// model reaches for a bar of its own accord. This says out loud that there
  /// is none, which leaves the body doing the movement and nothing else.
  static const String withoutKit =
      ' No gym equipment, no weights, no machine, empty hands.';

  /// The whole tail, for a drawing that may or may not show the kit.
  static String tailFor({required bool withEquipment}) =>
      withEquipment ? style : '$style$withoutKit';

  /// A prompt the coach wrote, cut back to one thought, with the same tail.
  ///
  /// The coach knows better than a template what those two pictures should
  /// show - it named the exercise - so its words lead. The tail still decides
  /// what the picture looks like, so a pair stays a pair.
  static String stylise(String prompt, {bool withEquipment = true}) {
    final trimmed = _shorten(prompt.trim());
    final ending = trimmed.endsWith('.') ? trimmed : '$trimmed.';
    return '$ending${tailFor(withEquipment: withEquipment)}';
  }

  /// Cuts at a sentence if there is one in reach, at a word otherwise. Never
  /// mid-word: half a word is a word the model still tries to draw.
  static String _shorten(String prompt) {
    if (prompt.length <= maxPromptLength) return prompt;
    final head = prompt.substring(0, maxPromptLength);
    final sentence = head.lastIndexOf(RegExp(r'[.!?]'));
    if (sentence > maxPromptLength ~/ 2) return head.substring(0, sentence);
    final word = head.lastIndexOf(' ');
    return word > 0 ? head.substring(0, word) : head;
  }

  /// Returns the image bytes, ready to be written to the photo directory.
  ///
  /// Two drawings of one exercise share a [seed]. Without it they are two
  /// unrelated draws: one came back in a white shirt in a squat rack, the
  /// other bare-chested at a cable machine, and the difference you were
  /// supposed to read off the pair was the difference between two people. One
  /// seed and one described outfit, and only the posture moves.
  Future<Uint8List> draw(String prompt, {int? seed}) async {
    final http.Response response;
    try {
      response =
          await (provider == DrawingService.cloudflare
                  ? _askCloudflare(prompt, seed)
                  : _askHuggingFace(prompt, seed))
              .timeout(timeout ?? defaultTimeout);
    } on TimeoutException {
      throw const CoachException(
        'Het tekenen duurde te lang. Probeer het opnieuw.',
      );
    } on SocketException {
      throw const CoachException(
        'Geen verbinding, dus er kan niets getekend worden.',
      );
    } on http.ClientException catch (error) {
      throw CoachException(
        'De verbinding werd afgebroken: ${_redact(error.message)}',
      );
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw CoachException(
        'Dat ${provider.label}-token wordt niet aanvaard.',
        badKey: true,
      );
    }
    if (response.statusCode == 402) {
      throw CoachException(
        'Je tegoed bij ${provider.label} is op. Er is niets getekend.',
        badKey: true,
      );
    }
    // A day's worth spent is not a key that was refused. Saying so sent the
    // user looking at their token, which was fine all along - and the portion
    // was back a few hours later.
    if (response.statusCode == 429) {
      throw CoachException(
        provider == DrawingService.cloudflare
            ? 'Cloudflare tekent nu niet: ${_detailOf(response.body)}. Er is '
                  'niets getekend. Is je portie van vandaag op, dan staat ze '
                  'er weer na middernacht (UTC).'
            : 'Er zijn te veel tekeningen na elkaar gevraagd. Probeer het zo '
                  'opnieuw.',
      );
    }
    if (response.statusCode != 200) {
      throw CoachException('Tekenen mislukte: ${_detailOf(response.body)}');
    }

    final encoded = _imageOf(response.body);
    if (encoded == null || encoded.isEmpty) {
      throw const CoachException('Er kwam geen afbeelding terug.');
    }

    try {
      return base64Decode(encoded);
    } on FormatException {
      throw const CoachException('De afbeelding was onleesbaar.');
    }
  }

  /// One JSON call, with the size and the seed in the body.
  Future<http.Response> _askHuggingFace(String prompt, int? seed) {
    return _client.post(
      Uri.parse(endpoint),
      headers: {
        'content-type': 'application/json',
        'authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': model,
        'prompt': prompt,
        'response_format': 'b64_json',
        'size': size,
        'seed': ?seed,
      }),
    );
  }

  /// The same question as form fields, which is the only shape FLUX.2 takes
  /// here - a JSON body comes back as "required properties at '/' are
  /// 'multipart'".
  Future<http.Response> _askCloudflare(String prompt, int? seed) async {
    final account = accountId;
    if (account == null || account.isEmpty) {
      throw const CoachException(
        'Er staat geen Cloudflare account-ID bij het token.',
        badKey: true,
      );
    }

    final request =
        http.MultipartRequest('POST', Uri.parse(cloudflareEndpoint(account)))
          ..headers['authorization'] = 'Bearer $apiKey'
          ..fields['prompt'] = prompt
          ..fields['width'] = '$width'
          ..fields['height'] = '$height';
    if (seed != null) request.fields['seed'] = '$seed';

    return http.Response.fromStream(await _client.send(request));
  }

  /// Reads the picture out of whichever answer came back.
  ///
  /// Hugging Face speaks the OpenAI shape and puts it in data[0].b64_json;
  /// Cloudflare wraps everything of its own in result and calls it image.
  static String? _imageOf(String body) {
    final json = jsonDecode(body);
    if (json is! Map) return null;
    if (json['result'] case final Map result) {
      return result['image'] as String?;
    }
    final data = json['data'];
    final first = data is List && data.isNotEmpty ? data.first : null;
    return first is Map ? first['b64_json'] as String? : null;
  }

  /// The same reading of an error body as the coach's, kept here so this class
  /// stands on its own.
  /// Takes the machine's throat-clearing out of a message meant for a person.
  ///
  /// What came back reads "AiError: AiError: you have used up your daily free
  /// allocation of 10,000 neurons... (fe5d7715-d06b-49c2-93d6-75c21dbbc197)".
  /// The repeated label and the trace number are for whoever writes the
  /// service, not for whoever is standing in a gym.
  static String _tidy(String message) {
    var text = message.trim();
    while (text.startsWith('AiError:')) {
      text = text.substring('AiError:'.length).trim();
    }
    return text
        .replaceAll(
          RegExp(
            r'\s*\(\s*[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-'
            r'[0-9a-f]{12}\s*\)',
          ),
          '',
        )
        .trim();
  }

  static String _detailOf(String body) {
    try {
      final json = jsonDecode(body);
      if (json is Map) {
        final error = json['error'];
        if (error is String && error.isNotEmpty) return _redact(error);
        if (error is Map && error['message'] is String) {
          return _redact(error['message']! as String);
        }
        // Cloudflare says it in a list, with a number next to it. That number
        // is the difference between "wait until tomorrow" (3036, the day's
        // allowance) and "try again in a minute" (3040, no capacity right
        // now), so it is worth carrying all the way to the screen.
        if (json['errors'] case final List errors when errors.isNotEmpty) {
          final first = errors.first;
          if (first is Map && first['message'] is String) {
            final code = first['code'];
            final message = _tidy(_redact(first['message']! as String));
            return code == null ? message : '$message ($code)';
          }
        }
      }
    } on FormatException {
      // An unreadable body is not worth a second failure.
    }
    return 'onbekende fout';
  }
}

class AiClient {
  AiClient({
    required this.apiKey,
    CoachProvider? provider,
    http.Client? client,
    this.timeout = kCoachTimeout,
  }) : provider = provider ?? CoachProvider.forKey(apiKey),
       _client = client ?? http.Client();

  final String apiKey;
  final CoachProvider provider;
  final Duration timeout;
  final http.Client _client;

  void close() => _client.close();

  /// One round trip. Tool results come back in as ordinary turns, so the loop
  /// that runs them lives above this.
  Future<CoachReply> send({
    required String system,
    required List<CoachMessage> messages,
    required List<Map<String, Object?>> tools,
    required String model,
    int maxTokens = 1024,
  }) async {
    final anthropic = provider == CoachProvider.anthropic;
    final uri = Uri.parse(
      anthropic
          ? provider.endpoint
          : '${provider.endpoint}/$model:generateContent',
    );

    final body = jsonEncode(
      anthropic
          ? _anthropicBody(system, messages, tools, model, maxTokens)
          : _geminiBody(system, messages, tools, maxTokens),
    );

    final http.Response response;
    try {
      response = await _client
          .post(
            uri,
            headers: {
              'content-type': 'application/json',
              // The key goes in a header, never in the URL: a URL ends up in
              // logs and in error messages by accident.
              if (anthropic) ...{
                'x-api-key': apiKey,
                'anthropic-version': kAnthropicVersion,
              } else
                'x-goog-api-key': apiKey,
            },
            body: body,
          )
          .timeout(timeout);
    } on TimeoutException {
      throw const CoachException(
        'De coach antwoordde niet op tijd. Probeer het opnieuw.',
      );
    } on SocketException {
      throw const CoachException(
        'Geen verbinding. De coach is het enige dat internet nodig heeft; de '
        'rest van FitLog werkt gewoon verder.',
      );
    } on http.ClientException catch (error) {
      throw CoachException(
        'De verbinding werd afgebroken: ${_redact(error.message)}',
      );
    }

    if (response.statusCode != 200) throw _errorFor(response);

    return anthropic
        ? _parseAnthropic(response.body)
        : _parseGemini(response.body);
  }

  /// Which models this key may actually use, straight from the service.
  ///
  /// The app ships with a handful of names it happens to know, and those go
  /// stale: a model released next month is not in this binary. So the picker
  /// asks, and what comes back is what the key can really do today.
  Future<List<CoachModelInfo>> listModels() async {
    final anthropic = provider == CoachProvider.anthropic;

    final http.Response response;
    try {
      response = await _client
          .get(
            Uri.parse(provider.modelsEndpoint),
            headers: {
              if (anthropic) ...{
                'x-api-key': apiKey,
                'anthropic-version': kAnthropicVersion,
              } else
                'x-goog-api-key': apiKey,
            },
          )
          .timeout(timeout);
    } on TimeoutException {
      throw const CoachException('De lijst met modellen kwam niet op tijd.');
    } on SocketException {
      throw const CoachException(
        'Geen verbinding, dus de lijst met modellen kan niet opgehaald worden.',
      );
    } on http.ClientException catch (error) {
      throw CoachException(
        'De verbinding werd afgebroken: ${_redact(error.message)}',
      );
    }

    if (response.statusCode != 200) throw _errorFor(response);

    final json = _decode(response.body);
    final models = anthropic ? json['data'] : json['models'];
    if (models is! List) {
      throw const CoachException('De lijst met modellen was onleesbaar.');
    }

    final result = <CoachModelInfo>[];
    for (final entry in models) {
      if (entry is! Map) continue;
      final info = anthropic ? _anthropicModel(entry) : _geminiModel(entry);
      if (info != null) result.add(info);
    }

    // Newest first, as far as a name can say so: "gemini-3..." sorts above
    // "gemini-2.5...", and that is the order someone is looking for.
    result.sort((a, b) => b.wire.compareTo(a.wire));
    return result;
  }

  CoachModelInfo? _anthropicModel(Map<Object?, Object?> entry) {
    final id = entry['id'];
    if (id is! String || id.isEmpty) return null;
    return CoachModelInfo(
      wire: id,
      label: entry['display_name'] is String
          ? entry['display_name']! as String
          : id,
    );
  }

  /// Google lists everything its API can do, including things this app cannot
  /// use: embeddings, images, speech, and the live streaming models.
  CoachModelInfo? _geminiModel(Map<Object?, Object?> entry) {
    final name = entry['name'];
    if (name is! String || !name.startsWith('models/')) return null;
    final wire = name.substring('models/'.length);

    final methods = entry['supportedGenerationMethods'];
    final talks = methods is List && methods.contains('generateContent');
    if (!talks) return null;

    final label = entry['displayName'] is String
        ? entry['displayName']! as String
        : wire;

    // An image model answers generateContent too, with a picture. The name is
    // what tells them apart, so both the id and the name it goes by are read.
    if (!isChatModel(wire, label)) return null;

    return CoachModelInfo(
      wire: wire,
      label: label,
      description: entry['description'] is String
          ? entry['description']! as String
          : null,
    );
  }

  // --- what goes out ------------------------------------------------------

  Map<String, Object?> _anthropicBody(
    String system,
    List<CoachMessage> messages,
    List<Map<String, Object?>> tools,
    String model,
    int maxTokens,
  ) => {
    'model': model,
    'max_tokens': maxTokens,
    'system': system,
    'messages': [for (final message in messages) _anthropicTurn(message)],
    if (tools.isNotEmpty) 'tools': tools,
  };

  Map<String, Object?> _anthropicTurn(CoachMessage message) {
    if (message.toolResults.isNotEmpty) {
      return {
        'role': 'user',
        'content': [
          for (final result in message.toolResults)
            {
              'type': 'tool_result',
              'tool_use_id': result.call.id,
              'content': result.json,
            },
        ],
      };
    }
    if (message.toolCalls.isEmpty) {
      final image = message.image;
      if (image == null) {
        return {'role': message.role, 'content': message.text ?? ''};
      }
      // The picture first: a question about it reads better after it, and
      // both services are happier that way round.
      return {
        'role': message.role,
        'content': [
          {
            'type': 'image',
            'source': {
              'type': 'base64',
              'media_type': image.mediaType,
              'data': image.base64,
            },
          },
          if (message.text != null && message.text!.isNotEmpty)
            {'type': 'text', 'text': message.text},
        ],
      };
    }
    return {
      'role': 'assistant',
      'content': [
        if (message.text != null && message.text!.isNotEmpty)
          {'type': 'text', 'text': message.text},
        for (final call in message.toolCalls)
          {
            'type': 'tool_use',
            'id': call.id,
            'name': call.name,
            'input': call.input,
          },
      ],
    };
  }

  Map<String, Object?> _geminiBody(
    String system,
    List<CoachMessage> messages,
    List<Map<String, Object?>> tools,
    int maxTokens,
  ) => {
    'systemInstruction': {
      'parts': [
        {'text': system},
      ],
    },
    'contents': [for (final message in messages) _geminiTurn(message)],
    if (tools.isNotEmpty)
      'tools': [
        {
          'functionDeclarations': [
            for (final tool in tools) _geminiDeclaration(tool),
          ],
        },
      ],
    'generationConfig': {'maxOutputTokens': maxTokens},
  };

  Map<String, Object?> _geminiTurn(CoachMessage message) {
    if (message.toolResults.isNotEmpty) {
      return {
        'role': 'user',
        'parts': [
          for (final result in message.toolResults)
            {
              'functionResponse': {
                'name': result.call.name,
                // Gemini wants an object, and a lookup answers with one.
                'response': _asObject(result.json),
              },
            },
        ],
      };
    }
    final image = message.image;
    return {
      'role': message.role == 'assistant' ? 'model' : 'user',
      'parts': [
        if (image != null)
          {
            'inlineData': {'mimeType': image.mediaType, 'data': image.base64},
          },
        if (message.text != null && message.text!.isNotEmpty)
          {'text': message.text, 'thoughtSignature': ?message.textSignature},
        for (final call in message.toolCalls)
          {
            'functionCall': {'name': call.name, 'args': call.input},
            // Handed back exactly as it came: the Gemini 3 models refuse a
            // functionCall that returns without its signature.
            'thoughtSignature': ?call.signature,
          },
      ],
    };
  }

  /// The same tool, in the shape Google expects.
  ///
  /// A declaration without parameters is left without a `parameters` key
  /// rather than given an empty object, which that API rejects.
  Map<String, Object?> _geminiDeclaration(Map<String, Object?> tool) {
    final schema = tool['input_schema'];
    final properties = schema is Map ? schema['properties'] : null;
    final hasProperties = properties is Map && properties.isNotEmpty;
    return {
      'name': tool['name'],
      'description': tool['description'],
      if (hasProperties) 'parameters': schema,
    };
  }

  Map<String, Object?> _asObject(String json) {
    try {
      final decoded = jsonDecode(json);
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry('$key', value));
      }
      return {'result': decoded};
    } on FormatException {
      return {'result': json};
    }
  }

  // --- what comes back ----------------------------------------------------

  CoachException _errorFor(http.Response response) {
    final status = response.statusCode;
    final detail = _detail(response.body);

    // Google says "API key not valid" with a 400, so the status alone does not
    // decide this.
    final aboutTheKey =
        status == 401 ||
        status == 403 ||
        detail.toLowerCase().contains('api key') ||
        detail.toLowerCase().contains('api-sleutel');

    if (aboutTheKey) {
      return const CoachException(
        'Die API-sleutel wordt niet aanvaard. Controleer hem bij '
        'Instellingen, AI-coach.',
        badKey: true,
      );
    }
    if (status == 402) {
      return const CoachException(
        'Er staat geen tegoed meer op dit account.',
        badKey: true,
      );
    }
    if (status == 429) {
      return const CoachException(
        'Te veel vragen na elkaar, of je gratis limiet is op. Wacht even en '
        'probeer opnieuw.',
      );
    }
    if (status >= 500) {
      return const CoachException(
        'De dienst is even overbelast. Probeer het zo opnieuw.',
      );
    }
    return CoachException('De vraag werd afgewezen: $detail');
  }

  /// The error message the service sent, if it sent one we can read.
  String _detail(String body) {
    try {
      final json = jsonDecode(body);
      if (json is Map && json['error'] is Map) {
        final message = (json['error'] as Map)['message'];
        if (message is String && message.isNotEmpty) return _redact(message);
      }
    } on FormatException {
      // An unreadable body is not worth a second failure.
    }
    return 'onbekende fout';
  }

  Map<String, Object?> _decode(String body) {
    final Object? json;
    try {
      json = jsonDecode(body);
    } on FormatException {
      throw const CoachException('Het antwoord was onleesbaar.');
    }
    if (json is! Map) {
      throw const CoachException('Het antwoord had een vorm die niet klopt.');
    }
    return json.map((key, value) => MapEntry('$key', value));
  }

  CoachReply _parseAnthropic(String body) {
    final json = _decode(body);
    final content = json['content'];
    if (content is! List) {
      throw const CoachException('Het antwoord bevatte geen tekst.');
    }

    final text = StringBuffer();
    final calls = <CoachToolCall>[];
    for (final block in content) {
      if (block is! Map) continue;
      switch (block['type']) {
        case 'text':
          final value = block['text'];
          if (value is String) text.write(value);
        case 'tool_use':
          calls.add(
            CoachToolCall(
              id: '${block['id']}',
              name: '${block['name']}',
              input: _args(block['input']),
            ),
          );
      }
    }

    final usage = json['usage'];
    return CoachReply(
      text: text.toString().trim(),
      toolCalls: calls,
      usage: CoachUsage(
        inputTokens: usage is Map ? (usage['input_tokens'] as int? ?? 0) : 0,
        outputTokens: usage is Map ? (usage['output_tokens'] as int? ?? 0) : 0,
      ),
    );
  }

  CoachReply _parseGemini(String body) {
    final json = _decode(body);
    final candidates = json['candidates'];
    if (candidates is! List || candidates.isEmpty) {
      // A prompt Google refuses to answer comes back without candidates.
      final blocked = json['promptFeedback'];
      throw CoachException(
        blocked == null
            ? 'Het antwoord bevatte geen tekst.'
            : 'De dienst wilde hier niet op antwoorden.',
      );
    }

    final first = candidates.first;
    final content = first is Map ? first['content'] : null;
    final parts = content is Map ? content['parts'] : null;

    final text = StringBuffer();
    final calls = <CoachToolCall>[];
    String? textSignature;
    if (parts is List) {
      for (final part in parts) {
        if (part is! Map) continue;
        // The signature belongs to the part it arrived on, and has to go back
        // on that same part.
        final signature = part['thoughtSignature'];

        final value = part['text'];
        if (value is String) {
          text.write(value);
          if (signature is String) textSignature = signature;
        }

        final call = part['functionCall'];
        if (call is Map) {
          calls.add(
            CoachToolCall(
              // Gemini matches a result to its request by name, not by id.
              id: '',
              name: '${call['name']}',
              input: _args(call['args']),
              signature: signature is String ? signature : null,
            ),
          );
        }
      }
    }

    final usage = json['usageMetadata'];
    return CoachReply(
      text: text.toString().trim(),
      toolCalls: calls,
      usage: CoachUsage(
        inputTokens: usage is Map
            ? (usage['promptTokenCount'] as int? ?? 0)
            : 0,
        outputTokens: usage is Map
            ? (usage['candidatesTokenCount'] as int? ?? 0)
            : 0,
      ),
      textSignature: textSignature,
    );
  }

  Map<String, Object?> _args(Object? input) => input is Map
      ? input.map((key, value) => MapEntry('$key', value))
      : const {};
}
