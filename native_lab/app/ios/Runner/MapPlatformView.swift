import Flutter
import MapKit
import UIKit

/// PlatformView 工厂：Flutter 每嵌一个 viewType=native_view 的视图，就调一次 create。
/// 对照 L1–L5 的 register(messenger:)：那是一条应用级 channel；这里是"按需产出视图实例"。
final class MapViewFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger
  init(messenger: FlutterBinaryMessenger) { self.messenger = messenger }

  // 创建参数用标准消息 codec 解码——必须和 Dart 侧 StandardMessageCodec 对齐。
  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }

  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64,
              arguments args: Any?) -> FlutterPlatformView {
    MapPlatformView(frame: frame, viewId: viewId, args: args, messenger: messenger)
  }
}

/// 单个嵌入的地图实例：持有 MKMapView + 一条【本实例专属】方法通道。
final class MapPlatformView: NSObject, FlutterPlatformView {
  private let mapView = MKMapView()
  private let initialRegion: MKCoordinateRegion

  init(frame: CGRect, viewId: Int64, args: Any?, messenger: FlutterBinaryMessenger) {
    // 读创建参数（Dart 传来的初始区域）。数字过 codec 是 NSNumber → as? Double 取。
    let dict = args as? [String: Any]
    let lat = dict?["lat"] as? Double ?? 31.2304
    let lng = dict?["lng"] as? Double ?? 121.4737
    let span = dict?["span"] as? Double ?? 0.2
    initialRegion = MKCoordinateRegion(
      center: CLLocationCoordinate2D(latitude: lat, longitude: lng),
      span: MKCoordinateSpan(latitudeDelta: span, longitudeDelta: span))
    super.init()
    mapView.frame = frame
    mapView.setRegion(initialRegion, animated: false)

    // 每实例一条通道：名字带 viewId，页面里多个视图各走各的（对照应用级单例 channel）。
    let channel = FlutterMethodChannel(
      name: "com.wenbo.native_lab/native_view_\(viewId)", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { return }
      switch call.method {
      case "setMapType":
        // 标准 ↔ 卫星（对照 Dart 的 setMapType('standard'|'satellite')）。
        self.mapView.mapType = (call.arguments as? String) == "satellite" ? .satellite : .standard
        result(nil)
      case "resetRegion":
        self.mapView.setRegion(self.initialRegion, animated: true)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  // FlutterPlatformView 协议：把要嵌进 Flutter 的 UIView 交出去。
  func view() -> UIView { mapView }
}
