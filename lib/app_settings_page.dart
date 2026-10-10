import 'package:flutter/material.dart';

import 'app_design_system.dart';
import 'app_preferences.dart';

class AppSettingsPage extends StatelessWidget {
  const AppSettingsPage({super.key});

  String _text(String english, String filipino, String languageCode) =>
      appLanguageText(english, filipino, languageCode: languageCode);

  Future<void> _update(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } on Exception catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: AppText(
              'Could not save your settings: $error',
              localize: true,
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: AppPreferences.instance,
    builder: (context, _) {
      final preferences = AppPreferences.instance;
      final languageCode = preferences.languageCode;
      final theme = Theme.of(context);
      final colors = theme.colorScheme;

      return Scaffold(
        appBar: AppBar(
          title: AppText(_text('Settings', 'Mga Setting', languageCode)),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            AppText(
              _text(
                'Make the app feel like yours.',
                'Iangkop ang app sa iyo.',
                languageCode,
              ),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            Card(
              child: SwitchListTile.adaptive(
                key: const ValueKey('app-settings-dark-mode'),
                value: preferences.darkMode,
                onChanged: (value) =>
                    _update(context, () => preferences.update(darkMode: value)),
                secondary: Icon(
                  preferences.darkMode
                      ? Icons.dark_mode_rounded
                      : Icons.light_mode_rounded,
                  color: colors.primary,
                ),
                title: AppText(
                  _text('Dark mode', 'Madilim na tema', languageCode),
                ),
                subtitle: AppText(
                  _text(
                    'Use a darker look that is easier on the eyes at night.',
                    'Gumamit ng mas madilim na itsura na mas komportable sa gabi.',
                    languageCode,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            _SectionHeading(
              title: _text('Theme color', 'Kulay ng tema', languageCode),
              subtitle: _text(
                'Choose an accent color for app controls.',
                'Pumili ng kulay para sa mga kontrol ng app.',
                languageCode,
              ),
            ),
            const SizedBox(height: 6),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 18,
                ),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final palette in AppPalette.values)
                      _PaletteChoice(
                        palette: palette,
                        selected:
                            preferences.customAccentColor == null &&
                            palette == preferences.palette,
                        onTap: () => _update(
                          context,
                          () => preferences.update(palette: palette),
                        ),
                      ),
                    _CustomColorChoice(
                      color: preferences.accentColor,
                      selected: preferences.customAccentColor != null,
                      onTap: () => _chooseCustomColor(context, preferences),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            _SectionHeading(
              title: _text('Text size', 'Laki ng teksto', languageCode),
              subtitle: _text(
                'Adjust text throughout the app.',
                'Ayusin ang laki ng teksto sa buong app.',
                languageCode,
              ),
            ),
            const SizedBox(height: 6),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: SegmentedButton<double>(
                  key: const ValueKey('app-settings-text-size'),
                  segments: [
                    ButtonSegment(
                      value: .9,
                      label: AppText(_text('Small', 'Maliit', languageCode)),
                    ),
                    ButtonSegment(
                      value: 1,
                      label: AppText(
                        _text('Default', 'Karaniwan', languageCode),
                      ),
                    ),
                    ButtonSegment(
                      value: 1.1,
                      label: AppText(_text('Large', 'Malaki', languageCode)),
                    ),
                    ButtonSegment(
                      value: 1.2,
                      label: AppText(_text('XL', 'XL', languageCode)),
                    ),
                  ],
                  selected: {preferences.textScale},
                  showSelectedIcon: false,
                  onSelectionChanged: (selection) => _update(
                    context,
                    () => preferences.update(textScale: selection.single),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            _SectionHeading(
              title: _text('Language', 'Wika', languageCode),
              subtitle: _text(
                'Choose your preferred app language.',
                'Piliin ang wikang gagamitin sa app.',
                languageCode,
              ),
            ),
            const SizedBox(height: 6),
            Card(
              child: RadioGroup<String>(
                groupValue: languageCode,
                onChanged: (value) {
                  if (value == null) return;
                  _update(
                    context,
                    () => preferences.update(languageCode: value),
                  );
                },
                child: Column(
                  children: [
                    for (
                      var index = 0;
                      index < AppLanguage.values.length;
                      index++
                    ) ...[
                      if (index > 0)
                        const Divider(height: 1, indent: 16, endIndent: 16),
                      _LanguageChoice(language: AppLanguage.values[index]),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    },
  );

  Future<void> _chooseCustomColor(
    BuildContext context,
    AppPreferences preferences,
  ) async {
    final selectedColor = await showDialog<Color>(
      context: context,
      builder: (_) =>
          _CustomAccentColorDialog(initialColor: preferences.accentColor),
    );
    if (selectedColor == null || !context.mounted) return;
    await _update(
      context,
      () => preferences.update(customAccentColor: selectedColor),
    );
  }
}

class _LanguageChoice extends StatelessWidget {
  const _LanguageChoice({required this.language});

  final AppLanguage language;

  @override
  Widget build(BuildContext context) => RadioListTile<String>(
    key: ValueKey(
      'app-settings-language-${language.englishName.toLowerCase()}',
    ),
    value: language.code,
    title: AppText(language.nativeName),
    subtitle: AppText(language.englishName),
  );
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      AppText(
        title,
        style: Theme.of(context).textTheme.titleMedium
            ?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 6),
      AppText(
        subtitle,
        style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    ],
  );
}

class _PaletteChoice extends StatelessWidget {
  const _PaletteChoice({
    required this.palette,
    required this.selected,
    required this.onTap,
  });

  final AppPalette palette;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: '${palette.key} theme color',
    child: InkResponse(
      key: ValueKey('app-settings-color-${palette.key}'),
      onTap: onTap,
      radius: 30,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: palette.color,
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.onSurface
                : Colors.transparent,
            width: 2,
          ),
        ),
        child: selected
            ? const Icon(Icons.check_rounded, color: Colors.white, size: 22)
            : null,
      ),
    ),
  );
}

class _CustomColorChoice extends StatelessWidget {
  const _CustomColorChoice({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: 'Custom theme color',
    child: InkResponse(
      key: const ValueKey('app-settings-color-custom'),
      onTap: onTap,
      radius: 30,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.onSurface
                : Colors.transparent,
            width: 2,
          ),
        ),
        child: Icon(
          selected ? Icons.check_rounded : Icons.colorize_rounded,
          color: AppColors.contrastingForeground(color),
          size: 22,
        ),
      ),
    ),
  );
}

class _CustomAccentColorDialog extends StatefulWidget {
  const _CustomAccentColorDialog({required this.initialColor});

  final Color initialColor;

  @override
  State<_CustomAccentColorDialog> createState() =>
      _CustomAccentColorDialogState();
}

class _CustomAccentColorDialogState extends State<_CustomAccentColorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _hexController;
  late HSVColor _hsvColor;

  Color get _color => _hsvColor.toColor();

  @override
  void initState() {
    super.initState();
    _hsvColor = HSVColor.fromColor(widget.initialColor);
    _hexController = TextEditingController(text: _hexFor(widget.initialColor));
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  void _updateFromHex(String value) {
    final color = _parseHex(value);
    if (color == null) return;
    setState(() => _hsvColor = HSVColor.fromColor(color));
  }

  void _updateFromSlider(HSVColor color) {
    setState(() {
      _hsvColor = color;
      final hex = _hexFor(_color);
      _hexController.value = TextEditingValue(
        text: hex,
        selection: TextSelection.collapsed(offset: hex.length),
      );
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const AppText('Custom theme color'),
    content: SizedBox(
      width: 360,
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              key: const ValueKey('app-settings-custom-color-preview'),
              width: double.infinity,
              height: 46,
              decoration: BoxDecoration(
                color: _color,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey('app-settings-custom-color-hex'),
              controller: _hexController,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Hex color',
                hintText: '#FF8200',
                prefixIcon: Icon(Icons.tag_rounded),
              ),
              onChanged: _updateFromHex,
              validator: (value) => _parseHex(value ?? '') == null
                  ? 'Enter a valid 6-digit hex color.'
                  : null,
            ),
            const SizedBox(height: 12),
            _ColorSlider(
              label: 'Hue',
              value: _hsvColor.hue,
              max: 360,
              color: _color,
              onChanged: (value) => _updateFromSlider(_hsvColor.withHue(value)),
            ),
            _ColorSlider(
              label: 'Saturation',
              value: _hsvColor.saturation,
              max: 1,
              color: _color,
              onChanged: (value) =>
                  _updateFromSlider(_hsvColor.withSaturation(value)),
            ),
            _ColorSlider(
              label: 'Brightness',
              value: _hsvColor.value,
              max: 1,
              color: _color,
              onChanged: (value) =>
                  _updateFromSlider(_hsvColor.withValue(value)),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const AppText('Cancel'),
      ),
      FilledButton(
        key: const ValueKey('app-settings-custom-color-apply'),
        onPressed: () {
          if (!_formKey.currentState!.validate()) return;
          Navigator.of(context).pop(_parseHex(_hexController.text));
        },
        child: const AppText('Use color'),
      ),
    ],
  );

  static Color? _parseHex(String value) {
    final hex = value.trim().replaceFirst('#', '');
    if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(hex)) return null;
    return Color(0xFF000000 | int.parse(hex, radix: 16));
  }

  static String _hexFor(Color color) =>
      '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
}

class _ColorSlider extends StatelessWidget {
  const _ColorSlider({
    required this.label,
    required this.value,
    required this.max,
    required this.color,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double max;
  final Color color;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      SizedBox(width: 84, child: AppText(label)),
      Expanded(
        child: Slider(
          value: value.clamp(0, max),
          max: max,
          activeColor: color,
          onChanged: onChanged,
        ),
      ),
    ],
  );
}
