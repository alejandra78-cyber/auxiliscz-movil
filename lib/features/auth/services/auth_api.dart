import '../../../core/network/api_client.dart';
import '../../../core/storage/token_storage.dart';

class AuthApi {
  AuthApi({ApiClient? apiClient, TokenStorage? tokenStorage})
      : _apiClient = apiClient ?? ApiClient(tokenStorage: tokenStorage),
        _tokenStorage = tokenStorage ?? TokenStorage();

  final ApiClient _apiClient;
  final TokenStorage _tokenStorage;

  Future<void> register({
    required String nombre,
    required String apellido,
    required String email,
    required String telefono,
    required String password,
  }) async {
    final fullName = '${nombre.trim()} ${apellido.trim()}'.trim();
    final res = await _apiClient.post('/auth/register', body: {
      'nombre': fullName,
      'email': email,
      'telefono': telefono,
      'password': password,
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
  }

  Future<void> logout() => _tokenStorage.clearToken();

  Future<String?> getToken() => _tokenStorage.readToken();

  Future<void> requestRecoveryToken(String email) async {
    final res = await _apiClient.post('/auth/password/recovery-request', body: {
      'email': email,
    });
    if (res.statusCode != 200) {
      throw Exception('No se pudo solicitar recuperación: ${res.body}');
    }
  }

  Future<void> validateResetToken(String token) async {
    final res = await _apiClient.post('/auth/password/validate-token', body: {
      'reset_token': token,
    });
    if (res.statusCode != 200) {
      throw Exception('Token inválido o expirado');
    }
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
}
