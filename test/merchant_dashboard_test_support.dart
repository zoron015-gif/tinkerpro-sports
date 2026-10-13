import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void setMerchantDashboardSession({
  String role = 'merchant',
  String apiToken = 'merchant-token',
}) {
  SharedPreferences.setMockInitialValues({
    'session_api_token': apiToken,
    'session_role': role,
  });
  FlutterSecureStorage.setMockInitialValues({
    'session_api_token': apiToken,
  });
}
