class NotificationModel {
  final String id;
  final String message;
  final String recipientRole;
  final bool isRead;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.message,
    required this.recipientRole,
    this.isRead = false,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['_id'] ?? '',
      message: json['message'] ?? '',
      recipientRole: json['recipientRole'] ?? '',
      isRead: json['isRead'] ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
    );
  }
}
