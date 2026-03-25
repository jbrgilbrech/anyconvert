import AnyConvertCore
import Foundation

struct CLI {
    let engine = ConversionEngine()

    func run() -> Int32 {
        let arguments = Array(CommandLine.arguments.dropFirst())
        guard let first = arguments.first else {
            print(usage)
            return 0
        }

        do {
            switch first {
            case "convert":
                return try runConvert(arguments.dropFirst())
            case "formats":
                return try runFormats(arguments.dropFirst())
            case "help", "--help", "-h":
                print(usage)
                return 0
            default:
                fputs("Unknown command: \(first)\n\n\(usage)\n", stderr)
                return 1
            }
        } catch {
            fputs("Error: \(error.localizedDescription)\n", stderr)
            return 1
        }
    }

    private func runConvert(_ args: ArraySlice<String>) throws -> Int32 {
        var inputPath: String?
        var targetExtension: String?
        var outputPath: String?

        var iterator = args.makeIterator()
        while let argument = iterator.next() {
            switch argument {
            case "--input", "-i":
                inputPath = iterator.next()
            case "--to", "-t":
                targetExtension = iterator.next()
            case "--output", "-o":
                outputPath = iterator.next()
            default:
                throw NSError(domain: "CLI", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unknown argument: \(argument)"])
            }
        }

        guard let inputPath, let targetExtension else {
            fputs("Missing required arguments.\n\n\(usage)\n", stderr)
            return 1
        }

        let inputURL = URL(fileURLWithPath: NSString(string: inputPath).expandingTildeInPath)
        let outputURL = outputPath.map { URL(fileURLWithPath: NSString(string: $0).expandingTildeInPath) }
        let result = try engine.convert(inputURL: inputURL, to: targetExtension, outputURL: outputURL)
        print("Converted \(inputURL.lastPathComponent) -> \(result.outputURL.path)")
        return 0
    }

    private func runFormats(_ args: ArraySlice<String>) throws -> Int32 {
        guard let inputPath = args.first else {
            fputs("Usage: anyconvert formats /path/to/file\n", stderr)
            return 1
        }

        let inputURL = URL(fileURLWithPath: NSString(string: String(inputPath)).expandingTildeInPath)
        let formats = try engine.supportedFormats(for: inputURL)
        for format in formats {
            print("\(format.fileExtension)\t\(format.displayName)")
        }
        return 0
    }

    private var usage: String {
        """
        anyconvert

        Commands:
          anyconvert formats /path/to/input
          anyconvert convert --input /path/to/input --to png [--output /path/to/output]

        Supported categories:
          images, text/documents, audio
        """
    }
}

exit(CLI().run())
