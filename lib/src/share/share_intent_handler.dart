import 'package:flutter/services.dart';

/// Receives text shared into the app from Android's share sheet (§7 screen 3).
class ShareIntentHandler {
  static const MethodChannel _channel = MethodChannel('app.cookbook/share');

  /// Text the app was launched with (cold start via share), or null.
  static Future<String?> getInitialSharedText() async {
    try {
      return await _channel.invokeMethod<String>('getInitialSharedText');
    } on MissingPluginException {
      return null; // non-Android platforms and tests
    }
  }

  /// Text shared while the app is already running.
  static void listen(void Function(String) onSharedText) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'sharedText' && call.arguments is String) {
        onSharedText(call.arguments as String);
      }
    });
  }
}
