import SwiftUI

/// QualiScan design tokens — a clean, trustworthy "document" look:
/// deep blue brand, paper-white surfaces, soft neutral background.
enum Palette {
    // Brand
    static let brand      = Color(red: 0.227, green: 0.435, blue: 0.969)   // #3A6FF7
    static let brandDeep  = Color(red: 0.133, green: 0.275, blue: 0.796)   // #2246CB
    static let brandSoft  = Color(red: 0.901, green: 0.929, blue: 1.000)   // tint chip bg

    // Text
    static let ink   = Color(red: 0.106, green: 0.137, blue: 0.235)        // #1B233C
    static let sub   = Color(red: 0.451, green: 0.486, blue: 0.569)        // muted slate
    static let faint = Color(red: 0.62, green: 0.65, blue: 0.72)

    // Surfaces
    static let card      = Color(red: 1.0, green: 1.0, blue: 1.0)
    static let bgTop     = Color(red: 0.957, green: 0.969, blue: 0.992)     // #F4F7FD
    static let bgBottom  = Color(red: 0.918, green: 0.937, blue: 0.976)     // #EAEFF9
    static let separator = Color(red: 0.886, green: 0.906, blue: 0.945)

    // Semantic
    static let success = Color(red: 0.18, green: 0.70, blue: 0.46)
    static let danger  = Color(red: 0.91, green: 0.30, blue: 0.34)
    static let amber   = Color(red: 0.98, green: 0.69, blue: 0.25)

    // Background gradient
    static let bg: [Color] = [bgTop, bgBottom]

    // Brand gradient (buttons, FAB, headers)
    static let brandGradient: [Color] = [
        Color(red: 0.29, green: 0.51, blue: 1.00),
        Color(red: 0.16, green: 0.33, blue: 0.90)
    ]

    /// Accent colour per filter chip.
    static func filterTint(_ raw: String) -> Color {
        switch raw {
        case "original":  return Color(red: 0.42, green: 0.46, blue: 0.55)
        case "color":     return brand
        case "grayscale": return Color(red: 0.36, green: 0.40, blue: 0.50)
        case "bw":        return ink
        default:          return brand
        }
    }
}

extension LinearGradient {
    static let brand = LinearGradient(colors: Palette.brandGradient, startPoint: .topLeading, endPoint: .bottomTrailing)
    static let appBackground = LinearGradient(colors: Palette.bg, startPoint: .top, endPoint: .bottom)
}
