import '../../../core/db/database.dart';
import 'ai_client.dart';

/// A client whose every request is counted in [db] as it goes out: what the
/// day limit holds to, whichever part of the app asks (DECISIONS 249).
AiClient countedClient(AppDatabase db, String apiKey, CoachProvider provider) =>
    AiClient(
      apiKey: apiKey,
      provider: provider,
      onRequest: () => db.chatDao.noteRequest(DateTime.now()),
    );
