part of 'auth_dashboard.dart';

class PasswordResetPage extends StatefulWidget {
  const PasswordResetPage({super.key, required this.service});

  final AuthService service;

  @override
  State<PasswordResetPage> createState() => _PasswordResetPageState();
}

class _PasswordResetPageState extends State<PasswordResetPage> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _codeRequested = false;
  bool _codeVerified = false;
  bool _loading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _message(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: AppText(message), backgroundColor: _navy));
  }

  Future<void> _requestCode() async {
    final email = _emailController.text.trim().toLowerCase();
    if (email.isEmpty) {
      _message('Please enter the email address linked to your account.');
      return;
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      _message('That email address doesn’t look right. Please check it.');
      return;
    }
    setState(() {
      _loading = true;
    });
    try {
      final response = await widget.service.requestPasswordReset(email);
      if (mounted) {
        setState(() {
          _codeRequested = true;
          _codeVerified = false;
          _codeController.clear();
          _passwordController.clear();
          _confirmController.clear();
        });
        _message(response['message'] as String? ?? 'Verification code sent.');
      }
    } on AuthApiException catch (error) {
      if (mounted) _message(error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verifyCode() async {
    final email = _emailController.text.trim().toLowerCase();
    final code = _codeController.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      _message('That code should be 6 digits. Check your email and try again.');
      return;
    }
    setState(() => _loading = true);
    try {
      await widget.service.verifyPasswordResetCode(email: email, code: code);
      if (mounted) {
        setState(() => _codeVerified = true);
        _message('Code verified. You can now choose a new password.');
      }
    } on AuthApiException catch (error) {
      if (mounted) _message(error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim().toLowerCase();
    final code = _codeController.text.trim();
    final password = _passwordController.text;
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      _message('That code should be 6 digits. Check your email and try again.');
      return;
    }
    if (password.length < 8) {
      _message('Choose a new password with at least 8 characters.');
      return;
    }
    if (password != _confirmController.text) {
      _message('Those passwords don’t match. Please try again.');
      return;
    }
    setState(() => _loading = true);
    try {
      final response = await widget.service.resetPassword(
        email: email,
        code: code,
        password: password,
      );
      if (mounted) {
        _message(response['message'] as String? ?? 'Password changed.');
        Navigator.of(context).pop();
      }
    } on AuthApiException catch (error) {
      if (mounted) _message(error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _page,
      appBar: AppBar(
        backgroundColor: _page,
        foregroundColor: _navy,
        elevation: 0,
        title: const AppText('Reset password', localize: true),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppText(
              'Forgot your password?',
              style: TextStyle(
                color: _ink,
                fontSize: 27,
                fontWeight: FontWeight.w900,
              ),
              localize: true,
            ),
            const SizedBox(height: 8),
            AppText(
              'Enter your email to receive a verification code, then choose a new password.',
              style: TextStyle(color: _muted, fontSize: 14, height: 1.45),
              localize: true,
            ),
            const SizedBox(height: 26),
            _AuthField(
              label: 'Account email',
              hint: 'you@example.com',
              icon: Icons.mail_outline_rounded,
              keyboardType: TextInputType.emailAddress,
              controller: _emailController,
            ),
            const SizedBox(height: 16),
            if (!_codeRequested)
              _ResetButton(
                label: 'Send verification code',
                loading: _loading,
                onPressed: _requestCode,
              )
            else ...[
              _AuthField(
                label: 'Verification code',
                hint: '000000',
                icon: Icons.verified_outlined,
                keyboardType: TextInputType.number,
                controller: _codeController,
                maxLength: 6,
              ),
              if (!_codeVerified) ...[
                const SizedBox(height: 22),
                _ResetButton(
                  label: 'Verify code',
                  loading: _loading,
                  onPressed: _verifyCode,
                ),
              ] else ...[
                const SizedBox(height: 14),
                _AuthField(
                  label: 'New password',
                  hint: 'At least 8 characters',
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
                const SizedBox(height: 14),
                _AuthField(
                  label: 'Confirm new password',
                  hint: 'Repeat your new password',
                  icon: Icons.verified_user_outlined,
                  obscureText: true,
                  controller: _confirmController,
                ),
                const SizedBox(height: 22),
                _ResetButton(
                  label: 'Change password',
                  loading: _loading,
                  onPressed: _resetPassword,
                ),
              ],
              Center(
                child: TextButton(
                  onPressed: _loading ? null : _requestCode,
                  child: const AppText('Send code again', localize: true),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ResetButton extends StatelessWidget {
  const _ResetButton({
    required this.label,
    required this.loading,
    required this.onPressed,
  });

  final String label;
  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: loading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: _orange,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(53),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        child: loading
            ? const CircularProgressIndicator(color: Colors.white)
            : AppText(label),
      ),
    );
  }
}
