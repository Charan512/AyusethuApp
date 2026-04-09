import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import '../models/chat_message_model.dart';
import '../services/farmer_service.dart';
import '../theme/app_theme.dart';

class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final AudioPlayer? audioPlayer;

  const ChatBubble({
    super.key,
    required this.message,
    this.audioPlayer,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        margin: EdgeInsets.only(
          left: isUser ? 48 : 8,
          right: isUser ? 8 : 48,
          top: 4,
          bottom: 4,
        ),
        child: Column(
          crossAxisAlignment:
              isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: isUser ? AppColors.userBubble : AppColors.aiBubble,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isUser ? 20 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                message.text,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: isUser ? Colors.white : AppColors.textPrimary,
                      height: 1.4,
                    ),
              ),
            ),
            // Show "Speak" button for AI responses that were NOT voice-initiated
            if (!isUser &&
                !message.isVoiceInitiated &&
                message.audioBase64 == null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: _ManualTtsButton(
                  message: message,
                  audioPlayer: audioPlayer,
                ),
              ),
            // Auto-play indicator / Replay button for voice-initiated AI responses
            if (!isUser && message.isVoiceInitiated && message.audioBase64 != null)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 4),
                child: InkWell(
                  onTap: () async {
                    if (audioPlayer == null) return;
                    try {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Replaying AI Voice Response...')),
                      );
                      final bytes = base64Decode(message.audioBase64!);
                      await audioPlayer!.play(BytesSource(bytes));
                    } catch (e) {
                      debugPrint('Replay error: $e');
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.replay_rounded, size: 16, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text(
                        'Replay Audio',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontSize: 12,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Small "Speak" button that appears next to keyboard-initiated AI responses
class _ManualTtsButton extends StatefulWidget {
  final ChatMessage message;
  final AudioPlayer? audioPlayer;

  const _ManualTtsButton({required this.message, this.audioPlayer});

  @override
  State<_ManualTtsButton> createState() => _ManualTtsButtonState();
}

class _ManualTtsButtonState extends State<_ManualTtsButton> {
  bool _isPlaying = false;
  final FarmerService _farmerService = FarmerService();

  Future<void> _handleTap() async {
    if (_isPlaying || widget.audioPlayer == null) return;
    
    setState(() => _isPlaying = true);

    try {
      // Use locally cached audio if available (from a previous click)
      String? base64String = widget.message.audioBase64;

      if (base64String == null) {
        base64String = await _farmerService.generateTts(text: widget.message.text);
        // Cache it back onto the message object so next replay is instant
        widget.message.audioBase64 = base64String;
      }

      if (base64String != null && mounted) {
        final bytes = base64Decode(base64String);
        await widget.audioPlayer!.play(BytesSource(bytes));
      }
    } catch (e) {
      debugPrint('Speak error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate speech. $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isPlaying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _handleTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.primarySurface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _isPlaying ? Icons.stop_rounded : Icons.volume_up_rounded,
              size: 16,
              color: AppColors.primary,
            ),
            const SizedBox(width: 4),
            Text(
              _isPlaying ? 'Playing...' : 'Speak',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 12,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
