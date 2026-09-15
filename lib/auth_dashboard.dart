import 'package:flutter/material.dart';

import 'auth_api.dart';

const _navy = Color(0xFF192B50);
const _ink = Color(0xFF101B33);
const _orange = Color(0xFFFF8200);
const _page = Color(0xFFF7F9FC);
const _muted = Color(0xFF68748A);

enum _AuthMode { login, register }

enum _AccountRole { user, merchant }

class AuthDashboardPage extends StatefulWidget {
  const AuthDashboardPage({super.key});

  @override
  State<AuthDashboardPage> createState() => _AuthDashboardPageState();
}

class _AuthDashboardPageState extends State<AuthDashboardPage> {
  _AuthMode _mode = _AuthMode.login;
  _AccountRole _role = _AccountRole.user;
  bool _obscurePassword = true;
  bool _loading = false;
  final _api = AuthApi();
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
      final response = _mode == _AuthMode.login
          ? await _api.login(email: email, password: password)
          : await _api.register(
              email: email,
              password: password,
              role: _role == _AccountRole.merchant ? 'merchant' : 'user',
            );
      if (!mounted) return;
      if (_mode == _AuthMode.register) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => EmailVerificationPage(email: email, api: _api),
          ),
        );
      } else {
        final user = response['user'] as Map<String, dynamic>?;
        _showMessage(
          'Welcome back${user?['email'] == null ? '' : ', ${user!['email']}'}!',
        );
      }
    } on AuthApiException catch (error) {
      if (mounted) _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLogin = _mode == _AuthMode.login;
    return Scaffold(
      backgroundColor: _page,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back_rounded),
                color: _navy,
              ),
              const SizedBox(height: 18),
              Center(
                child: Image.asset(
                  'assets/tinker_logo.png',
                  width: 76,
                  height: 58,
                ),
              ),
              const SizedBox(height: 15),
              Center(
                child: Text(
                  isLogin ? 'Welcome back' : 'Create your account',
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 27,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 7),
              Center(
                child: Text(
                  isLogin
                      ? 'Sign in to continue your game.'
                      : 'Join TinkerPro and get in the game.',
                  style: const TextStyle(color: _muted, fontSize: 13),
                ),
              ),
              const SizedBox(height: 26),
              _AuthModeToggle(
                mode: _mode,
                onChanged: (mode) => setState(() => _mode = mode),
              ),
              const SizedBox(height: 24),
              if (!isLogin) ...[
                const Text(
                  'I am joining as',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _RoleCard(
                        icon: Icons.person_rounded,
                        title: 'Player',
                        subtitle: 'Book and play',
                        selected: _role == _AccountRole.user,
                        onTap: () => setState(() => _role = _AccountRole.user),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _RoleCard(
                        icon: Icons.storefront_rounded,
                        title: 'Merchant',
                        subtitle: 'Manage facilities',
                        selected: _role == _AccountRole.merchant,
                        onTap: () =>
                            setState(() => _role = _AccountRole.merchant),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
              _AuthField(
                label: 'Email address',
                hint: 'you@example.com',
                icon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
                controller: _emailController,
              ),
              const SizedBox(height: 14),
              _AuthField(
                label: 'Password',
                hint: 'Enter your password',
                icon: Icons.lock_outline_rounded,
                obscureText: _obscurePassword,
                controller: _passwordController,
                suffix: IconButton(
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
              if (!isLogin) ...[
                const SizedBox(height: 14),
                _AuthField(
                  label: 'Confirm password',
                  hint: 'Repeat your password',
                  icon: Icons.verified_user_outlined,
                  obscureText: true,
                  controller: _confirmPasswordController,
                ),
              ],
              if (isLogin)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => _showMessage(
                      'Password recovery will be available soon.',
                    ),
                    child: const Text('Forgot password?'),
                  ),
                )
              else
                const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _loading ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: _orange,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(53),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    textStyle: const TextStyle(fontWeight: FontWeight.w900),
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
              const SizedBox(height: 22),
              const _OrDivider(),
              const SizedBox(height: 18),
              _SocialButton(
                label: 'Continue with Google',
                logoAsset: 'assets/google_logo.png',
                onTap: () => _showMessage(
                  'Google sign in requires OAuth configuration.',
                ),
              ),
              const SizedBox(height: 11),
              _SocialButton(
                label: 'Continue with Facebook',
                logoAsset: 'assets/facebook_logo.jpg',
                onTap: () => _showMessage(
                  'Facebook sign in requires OAuth configuration.',
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: TextButton(
                  onPressed: () => setState(
                    () =>
                        _mode = isLogin ? _AuthMode.register : _AuthMode.login,
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
    );
  }
}

class EmailVerificationPage extends StatefulWidget {
  const EmailVerificationPage({
    super.key,
    required this.email,
    required this.api,
  });

  final String email;
  final AuthApi api;

  @override
  State<EmailVerificationPage> createState() => _EmailVerificationPageState();
}

class _EmailVerificationPageState extends State<EmailVerificationPage> {
  final _codeController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final code = _codeController.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      _message('Enter the 6-digit code from your email.');
      return;
    }
    setState(() => _loading = true);
    try {
      await widget.api.verifyEmail(email: widget.email, code: code);
      if (!mounted) return;
      _message('Email verified. Your account is ready.');
      Navigator.of(context).pop();
    } on AuthApiException catch (error) {
      if (mounted) _message(error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    setState(() => _loading = true);
    try {
      final response = await widget.api.resendVerification(widget.email);
      if (mounted) {
        _message(response['message'] as String? ?? 'A new code was sent.');
      }
    } on AuthApiException catch (error) {
      if (mounted) _message(error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _message(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message), backgroundColor: _navy));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _page,
      appBar: AppBar(
        backgroundColor: _page,
        foregroundColor: _navy,
        elevation: 0,
        title: const Text(
          'Verify email',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 26),
            Center(
              child: Image.asset(
                'assets/tinker_logo.png',
                width: 82,
                height: 62,
              ),
            ),
            const SizedBox(height: 25),
            const Text(
              'Check your inbox',
              style: TextStyle(
                color: _ink,
                fontSize: 27,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 9),
            Text(
              'We sent a 6-digit verification code to ${widget.email}.',
              style: const TextStyle(color: _muted, fontSize: 14, height: 1.45),
            ),
            const SizedBox(height: 28),
            _AuthField(
              label: 'Verification code',
              hint: '000000',
              icon: Icons.mark_email_read_outlined,
              keyboardType: TextInputType.number,
              controller: _codeController,
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _loading ? null : _verify,
                style: FilledButton.styleFrom(
                  backgroundColor: _orange,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(53),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  textStyle: const TextStyle(fontWeight: FontWeight.w900),
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
                    : const Text('Verify email'),
              ),
            ),
            const SizedBox(height: 14),
            Center(
              child: TextButton(
                onPressed: _loading ? null : _resend,
                child: const Text('Resend code'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthModeToggle extends StatelessWidget {
  const _AuthModeToggle({required this.mode, required this.onChanged});

  final _AuthMode mode;
  final ValueChanged<_AuthMode> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: const Color(0xFFE9EDF4),
      borderRadius: BorderRadius.circular(13),
    ),
    child: Row(
      children: [
        _ToggleOption(
          label: 'Sign in',
          selected: mode == _AuthMode.login,
          onTap: () => onChanged(_AuthMode.login),
        ),
        _ToggleOption(
          label: 'Register',
          selected: mode == _AuthMode.register,
          onTap: () => onChanged(_AuthMode.register),
        ),
      ],
    ),
  );
}

class _ToggleOption extends StatelessWidget {
  const _ToggleOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? _navy : _muted,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    ),
  );
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(15),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: selected ? _navy : Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: selected ? _orange : const Color(0xFFE4E8EF),
          width: selected ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: selected ? _orange : _muted, size: 24),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: selected ? Colors.white : _ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: selected
                        ? Colors.white.withValues(alpha: .65)
                        : _muted,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _AuthField extends StatelessWidget {
  const _AuthField({
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.obscureText = false,
    this.suffix,
    this.controller,
  });

  final String label;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffix;
  final TextEditingController? controller;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          color: _ink,
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 8),
      TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, color: _muted, size: 20),
          suffixIcon: suffix,
          filled: true,
          fillColor: Colors.white,
          hintStyle: const TextStyle(color: Color(0xFF9CA6B5), fontSize: 13),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE2E7EF)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE2E7EF)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _orange, width: 1.5),
          ),
        ),
      ),
    ],
  );
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) => const Row(
    children: [
      Expanded(child: Divider(color: Color(0xFFDDE2EA))),
      Padding(
        padding: EdgeInsets.symmetric(horizontal: 12),
        child: Text(
          'OR CONTINUE WITH',
          style: TextStyle(
            color: _muted,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: .8,
          ),
        ),
      ),
      Expanded(child: Divider(color: Color(0xFFDDE2EA))),
    ],
  );
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.label,
    required this.logoAsset,
    required this.onTap,
  });

  final String label;
  final String logoAsset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: onTap,
    style: OutlinedButton.styleFrom(
      minimumSize: const Size.fromHeight(51),
      backgroundColor: Colors.white,
      foregroundColor: _ink,
      side: const BorderSide(color: Color(0xFFE1E6EE)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Image.asset(logoAsset, width: 24, height: 24, fit: BoxFit.contain),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(
            color: _ink,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}
