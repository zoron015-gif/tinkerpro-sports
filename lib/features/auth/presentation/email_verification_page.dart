part of 'auth_dashboard.dart';

class EmailVerificationPage extends StatefulWidget {
  const EmailVerificationPage({
    super.key,
    required this.email,
    required this.service,
  });

  final String email;
  final AuthService service;

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
      _message('That code should be 6 digits. Check your email and try again.');
      return;
    }
    setState(() => _loading = true);
    try {
      final response = await widget.service.verifyEmail(
        email: widget.email,
        code: code,
      );
      if (!mounted) return;
      _message('Email verified. Your account is ready.');
      Navigator.of(context).pop(response);
    } on AuthApiException catch (error) {
      if (mounted) _message(error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    setState(() => _loading = true);
    try {
      final response = await widget.service.resendVerification(widget.email);
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
        .showSnackBar(SnackBar(content: AppText(message), backgroundColor: _navy));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _page,
      appBar: AppBar(
        backgroundColor: _page,
        foregroundColor: _navy,
        elevation: 0,
        title: const AppText(
          'Verify email',
          style: TextStyle(fontWeight: FontWeight.w900),
         localize: true,),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
            Center(
              child: Image.asset(
                'assets/tinker_logo.png',
                width: 82,
                height: 62,
              ),
            ),
            const SizedBox(height: 6),
            AppText(
              'Check your inbox',
              style: TextStyle(
                color: _ink,
                fontSize: 27,
                fontWeight: FontWeight.w900,
              ),
             localize: true,),
            const SizedBox(height: 6),
            AppText(
              'We sent a 6-digit verification code to ${widget.email}.',
              style: TextStyle(color: _muted, fontSize: 14, height: 1.45),
             localize: true,),
            const SizedBox(height: 6),
            _AuthField(
              label: 'Verification code',
              hint: '000000',
              icon: Icons.mark_email_read_outlined,
              keyboardType: TextInputType.number,
              controller: _codeController,
            ),
            const SizedBox(height: 6),
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
                    : const AppText('Verify email', localize: true),
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: TextButton(
                onPressed: _loading ? null : _resend,
                child: const AppText('Resend code', localize: true),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
