import '../../../app_session.dart';
import '../../../auth_api.dart';

abstract interface class AuthSessionStore {
  Future<bool> hasAuthenticatedApiSession();

  Future<void> save({
    required String email,
    required String token,
    required String role,
  });
}

class AppSessionAuthStore implements AuthSessionStore {
  const AppSessionAuthStore();

  @override
  Future<bool> hasAuthenticatedApiSession() async {
    final session = await AppSession.load();
    return session.isAuthenticated && session.apiToken?.isNotEmpty == true;
  }

  @override
  Future<void> save({
    required String email,
    required String token,
    required String role,
  }) async {
    final session = await AppSession.load();
    await session.setAccountEmail(email);
    await session.setApiToken(token);
    await session.setRole(role);
    await session.markAuthenticated();
  }
}

class AuthService {
  AuthService({
    required this.api,
    this.sessions = const AppSessionAuthStore(),
  });

  final AuthApi api;
  final AuthSessionStore sessions;

  Future<bool> hasAuthenticatedApiSession() =>
      sessions.hasAuthenticatedApiSession();

  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String role,
  }) => api.register(email: email, password: password, role: role);

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await api.login(email: email, password: password);
    await _persistApiSession(response, fallbackEmail: email);
    return response;
  }

  Future<Map<String, dynamic>> loginWithGoogle(
    String idToken, {
    String? role,
    String? email,
  }) async {
    final response = await api.loginWithGoogle(idToken, role: role);
    await _persistApiSession(response, fallbackEmail: email);
    return response;
  }

  Future<Map<String, dynamic>> verifyEmail({
    required String email,
    required String code,
  }) async {
    final response = await api.verifyEmail(email: email, code: code);
    await _persistApiSession(response, fallbackEmail: email);
    return response;
  }

  Future<Map<String, dynamic>> resendVerification(String email) =>
      api.resendVerification(email);

  Future<Map<String, dynamic>> requestPasswordReset(String email) =>
      api.requestPasswordReset(email);

  Future<Map<String, dynamic>> verifyPasswordResetCode({
    required String email,
    required String code,
  }) => api.verifyPasswordResetCode(email: email, code: code);

  Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String code,
    required String password,
  }) => api.resetPassword(email: email, code: code, password: password);

  Future<void> _persistApiSession(
    Map<String, dynamic> response, {
    String? fallbackEmail,
  }) async {
    final user = response['user'];
    final token = response['token'];
    if (user is! Map || token is! String || token.isEmpty) {
      throw const AuthApiException(
        'The server returned an incomplete sign-in response.',
        502,
      );
    }
    final role = user['role'];
    if (role is! String || role.isEmpty) {
      throw const AuthApiException(
        'The server returned an incomplete sign-in response.',
        502,
      );
    }
    final email = user['email'] is String
        ? (user['email'] as String).trim()
        : (fallbackEmail ?? '').trim();
    if (email.isEmpty) {
      throw const AuthApiException(
        'The server returned an incomplete sign-in response.',
        502,
      );
    }
    await sessions.save(email: email, token: token, role: role);
  }
}
