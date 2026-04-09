import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/notification_model.dart';
import '../services/notification_service.dart';

class NotificationState {
  final List<NotificationModel> notifications;
  final bool isLoading;

  const NotificationState({
    this.notifications = const [],
    this.isLoading = false,
  });

  int get unreadCount => notifications.where((n) => !n.isRead).length;

  NotificationState copyWith({
    List<NotificationModel>? notifications,
    bool? isLoading,
  }) {
    return NotificationState(
      notifications: notifications ?? this.notifications,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class NotificationNotifier extends StateNotifier<NotificationState> {
  final NotificationService _service = NotificationService();

  NotificationNotifier() : super(const NotificationState());

  Future<void> loadNotifications() async {
    state = state.copyWith(isLoading: true);
    try {
      final notifications = await _service.getNotifications();
      state = state.copyWith(notifications: notifications, isLoading: false);
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> markAsRead(String id) async {
    try {
      await _service.markAsRead(id);
      state = state.copyWith(
        notifications: state.notifications
            .map((n) => n.id == id
                ? NotificationModel(
                    id: n.id,
                    message: n.message,
                    recipientRole: n.recipientRole,
                    isRead: true,
                    createdAt: n.createdAt,
                  )
                : n)
            .toList(),
      );
    } catch (_) {}
  }
}

final notificationProvider =
    StateNotifierProvider<NotificationNotifier, NotificationState>((ref) {
  return NotificationNotifier();
});
