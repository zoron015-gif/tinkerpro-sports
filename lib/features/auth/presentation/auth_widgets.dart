part of 'auth_dashboard.dart';

class _AuthModeToggle extends StatelessWidget {
  const _AuthModeToggle({required this.mode, required this.onChanged});

  final _AuthMode mode;
  final ValueChanged<_AuthMode> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('auth-mode-toggle'),
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: const Color(0xFFE9EDF4),
      borderRadius: BorderRadius.circular(13),
    ),
    child: Row(
      children: [
        _ToggleOption(
          label: appLanguageText('Sign in', 'Mag-sign in'),
          selected: mode == _AuthMode.login,
          onTap: () => onChanged(_AuthMode.login),
        ),
        _ToggleOption(
          label: appLanguageText('Register', 'Mag-register'),
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
        constraints: const BoxConstraints(minHeight: 40),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: AppText(
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
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.onNoticeTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onNoticeTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(15),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.all(10),
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
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: AppText(
                        title,
                        localize: true,
                        style: TextStyle(
                          color: selected ? Colors.white : _ink,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (onNoticeTap != null)
                      SizedBox(
                        width: 44,
                        height: 44,
                        child: IconButton(
                          tooltip: appLanguageText(
                            'About merchant tools',
                            'About merchant tools',
                          ),
                          onPressed: onNoticeTap,
                          padding: AppSpacing.buttonPadding,
                          constraints: const BoxConstraints.tightFor(
                            width: 44,
                            height: 44,
                          ),
                          visualDensity: VisualDensity.compact,
                          icon: Icon(
                            Icons.info_outline_rounded,
                            color: selected ? Colors.white70 : _muted,
                            size: 18,
                          ),
                        ),
                      ),
                  ],
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 6),
                  AppText(
                    subtitle!,
                    localize: true,
                    style: TextStyle(
                      color: selected
                          ? Colors.white.withValues(alpha: .65)
                          : _muted,
                      fontSize: 10,
                    ),
                  ),
                ],
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
    this.errorText,
    this.fieldKey,
    this.onChanged,
  });

  final String label;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffix;
  final TextEditingController? controller;
  final String? errorText;
  final Key? fieldKey;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) => Column(
    key: fieldKey,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      AppText(
        label,
        localize: true,
        style: TextStyle(
          color: _ink,
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 6),
      TextField(
        key: ValueKey('auth-field-${label.toLowerCase().replaceAll(' ', '-')}'),
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        onChanged: onChanged,
        decoration: InputDecoration(
          errorText: errorText,
          hintText: appLanguageText(hint, hint),
          prefixIcon: Icon(icon, color: _muted, size: 20),
          suffixIcon: suffix,
          prefixIconConstraints: const BoxConstraints(
            minWidth: 48,
            minHeight: 48,
          ),
          suffixIconConstraints: const BoxConstraints(
            minWidth: 48,
            minHeight: 48,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
          filled: true,
          fillColor: AppColors.surface,
          hintStyle: const TextStyle(color: Color(0xFF9CA6B5), fontSize: 13),
          labelStyle: TextStyle(
            color: _ink,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: _orange, width: 1.5),
          ),
        ),
      ),
    ],
  );
}

class _AuthCodeField extends StatefulWidget {
  const _AuthCodeField({
    required this.controller,
    required this.fieldKey,
    this.errorText,
    this.onChanged,
  });

  final TextEditingController controller;
  final Key fieldKey;
  final String? errorText;
  final ValueChanged<String>? onChanged;

  @override
  State<_AuthCodeField> createState() => _AuthCodeFieldState();
}

class _AuthCodeFieldState extends State<_AuthCodeField> {
  late final List<TextEditingController> _digitControllers;
  late final List<FocusNode> _focusNodes;

  @override
  void initState() {
    super.initState();
    _digitControllers = List.generate(6, (_) => TextEditingController());
    _focusNodes = List.generate(6, (_) => FocusNode());
    _distributeDigits(widget.controller.text);
  }

  @override
  void didUpdateWidget(covariant _AuthCodeField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _distributeDigits(widget.controller.text);
    }
  }

  @override
  void dispose() {
    for (final controller in _digitControllers) {
      controller.dispose();
    }
    for (final focusNode in _focusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  void _distributeDigits(String value, {int startAt = 0, bool notify = false}) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    final start = startAt.clamp(0, _digitControllers.length);
    for (var index = start; index < _digitControllers.length; index++) {
      _digitControllers[index].clear();
    }
    for (
      var index = 0;
      index < digits.length && start + index < _digitControllers.length;
      index++
    ) {
      _digitControllers[start + index].text = digits[index];
    }
    _syncCode(notify: notify);
  }

  void _onDigitChanged(int index, String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 1) {
      _distributeDigits(digits, startAt: index, notify: true);
      final next = index + digits.length;
      if (next < _focusNodes.length) {
        _focusNodes[next].requestFocus();
      } else {
        _focusNodes.last.unfocus();
      }
    } else {
      _digitControllers[index].text = digits;
      if (digits.isNotEmpty && index < _focusNodes.length - 1) {
        _focusNodes[index + 1].requestFocus();
      } else if (digits.isEmpty && index > 0) {
        _focusNodes[index - 1].requestFocus();
      }
      _syncCode();
    }
  }

  void _syncCode({bool notify = true}) {
    final code = _digitControllers.map((controller) => controller.text).join();
    widget.controller.value = TextEditingValue(
      text: code,
      selection: TextSelection.collapsed(offset: code.length),
    );
    if (notify) widget.onChanged?.call(code);
  }

  @override
  Widget build(BuildContext context) => Column(
    key: widget.fieldKey,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      AppText(
        'Verification code',
        localize: true,
        style: TextStyle(
          color: _ink,
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 8),
      Row(
        children: List.generate(
          _digitControllers.length,
          (index) => Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                right: index == _digitControllers.length - 1 ? 0 : 6,
              ),
              child: Semantics(
                label: 'Verification code digit ${index + 1} of 6',
                child: TextField(
                  controller: _digitControllers[index],
                  focusNode: _focusNodes[index],
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (value) => _onDigitChanged(index, value),
                  style: TextStyle(
                    color: _ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: _orange, width: 1.5),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      if (widget.errorText != null) ...[
        const SizedBox(height: 6),
        AppText(
          widget.errorText!,
          style: TextStyle(color: AppColors.errorText, fontSize: 12),
          localize: true,
        ),
      ],
    ],
  );
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Divider(color: Color(0xFFDDE2EA))),
      Padding(
        padding: EdgeInsets.symmetric(horizontal: 12),
        child: AppText(
          'OR CONTINUE WITH',
          style: TextStyle(
            color: _muted,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: .8,
          ),
          localize: true,
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
    key: const ValueKey('auth-social-button'),
    onPressed: onTap,
    style: OutlinedButton.styleFrom(
      fixedSize: const Size.fromHeight(48),
      backgroundColor: AppColors.surface,
      foregroundColor: _ink,
      side: const BorderSide(color: Color(0xFFE1E6EE)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Image.asset(
          logoAsset,
          width: 22,
          height: 22,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        ),
        const SizedBox(width: 6),
        AppText(
          label,
          style: TextStyle(
            color: _ink,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}
