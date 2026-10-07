import 'package:flutter/material.dart';

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
          SnackBar(content: AppText('Could not save your settings: $error', localize: true)),
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
              title: AppText(_text('Dark mode', 'Madilim na tema', languageCode)),
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
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final palette in AppPalette.values)
                    _PaletteChoice(
                      palette: palette,
                      selected: palette == preferences.palette,
                      onTap: () => _update(
                        context,
                        () => preferences.update(palette: palette),
                      ),
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
                    label: AppText(_text('Default', 'Karaniwan', languageCode)),
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
                _update(context, () => preferences.update(languageCode: value));
              },
              child: Column(
                children: [
                  for (var index = 0;
                      index < AppLanguage.values.length;
                      index++) ...[
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
}

class _LanguageChoice extends StatelessWidget {
  const _LanguageChoice({required this.language});

  final AppLanguage language;

  @override
  Widget build(BuildContext context) => RadioListTile<String>(
    key: ValueKey('app-settings-language-${language.englishName.toLowerCase()}'),
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
