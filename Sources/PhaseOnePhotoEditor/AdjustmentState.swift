import Foundation

enum AdjustmentControl: String, CaseIterable, Identifiable {
    case exposure
    case brightness
    case contrast
    case saturation
    case vibrance
    case highlights
    case shadows
    case temperature
    case tint
    case sharpness
    case clarity
    case noiseReduction
    case gamma
    case hue
    case sepia
    case monochrome
    case vignette
    case vignetteRadius
    case bloom
    case bloomRadius
    case blur
    case redBalance
    case greenBalance
    case blueBalance
    case blackLevel
    case whiteLevel

    var id: String { rawValue }

    var title: String {
        switch self {
        case .exposure: "Exposure"
        case .brightness: "Brightness"
        case .contrast: "Contrast"
        case .saturation: "Saturation"
        case .vibrance: "Vibrance"
        case .highlights: "Highlights"
        case .shadows: "Shadows"
        case .temperature: "Temperature"
        case .tint: "Tint"
        case .sharpness: "Sharpness"
        case .clarity: "Clarity"
        case .noiseReduction: "Noise Reduction"
        case .gamma: "Gamma"
        case .hue: "Hue"
        case .sepia: "Sepia"
        case .monochrome: "Monochrome"
        case .vignette: "Vignette"
        case .vignetteRadius: "Vignette Radius"
        case .bloom: "Bloom"
        case .bloomRadius: "Bloom Radius"
        case .blur: "Blur"
        case .redBalance: "Red Balance"
        case .greenBalance: "Green Balance"
        case .blueBalance: "Blue Balance"
        case .blackLevel: "Black Level"
        case .whiteLevel: "White Level"
        }
    }

    var range: ClosedRange<Double> {
        switch self {
        case .exposure: -4.0...4.0
        case .brightness: -1.0...1.0
        case .contrast: -1.0...1.0
        case .saturation: 0.0...2.0
        case .vibrance: -1.0...1.0
        case .highlights: -1.0...1.0
        case .shadows: -1.0...1.0
        case .temperature: -100.0...100.0
        case .tint: -100.0...100.0
        case .sharpness: 0.0...2.0
        case .clarity: 0.0...2.0
        case .noiseReduction: 0.0...1.0
        case .gamma: 0.2...3.0
        case .hue: -180.0...180.0
        case .sepia: 0.0...1.0
        case .monochrome: 0.0...1.0
        case .vignette: 0.0...2.0
        case .vignetteRadius: 0.0...2.0
        case .bloom: 0.0...1.0
        case .bloomRadius: 0.0...30.0
        case .blur: 0.0...20.0
        case .redBalance: -1.0...1.0
        case .greenBalance: -1.0...1.0
        case .blueBalance: -1.0...1.0
        case .blackLevel: 0.0...0.5
        case .whiteLevel: 0.5...1.0
        }
    }

    var defaultValue: Double {
        switch self {
        case .saturation, .gamma, .vignetteRadius, .whiteLevel:
            return 1.0
        case .bloomRadius:
            return 10.0
        default:
            return 0.0
        }
    }

    var isDefaultVisible: Bool {
        switch self {
        case .exposure,
             .brightness,
             .contrast,
             .saturation,
             .vibrance,
             .highlights,
             .shadows,
             .temperature,
             .tint,
             .sharpness:
            return true
        default:
            return false
        }
    }

    var apiParameter: JSONObject {
        [
            "name": .string(rawValue),
            "label": .string(title),
            "type": .string("number"),
            "required": .bool(false),
            "range": .numbers([range.lowerBound, range.upperBound]),
            "default": .number(defaultValue),
            "defaultVisible": .bool(isDefaultVisible)
        ]
    }

    static var defaultVisibleIDs: Set<String> {
        Set(allCases.filter(\.isDefaultVisible).map(\.rawValue))
    }

    static var apiCatalog: [JSONObject] {
        allCases.map(\.apiParameter)
    }
}

struct AdjustmentState {
    private var values: [String: Double] = AdjustmentState.defaultValues()

    var apiRepresentation: [String: Double] {
        Dictionary(uniqueKeysWithValues: AdjustmentControl.allCases.map { control in
            (control.rawValue, value(for: control))
        })
    }

    mutating func reset() {
        values = Self.defaultValues()
    }

    func value(for control: AdjustmentControl) -> Double {
        values[control.rawValue] ?? control.defaultValue
    }

    mutating func setValue(_ value: Double, for control: AdjustmentControl) {
        values[control.rawValue] = value.clamped(to: control.range)
    }

    mutating func apply(apiValues: JSONObject) {
        for control in AdjustmentControl.allCases {
            guard let value = apiValues[control.rawValue]?.numberValue else {
                continue
            }
            setValue(value, for: control)
        }
    }

    private static func defaultValues() -> [String: Double] {
        Dictionary(uniqueKeysWithValues: AdjustmentControl.allCases.map { control in
            (control.rawValue, control.defaultValue)
        })
    }

}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
