import '../../../core/network/api_client.dart';
import '../../../core/notifications/push_notifications_service.dart';
import '../../../core/storage/token_storage.dart';

class AuthApi {
  AuthApi({ApiClient? apiClient, TokenStorage? tokenStorage})
      : _apiClient = apiClient ?? ApiClient(tokenStorage: tokenStorage),
        _tokenStorage = tokenStorage ?? TokenStorage();

  final ApiClient _apiClient;
  final TokenStorage _tokenStorage;

  Future<void> register({
    required String nombre,
    required String email,
    required String password,
  }) async {
    final res = await _apiClient.post('/auth/register', body: {
      'nombre': nombre,
      'email': email,
      'password': password,
      'rol': 'conductor',
    });
    if (res.statusCode != 200) {
      throw Exception('No se pudo registrar usuario: ${res.body}');
    }
  }

  Future<void> login({required String email, required String password}) async {
    final res = await _apiClient.post('/auth/login', body: {
      'email': email,
      'password': password,
    });
    if (res.statusCode != 200) {
      throw Exception('No se pudo iniciar sesión: ${res.body}');
    }
    final json = ApiClient.decodeJsonMap(res.body);
    await _tokenStorage.saveToken((json['access_token'] ?? '').toString());
    await syncPushTokenIfPossible();
  }

  Future<void> logout() async {
    final pushToken = await PushNotificationsService.instance.getDeviceToken();
    if (pushToken != null && pushToken.isNotEmpty) {
      await _apiClient.post('/auth/device-token/remove', body: {
        'token': pushToken,
        'plataforma': PushNotificationsService.instance.platformName,
      });
    }
    await _tokenStorage.clearToken();
  }

  Future<String?> getToken() => _tokenStorage.readToken();

  Future<String?> requestRecoveryToken(String email) async {
    final res = await _apiClient.post('/auth/password/recovery-request', body: {
      'email': email,
    });
    if (res.statusCode != 200) {
      throw Exception('No se pudo solicitar recuperación: ${res.body}');
    }
    final json = ApiClient.decodeJsonMap(res.body);
    return json['reset_token']?.toString();
  }

  Future<void> resetPassword({required String token, required String newPassword}) async {
    final res = await _apiClient.post('/auth/password/reset', body: {
      'reset_token': token,
      'nueva_password': newPassword,
    });
    if (res.statusCode != 200) {
      throw Exception('No se pudo restablecer contraseña: ${res.body}');
    }
  }

  Future<void> registerDeviceToken({
    required String token,
    String? plataforma,
  }) async {
    final res = await _apiClient.post('/auth/device-token', body: {
      'token': token,
      'plataforma': plataforma ?? PushNotificationsService.instance.platformName,
    });
    if (res.statusCode != 200) {
      throw Exception('No se pudo registrar token del dispositivo: ${res.body}');
    }
  }

  Future<void> syncPushTokenIfPossible() async {
    final token = await PushNotificationsService.instance.getDeviceToken();
    if (token == null || token.isEmpty) return;
    await registerDeviceToken(token: token);
  }
}
