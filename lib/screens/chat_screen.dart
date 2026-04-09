import 'dart:convert';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import '../providers/chat_provider.dart';
import '../services/farmer_service.dart';
import '../theme/app_theme.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/chat_input_bar.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final ScrollController _scrollController = ScrollController();
  final AudioPlayer _audioPlayer = AudioPlayer();
  late final AudioRecorder _recorder;
  final FarmerService _farmerService = FarmerService();

  @override
  void initState() {
    super.initState();
    _recorder = AudioRecorder();
    Future.microtask(() {
      ref.read(chatProvider.notifier).loadHistory();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _audioPlayer.dispose();
    _recorder.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _startRecording() async {
    try {
      if (await _recorder.hasPermission()) {
        ref.read(chatProvider.notifier).startRecording();

        final dir = await getTemporaryDirectory();
        final path = '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.wav';

        await _recorder.start(
          const RecordConfig(
            encoder: AudioEncoder.wav,
            sampleRate: 16000,
            numChannels: 1,
          ),
          path: path,
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Microphone permission is required for voice input'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Recording error: $e');
      _handleVoiceError('Failed to start microphone.');
    }
  }

  Future<void> _stopRecording() async {
    try {
      ref.read(chatProvider.notifier).stopRecording();

      final path = await _recorder.stop();
      if (path != null) {
        await _processAudio(path);
      } else {
        // Recording stopped without a file
        _handleVoiceError('Recording cancelled or failed.');
      }
    } catch (e) {
      debugPrint('Stop recording error: $e');
      _handleVoiceError('Microphone error occurred.');
    }
  }

  Future<void> _processAudio(String filePath) async {
    try {
      // Read actual file bytes from the device and convert to base64
      final audioFile = File(filePath);
      final fileBytes = await audioFile.readAsBytes();
      final base64String = base64Encode(fileBytes);

      final response = await _farmerService.sendVoiceMessage(
        audioBase64: base64String,
        sourceLanguage: 'en',
      );

      final transcript = response['transcript'] ?? 'Hello, I am a farmer';
      ref.read(chatProvider.notifier).onAsrComplete(transcript);
    } catch (e) {
      debugPrint('ASR processing error: $e');
      _handleVoiceError('Failed to connect to Voice Server. Please try again.');
    }
  }

  void _handleVoiceError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.error,
        ),
      );
      // Ensure UI knows recording/processing is aborted and return to idle
      ref.read(chatProvider.notifier).onTextCleared();
    }
  }

  void _handleSend(String text, bool isVoice) {
    if (isVoice) {
      ref.read(chatProvider.notifier).sendVoiceMessage(text);
    } else {
      ref.read(chatProvider.notifier).sendTextMessage(text);
    }
    _scrollToBottom();
  }

  /// Auto-play TTS for voice-initiated responses
  Future<void> _autoPlayTts(String? audioBase64) async {
    if (audioBase64 == null || audioBase64.isEmpty) return;
    try {
      final bytes = base64Decode(audioBase64);
      // Play from disk instead of memory for consistent Android emulator behaviour
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/tts_response_${DateTime.now().millisecondsSinceEpoch}.mp3');
      await file.writeAsBytes(bytes);
      
      await _audioPlayer.play(DeviceFileSource(file.path));
    } catch (e) {
      debugPrint('TTS autoplay error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);

    // Auto-scroll when new messages arrive
    ref.listen<ChatState>(chatProvider, (prev, next) {
      if (prev != null && next.messages.length > prev.messages.length) {
        _scrollToBottom();
        // Auto-play TTS for voice-initiated AI responses
        final lastMsg = next.messages.last;
        if (!lastMsg.isUser && lastMsg.isVoiceInitiated) {
          _autoPlayTts(lastMsg.audioBase64);
        }
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('AyuSethu Chat'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'AI Online',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Chat messages ──────────────────────
          Expanded(
            child: chatState.messages.isEmpty && !chatState.isSending
                ? _buildEmptyState(context)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 16,
                    ),
                    itemCount: chatState.messages.length +
                        (chatState.isSending ? 1 : 0),
                    itemBuilder: (context, index) {
                      // Show typing indicator for pending AI response
                      if (index == chatState.messages.length &&
                          chatState.isSending) {
                        return _buildTypingIndicator();
                      }
                      return ChatBubble(
                        message: chatState.messages[index],
                        audioPlayer: _audioPlayer,
                      );
                    },
                  ),
          ),

          // ── Input bar ─────────────────────────
          ChatInputBar(
            onStartRecording: _startRecording,
            onStopRecording: _stopRecording,
            onSend: _handleSend,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chat_rounded,
                size: 48,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Start a Conversation',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            Text(
              'Type a message or tap the mic to speak in your language. I\'ll help you manage your farm!',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(left: 8, top: 4, bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.aiBubble,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomRight: Radius.circular(20),
            bottomLeft: Radius.circular(4),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _TypingDot(delay: 0),
            const SizedBox(width: 4),
            _TypingDot(delay: 200),
            const SizedBox(width: 4),
            _TypingDot(delay: 400),
          ],
        ),
      ),
    );
  }
}

class _TypingDot extends StatefulWidget {
  final int delay;
  const _TypingDot({required this.delay});

  @override
  State<_TypingDot> createState() => _TypingDotState();
}

class _TypingDotState extends State<_TypingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _animation = Tween<double>(begin: 0, end: -8).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _controller.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _animation.value),
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}
