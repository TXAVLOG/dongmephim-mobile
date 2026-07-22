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
          
        case "set3DAudioEnabled", "setAudioOptimizeEnabled", "setAudioBoostLevel":
          result(true)
          
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  // --- Secure Mode (DRM) ---
  // Uses the isSecureTextEntry trick to prevent screen capture/recording on iOS
  private func enableSecureMode() {
    guard let window = self.window else { return }
    
    if secureTextField == nil {
      let field = UITextField()
      field.isSecureTextEntry = true
      field.isUserInteractionEnabled = false
      window.addSubview(field)
      field.centerYAnchor.constraint(equalTo: window.centerYAnchor).isActive = true
      field.centerXAnchor.constraint(equalTo: window.centerXAnchor).isActive = true
      
      // Safe layer hierarchy manipulation
      if let windowLayer = window.layer.superlayer,
         let sublayers = field.layer.sublayers,
         let fieldSublayer = sublayers.first {
        windowLayer.addSublayer(field.layer)
        fieldSublayer.addSublayer(window.layer)
        secureTextField = field
      }
    }
    
    // Also add observer for screen recording
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(screenCaptureChanged),
      name: UIScreen.capturedDidChangeNotification,
      object: nil
    )
  }
  
  private func disableSecureMode() {
    if let field = secureTextField {
      // Safe restore of window layer
      if let sublayers = field.layer.sublayers,
         let superLayer = sublayers.first {
        field.layer.superlayer?.addSublayer(superLayer)
      }
      field.removeFromSuperview()
      secureTextField = nil
    }
    
    NotificationCenter.default.removeObserver(
      self,
      name: UIScreen.capturedDidChangeNotification,
      object: nil
    )
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
