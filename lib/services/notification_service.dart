import '../config/api_config.dart';
import '../models/notification_model.dart';
import 'api_service.dart';

class NotificationService {
  final ApiService _api = ApiService();

  Future<List<NotificationModel>> getNotifications() async {
    final response = await _api.get(ApiConfig.notificationsUrl);
    final List data = response.data['data'] ?? [];
    return data.map((n) => NotificationModel.fromJson(n)).toList();
  }

  Future<void> markAsRead(String id) async {
    await _api.put(ApiConfig.notificationReadUrl(id));
  }
}
