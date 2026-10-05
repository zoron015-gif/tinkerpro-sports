import 'package:flutter/material.dart';
import 'package:myapp/auth_api.dart';

import 'activity_log_page.dart';

abstract final class ActivityLogRoutes {
  static Route<void> open({AuthApi? api, bool isMerchant = false}) =>
      MaterialPageRoute<void>(
        builder: (_) => ActivityLogPage(api: api, isMerchant: isMerchant),
      );
}
