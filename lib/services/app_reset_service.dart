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

  /// Wipes ALL app data via Android's system-level clearAppData API
  /// and kills the app process. This call will typically never
  /// return — the process dies before a response arrives. Callers
  /// must NOT await this and then navigate/update UI afterward;
  /// treat it as fire-and-forget, since by design the app is about
  /// to disappear.
  static Future<void> clearAllAppData() async {
    try {
      await _channel.invokeMethod('clearAppData');
    } on PlatformException {
      // If this throws, the OS call itself failed to even start —
      // rethrow so the caller can show an error, since in that case
      // the app is NOT closing and the user needs to know deletion
      // did not happen.
      rethrow;
    }
    // No further code here: if clearApplicationUserData() succeeded,
    // the process is killed by the OS shortly after — any code past
    // this point is not guaranteed to run.
  }
}