import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chat_message_model.dart';
import '../services/farmer_service.dart';

/// State machine for the chat input bar
enum ChatInputMode { idle, recording, processing, voiceReady, typing }

class ChatState {
  final List<ChatMessage> messages;
  final ChatInputMode inputMode;
  final bool isSending;
  final String? errorMessage;
  final String pendingVoiceText; // ASR transcript waiting to be sent

  const ChatState({
    this.messages = const [],
    this.inputMode = ChatInputMode.idle,
    this.isSending = false,
    this.errorMessage,
    this.pendingVoiceText = '',
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    ChatInputMode? inputMode,
    bool? isSending,
    String? errorMessage,
    String? pendingVoiceText,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      inputMode: inputMode ?? this.inputMode,
      isSending: isSending ?? this.isSending,
      errorMessage: errorMessage,
      pendingVoiceText: pendingVoiceText ?? this.pendingVoiceText,
    );
  }
}

class ChatNotifier extends StateNotifier<ChatState> {
  final FarmerService _farmerService = FarmerService();

  ChatNotifier() : super(const ChatState());

  /// Load chat history from backend on screen mount
  Future<void> loadHistory() async {
    try {
      final messages = await _farmerService.getChatHistory();
      state = state.copyWith(messages: messages);
    } catch (e) {
      // Silently fail — fresh chat session
      state = state.copyWith(messages: []);
    }
  }

  /// Send a text (keyboard) message — isVoiceInitiated = false
  Future<void> sendTextMessage(String text) async {
    if (text.trim().isEmpty) return;

    // Add user message to the list immediately
    final userMsg = ChatMessage(text: text, isUser: true, isVoiceInitiated: false);
    state = state.copyWith(
      messages: [...state.messages, userMsg],
      isSending: true,
      inputMode: ChatInputMode.idle,
    );

    try {
      final response = await _farmerService.sendMessage(
        message: text,
        isVoiceInitiated: false,
      );
      final aiMsg = ChatMessage.fromApiResponse(response);
      state = state.copyWith(
        messages: [...state.messages, aiMsg],
        isSending: false,
      );
    } catch (e) {
      state = state.copyWith(
        isSending: false,
        errorMessage: 'Failed to send message',
      );
    }
  }

  /// Send a voice-initiated message — isVoiceInitiated = true
  /// The text was populated by ASR and is now being sent.
  Future<void> sendVoiceMessage(String text) async {
    if (text.trim().isEmpty) return;

    final userMsg = ChatMessage(text: text, isUser: true, isVoiceInitiated: true);
    state = state.copyWith(
      messages: [...state.messages, userMsg],
      isSending: true,
      inputMode: ChatInputMode.idle,
      pendingVoiceText: '',
    );

    try {
      final response = await _farmerService.sendMessage(
        message: text,
        isVoiceInitiated: true,
      );
      final aiMsg = ChatMessage(
        text: response['reply'] ?? '',
        isUser: false,
        isVoiceInitiated: true,
        audioBase64: response['aiResponseAudio'],
      );
      state = state.copyWith(
        messages: [...state.messages, aiMsg],
        isSending: false,
      );
    } catch (e) {
      state = state.copyWith(
        isSending: false,
        errorMessage: 'Failed to send voice message',
      );
    }
  }

  /// ── State machine transitions ─────────────────────

  void startRecording() {
    state = state.copyWith(inputMode: ChatInputMode.recording);
  }

  void stopRecording() {
    state = state.copyWith(inputMode: ChatInputMode.processing);
  }

  void onAsrComplete(String transcript) {
    state = state.copyWith(
      inputMode: ChatInputMode.voiceReady,
      pendingVoiceText: transcript,
    );
  }

  void onUserTyping() {
    if (state.inputMode != ChatInputMode.typing) {
      state = state.copyWith(inputMode: ChatInputMode.typing);
    }
  }

  void onTextCleared() {
    state = state.copyWith(inputMode: ChatInputMode.idle);
  }

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }
}

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  return ChatNotifier();
});
