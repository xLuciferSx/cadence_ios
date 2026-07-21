import SwiftUI

public struct Palette: Sendable {
  public var background: Color
  public var text: Color
  public var subtext: Color
  public var tray: Color
  public var key: Color
  public var keyText: Color
  public var special: Color
  public var accent: Color
  public var border: Color
  public var bubbleIn: Color
  public var placeholder: Color

  public static let light = Palette(
    background: Color(hex: 0xFCFCFD),
    text: Color(hex: 0x2B2F34),
    subtext: Color(hex: 0x71767C),
    tray: Color(hex: 0xE9EAEC),
    key: Color(hex: 0xFFFFFF),
    keyText: Color(hex: 0x2B2F34),
    special: Color(hex: 0xD3D6D9),
    accent: Color(hex: 0x3B6FE5),
    border: Color(hex: 0xDCDEE1),
    bubbleIn: Color(hex: 0xE7E8EB),
    placeholder: Color(hex: 0x9BA0A6)
  )

  public static let dark = Palette(
    background: Color(hex: 0x2B2F35),
    text: Color(hex: 0xF0F1F2),
    subtext: Color(hex: 0xA6ABB0),
    tray: Color(hex: 0x24282D),
    key: Color(hex: 0x40454B),
    keyText: Color(hex: 0xF3F4F5),
    special: Color(hex: 0x2F343A),
    accent: Color(hex: 0x5B86EE),
    border: Color(hex: 0x40454B),
    bubbleIn: Color(hex: 0x40454B),
    placeholder: Color(hex: 0x7E848A)
  )

  public static func resolve(_ scheme: ColorScheme) -> Palette {
    scheme == .dark ? .dark : .light
  }
}

public extension Color {
  init(hex: UInt32) {
    self.init(
      .sRGB,
      red: Double((hex >> 16) & 0xFF) / 255,
      green: Double((hex >> 8) & 0xFF) / 255,
      blue: Double(hex & 0xFF) / 255,
      opacity: 1
    )
  }
}

public extension EnvironmentValues {
  var palette: Palette {
    get { self[PaletteKey.self] }
    set { self[PaletteKey.self] = newValue }
  }
}

private struct PaletteKey: EnvironmentKey {
  static let defaultValue = Palette.light
}
