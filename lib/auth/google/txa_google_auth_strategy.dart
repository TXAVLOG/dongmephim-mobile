import 'package:flutter/material.dart';

abstract class TxaGoogleAuthStrategy {
  /// Trả về một Map chứa idToken và accessToken, hoặc throw Exception nếu có lỗi/hủy
  Future<Map<String, String?>> authenticate(BuildContext context);
}
