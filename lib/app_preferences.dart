import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_localization.dart';
export 'app_localization.dart';
export 'app_text.dart';

class AppPreferences extends ChangeNotifier {
  AppPreferences._();

  static final instance = AppPreferences._();
  static const _storageKeyPrefix = 'app_preferences_';

  bool _darkMode = false;
  AppPalette _palette = AppPalette.orange;
  Color? _customAccentColor;
  double _textScale = 1;
  String _languageCode = 'en';
  String? _activeAccount;
  String? _loadedAccount;
  bool _hasLoaded = false;
  Future<void> _loadQueue = Future<void>.value();

  bool get darkMode => _darkMode;
  AppPalette get palette => _palette;
  Color? get customAccentColor => _customAccentColor;
  Color get accentColor => _customAccentColor ?? _palette.color;
  double get textScale => _textScale;
  String get languageCode => _languageCode;

  Future<void> load({String? accountEmail}) {
    final account = _normalizeAccount(accountEmail);
    final operation = _loadQueue.then<void>(
      (_) => _loadAccount(account),
      onError: (Object error) => _loadAccount(account),
    );
    _loadQueue = operation;
    return operation;
  }

  Future<void> _loadAccount(String? account) async {
    if (_hasLoaded && _loadedAccount == account) return;
    _activeAccount = account;
    _resetToDefaults();
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString(_storageKeyFor(account));
    if (encoded == null) {
      _loadedAccount = account;
      _hasLoaded = true;
      notifyListeners();
      return;
    }

    final value = jsonDecode(encoded);
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Saved app preferences are invalid.');
    }
    _darkMode = value['darkMode'] == true;
    _palette = AppPalette.fromKey(value['palette'] as String?);
    final customAccentColor = value['customAccentColor'];
    _customAccentColor = customAccentColor is int
        ? Color(customAccentColor)
        : null;
    _textScale = switch (value['textScale']) {
      0.9 => .9,
      1.1 => 1.1,
      1.2 => 1.2,
      _ => 1,
    };
    _languageCode = AppLanguage.fromCode(value['languageCode'] as String?).code;
    _loadedAccount = account;
    _hasLoaded = true;
    notifyListeners();
  }

  Future<void> update({
    bool? darkMode,
    AppPalette? palette,
    Color? customAccentColor,
    double? textScale,
    String? languageCode,
  }) async {
    if (languageCode != null &&
        !AppLanguage.values.any((language) => language.code == languageCode)) {
      throw ArgumentError.value(
        languageCode,
        'languageCode',
        'Unsupported app language.',
      );
    }
    final previous = (
      darkMode: _darkMode,
      palette: _palette,
      customAccentColor: _customAccentColor,
      textScale: _textScale,
      languageCode: _languageCode,
    );
    final account = _activeAccount;
    final nextCustomAccentColor = customAccentColor ??
        (palette == null ? _customAccentColor : null);
    final encoded = jsonEncode({
      'darkMode': darkMode ?? _darkMode,
      'palette': (palette ?? _palette).key,
      if (nextCustomAccentColor != null)
        'customAccentColor': nextCustomAccentColor.toARGB32(),
      'textScale': textScale ?? _textScale,
      'languageCode': languageCode ?? _languageCode,
    });
    _darkMode = darkMode ?? _darkMode;
    _palette = palette ?? _palette;
    _customAccentColor = nextCustomAccentColor;
    _textScale = textScale ?? _textScale;
    _languageCode = languageCode ?? _languageCode;
    notifyListeners();

    try {
      final preferences = await SharedPreferences.getInstance();
      final saved = await preferences.setString(
        _storageKeyFor(account),
        encoded,
      );
      if (!saved) {
        throw Exception('Your settings could not be saved on this device.');
      }
    } on Exception {
      if (_activeAccount == account) {
        _darkMode = previous.darkMode;
        _palette = previous.palette;
        _customAccentColor = previous.customAccentColor;
        _textScale = previous.textScale;
        _languageCode = previous.languageCode;
        notifyListeners();
      }
      rethrow;
    }
  }

  void _resetToDefaults() {
    _darkMode = false;
    _palette = AppPalette.orange;
    _customAccentColor = null;
    _textScale = 1;
    _languageCode = 'en';
  }

  static String? _normalizeAccount(String? accountEmail) {
    final account = accountEmail?.trim().toLowerCase();
    return account == null || account.isEmpty ? null : account;
  }

  static String _storageKeyFor(String? account) {
    if (account == null) return '${_storageKeyPrefix}guest';
    final encodedAccount = base64Url
        .encode(utf8.encode(account))
        .replaceAll('=', '');
    return '$_storageKeyPrefix$encodedAccount';
  }
}
