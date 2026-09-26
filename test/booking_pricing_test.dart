import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/booking_pricing.dart';

void main() {
  group('calculateExtraPlayerCharge', () {
    test('charges for each player above the included count once', () {
      expect(
        calculateExtraPlayerCharge(
          players: 13,
          includedPlayers: 10,
          feePerExtraPlayer: 50,
        ),
        150,
      );
    });

    test('does not charge when players are within the included count', () {
      expect(
        calculateExtraPlayerCharge(
          players: 10,
          includedPlayers: 10,
          feePerExtraPlayer: 50,
        ),
        0,
      );
    });

    test('does not charge when merchant has not configured a fee', () {
      expect(
        calculateExtraPlayerCharge(
          players: 13,
          includedPlayers: 0,
          feePerExtraPlayer: 0,
        ),
        0,
      );
    });
  });
}
