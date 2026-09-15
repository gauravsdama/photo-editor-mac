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
    let recommendedAIBackend: String

    static let unknown = GPUStatus(
        deviceName: "Not checked",
        isAvailable: false,
        isAppleSiliconBuild: isArm64,
        hasUnifiedMemory: false,
        isLowPower: false,
        isRemovable: false,
        recommendedRenderingBackend: "Metal/Core Image pending device detection",
        recommendedAIBackend: "PyTorch MPS pending environment check"
    )

    var looksLikeAppleSiliconVirtualGPU: Bool {
        isAvailable && isAppleSiliconBuild && hasUnifiedMemory && !isRemovable
    }

    var apiRepresentation: [String: Any] {
        [
            "deviceName": deviceName,
            "isAvailable": isAvailable,
            "isAppleSiliconBuild": isAppleSiliconBuild,
            "hasUnifiedMemory": hasUnifiedMemory,
            "isLowPower": isLowPower,
            "isRemovable": isRemovable,
            "looksLikeAppleSiliconVirtualGPU": looksLikeAppleSiliconVirtualGPU,
            "recommendedRenderingBackend": recommendedRenderingBackend,
            "recommendedAIBackend": recommendedAIBackend
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
                recommendedRenderingBackend: "Unavailable",
                recommendedAIBackend: "Unavailable"
            )
        }

        return GPUStatus(
            deviceName: device.name,
            isAvailable: true,
            isAppleSiliconBuild: isArm64,
            hasUnifiedMemory: device.hasUnifiedMemory,
            isLowPower: device.isLowPower,
            isRemovable: device.isRemovable,
            recommendedRenderingBackend: "Metal device + CIContext(mtlDevice:)",
            recommendedAIBackend: "PyTorch MPS sidecar with PYTORCH_ENABLE_MPS_FALLBACK=1"
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
