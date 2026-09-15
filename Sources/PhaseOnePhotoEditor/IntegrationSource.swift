import Foundation

struct IntegrationSource: Identifiable {
    let id = UUID()
    let name: String
    let role: String
    let repositoryPath: URL?
    let phaseOneAction: String

    var apiRepresentation: [String: Any] {
        [
            "name": name,
            "role": role,
            "repositoryPath": repositoryPath?.path ?? "Not configured",
            "phaseOneAction": phaseOneAction
        ]
    }

    static let phaseOneDefaults = [
        IntegrationSource(
            name: "RapidRAW",
            role: "RAW pipeline and advanced adjustment reference",
            repositoryPath: PhaseOnePaths.rapidRAW,
            phaseOneAction: "Port concepts into Swift/Metal first; only bind Rust modules after the native render graph is stable."
        ),
        IntegrationSource(
            name: "TUI image-editor",
            role: "Canvas command model, crop, rotate, draw, text, shapes",
            repositoryPath: PhaseOnePaths.tuiImageEditor,
            phaseOneAction: "Translate command/history/tool-mode architecture into Swift instead of embedding the old Webpack UI."
        ),
        IntegrationSource(
            name: "OmniGen",
            role: "Prompt-driven AI editing sidecar",
            repositoryPath: PhaseOnePaths.omniGen,
            phaseOneAction: "Run as a separate Python process using PyTorch MPS on Apple Silicon."
        )
    ]
}
