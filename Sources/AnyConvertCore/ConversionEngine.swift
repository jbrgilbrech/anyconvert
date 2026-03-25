import Foundation

public struct ConversionEngine: Sendable {
    public init() {}

    public func supportedFormats(for inputURL: URL) throws -> [OutputFormat] {
        guard FileManager.default.fileExists(atPath: inputURL.path) else {
            throw ConversionError.invalidSource(inputURL)
        }
        guard let category = FileClassifier.category(for: inputURL) else {
            throw ConversionError.unsupportedInput(inputURL)
        }
        return FormatCatalog.formats(for: category)
    }

    public func convert(inputURL: URL, to targetExtension: String, outputURL: URL? = nil) throws -> ConversionResult {
        guard FileManager.default.fileExists(atPath: inputURL.path) else {
            throw ConversionError.invalidSource(inputURL)
        }
        guard let category = FileClassifier.category(for: inputURL) else {
            throw ConversionError.unsupportedInput(inputURL)
        }

        let normalizedExtension = normalize(targetExtension)
        let supported = FormatCatalog.formats(for: category)
        guard supported.contains(where: { $0.fileExtension == normalizedExtension }) else {
            throw ConversionError.unsupportedOutput(normalizedExtension, category: category)
        }

        let resolvedOutput = outputURL ?? defaultOutputURL(for: inputURL, targetExtension: normalizedExtension)

        switch category {
        case .image:
            try convertImage(inputURL: inputURL, outputURL: resolvedOutput, targetExtension: normalizedExtension)
        case .document:
            try convertDocument(inputURL: inputURL, outputURL: resolvedOutput, targetExtension: normalizedExtension)
        case .audio:
            try convertAudio(inputURL: inputURL, outputURL: resolvedOutput, targetExtension: normalizedExtension)
        }

        return ConversionResult(outputURL: resolvedOutput, category: category)
    }

    public func defaultOutputURL(for inputURL: URL, targetExtension: String) -> URL {
        let normalizedExtension = normalize(targetExtension)
        let baseName = inputURL.deletingPathExtension().lastPathComponent
        let outputName = "\(baseName).\(normalizedExtension)"
        return inputURL.deletingLastPathComponent().appendingPathComponent(outputName)
    }

    private func convertImage(inputURL: URL, outputURL: URL, targetExtension: String) throws {
        try ProcessRunner.run(
            executable: "/usr/bin/sips",
            arguments: [
                "--setProperty", "format", sipsFormat(for: targetExtension),
                inputURL.path,
                "--out", outputURL.path,
            ]
        )
    }

    private func convertDocument(inputURL: URL, outputURL: URL, targetExtension: String) throws {
        try ProcessRunner.run(
            executable: "/usr/bin/textutil",
            arguments: [
                "-convert", targetExtension,
                inputURL.path,
                "-output", outputURL.path,
            ]
        )
    }

    private func convertAudio(inputURL: URL, outputURL: URL, targetExtension: String) throws {
        let config = audioConfig(for: targetExtension)
        var arguments = [inputURL.path, "-o", outputURL.path, "-f", config.fileFormat]
        if let dataFormat = config.dataFormat {
            arguments.append(contentsOf: ["-d", dataFormat])
        }
        try ProcessRunner.run(executable: "/usr/bin/afconvert", arguments: arguments)
    }

    private func sipsFormat(for ext: String) -> String {
        switch ext {
        case "jpg":
            return "jpeg"
        default:
            return ext
        }
    }

    private func audioConfig(for ext: String) -> (fileFormat: String, dataFormat: String?) {
        switch ext {
        case "wav":
            return ("WAVE", "LEI16")
        case "aiff":
            return ("AIFF", "BEI16")
        case "aifc":
            return ("AIFC", "BEI16")
        case "caf":
            return ("caff", nil)
        case "m4a":
            return ("m4af", "aac")
        case "mp3":
            return ("MPG3", ".mp3")
        case "aac":
            return ("adts", "aac")
        case "flac":
            return ("flac", "flac")
        case "opus":
            return ("Oggf", "opus")
        default:
            return ("WAVE", "LEI16")
        }
    }

    private func normalize(_ ext: String) -> String {
        ext
            .lowercased()
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
    }
}
