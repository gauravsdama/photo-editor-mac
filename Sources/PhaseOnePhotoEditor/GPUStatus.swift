import Foundation
import Metal

struct GPUStatus {
    let deviceName: String
    let isAvailable: Bool
    let isAppleSiliconBuild: Bool
    let hasUnifiedMemory: Bool
    let isLowPower: Bool
    let isRemovable: Bool
    let recommendedRenderingBackend: String

    static let unknown = GPUStatus(
        deviceName: "Not checked",
        isAvailable: false,
        isAppleSiliconBuild: isArm64,
        hasUnifiedMemory: false,
        isLowPower: false,
        isRemovable: false,
        recommendedRenderingBackend: "Metal/Core Image pending device detection"
    )

    var apiRepresentation: JSONObject {
        [
            "deviceName": .string(deviceName),
            "isAvailable": .bool(isAvailable),
            "isAppleSiliconBuild": .bool(isAppleSiliconBuild),
            "hasUnifiedMemory": .bool(hasUnifiedMemory),
            "isLowPower": .bool(isLowPower),
            "isRemovable": .bool(isRemovable),
            "recommendedRenderingBackend": .string(recommendedRenderingBackend)
        ]
    }

    static func detect() -> GPUStatus {
        guard let device = MTLCreateSystemDefaultDevice() else {
            return GPUStatus(
                deviceName: "No Metal device",
                isAvailable: false,
                isAppleSiliconBuild: isArm64,
                hasUnifiedMemory: false,
                isLowPower: false,
                isRemovable: false,
                recommendedRenderingBackend: "Unavailable"
            )
        }

        return GPUStatus(
            deviceName: device.name,
            isAvailable: true,
            isAppleSiliconBuild: isArm64,
            hasUnifiedMemory: device.hasUnifiedMemory,
            isLowPower: device.isLowPower,
            isRemovable: device.isRemovable,
            recommendedRenderingBackend: "Metal device + CIContext(mtlDevice:)"
        )
    }

    private static var isArm64: Bool {
        #if arch(arm64)
        true
        #else
        false
        #endif
    }
}
