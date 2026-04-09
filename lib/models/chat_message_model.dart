class ChatMessage {
  final String text;
  final bool isUser;
  final bool isVoiceInitiated;
  String? audioBase64; // TTS audio for AI responses
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    this.isVoiceInitiated = false,
    this.audioBase64,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Build from the Gemini chat history format stored in MongoDB
  /// { role: 'user'|'model', parts: [{ text: '...' }] }
  factory ChatMessage.fromChatHistory(Map<String, dynamic> json) {
    return ChatMessage(
      text: (json['parts'] as List?)?.first?['text'] ?? '',
      isUser: json['role'] == 'user',
    );
  }

  /// Build from a POST /farmer/chat API response
  factory ChatMessage.fromApiResponse(Map<String, dynamic> json) {
    return ChatMessage(
      text: json['reply'] ?? json['aiResponseText'] ?? '',
      isUser: false,
      isVoiceInitiated: json['isVoiceInitiated'] ?? false,
      audioBase64: json['aiResponseAudio'],
    );
  }
}
