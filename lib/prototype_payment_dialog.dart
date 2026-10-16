import 'package:flutter/material.dart';

import 'app_text.dart';

class PrototypePaymentDialog extends StatefulWidget {
  const PrototypePaymentDialog({super.key, required this.amount});

  final double amount;

  @override
  State<PrototypePaymentDialog> createState() => _PrototypePaymentDialogState();
}

class _PrototypePaymentDialogState extends State<PrototypePaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _cardholder = TextEditingController();
  final _cardNumber = TextEditingController();
  final _expiry = TextEditingController();
  final _securityCode = TextEditingController();
  final _mobileNumber = TextEditingController();
  final _verificationCode = TextEditingController();
  String _provider = 'gcash';

  bool get _usesCard => _provider == 'card';

  String get _providerLabel => switch (_provider) {
    'gcash' => 'GCash',
    'maya' => 'Maya',
    'atome' => 'Atome',
    _ => 'Card',
  };

  @override
  void dispose() {
    _cardholder.dispose();
    _cardNumber.dispose();
    _expiry.dispose();
    _securityCode.dispose();
    _mobileNumber.dispose();
    _verificationCode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const AppText('Prototype payment', localize: true),
    content: SingleChildScrollView(
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppText(
              'Test amount: \u{20B1} ${widget.amount.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const AppText(
              'Demo only: no real payment is made. Do not enter real payment details, PINs, or passwords. Demo details stay on this device.',
              localize: true,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: const ValueKey('prototype-payment-provider'),
              initialValue: _provider,
              decoration: const InputDecoration(
                labelText: 'Choose demo payment method',
              ),
              items: const [
                DropdownMenuItem(value: 'gcash', child: Text('GCash')),
                DropdownMenuItem(value: 'maya', child: Text('Maya')),
                DropdownMenuItem(value: 'atome', child: Text('Atome')),
                DropdownMenuItem(
                  value: 'card',
                  child: Text('Credit/debit card'),
                ),
              ],
              onChanged: (provider) {
                if (provider != null) setState(() => _provider = provider);
              },
            ),
            const SizedBox(height: 12),
            if (_usesCard) ...[
              const AppText(
                'Use the sample card only: 4242 4242 4242 4242',
                localize: true,
              ),
              const SizedBox(height: 8),
              TextFormField(
                key: const ValueKey('prototype-payment-cardholder'),
                controller: _cardholder,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Demo cardholder name',
                ),
                validator: (value) =>
                    _usesCard && (value == null || value.trim().isEmpty)
                    ? 'Enter a demo name.'
                    : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                key: const ValueKey('prototype-payment-card-number'),
                controller: _cardNumber,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Demo card number',
                ),
                validator: (value) {
                  if (!_usesCard) return null;
                  final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
                  return digits == '4242424242424242'
                      ? null
                      : 'Use the sample card number shown above.';
                },
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      key: const ValueKey('prototype-payment-expiry'),
                      controller: _expiry,
                      keyboardType: TextInputType.datetime,
                      decoration: const InputDecoration(labelText: 'MM/YY'),
                      validator: (value) =>
                          !_usesCard ||
                              RegExp(r'^(0[1-9]|1[0-2])\/\d{2}$')
                                  .hasMatch(value?.trim() ?? '')
                          ? null
                          : 'Use MM/YY.',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      key: const ValueKey('prototype-payment-security-code'),
                      controller: _securityCode,
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Demo CVC'),
                      validator: (value) =>
                          !_usesCard ||
                              RegExp(r'^\d{3}$').hasMatch(value?.trim() ?? '')
                          ? null
                          : 'Enter 3 digits.',
                    ),
                  ),
                ],
              ),
            ] else ...[
              TextFormField(
                key: const ValueKey('prototype-payment-mobile'),
                controller: _mobileNumber,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Demo mobile number',
                  hintText: '09171234567',
                ),
                validator: (value) {
                  if (_usesCard) return null;
                  return RegExp(r'^09\d{9}$').hasMatch(value?.trim() ?? '')
                      ? null
                      : 'Enter the demo number 09171234567.';
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                key: const ValueKey('prototype-payment-verification-code'),
                controller: _verificationCode,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Demo verification code',
                  hintText: '123456',
                ),
                validator: (value) =>
                    _usesCard ||
                        RegExp(r'^\d{6}$').hasMatch(value?.trim() ?? '')
                    ? null
                    : 'Enter the demo code 123456.',
              ),
              const SizedBox(height: 6),
              const AppText(
                'Demo number: 09171234567 · Demo code: 123456',
                localize: true,
                style: TextStyle(fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(null),
        child: const AppText('Cancel', localize: true),
      ),
      FilledButton(
        key: const ValueKey('prototype-payment-confirm'),
        onPressed: () {
          if (_formKey.currentState?.validate() == true) {
            Navigator.of(context).pop(_provider);
          }
        },
        child: AppText('Simulate $_providerLabel payment', localize: true),
      ),
    ],
  );
}
