import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/chat_provider.dart';
import '../theme/app_theme.dart';

class ChatInputBar extends ConsumerStatefulWidget {
  final VoidCallback onStartRecording;
  final VoidCallback onStopRecording;
  final Function(String text, bool isVoice) onSend;

  const ChatInputBar({
    super.key,
    required this.onStartRecording,
    required this.onStopRecording,
    required this.onSend,
  });

  @override
  ConsumerState<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends ConsumerState<ChatInputBar>
    with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final chatNotifier = ref.read(chatProvider.notifier);
    if (_controller.text.isNotEmpty) {
      chatNotifier.onUserTyping();
    } else {
      chatNotifier.onTextCleared();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);
    final mode = chatState.inputMode;

    // Populate text field with ASR transcript when voice-ready
    if (mode == ChatInputMode.voiceReady &&
        chatState.pendingVoiceText.isNotEmpty &&
        _controller.text != chatState.pendingVoiceText) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _controller.text = chatState.pendingVoiceText;
        _controller.selection = TextSelection.fromPosition(
          TextPosition(offset: _controller.text.length),
        );
      });
    }

    // Pulse animation during recording
    if (mode == ChatInputMode.recording) {
      _pulseController.repeat(reverse: true);
    } else {
      _pulseController.stop();
      _pulseController.reset();
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // ── Text field ──────────────────────────
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(24),
                  border: mode == ChatInputMode.recording
                      ? Border.all(color: AppColors.error, width: 2)
                      : null,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        enabled: mode != ChatInputMode.recording &&
                            mode != ChatInputMode.processing,
                        maxLines: 4,
                        minLines: 1,
                        style: Theme.of(context).textTheme.bodyLarge,
                        decoration: InputDecoration(
                          hintText: mode == ChatInputMode.recording
                              ? 'Listening...'
                              : mode == ChatInputMode.processing
                                  ? 'Processing speech...'
                                  : 'Type your message...',
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(width: 8),

            // ── Action button (Mic / Stop / Send / Loading) ──
            _buildActionButton(mode, chatState.isSending),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(ChatInputMode mode, bool isSending) {
    if (isSending) {
      return Container(
        width: 52,
        height: 52,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.primaryLight,
        ),
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2.5,
            ),
          ),
        ),
      );
    }

    switch (mode) {
      case ChatInputMode.recording:
        return _AnimatedRecordButton(
          controller: _pulseController,
          onTap: () {
            widget.onStopRecording();
          },
        );

      case ChatInputMode.processing:
        return Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.warning.withValues(alpha: 0.15),
          ),
          child: const Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                color: AppColors.warning,
                strokeWidth: 2.5,
              ),
            ),
          ),
        );

      case ChatInputMode.typing:
      case ChatInputMode.voiceReady:
        return GestureDetector(
          onTap: () {
            final text = _controller.text.trim();
            if (text.isEmpty) return;
            final isVoice = mode == ChatInputMode.voiceReady;
            widget.onSend(text, isVoice);
            _controller.clear();
          },
          child: Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.primaryGradient,
              boxShadow: [
                BoxShadow(
                  color: Color(0x401B5E20),
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(
              Icons.send_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
        );

      case ChatInputMode.idle:
        return GestureDetector(
          onTap: widget.onStartRecording,
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.accentGradient,
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(
              Icons.mic_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
        );
    }
  }
}

/// Animated pulsing stop button during recording
class _AnimatedRecordButton extends StatelessWidget {
  final AnimationController controller;
  final VoidCallback onTap;

  const _AnimatedRecordButton({
    required this.controller,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, child) {
          return Container(
            width: 52 + (controller.value * 8),
            height: 52 + (controller.value * 8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.error,
              boxShadow: [
                BoxShadow(
                  color: AppColors.error.withValues(alpha: 0.3 + controller.value * 0.2),
                  blurRadius: 12 + controller.value * 8,
                  spreadRadius: controller.value * 4,
                ),
              ],
            ),
            child: const Icon(
              Icons.stop_rounded,
              color: Colors.white,
              size: 28,
            ),
          );
        },
      ),
    );
  }
}
