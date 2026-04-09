import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConfig {
  static String get baseUrl =>
      dotenv.env['BASE_URL'] ?? 'http://10.0.2.2:5001/api/v1';

  // ── Auth ───────────────────────────────────────────
  static String get loginUrl => '$baseUrl/auth/login';
  static String get registerUrl => '$baseUrl/auth/register';

  // ── Farmer ─────────────────────────────────────────
  static String get profileUrl => '$baseUrl/farmer/profile';
  static String get profileUpdateUrl => '$baseUrl/farmer/profile/update';
  static String get dashboardUrl => '$baseUrl/farmer/dashboard';
  static String get chatUrl => '$baseUrl/farmer/chat';
  static String get chatHistoryUrl => '$baseUrl/farmer/chat-history';
  static String get voiceChatUrl => '$baseUrl/farmer/voice-chat';
  static String get ttsUrl => '$baseUrl/farmer/tts';
  static String get batchesUrl => '$baseUrl/farmer/batches';
  static String completeStageUrl(String batchId, int stage) =>
      '$baseUrl/farmer/batch/$batchId/stage/$stage';

  // ── Notifications ──────────────────────────────────
  static String get notificationsUrl => '$baseUrl/notifications';
  static String notificationReadUrl(String id) =>
      '$baseUrl/notifications/$id/read';
}
