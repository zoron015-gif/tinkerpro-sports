import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/input_formatters.dart';

void main() {
  group('PhilippineMobilePhoneFormatter', () {
    const formatter = PhilippineMobilePhoneFormatter();

    test('groups a local mobile number as it is entered', () {
      final result = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(
          text: '09171234567',
          selection: TextSelection.collapsed(offset: 11),
        ),
      );

      expect(result.text, '0917 123 4567');
      expect(result.selection.baseOffset, result.text.length);
    });

    test('accepts and groups the +63 international prefix', () {
      final result = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(
          text: '+639171234567',
          selection: TextSelection.collapsed(offset: 13),
        ),
      );

      expect(result.text, '+63 917 123 4567');
      expect(result.selection.baseOffset, result.text.length);
    });

    test('removes non-phone characters and caps local input length', () {
      final result = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(
          text: '09a1712345678',
          selection: TextSelection.collapsed(offset: 13),
        ),
      );

      expect(result.text, '0917 123 4567');
    });
  });
}
