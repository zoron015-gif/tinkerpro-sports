import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/merchant_business_status.dart';

void main() {
  test('merchant-disabled fields mark a venue unavailable', () {
    expect(isMerchantBusinessDisabled({'enabled': false}), isTrue);
    expect(isMerchantBusinessDisabled({'enabled': 0}), isTrue);
    expect(isMerchantBusinessDisabled({'businessEnabled': 'false'}), isTrue);
    expect(
      isMerchantBusinessDisabled({'enabled': true, 'businessEnabled': false}),
      isTrue,
    );
    expect(
      isMerchantBusinessDisabled({
        'business': {'is_enabled': 0},
      }),
      isTrue,
    );
    expect(isMerchantBusinessDisabled({'enabled': true}), isFalse);
    expect(isMerchantBusinessDisabled({}), isFalse);
  });
}
