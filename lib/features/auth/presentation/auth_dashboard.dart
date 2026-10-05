import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:google_sign_in/google_sign_in.dart';

import '../../../auth_api.dart';
import '../../../app_design_system.dart';
import '../application/auth_service.dart';

part 'password_reset_page.dart';
part 'email_verification_page.dart';
part 'auth_widgets.dart';

const _navy = AppColors.navy;
const _ink = AppColors.ink;
const _orange = AppColors.orange;
const _page = AppColors.page;
const _muted = AppColors.muted;
const _authSectionGap = 12.0;
const _authFieldGap = 8.0;
const _authPrimaryButtonHeight = 48.0;
const _authHeadingStyle = TextStyle(
  color: _ink,
  fontSize: 27,
  fontWeight: FontWeight.w900,
);
const _authDescriptionStyle = TextStyle(
  color: _muted,
  fontSize: 13,
  height: 1.4,
);
const _authPrimaryButtonTextStyle = TextStyle(
  fontSize: 15,
  fontWeight: FontWeight.w900,
);
const _googleServerClientId = String.fromEnvironment(
  'GOOGLE_SERVER_CLIENT_ID',
  defaultValue: '451592121635-f7hgfk7plbi3mngvor1eenrup21mlbg5.apps.googleusercontent.com',
);

enum _AuthMode { login, register }

enum _AccountRole { customer, merchant }

class AuthDashboardPage extends StatefulWidget {
  const AuthDashboardPage({super.key});

  @override
  State<AuthDashboardPage> createState() => _AuthDashboardPageState();
}

class _AuthDashboardPageState extends State<AuthDashboardPage> {
  _AuthMode _mode = _AuthMode.login;
  _AccountRole _role = _AccountRole.customer;
  bool _obscurePassword = true;
  bool _loading = false;
  final _api = AuthApi();
  late final _authService = AuthService(api: _api);
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message), backgroundColor: _navy));
  }

  Future<void> _submit() async {
    if (await _authService.hasAuthenticatedApiSession()) {
      if (mounted) Navigator.of(context).pop(true);
      return;
    }

    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text;
    if (!email.contains('@') || password.length < 8) {
      _showMessage(
        'Enter a valid email and a password with at least 8 characters.',
      );
      return;
    }

    if (_mode == _AuthMode.register &&
        password != _confirmPasswordController.text) {
      _showMessage('Passwords do not match.');
      return;
    }

    setState(() => _loading = true);
    try {
      final isRegistering = _mode == _AuthMode.register;
      late final Map<String, dynamic> response;
      if (isRegistering) {
        response = await _authService.register(
          email: email,
          password: password,
          role: _role == _AccountRole.merchant ? 'merchant' : 'customer',
        );
      } else {
        response = await _authService.login(email: email, password: password);
      }
      if (!mounted) return;
      if (isRegistering) {
        final verificationResult = await Navigator.of(context)
            .push<Map<String, dynamic>>(
              MaterialPageRoute(
                builder: (_) =>
                    EmailVerificationPage(email: email, service: _authService),
              ),
            );
        if (!mounted) return;
        if (verificationResult == null) {
          _showMessage('Email verification did not return a valid session.');
          return;
        }
        if (!mounted) return;
        Navigator.of(context).pop(true);
      } else if (response['user'] is Map) {
        if (!mounted) return;
        Navigator.of(context).pop(true);
      }
    } on AuthApiException catch (error) {
      if (mounted) _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    if (_loading) return;
    if (_googleServerClientId.isEmpty) {
      _showMessage(
        'Google sign-in is not configured. Add GOOGLE_SERVER_CLIENT_ID.',
      );
      return;
    }
    setState(() => _loading = true);
    try {
      await GoogleSignIn.instance.initialize(
        serverClientId: _googleServerClientId,
      );
      final account = await GoogleSignIn.instance.authenticate();
      final authentication = account.authentication;
      final idToken = authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw StateError('Google sign-in did not return an ID token.');
      }
      final credential = GoogleAuthProvider.credential(idToken: idToken);
      final result = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );
      final firebaseUser = result.user;
      if (firebaseUser == null) {
        throw StateError('Google sign-in did not return a user account.');
      }
      Map<String, dynamic> apiResult;
      try {
        apiResult = await _authService.loginWithGoogle(
          idToken,
          email: firebaseUser.email,
        );
      } on AuthApiException catch (error) {
        final roleIsRequired =
            error.data['code'] == 'role_required' ||
            (error.statusCode == 400 &&
                error.message.contains('Role must be customer or merchant'));
        if (!roleIsRequired) rethrow;

        final selectedRole = await _chooseGoogleRole();
        if (selectedRole == null) {
          await FirebaseAuth.instance.signOut();
          await GoogleSignIn.instance.signOut();
          return;
        }
        apiResult = await _authService.loginWithGoogle(
          idToken,
          role: selectedRole == _AccountRole.merchant ? 'merchant' : 'customer',
          email: firebaseUser.email,
        );
      }
      if (!mounted) return;
      final user = apiResult['user'] as Map<String, dynamic>?;
      if (user != null) {
        if (!mounted) return;
        Navigator.of(context).pop(true);
      }
    } on FirebaseAuthException catch (error) {
      if (mounted) _showMessage(error.message ?? 'Google sign-in failed.');
    } on Exception catch (error) {
      if (mounted) _showMessage('Google sign-in failed: $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<_AccountRole?> _chooseGoogleRole() {
    var selectedRole = _AccountRole.customer;
    return showDialog<_AccountRole>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Choose your TinkerPro account type'),
          content: RadioGroup<_AccountRole>(
            groupValue: selectedRole,
            onChanged: (value) {
              if (value != null) setDialogState(() => selectedRole = value);
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const RadioListTile<_AccountRole>(
                  value: _AccountRole.customer,
                  title: Text('Customer'),
                  subtitle: Text('Discover and book experiences'),
                ),
                const RadioListTile<_AccountRole>(
                  value: _AccountRole.merchant,
                  title: Text('Merchant'),
                  subtitle: Text('List and manage your business'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(selectedRole),
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLogin = _mode == _AuthMode.login;
    final safeTop = MediaQuery.paddingOf(context).top;
    final headerHeight = (MediaQuery.sizeOf(context).height * .38).clamp(
      280.0,
      370.0,
    );
    return Scaffold(
      backgroundColor: _page,
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: headerHeight,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  'assets/bg 1.png',
                  key: const ValueKey('auth-background-image'),
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x150A1730),
                        Color(0x280A1730),
                        Color(0xB30A1730),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: safeTop + 8,
            left: 12,
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back_rounded),
              color: Colors.white,
              style: IconButton.styleFrom(
                backgroundColor: Colors.black.withValues(alpha: .24),
              ),
            ),
          ),
          Positioned(
            top: headerHeight * .69,
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              key: const ValueKey('auth-form-panel'),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x40101B33),
                    blurRadius: 22,
                    offset: Offset(0, -8),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                key: const ValueKey('auth-content-scroll'),
                padding: EdgeInsets.fromLTRB(
                  22,
                  10,
                  22,
                  MediaQuery.paddingOf(context).bottom + 4,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Image.asset(
                            'assets/tinker_logo.png',
                            width: 56,
                            height: 36,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Center(
                          child: Text(
                            isLogin ? 'Welcome back' : 'Create your account',
                            style: _authHeadingStyle,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Center(
                          child: Text(
                            isLogin
                                ? 'Sign in to book sports, events, and local experiences.'
                                : 'Join the marketplace for sports, events, and local businesses.',
                            style: _authDescriptionStyle,
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: _authSectionGap),
                        _AuthModeToggle(
                          mode: _mode,
                          onChanged: (mode) => setState(() => _mode = mode),
                        ),
                        const SizedBox(height: _authSectionGap),
                        if (!isLogin) ...[
                          const Text(
                            'How will you use TinkerPro?',
                            style: TextStyle(
                              color: _ink,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: _RoleCard(
                                  icon: Icons.person_rounded,
                                  title: 'Client',
                                  subtitle: 'Discover and book',
                                  selected: _role == _AccountRole.customer,
                                  onTap: () => setState(
                                    () => _role = _AccountRole.customer,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _RoleCard(
                                  icon: Icons.storefront_rounded,
                                  title: 'Merchant',
                                  subtitle: 'List and grow your business',
                                  selected: _role == _AccountRole.merchant,
                                  onTap: () => setState(
                                    () => _role = _AccountRole.merchant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                        ],
                        _AuthField(
                          label: 'Email address',
                          hint: 'you@example.com',
                          icon: Icons.mail_outline_rounded,
                          keyboardType: TextInputType.emailAddress,
                          controller: _emailController,
                        ),
                        const SizedBox(height: _authFieldGap),
                        _AuthField(
                          label: 'Password',
                          hint: isLogin
                              ? 'Enter your password'
                              : 'At least 8 characters',
                          icon: Icons.lock_outline_rounded,
                          obscureText: _obscurePassword,
                          controller: _passwordController,
                          suffix: IconButton(
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                        if (!isLogin) ...[
                          const SizedBox(height: _authFieldGap),
                          _AuthField(
                            label: 'Confirm password',
                            hint: 'Repeat your password',
                            icon: Icons.verified_user_outlined,
                            obscureText: true,
                            controller: _confirmPasswordController,
                          ),
                        ],
                        SizedBox(
                          key: const ValueKey('auth-reset-slot'),
                          height: 32,
                          child: isLogin
                              ? Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: _loading
                                        ? null
                                        : () => Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  PasswordResetPage(
                                                    service: _authService,
                                                  ),
                                            ),
                                          ),
                                    child: const Text('Forgot password?'),
                                  ),
                                )
                              : const SizedBox.expand(),
                        ),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            key: const ValueKey('auth-primary-button'),
                            onPressed: _loading ? null : _submit,
                            style: FilledButton.styleFrom(
                              backgroundColor: _orange,
                              foregroundColor: Colors.white,
                              fixedSize: const Size.fromHeight(
                                _authPrimaryButtonHeight,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                              textStyle: _authPrimaryButtonTextStyle,
                            ),
                            child: _loading
                                ? const SizedBox(
                                    width: 21,
                                    height: 21,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(isLogin ? 'Sign in' : 'Create account'),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const _OrDivider(),
                        const SizedBox(height: 8),
                        const Padding(
                          padding: EdgeInsets.only(bottom: 6),
                          child: Center(
                            child: Text(
                              'Continue securely with',
                              style: TextStyle(
                                color: _muted,
                                fontSize: 12,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ),
                        _SocialButton(
                          label: 'Continue with Google',
                          logoAsset: 'assets/google_logo.png',
                          onTap: _signInWithGoogle,
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: TextButton(
                            style: TextButton.styleFrom(
                              minimumSize: const Size(0, 36),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                            ),
                            onPressed: () => setState(
                              () => _mode = isLogin
                                  ? _AuthMode.register
                                  : _AuthMode.login,
                            ),
                            child: Text(
                              isLogin
                                  ? 'New to TinkerPro? Register'
                                  : 'Already have an account? Sign in',
                              style: const TextStyle(
                                color: _orange,
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
