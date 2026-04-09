import '../config/api_config.dart';
import '../models/user_model.dart';
import 'api_service.dart';

class AuthService {
  final ApiService _api = ApiService();

  /// POST /api/v1/auth/login
  /// Returns { token, user } on success.
  Future<Map<String, dynamic>> login({
    String? phone,
    String? email,
    required String password,
  }) async {
    final body = <String, dynamic>{
      'password': password,
    };
    if (email != null && email.isNotEmpty) {
      body['email'] = email;
    } else {
      body['phone'] = phone;
    }

    final response = await _api.post(ApiConfig.loginUrl, data: body);
    final data = response.data['data'];

    // Save JWT token
    await _api.saveToken(data['token']);

    return {
      'token': data['token'],
      'user': UserModel.fromJson(data['user']),
    };
  }

  /// POST /api/v1/auth/register
  /// Sends farmer registration fields and stores token.
  Future<Map<String, dynamic>> register({
    required String name,
    required String phone,
    String? email,
    required String password,
    String? farmSize,
    String? irrigationType,
    String? location,
  }) async {
    final body = {
      'name': name,
      'phone': phone,
      'password': password,
      'role': 'FARMER',
      if (email != null && email.isNotEmpty) 'email': email,
      if (farmSize != null && farmSize.isNotEmpty) 'farmSize': farmSize,
      if (irrigationType != null && irrigationType.isNotEmpty)
        'irrigationType': irrigationType,
      if (location != null && location.isNotEmpty) 'location': location,
    };

    final response = await _api.post(ApiConfig.registerUrl, data: body);
    final data = response.data['data'];

    // Save JWT token
    await _api.saveToken(data['token']);

    return {
      'token': data['token'],
      'user': UserModel.fromJson(data['user']),
    };
  }

  /// Logout — clear stored token
  Future<void> logout() async {
    await _api.clearToken();
  }

  /// Check if user has a stored token
  Future<bool> isLoggedIn() async {
    final token = await _api.getToken();
    return token != null && token.isNotEmpty;
  }
}
