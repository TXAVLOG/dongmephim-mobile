import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var secureTextField: UITextField?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Setup platform channel
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "online.dongmephim/platform",
        binaryMessenger: controller.binaryMessenger
      )
      
      channel.setMethodCallHandler { [weak self] (call, result) in
        switch call.method {
        case "getBatteryInfo":
          UIDevice.current.isBatteryMonitoringEnabled = true
          let level = Int(UIDevice.current.batteryLevel * 100)
          let state = UIDevice.current.batteryState
          let isCharging = (state == .charging || state == .full)
          result([
            "level": level >= 0 ? level : -1,
            "isCharging": isCharging
          ])
          
        case "enableSecureMode":
          self?.enableSecureMode()
          result(true)
          
        case "disableSecureMode":
          self?.disableSecureMode()
          result(true)
          
        case "changeAppIcon":
          if let args = call.arguments as? [String: Any],
             let iconName = args["iconName"] as? String {
            self?.changeAppIcon(iconName: iconName, result: result)
          } else {
            result(FlutterError(code: "INVALID_ARGS", message: "Arguments must be a dictionary with iconName key", details: nil))
          }
          
        case "set3DAudioEnabled", "setAudioOptimizeEnabled", "setAudioBoostLevel":
          result(true)
          
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func changeAppIcon(iconName: String, result: @escaping FlutterResult) {
    DispatchQueue.main.async {
      guard UIApplication.shared.supportsAlternateIcons else {
        result(FlutterError(code: "NOT_SUPPORTED", message: "iOS device/version does not support alternate icons", details: nil))
        return
      }
      
      let targetIconName: String? = (iconName == "default" || iconName.isEmpty) ? nil : "icon_" + iconName
      
      UIApplication.shared.setAlternateIconName(targetIconName) { error in
        if let error = error {
          result(FlutterError(code: "ICON_ERROR", message: error.localizedDescription, details: nil))
        } else {
          result(true)
        }
      }
    }
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  // --- Secure Mode (DRM) ---
  // Safe secure text entry helper to prevent screen capture on iOS without CALayer cycles
  private func enableSecureMode() {
    DispatchQueue.main.async { [weak self] in
      guard let self = self, let window = self.window else { return }
      
      if self.secureTextField == nil {
        let field = UITextField()
        field.isSecureTextEntry = true
        field.isUserInteractionEnabled = false
        window.addSubview(field)
        field.centerYAnchor.constraint(equalTo: window.centerYAnchor).isActive = true
        field.centerXAnchor.constraint(equalTo: window.centerXAnchor).isActive = true
        self.secureTextField = field
      }
      
      NotificationCenter.default.removeObserver(self, name: UIScreen.capturedDidChangeNotification, object: nil)
      NotificationCenter.default.addObserver(
        self,
        selector: #selector(self.screenCaptureChanged),
        name: UIScreen.capturedDidChangeNotification,
        object: nil
      )
    }
  }
  
  private func disableSecureMode() {
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      if let field = self.secureTextField {
        field.removeFromSuperview()
        self.secureTextField = nil
      }
      NotificationCenter.default.removeObserver(
        self,
        name: UIScreen.capturedDidChangeNotification,
        object: nil
      )
    }
  }
  
  @objc private func screenCaptureChanged() {
    // When screen recording starts, show a black overlay
    if UIScreen.main.isCaptured {
      let overlay = UIView(frame: window?.bounds ?? .zero)
      overlay.backgroundColor = .black
      overlay.tag = 9999
      
      let label = UILabel()
      label.text = "Ứng dụng không cho phép quay màn hình"
      label.textColor = .white
      label.font = .systemFont(ofSize: 16, weight: .medium)
      label.textAlignment = .center
      label.translatesAutoresizingMaskIntoConstraints = false
      overlay.addSubview(label)
      
      NSLayoutConstraint.activate([
        label.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
        label.centerYAnchor.constraint(equalTo: overlay.centerYAnchor),
      ])
      
      window?.addSubview(overlay)
    } else {
      window?.viewWithTag(9999)?.removeFromSuperview()
    }
  }
}
