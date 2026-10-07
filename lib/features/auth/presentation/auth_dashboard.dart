import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:google_sign_in/google_sign_in.dart';

import '../../../auth_api.dart';
import '../../../app_design_system.dart';
import '../../../app_preferences.dart';
import '../application/auth_service.dart';

part 'password_reset_page.dart';
part 'email_verification_page.dart';
part 'auth_widgets.dart';

const _navy = AppColors.navy;
Color get _ink => AppColors.ink;
Color get _orange => AppColors.accent;
Color get _page => AppColors.page;
Color get _muted => AppColors.muted;
const _authSectionGap = 12.0;
const _authFieldGap = 8.0;
const _authPrimaryButtonHeight = 48.0;
TextStyle get _authHeadingStyle =>
    TextStyle(color: _ink, fontSize: 27, fontWeight: FontWeight.w900);
TextStyle get _authDescriptionStyle =>
    TextStyle(color: _muted, fontSize: 13, height: 1.4);
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
        .showSnackBar(SnackBar(content: AppText(message), backgroundColor: _navy));
  }

  Future<void> _updateLanguage(String languageCode) async {
    try {
      await AppPreferences.instance.update(languageCode: languageCode);
    } on Exception catch (error) {
      if (mounted) _showMessage('Could not save your language setting: $error');
    }
  }

  Future<void> _submit() async {
    if (await _authService.hasAuthenticatedApiSession()) {
      if (mounted) Navigator.of(context).pop(true);
      return;
    }

    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text;
    if (email.isEmpty) {
      _showMessage('Please enter your email address.');
      return;
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      _showMessage('That email address doesn’t look right. Please check it.');
      return;
    }
    if (password.isEmpty) {
      _showMessage('Please enter your password.');
      return;
    }
    if (password.length < 8) {
      _showMessage('Choose a password with at least 8 characters.');
      return;
    }

    if (_mode == _AuthMode.register &&
        password != _confirmPasswordController.text) {
      _showMessage('Those passwords don’t match. Please try again.');
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
          contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
          actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          title: AppText(
            'How will you use TinkerPro?',
            style: TextStyle(
              color: _ink,
              fontSize: 21,
              fontWeight: FontWeight.w900,
            ),
           localize: true,),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _RoleCard(
                icon: Icons.person_rounded,
                title: 'Client',
                selected: selectedRole == _AccountRole.customer,
                onTap: () =>
                    setDialogState(() => selectedRole = _AccountRole.customer),
                onNoticeTap: () => showDialog<void>(
                  context: context,
                  builder: (noticeContext) => AlertDialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    title: AppText(
                      'Client account',
                      style: TextStyle(
                        color: _ink,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                     localize: true,),
                    content: AppText(
                      'Discover and book experiences.',
                      style: TextStyle(color: _muted, height: 1.4),
                     localize: true,),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(noticeContext).pop(),
                        child: const AppText('Got it', localize: true),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              _RoleCard(
                icon: Icons.storefront_rounded,
                title: 'Merchant',
                selected: selectedRole == _AccountRole.merchant,
                onTap: () =>
                    setDialogState(() => selectedRole = _AccountRole.merchant),
                onNoticeTap: () => showDialog<void>(
                  context: context,
                  builder: (noticeContext) => AlertDialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    title: AppText(
                      'Merchant dashboard',
                      style: TextStyle(
                        color: _ink,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                     localize: true,),
                    content: AppText(
                      'Track sales, customers, and venue performance.',
                      style: TextStyle(color: _muted, height: 1.4),
                     localize: true,),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(noticeContext).pop(),
                        child: const AppText('Got it', localize: true),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(foregroundColor: _muted),
              child: const AppText('Cancel', localize: true),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(selectedRole),
              style: FilledButton.styleFrom(
                backgroundColor: _orange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(fontWeight: FontWeight.w900),
              ),
              child: const AppText('Continue', localize: true),
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
                    gradient: AppGradients.authBackdropOverlay,
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
            top: safeTop + 8,
            right: 12,
            child: PopupMenuButton<String>(
              key: const ValueKey('auth-language-selector'),
              tooltip: appLanguageText('Choose language', 'Pumili ng wika'),
              onSelected: _updateLanguage,
              itemBuilder: (context) => [
                for (final language in AppLanguage.values)
                  PopupMenuItem(
                    value: language.code,
                    child: Row(
                      children: [
                        Expanded(
                          child: AppText(
                            '${language.nativeName} (${language.englishName})',
                           localize: true,),
                        ),
                        if (language.code ==
                            AppPreferences.instance.languageCode)
                          const Icon(Icons.check_rounded, size: 18),
                      ],
                    ),
                  ),
              ],
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: .24),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.language_rounded,
                        color: Colors.white,
                        size: 17,
                      ),
                      const SizedBox(width: 6),
                      AppText(
                        AppLanguage.fromCode(
                          AppPreferences.instance.languageCode,
                        ).nativeName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
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
              decoration: BoxDecoration(
                color: AppColors.surface,
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
                        const SizedBox(height: 6),
                        Center(
                          child: AppText(
                            appLanguageText(
                              isLogin ? 'Welcome back' : 'Create your account',
                              isLogin ? 'Maligayang pagbabalik' : 'Gumawa ng account',
                            ),
                            style: _authHeadingStyle,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Center(
                          child: AppText(
                            appLanguageText(
                              isLogin
                                  ? 'Sign in to book sports, events, and local experiences.'
                                  : 'Join the marketplace for sports, events, and local businesses.',
                              isLogin
                                  ? 'Mag-sign in upang mag-book ng sports, event, at lokal na karanasan.'
                                  : 'Sumali sa marketplace para sa sports, event, at lokal na negosyo.',
                            ),
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
                          AppText(
                            appLanguageText(
                              'How will you use TinkerPro?',
                              'Paano mo gagamitin ang TinkerPro?',
                            ),
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
                                  title: appLanguageText('Client', 'Customer'),
                                  subtitle: appLanguageText(
                                    'Discover and book',
                                    'Tuklasin at mag-book',
                                  ),
                                  selected: _role == _AccountRole.customer,
                                  onTap: () => setState(
                                    () => _role = _AccountRole.customer,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: _RoleCard(
                                  icon: Icons.storefront_rounded,
                                  title: appLanguageText('Merchant', 'Merchant'),
                                  subtitle: appLanguageText(
                                    'List and grow your business',
                                    'Ilista at palaguin ang negosyo',
                                  ),
                                  selected: _role == _AccountRole.merchant,
                                  onTap: () => setState(
                                    () => _role = _AccountRole.merchant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                        ],
                        _AuthField(
                          label: appLanguageText('Email address', 'Email address'),
                          hint: 'you@example.com',
                          icon: Icons.mail_outline_rounded,
                          keyboardType: TextInputType.emailAddress,
                          controller: _emailController,
                        ),
                        const SizedBox(height: _authFieldGap),
                        _AuthField(
                          label: appLanguageText('Password', 'Password'),
                          hint: appLanguageText(
                            isLogin
                                ? 'Enter your password'
                                : 'At least 8 characters',
                            isLogin
                                ? 'Ilagay ang iyong password'
                                : 'Hindi bababa sa 8 character',
                          ),
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
                            label: appLanguageText(
                              'Confirm password',
                              'Kumpirmahin ang password',
                            ),
                            hint: appLanguageText(
                              'Repeat your password',
                              'Ulitin ang iyong password',
                            ),
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
                                              builder: (_) => PasswordResetPage(
                                                service: _authService,
                                              ),
                                            ),
                                          ),
                                    child: AppText(
                                      appLanguageText(
                                        'Forgot password?',
                                        'Nakalimutan ang password?',
                                      ),
                                    ),
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
                                : AppText(
                                    appLanguageText(
                                      isLogin ? 'Sign in' : 'Create account',
                                      isLogin ? 'Mag-sign in' : 'Gumawa ng account',
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const _OrDivider(),
                        const SizedBox(height: 6),
                        Padding(
                          padding: EdgeInsets.only(bottom: 6),
                          child: Center(
                            child: AppText(
                              appLanguageText(
                                'Continue securely with',
                                'Magpatuloy nang ligtas gamit ang',
                              ),
                              style: TextStyle(
                                color: _muted,
                                fontSize: 12,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ),
                        _SocialButton(
                          label: appLanguageText(
                            'Continue with Google',
                            'Magpatuloy gamit ang Google',
                          ),
                          logoAsset: 'assets/google_logo.png',
                          onTap: _signInWithGoogle,
                        ),
                        const SizedBox(height: 6),
                        Center(
                          child: TextButton(
                            style: TextButton.styleFrom(
                              minimumSize: const Size(0, 36),
                              padding: AppSpacing.buttonPadding,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                            ),
                            onPressed: () => setState(
                              () => _mode = isLogin
                                  ? _AuthMode.register
                                  : _AuthMode.login,
                            ),
                            child: AppText(
                              appLanguageText(
                                isLogin
                                    ? 'New to TinkerPro? Register'
                                    : 'Already have an account? Sign in',
                                isLogin
                                    ? 'Bago sa TinkerPro? Mag-register'
                                    : 'May account ka na? Mag-sign in',
                              ),
                              style: TextStyle(
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
