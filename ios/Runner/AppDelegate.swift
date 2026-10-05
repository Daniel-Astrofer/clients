import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    // iOS has no public FLAG_SECURE equivalent. Channel is a no-op so the
    // Flutter SecureScreenGuard does not throw MissingPluginException.
    // Seed UIs still auto-hide on background via SecureSeedVisibility.
    let controller = window?.rootViewController as? FlutterViewController
    if let controller = controller {
      FlutterMethodChannel(
        name: "com.kerosene.app/secure_screen",
        binaryMessenger: controller.binaryMessenger
      ).setMethodCallHandler { call, result in
        if call.method == "setSecure" {
          result(nil)
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
