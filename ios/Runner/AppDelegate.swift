import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let reminders = RoutinaNotifications()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = reminders
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "RoutinaDeviceTimeZone") {
      FlutterMethodChannel(
        name: "routina/device_time_zone", binaryMessenger: registrar.messenger()
      ).setMethodCallHandler { call, result in
        if call.method == "identifier" {
          result(TimeZone.current.identifier)
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "RoutinaNotifications") {
      FlutterMethodChannel(
        name: "routina/notifications", binaryMessenger: registrar.messenger()
      ).setMethodCallHandler { [weak self] call, result in
        self?.reminders.handle(call, result: result)
      }
    }
  }
}

private final class RoutinaNotifications: NSObject, UNUserNotificationCenterDelegate {
  private let center = UNUserNotificationCenter.current()
  private let defaults = UserDefaults.standard
  private let prefix = "routina:"
  private let queueKey = "routina.notification.installed"
  private let quietKey = "routina.notification.quiet"

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "permission":
      center.getNotificationSettings { settings in
        let permission: String
        switch settings.authorizationStatus {
        case .notDetermined: permission = "notDetermined"
        case .denied: permission = "denied"
        default:
          permission = settings.alertSetting == .enabled ||
            settings.notificationCenterSetting == .enabled ? "authorized" : "denied"
        }
        DispatchQueue.main.async { result(permission) }
      }
    case "request":
      center.requestAuthorization(options: [.alert, .sound]) { _, error in
        DispatchQueue.main.async { result(self.failure(error)) }
      }
    case "settings":
      let value: String
      if #available(iOS 16.0, *) {
        value = UIApplication.openNotificationSettingsURLString
      } else {
        value = UIApplication.openSettingsURLString
      }
      guard let url = URL(string: value) else {
        result(FlutterError(code: "notifications", message: "Settings unavailable", details: nil))
        return
      }
      UIApplication.shared.open(url) { opened in
        result(opened ? nil : FlutterError(
          code: "notifications", message: "Settings unavailable", details: nil
        ))
      }
    case "sync":
      guard let payload = call.arguments as? [String: Any],
            let rows = payload["reminders"] as? [[String: Any]] else {
        result(FlutterError(code: "notifications", message: "Invalid reminder queue", details: nil))
        return
      }
      defaults.set(payload["quiet"] as? [String: Any], forKey: quietKey)
      synchronize(rows, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func failure(_ error: Error?) -> FlutterError? {
    error.map { FlutterError(code: "notifications", message: $0.localizedDescription, details: nil) }
  }

  private func synchronize(_ rows: [[String: Any]], result: @escaping FlutterResult) {
    center.getPendingNotificationRequests { pending in
      DispatchQueue.main.async {
        let previous = self.defaults.dictionary(forKey: self.queueKey) ?? [:]
        let now = Date()
        let requests = Dictionary(uniqueKeysWithValues: pending.map { ($0.identifier, $0) })
        var installed: [String: NSNumber] = [:]
        var needed = Set<String>()
        var additions: [(UNNotificationRequest, NSNumber)] = []
        for row in rows.prefix(60) {
          guard let id = row["id"] as? String, let at = row["at"] as? NSNumber,
                let expiry = row["expires"] as? NSNumber,
                let title = row["title"] as? String, let body = row["body"] as? String,
                let kind = row["kind"] as? String else { continue }
          guard Date(timeIntervalSince1970: expiry.doubleValue / 1000) > now else { continue }
          let identifier = self.prefix + id
          needed.insert(identifier)
          let date = Date(timeIntervalSince1970: (at.doubleValue / 1000).rounded(.up))
          let existing = requests[identifier]
          let sameTime = existing?.content.userInfo["at"] as? NSNumber == at
          let zone = row["deviceTime"] as? Bool == true ? TimeZone.current.identifier : ""
          if sameTime && existing?.content.title == title && existing?.content.body == body &&
            existing?.content.userInfo["deviceZone"] as? String == zone &&
            existing?.content.userInfo["expires"] as? NSNumber == expiry {
            installed[identifier] = at
            continue
          }
          let alreadyAccepted = previous[identifier] as? NSNumber == at
          if date <= now && (alreadyAccepted || row["catchUp"] as? Bool != true) {
            if existing != nil {
              self.center.removePendingNotificationRequests(withIdentifiers: [identifier])
            }
            if alreadyAccepted { installed[identifier] = at }
            continue
          }
          if let old = previous[identifier] as? NSNumber, old != at {
            self.center.removeDeliveredNotifications(withIdentifiers: [identifier])
          }
          let content = UNMutableNotificationContent()
          content.title = title
          content.body = body
          content.sound = .default
          content.userInfo = [
            "at": at, "kind": kind, "expires": expiry,
            "deviceZone": zone
          ]
          var calendar = Calendar(identifier: .gregorian)
          calendar.timeZone = TimeZone(secondsFromGMT: 0)!
          let trigger: UNNotificationTrigger
          if date <= now {
            trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
          } else {
            let components = calendar.dateComponents(
              [.calendar, .timeZone, .year, .month, .day, .hour, .minute, .second], from: date
            )
            trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
          }
          additions.append((UNNotificationRequest(identifier: identifier, content: content, trigger: trigger), at))
        }
        let obsolete = Set(requests.keys).union(previous.keys).filter {
          $0.hasPrefix(self.prefix) && !needed.contains($0)
        }
        self.center.removePendingNotificationRequests(withIdentifiers: Array(obsolete))
        self.center.removeDeliveredNotifications(withIdentifiers: Array(obsolete))
        var issue: Error?
        let group = DispatchGroup()
        for (request, at) in additions {
          group.enter()
          self.center.add(request) { error in
            DispatchQueue.main.async {
              if let error = error {
                issue = error
              } else {
                installed[request.identifier] = at
              }
              group.leave()
            }
          }
        }
        group.notify(queue: .main) {
          self.defaults.set(installed, forKey: self.queueKey)
          result(self.failure(issue))
        }
      }
    }
  }

  private func quietNow(_ kind: String) -> Bool {
    guard let quiet = defaults.dictionary(forKey: quietKey),
          let start = quiet["start"] as? Int, let end = quiet["end"] as? Int,
          let exceptions = quiet["exceptions"] as? [String],
          !exceptions.contains(kind), start != end else { return false }
    let parts = Calendar.current.dateComponents([.hour, .minute], from: Date())
    let minutes = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    return start < end ? minutes >= start && minutes < end : minutes >= start || minutes < end
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter, willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    let data = notification.request.content.userInfo
    let zone = data["deviceZone"] as? String ?? ""
    let expired = (data["expires"] as? NSNumber).map {
      Date(timeIntervalSince1970: $0.doubleValue / 1000) <= Date()
    } ?? false
    if expired || (!zone.isEmpty && zone != TimeZone.current.identifier) ||
      quietNow(data["kind"] as? String ?? "") {
      completionHandler([])
    } else if #available(iOS 14, *) {
      completionHandler([.banner, .list, .sound])
    } else {
      completionHandler([.alert, .sound])
    }
  }
}
