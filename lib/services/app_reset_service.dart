// Finance Me Local
// Copyright (c) 2026 BaveSerdem. All rights reserved.
//
// This source code is licensed for personal, non-commercial use
// only. Selling, sublicensing, or commercially redistributing this
// software — or any derivative work based on it — is prohibited
// without prior written permission from the copyright holder.
//
// Full license: see LICENSE file in the repository root.

import 'package:flutter/services.dart';

class AppResetService {
  static const _channel = MethodChannel('com.financeme.local/clear_data');

  /// Error code raised when the OS accepted the call but declined to clear
  /// the data (`clearApplicationUserData()` returned `false`, typically under
  /// a device policy such as DISALLOW_APPS_CONTROL). Nothing was deleted.
  static const String refusedCode = 'clear_refused';

  /// Wipes ALL app data via Android's system-level clearAppData API
  /// and kills the app process. This call will typically never
  /// return — the process dies before a response arrives. Callers
  /// must NOT await this and then navigate/update UI afterward;
  /// treat it as fire-and-forget, since by design the app is about
  /// to disappear.
  static Future<void> clearAllAppData() async {
    final bool? cleared;
    try {
      cleared = await _channel.invokeMethod<bool>('clearAppData');
    } on PlatformException {
      // If this throws, the OS call itself failed to even start —
      // rethrow so the caller can show an error, since in that case
      // the app is NOT closing and the user needs to know deletion
      // did not happen.
      rethrow;
    }
    // A `false` return used to be silently ignored, leaving the user sure
    // their data was gone while nothing had happened (L-1). Surface it the
    // same way as a failed call.
    if (cleared != true) {
      throw PlatformException(
        code: refusedCode,
        message: 'clearApplicationUserData() returned false',
      );
    }
    // No further code here: if clearApplicationUserData() succeeded,
    // the process is killed by the OS shortly after — any code past
    // this point is not guaranteed to run.
  }
}
