import Foundation

struct OmniGenService {
    let repositoryPath: URL?

    var inferenceScript: URL? {
        PhaseOnePaths.phaseRoot?
            .appendingPathComponent("scripts", isDirectory: true)
            .appendingPathComponent("omnigen_mps_runner.py")
    }

    var mpsEnvironment: [String: String] {
        [
            "PYTORCH_ENABLE_MPS_FALLBACK": "1",
            "PYTORCH_MPS_HIGH_WATERMARK_RATIO": "0.0"
        ]
    }

    func commandPreview(prompt: String, inputImage: URL?, outputImage: URL) -> [String]? {
        guard let inferenceScript else {
            return nil
        }
        var command = [
            "python3",
            inferenceScript.path,
            "--prompt",
            prompt,
            "--output",
            outputImage.path
        ]

        if let inputImage {
            command.append(contentsOf: ["--input", inputImage.path])
        }

        return command
    }
}
