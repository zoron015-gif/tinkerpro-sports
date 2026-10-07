import 'package:flutter/material.dart';

import 'app_localization.dart';

class AppText extends Text {
  const AppText(
    super.data, {
    super.key,
    this.localize = true,
    super.style,
    super.strutStyle,
    super.textAlign,
    super.textDirection,
    super.locale,
    super.softWrap,
    super.overflow,
    super.textScaler,
    super.maxLines,
    super.semanticsLabel,
    super.semanticsIdentifier,
    super.textWidthBasis,
    super.textHeightBehavior,
    super.selectionColor,
  });

  const AppText.rich(
    super.textSpan, {
    super.key,
    this.localize = true,
    super.style,
    super.strutStyle,
    super.textAlign,
    super.textDirection,
    super.locale,
    super.softWrap,
    super.overflow,
    super.textScaler,
    super.maxLines,
    super.semanticsLabel,
    super.semanticsIdentifier,
    super.textWidthBasis,
    super.textHeightBehavior,
    super.selectionColor,
  }) : super.rich();

  final bool localize;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.maybeLocaleOf(context);
    final languageCode =
        locale?.languageCode ??
        WidgetsBinding.instance.platformDispatcher.locale.languageCode;

    final plainText = data;
    if (plainText != null) {
      return Text(
        localize
            ? appLanguageText(plainText, plainText, languageCode: languageCode)
            : plainText,
        style: style,
        strutStyle: strutStyle,
        textAlign: textAlign,
        textDirection: textDirection,
        locale: locale,
        softWrap: softWrap,
        overflow: overflow,
        textScaler: textScaler,
        maxLines: maxLines,
        semanticsLabel: semanticsLabel == null
            ? null
            : localize
            ? appLanguageText(
                semanticsLabel!,
                semanticsLabel!,
                languageCode: languageCode,
              )
            : semanticsLabel,
        semanticsIdentifier: semanticsIdentifier,
        textWidthBasis: textWidthBasis,
        textHeightBehavior: textHeightBehavior,
        selectionColor: selectionColor,
      ).build(context);
    }

    return Text.rich(
      localize ? _localizeSpan(textSpan!, languageCode) : textSpan!,
      style: style,
      strutStyle: strutStyle,
      textAlign: textAlign,
      textDirection: textDirection,
      locale: locale,
      softWrap: softWrap,
      overflow: overflow,
      textScaler: textScaler,
      maxLines: maxLines,
      semanticsLabel: semanticsLabel == null
          ? null
          : localize
          ? appLanguageText(
              semanticsLabel!,
              semanticsLabel!,
              languageCode: languageCode,
            )
          : semanticsLabel,
      semanticsIdentifier: semanticsIdentifier,
      textWidthBasis: textWidthBasis,
      textHeightBehavior: textHeightBehavior,
      selectionColor: selectionColor,
    ).build(context);
  }
}

InlineSpan _localizeSpan(InlineSpan span, String languageCode) {
  if (span is! TextSpan) return span;
  final spanText = span.text;
  return TextSpan(
    text: spanText == null
        ? null
        : appLanguageText(spanText, spanText, languageCode: languageCode),
    children: span.children
        ?.map((child) => _localizeSpan(child, languageCode))
        .toList(growable: false),
    style: span.style,
    recognizer: span.recognizer,
    mouseCursor: span.mouseCursor,
    onEnter: span.onEnter,
    onExit: span.onExit,
    semanticsLabel: span.semanticsLabel == null
        ? null
        : appLanguageText(
            span.semanticsLabel!,
            span.semanticsLabel!,
            languageCode: languageCode,
          ),
    locale: span.locale,
    spellOut: span.spellOut,
    semanticsIdentifier: span.semanticsIdentifier,
  );
}
