import CoreImage
import Flutter
import UIKit
import Vision

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    // scontorno sul telefono con Apple Vision (iOS 17+), stesso canale della versione Android
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "TkScontorno") else { return }
    let canale = FlutterMethodChannel(name: "tkfoto/scontorno", binaryMessenger: registrar.messenger())
    canale.setMethodCallHandler { call, result in
      if call.method == "oggetti" {
        guard let a = call.arguments as? [String: Any], let percorso = a["percorso"] as? String,
              let x = a["x"] as? Int, let y = a["y"] as? Int,
              let w = a["larghezza"] as? Int, let h = a["altezza"] as? Int else {
          result(FlutterMethodNotImplemented)
          return
        }
        DispatchQueue.global(qos: .userInitiated).async {
          let esito = Self.oggetti(percorso: percorso, zona: CGRect(x: x, y: y, width: w, height: h))
          DispatchQueue.main.async { result(esito) }
        }
        return
      }
      guard call.method == "scontorna", let a = call.arguments as? [String: Any],
            let percorso = a["percorso"] as? String, let uscita = a["uscita"] as? String else {
        result(FlutterMethodNotImplemented)
        return
      }
      let latoMax = CGFloat((a["latoMax"] as? Int) ?? 2048)
      DispatchQueue.global(qos: .userInitiated).async {
        let esito = Self.scontorna(percorso: percorso, latoMax: latoMax, uscita: uscita)
        DispatchQueue.main.async { result(esito) }
      }
    }
  }

  /// Gli oggetti riconosciuti nel pezzo [zona] della foto raddrizzata: una maschera di byte (0–255) per oggetto,
  /// alla misura del pezzo (rimpicciolito a lato lungo ≤ 1024).
  private static func oggetti(percorso: String, zona: CGRect) -> Any {
    guard let foto = UIImage(contentsOfFile: percorso)?.cgImage,
          let ritagliato = foto.cropping(to: zona.integral) else {
      return FlutterError(code: "FOTO", message: "Non riesco ad aprire la foto", details: nil)
    }
    var pezzo = ritagliato
    let lungo = CGFloat(max(ritagliato.width, ritagliato.height))
    if lungo > 1024 {
      let misura = CGSize(width: floor(CGFloat(ritagliato.width) * 1024 / lungo),
                          height: floor(CGFloat(ritagliato.height) * 1024 / lungo))
      let formato = UIGraphicsImageRendererFormat()
      formato.scale = 1
      let piccola = UIGraphicsImageRenderer(size: misura, format: formato).image { _ in
        UIImage(cgImage: ritagliato).draw(in: CGRect(origin: .zero, size: misura))
      }
      if let cg = piccola.cgImage { pezzo = cg }
    }
    guard #available(iOS 17.0, *) else {
      return FlutterError(code: "OGGETTI", message: "Serve iOS 17 o più recente", details: nil)
    }
    let w = pezzo.width, h = pezzo.height
    do {
      let richiesta = VNGenerateForegroundInstanceMaskRequest()
      let gestore = VNImageRequestHandler(cgImage: pezzo)
      try gestore.perform([richiesta])
      var maschere: [FlutterStandardTypedData] = []
      if let osservazione = richiesta.results?.first {
        for i in osservazione.allInstances {
          let buffer = try osservazione.generateScaledMaskForImage(forInstances: IndexSet(integer: i), from: gestore)
          maschere.append(FlutterStandardTypedData(bytes: byteDa(buffer, w, h)))
        }
      }
      return ["larghezza": w, "altezza": h, "maschere": maschere]
    } catch {
      return FlutterError(code: "OGGETTI", message: error.localizedDescription, details: nil)
    }
  }

  /// Maschera di Vision (un Float32 per pixel, da 0 a 1) → byte da 0 a 255.
  private static func byteDa(_ buffer: CVPixelBuffer, _ w: Int, _ h: Int) -> Data {
    var out = Data(count: w * h)
    CVPixelBufferLockBaseAddress(buffer, .readOnly)
    defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
    guard let base = CVPixelBufferGetBaseAddress(buffer) else { return out }
    let bw = min(w, CVPixelBufferGetWidth(buffer)), bh = min(h, CVPixelBufferGetHeight(buffer))
    let riga = CVPixelBufferGetBytesPerRow(buffer)
    out.withUnsafeMutableBytes { (p: UnsafeMutableRawBufferPointer) in
      for y in 0..<bh {
        let valori = base.advanced(by: y * riga).assumingMemoryBound(to: Float32.self)
        for x in 0..<bw {
          p[y * w + x] = UInt8(max(0, min(1, valori[x])) * 255)
        }
      }
    }
    return out
  }

  private static func scontorna(percorso: String, latoMax: CGFloat, uscita: String) -> Any {
    guard let foto = UIImage(contentsOfFile: percorso) else {
      return FlutterError(code: "FOTO", message: "Non riesco ad aprire la foto", details: nil)
    }
    // foto girata come la si vede e rimpicciolita
    let scala = min(1, latoMax / max(foto.size.width, foto.size.height))
    let misura = CGSize(width: floor(foto.size.width * scala), height: floor(foto.size.height * scala))
    let formato = UIGraphicsImageRendererFormat()
    formato.scale = 1
    let diritta = UIGraphicsImageRenderer(size: misura, format: formato).image { _ in
      foto.draw(in: CGRect(origin: .zero, size: misura))
    }
    guard let cg = diritta.cgImage else {
      return FlutterError(code: "FOTO", message: "Non riesco ad aprire la foto", details: nil)
    }
    guard #available(iOS 17.0, *) else {
      return FlutterError(code: "SCONTORNO", message: "Lo scontorno vuole iOS 17 o più recente", details: nil)
    }
    do {
      let richiesta = VNGenerateForegroundInstanceMaskRequest()
      let gestore = VNImageRequestHandler(cgImage: cg)
      try gestore.perform([richiesta])
      guard let maschera = richiesta.results?.first, !maschera.allInstances.isEmpty else {
        return FlutterError(code: "VUOTO", message: "Nella foto non trovo un soggetto da ritagliare", details: nil)
      }
      let buffer = try maschera.generateMaskedImage(
        ofInstances: maschera.allInstances, from: gestore, croppedToInstancesExtent: false)
      let immagine = CIImage(cvPixelBuffer: buffer)
      guard let spazio = CGColorSpace(name: CGColorSpace.sRGB),
            let png = CIContext().pngRepresentation(of: immagine, format: .RGBA8, colorSpace: spazio) else {
        return FlutterError(code: "SCONTORNO", message: "Non riesco a salvare il ritaglio", details: nil)
      }
      try png.write(to: URL(fileURLWithPath: uscita))
      // la foto raddrizzata, della stessa misura del ritaglio: serve al ritocco per ripristinare
      let originale = (uscita as NSString).deletingPathExtension + "-originale.jpg"
      try diritta.jpegData(compressionQuality: 0.94)?.write(to: URL(fileURLWithPath: originale))
      return ["larghezza": cg.width, "altezza": cg.height, "originale": originale]
    } catch {
      return FlutterError(code: "SCONTORNO", message: error.localizedDescription, details: nil)
    }
  }
}
