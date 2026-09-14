/// The one place in this app that can reach the network.
///
/// Everything else in FitLog works on the device and nowhere else. The coach
/// is the single exception, and the user switches it on by entering their own
/// API key. This file is the whole of that exception: one host, one endpoint,
/// one key, no analytics, no second request. A test walks `lib/` and fails if
/// any other file so much as imports an HTTP client.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// The only address the app ever contacts.
const String kAnthropicEndpoint = 'https://api.anthropic.com/v1/messages';

/// The wire version of the messages API this client speaks.
const String kAnthropicVersion = '2023-06-01';

/// How long an answer may take before we stop waiting.
const Duration kCoachTimeout = Duration(seconds: 90);

/// The models the coach may be pointed at.
///
/// A short list rather than a text field: a typo in a model name is a 404 from
/// a server the user cannot see, and this is a fitness app.
enum CoachModel {
  sonnet('claude-sonnet-5', 'Sonnet 5', 'Het beste evenwicht. Aanbevolen.'),
  opus('claude-opus-5', 'Opus 5', 'Slimste antwoorden, duurder per vraag.'),
  haiku(
    'claude-haiku-4-5-20251001',
    'Haiku 4.5',
    'Snelst en goedkoopst, korter van stof.',
  );

  const CoachModel(this.wire, this.label, this.description);

  final String wire;
  final String label;
  final String description;

  static CoachModel fromWire(String? value) => values.firstWhere(
    (m) => m.wire == value,
    orElse: () => CoachModel.sonnet,
  );
}

/// What one answer cost, as the API counted it.
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

  final String id;
  final String name;
  final Map<String, Object?> input;
}

/// One turn back from the API.
class CoachReply {
  const CoachReply({
    required this.text,
    required this.toolCalls,
    required this.usage,
    required this.content,
  });

  /// What it said, with the tool requests left out.
  final String text;

  /// What it wants looked up before it can finish.
  final List<CoachToolCall> toolCalls;

  final CoachUsage usage;

  /// The raw content blocks, to be sent back as the assistant's turn when
  /// tools have to run.
  final List<Object?> content;

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
String _redact(String text) =>
    text.replaceAll(RegExp(r'sk-ant-[A-Za-z0-9_\-]+'), 'sk-ant-...');

class AnthropicClient {
  AnthropicClient({
    required this.apiKey,
    http.Client? client,
    this.timeout = kCoachTimeout,
  }) : _client = client ?? http.Client();

  final String apiKey;
  final Duration timeout;
  final http.Client _client;

  void close() => _client.close();

  /// One round trip. Tool results come back in as ordinary messages, so the
  /// loop that runs them lives above this.
  Future<CoachReply> send({
    required String system,
    required List<Map<String, Object?>> messages,
    required List<Map<String, Object?>> tools,
    required CoachModel model,
    int maxTokens = 1024,
  }) async {
    final body = jsonEncode({
      'model': model.wire,
      'max_tokens': maxTokens,
      'system': system,
      'messages': messages,
      if (tools.isNotEmpty) 'tools': tools,
    });

    final http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse(kAnthropicEndpoint),
            headers: {
              'content-type': 'application/json',
              'x-api-key': apiKey,
              'anthropic-version': kAnthropicVersion,
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

    return _parse(response.body);
  }

  CoachException _errorFor(http.Response response) {
    final status = response.statusCode;
    if (status == 401 || status == 403) {
      return const CoachException(
        'Die API-sleutel wordt niet aanvaard. Controleer hem bij '
        'Instellingen, AI-coach.',
        badKey: true,
      );
    }
    // The key works, but the account behind it has nothing left to spend.
    if (status == 402) {
      return const CoachException(
        'Er staat geen tegoed meer op dit Anthropic-account.',
        badKey: true,
      );
    }
    if (status == 429) {
      return const CoachException(
        'Te veel vragen na elkaar. Wacht even en probeer opnieuw.',
      );
    }
    if (status >= 500) {
      return const CoachException(
        'Anthropic is even overbelast. Probeer het zo opnieuw.',
      );
    }
    return CoachException(
      'Anthropic wees de vraag af: ${_detail(response.body)}',
    );
  }

  /// The error message the API sent, if it sent one we can read.
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

  CoachReply _parse(String body) {
    final Object? json;
    try {
      json = jsonDecode(body);
    } on FormatException {
      throw const CoachException('Het antwoord was onleesbaar.');
    }
    if (json is! Map) {
      throw const CoachException('Het antwoord had een vorm die niet klopt.');
    }

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
          final input = block['input'];
          calls.add(
            CoachToolCall(
              id: '${block['id']}',
              name: '${block['name']}',
              input: input is Map
                  ? input.map((key, value) => MapEntry('$key', value))
                  : const {},
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
      content: content,
    );
  }
}
