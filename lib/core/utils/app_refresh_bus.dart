import 'package:flutter/foundation.dart';

class AppRefreshBus {
  static final ValueNotifier<int> notifier = ValueNotifier<int>(0);

  static void bump() {
    notifier.value = notifier.value + 1;
  }
}
