import 'package:flutter/material.dart';

/// Global navigator key dùng để điều hướng và hiển thị toast
/// từ các service không có BuildContext.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
