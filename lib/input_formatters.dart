import 'package:flutter/services.dart';

class PhilippineMobilePhoneFormatter extends TextInputFormatter {
  const PhilippineMobilePhoneFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final rawText = newValue.text;
    final isInternational = rawText.trimLeft().startsWith('+');
    if (isInternational && !rawText.trimLeft().startsWith('+63')) {
      return newValue;
    }
    var digits = rawText.replaceAll(RegExp(r'\D'), '');

    if (isInternational && digits.startsWith('63')) {
      digits = digits.substring(2);
      if (digits.startsWith('0')) digits = digits.substring(1);
      if (digits.length > 10) digits = digits.substring(0, 10);
    } else if (digits.length > 11) {
      digits = digits.substring(0, 11);
    }

    final cursor = newValue.selection.baseOffset.clamp(0, rawText.length);
    var digitsBeforeCursor = rawText
        .substring(0, cursor)
        .replaceAll(RegExp(r'\D'), '')
        .length;
    if (isInternational && rawText.substring(0, cursor).startsWith('+63')) {
      digitsBeforeCursor = (digitsBeforeCursor - 2)
          .clamp(0, digits.length)
          .toInt();
      final digitsBeforePrefix = rawText
          .substring(0, cursor)
          .replaceAll(RegExp(r'\D'), '');
      if (digitsBeforePrefix.startsWith('630')) {
        digitsBeforeCursor = (digitsBeforeCursor - 1)
            .clamp(0, digits.length)
            .toInt();
      }
    } else {
      digitsBeforeCursor = digitsBeforeCursor.clamp(0, digits.length).toInt();
    }

    final formatted = _format(digits, international: isInternational);
    var selectionOffset = digitsBeforeCursor;
    if (isInternational) {
      selectionOffset += 4;
      if (digitsBeforeCursor > 3) selectionOffset++;
      if (digitsBeforeCursor > 6) selectionOffset++;
    } else {
      if (digitsBeforeCursor > 4) selectionOffset++;
      if (digitsBeforeCursor > 7) selectionOffset++;
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(
        offset: selectionOffset.clamp(0, formatted.length).toInt(),
      ),
    );
  }

  String _format(String digits, {required bool international}) {
    if (international) {
      final first = digits.substring(0, digits.length.clamp(0, 3).toInt());
      final second = digits.length > 3
          ? digits.substring(3, digits.length.clamp(3, 6).toInt())
          : '';
      final third = digits.length > 6 ? digits.substring(6) : '';
      return '+63 $first'
          '${second.isEmpty ? '' : ' $second'}'
          '${third.isEmpty ? '' : ' $third'}';
    }

    final first = digits.substring(0, digits.length.clamp(0, 4).toInt());
    final second = digits.length > 4
        ? digits.substring(4, digits.length.clamp(4, 7).toInt())
        : '';
    final third = digits.length > 7 ? digits.substring(7) : '';
    return '$first'
        '${second.isEmpty ? '' : ' $second'}'
        '${third.isEmpty ? '' : ' $third'}';
  }
}
