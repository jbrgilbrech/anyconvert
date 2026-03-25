import Foundation
import UniformTypeIdentifiers

public enum ConversionCategory: String, CaseIterable, Sendable {
    case image
    case document
    case audio
}

public struct OutputFormat: Hashable, Sendable {
    public let category: ConversionCategory
    public let displayName: String
    public let fileExtension: String

    public init(category: ConversionCategory, displayName: String, fileExtension: String) {
        self.category = category
        self.displayName = displayName
        self.fileExtension = fileExtension
    }
}

public struct ConversionResult: Sendable {
    public let outputURL: URL
    public let category: ConversionCategory

    public init(outputURL: URL, category: ConversionCategory) {
        self.outputURL = outputURL
        self.category = category
    }
}

public enum ConversionError: LocalizedError, Sendable {
    case unsupportedInput(URL)
    case unsupportedOutput(String, category: ConversionCategory)
    case processFailed(tool: String, message: String)
    case invalidSource(URL)

    public var errorDescription: String? {
        switch self {
        case .unsupportedInput(let url):
            return "Unsupported input file type: \(url.lastPathComponent)"
        case .unsupportedOutput(let ext, let category):
            return "Unsupported \(category.rawValue) output format: .\(ext)"
        case .processFailed(let tool, let message):
            return "\(tool) failed: \(message)"
        case .invalidSource(let url):
            return "Input file does not exist: \(url.path)"
        }
    }
}

public enum FormatCatalog {
    public static let imageFormats: [OutputFormat] = [
        .init(category: .image, displayName: "PNG", fileExtension: "png"),
        .init(category: .image, displayName: "JPEG", fileExtension: "jpg"),
        .init(category: .image, displayName: "TIFF", fileExtension: "tiff"),
        .init(category: .image, displayName: "GIF", fileExtension: "gif"),
        .init(category: .image, displayName: "BMP", fileExtension: "bmp"),
        .init(category: .image, displayName: "HEIC", fileExtension: "heic"),
        .init(category: .image, displayName: "JPEG 2000", fileExtension: "jp2"),
        .init(category: .image, displayName: "PDF", fileExtension: "pdf"),
        .init(category: .image, displayName: "ICO", fileExtension: "ico"),
        .init(category: .image, displayName: "ICNS", fileExtension: "icns"),
        .init(category: .image, displayName: "TGA", fileExtension: "tga"),
        .init(category: .image, displayName: "PSD", fileExtension: "psd"),
        .init(category: .image, displayName: "AVIF", fileExtension: "avif"),
        .init(category: .image, displayName: "PBM", fileExtension: "pbm"),
    ]

    public static let documentFormats: [OutputFormat] = [
        .init(category: .document, displayName: "Plain Text", fileExtension: "txt"),
        .init(category: .document, displayName: "Rich Text", fileExtension: "rtf"),
        .init(category: .document, displayName: "Rich Text Bundle", fileExtension: "rtfd"),
        .init(category: .document, displayName: "HTML", fileExtension: "html"),
        .init(category: .document, displayName: "Word DOC", fileExtension: "doc"),
        .init(category: .document, displayName: "Word DOCX", fileExtension: "docx"),
        .init(category: .document, displayName: "OpenDocument", fileExtension: "odt"),
        .init(category: .document, displayName: "WordML", fileExtension: "wordml"),
        .init(category: .document, displayName: "Web Archive", fileExtension: "webarchive"),
    ]

    public static let audioFormats: [OutputFormat] = [
        .init(category: .audio, displayName: "WAV", fileExtension: "wav"),
        .init(category: .audio, displayName: "AIFF", fileExtension: "aiff"),
        .init(category: .audio, displayName: "AIFC", fileExtension: "aifc"),
        .init(category: .audio, displayName: "CAF", fileExtension: "caf"),
        .init(category: .audio, displayName: "M4A", fileExtension: "m4a"),
        .init(category: .audio, displayName: "MP3", fileExtension: "mp3"),
        .init(category: .audio, displayName: "AAC", fileExtension: "aac"),
        .init(category: .audio, displayName: "FLAC", fileExtension: "flac"),
        .init(category: .audio, displayName: "Ogg Opus", fileExtension: "opus"),
    ]

    public static func formats(for category: ConversionCategory) -> [OutputFormat] {
        switch category {
        case .image:
            return imageFormats
        case .document:
            return documentFormats
        case .audio:
            return audioFormats
        }
    }
}

public enum FileClassifier {
    public static func category(for url: URL) -> ConversionCategory? {
        let ext = url.pathExtension.lowercased()
        guard !ext.isEmpty else { return nil }

        if let type = UTType(filenameExtension: ext) {
            if type.conforms(to: .image) || ext == "pdf" {
                return .image
            }
            if type.conforms(to: .audio) {
                return .audio
            }
            if type.conforms(to: .text) || type.conforms(to: .html) || type.conforms(to: .rtf) {
                return .document
            }
            if type.conforms(to: .content) && ["doc", "docx", "odt", "wordml", "webarchive", "rtfd"].contains(ext) {
                return .document
            }
        }

        if ["doc", "docx", "odt", "rtf", "rtfd", "txt", "html", "htm", "wordml", "webarchive"].contains(ext) {
            return .document
        }

        if ["wav", "aiff", "aif", "aifc", "caf", "m4a", "m4r", "mp3", "aac", "flac", "opus", "ogg", "oga", "au", "snd", "amr"].contains(ext) {
            return .audio
        }

        return nil
    }
}
