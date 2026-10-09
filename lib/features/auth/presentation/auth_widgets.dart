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
                          tooltip: appLanguageText('About merchant tools', 'About merchant tools'),
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
    this.maxLength,
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
  final int? maxLength;
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
        key: ValueKey(
          'auth-field-${label.toLowerCase().replaceAll(' ', '-')}',
        ),
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        maxLength: maxLength,
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
          counterText: maxLength == null ? null : '',
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
         localize: true,),
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
