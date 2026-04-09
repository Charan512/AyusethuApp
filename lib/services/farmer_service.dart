import '../config/api_config.dart';
import '../models/chat_message_model.dart';
import 'api_service.dart';

class FarmerService {
  final ApiService _api = ApiService();

  // ── Profile ─────────────────────────────────────────
  Future<Map<String, dynamic>> getProfile() async {
    final response = await _api.get(ApiConfig.profileUrl);
    return response.data['data'];
  }

  Future<Map<String, dynamic>> updateProfile({
    String? phone,
    String? email,
    String? farmSize,
    String? irrigationType,
    String? location,
  }) async {
    final body = <String, dynamic>{};
    if (phone != null) body['phone'] = phone;
    if (email != null) body['email'] = email;
    if (farmSize != null) body['farmSize'] = farmSize;
    if (irrigationType != null) body['irrigationType'] = irrigationType;
    if (location != null) body['location'] = location;

    final response = await _api.put(ApiConfig.profileUpdateUrl, data: body);
    return response.data['data'];
  }

  // ── Dashboard ───────────────────────────────────────
  Future<Map<String, dynamic>> getDashboard({double? lat, double? lon}) async {
    String url = ApiConfig.dashboardUrl;
    if (lat != null && lon != null) {
      url += '?lat=$lat&lon=$lon';
    }
    final response = await _api.get(url);
    return response.data['data'];
  }

  // ── Text Chat ───────────────────────────────────────
  Future<Map<String, dynamic>> sendMessage({
    required String message,
    bool isVoiceInitiated = false,
  }) async {
    final response = await _api.post(
      ApiConfig.chatUrl,
      data: {
        'message': message,
        'isVoiceInitiated': isVoiceInitiated,
      },
    );
    return response.data['data'];
  }

  // ── My Batches ──────────────────────────────────────
  Future<List<Map<String, dynamic>>> getMyBatches() async {
    final response = await _api.get(ApiConfig.batchesUrl);
    final List data = response.data['data'] ?? [];
    return data.cast<Map<String, dynamic>>();
  }

  // ── Chat History ────────────────────────────────────
  Future<List<ChatMessage>> getChatHistory() async {
    final response = await _api.get(ApiConfig.chatHistoryUrl);
    final data = response.data['data'];
    final List history = data['chatHistory'] ?? [];

    return history
        .map<ChatMessage>((h) => ChatMessage.fromChatHistory(h))
        .toList();
  }

  // ── Voice Chat (full pipeline: audio → ASR → Gemini → TTS) ──
  Future<Map<String, dynamic>> sendVoiceMessage({
    required String audioBase64,
    String sourceLanguage = 'en',
  }) async {
    final response = await _api.post(
      ApiConfig.voiceChatUrl,
      data: {
        'audio': audioBase64,
        'sourceLanguage': sourceLanguage,
      },
    );
    return response.data['data'];
  }

  // ── On-Demand TTS ───────────────────────────────────
  Future<String?> generateTts({
    required String text,
  }) async {
    final response = await _api.post(
      ApiConfig.ttsUrl,
      data: {'text': text},
    );
    return response.data['data']['audioBase64'];
  }
}
