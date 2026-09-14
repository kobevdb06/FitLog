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
  static CoachModel resolve(String? wire, CoachProvider provider) {
    for (final model in values) {
      if (model.wire == wire && model.provider == provider) return model;
    }
    return defaultFor(provider);
  }
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
  });

  /// Anthropic matches a result to its request by id. Gemini matches by name
  /// and leaves this empty.
  final String id;
  final String name;
  final Map<String, Object?> input;
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
  const CoachMessage.user(String this.text)
    : role = 'user',
      toolCalls = const [],
      toolResults = const [];

  const CoachMessage.assistant({this.text, this.toolCalls = const []})
    : role = 'assistant',
      toolResults = const [];

  const CoachMessage.results(this.toolResults)
    : role = 'user',
      text = null,
      toolCalls = const [];

  final String role;
  final String? text;
  final List<CoachToolCall> toolCalls;
  final List<CoachToolResult> toolResults;
}

/// One turn back from the service.
class CoachReply {
  const CoachReply({
    required this.text,
    required this.toolCalls,
    required this.usage,
  });

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
    required CoachModel model,
    int maxTokens = 1024,
  }) async {
    final anthropic = provider == CoachProvider.anthropic;
    final uri = Uri.parse(
      anthropic
          ? provider.endpoint
          : '${provider.endpoint}/${model.wire}:generateContent',
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

  // --- what goes out ------------------------------------------------------

  Map<String, Object?> _anthropicBody(
    String system,
    List<CoachMessage> messages,
    List<Map<String, Object?>> tools,
    CoachModel model,
    int maxTokens,
  ) => {
    'model': model.wire,
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
      return {'role': message.role, 'content': message.text ?? ''};
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
    return {
      'role': message.role == 'assistant' ? 'model' : 'user',
      'parts': [
        if (message.text != null && message.text!.isNotEmpty)
          {'text': message.text},
        for (final call in message.toolCalls)
          {
            'functionCall': {'name': call.name, 'args': call.input},
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
    if (parts is List) {
      for (final part in parts) {
        if (part is! Map) continue;
        final value = part['text'];
        if (value is String) text.write(value);

        final call = part['functionCall'];
        if (call is Map) {
          calls.add(
            CoachToolCall(
              // Gemini matches a result to its request by name, not by id.
              id: '',
              name: '${call['name']}',
              input: _args(call['args']),
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
    );
  }

  Map<String, Object?> _args(Object? input) => input is Map
      ? input.map((key, value) => MapEntry('$key', value))
      : const {};
}
