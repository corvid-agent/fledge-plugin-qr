import CoreImage
import CoreGraphics
import Foundation

// MARK: - QR Matrix Generation (CoreImage)

/// Generate a QR code boolean matrix from a string using CoreImage.
/// Returns a 2D array where `true` = dark module, `false` = light module.
func generateQRMatrix(from string: String, correctionLevel: String = "L") -> [[Bool]]? {
    guard let data = string.data(using: .utf8) else { return nil }
    guard let filter = CIFilter(name: "CIQRCodeGenerator") else {
        fputs("Error: CIQRCodeGenerator filter not available\n", stderr)
        return nil
    }
    filter.setValue(data, forKey: "inputMessage")
    filter.setValue(correctionLevel, forKey: "inputCorrectionLevel")

    guard let output = filter.outputImage else { return nil }

    let width = Int(output.extent.width)
    let height = Int(output.extent.height)

    let context = CIContext(options: [.useSoftwareRenderer: true])
    guard let cgImage = context.createCGImage(output, from: output.extent) else { return nil }

    // Render into a bitmap to read pixel values
    let bytesPerPixel = 4
    let bytesPerRow = width * bytesPerPixel
    var pixelData = [UInt8](repeating: 0, count: height * bytesPerRow)

    guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
    guard let ctx = CGContext(
        data: &pixelData,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: bytesPerRow,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }

    ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

    var matrix = [[Bool]](repeating: [Bool](repeating: false, count: width), count: height)
    for y in 0..<height {
        for x in 0..<width {
            let offset = y * bytesPerRow + x * bytesPerPixel
            let r = pixelData[offset]
            // Dark module if pixel is dark (QR codes: black = data)
            matrix[y][x] = r < 128
        }
    }
    return matrix
}

// MARK: - Terminal Rendering

/// Render a QR matrix to the terminal using Unicode half-block characters.
/// Each character cell represents 2 vertical modules.
/// Uses a quiet zone of 2 modules around the code.
func renderQR(_ matrix: [[Bool]], invert: Bool, moduleSize: Int) {
    let height = matrix.count
    let width = height > 0 ? matrix[0].count : 0
    let quietZone = 2

    // Half-block rendering: process two rows at a time.
    // dark=black, light=white. On a dark terminal background:
    //   top=dark,  bot=dark  => "█" (full block, shows as dark)
    //   top=dark,  bot=light => "▀" (upper half dark)
    //   top=light, bot=dark  => "▄" (lower half dark)
    //   top=light, bot=light => " " (space, background shows)

    let totalHeight = height + 2 * quietZone
    let totalWidth = width + 2 * quietZone

    func isDark(_ row: Int, _ col: Int) -> Bool {
        let r = row - quietZone
        let c = col - quietZone
        if r < 0 || r >= height || c < 0 || c >= width { return false }
        let val = matrix[r][c]
        return invert ? !val : val
    }

    // Process two rows at a time
    var row = 0
    while row < totalHeight {
        var line = ""
        for col in 0..<totalWidth {
            let topDark = isDark(row, col)
            let botDark = (row + 1 < totalHeight) ? isDark(row + 1, col) : false

            let ch: String
            if topDark && botDark {
                ch = "\u{2588}" // full block
            } else if topDark && !botDark {
                ch = "\u{2580}" // upper half block
            } else if !topDark && botDark {
                ch = "\u{2584}" // lower half block
            } else {
                ch = " "
            }

            // Repeat character for module size (horizontal scaling)
            for _ in 0..<moduleSize {
                line += ch
            }
        }
        print(line)
        row += 2
    }
}

// MARK: - WiFi String Encoding

func wifiString(ssid: String, password: String, security: String) -> String {
    func escape(_ s: String) -> String {
        var result = ""
        for ch in s {
            if "\\;,:\"".contains(ch) {
                result += "\\\(ch)"
            } else {
                result += String(ch)
            }
        }
        return result
    }
    return "WIFI:T:\(security);S:\(escape(ssid));P:\(escape(password));;"
}

// MARK: - Terminal Width Detection

func terminalWidth() -> Int {
    var ws = winsize()
    if ioctl(STDOUT_FILENO, TIOCGWINSZ, &ws) == 0 && ws.ws_col > 0 {
        return Int(ws.ws_col)
    }
    return 80
}

// MARK: - CLI Parsing

enum Command {
    case generate(text: String, size: Int?, invert: Bool)
    case url(url: String, size: Int?, invert: Bool)
    case wifi(ssid: String, password: String, security: String, size: Int?, invert: Bool)
    case text(text: String, size: Int?, invert: Bool)
    case help
    case version
}

func printUsage() {
    let usage = """
    fledge-qr: Generate QR codes in the terminal

    USAGE:
        fledge qr <command> [options]

    COMMANDS:
        generate <text>     Generate a QR code from text
        text <text>         Alias for generate
        url <url>           Generate a QR code from a URL
        wifi                Generate a WiFi QR code
        help                Show this help message
        version             Show version

    OPTIONS:
        --size <n>          Module size (default: auto-detect)
        --invert            Invert colors (for light terminals)
        -h, --help          Show help

    WIFI OPTIONS:
        --ssid <name>       WiFi network name (required)
        --password <pass>   WiFi password (required)
        --security <type>   Security type: WPA, WEP, nopass (default: WPA)

    EXAMPLES:
        fledge qr generate "Hello, World!"
        fledge qr url https://example.com
        fledge qr wifi --ssid MyNetwork --password secret123
        fledge qr text "Some text" --invert
    """
    print(usage)
}

func parseArgs() -> Command {
    let args = Array(CommandLine.arguments.dropFirst())

    if args.isEmpty {
        return .help
    }

    func findFlag(_ name: String, in args: [String]) -> Bool {
        return args.contains(name)
    }

    func findValue(_ name: String, in args: [String]) -> String? {
        guard let idx = args.firstIndex(of: name), idx + 1 < args.count else { return nil }
        return args[idx + 1]
    }

    let invert = findFlag("--invert", in: args)
    let sizeStr = findValue("--size", in: args)
    let size = sizeStr.flatMap { Int($0) }

    let command = args[0].lowercased()

    switch command {
    case "generate":
        let text = collectPositionalArgs(from: Array(args.dropFirst()))
        if text.isEmpty {
            fputs("Error: generate requires text argument\n", stderr)
            return .help
        }
        return .generate(text: text, size: size, invert: invert)

    case "text":
        let text = collectPositionalArgs(from: Array(args.dropFirst()))
        if text.isEmpty {
            fputs("Error: text requires text argument\n", stderr)
            return .help
        }
        return .text(text: text, size: size, invert: invert)

    case "url":
        let url = collectPositionalArgs(from: Array(args.dropFirst()))
        if url.isEmpty {
            fputs("Error: url requires a URL argument\n", stderr)
            return .help
        }
        return .url(url: url, size: size, invert: invert)

    case "wifi":
        guard let ssid = findValue("--ssid", in: args) else {
            fputs("Error: wifi requires --ssid\n", stderr)
            return .help
        }
        guard let password = findValue("--password", in: args) else {
            fputs("Error: wifi requires --password\n", stderr)
            return .help
        }
        let security = findValue("--security", in: args) ?? "WPA"
        let validSecurity = ["WPA", "WEP", "nopass"]
        if !validSecurity.contains(security) {
            fputs("Error: --security must be one of: WPA, WEP, nopass\n", stderr)
            return .help
        }
        return .wifi(ssid: ssid, password: password, security: security, size: size, invert: invert)

    case "help", "-h", "--help":
        return .help

    case "version", "--version", "-v":
        return .version

    default:
        // Treat unknown first arg as text to encode directly
        let text = args.joined(separator: " ")
        return .generate(text: text, size: size, invert: invert)
    }
}

/// Collect positional arguments, skipping known flags and their values
func collectPositionalArgs(from args: [String]) -> String {
    var positional: [String] = []
    var i = 0
    while i < args.count {
        let arg = args[i]
        if arg == "--size" || arg == "--ssid" || arg == "--password" || arg == "--security" {
            i += 2
            continue
        }
        if arg == "--invert" {
            i += 1
            continue
        }
        if arg.hasPrefix("-") {
            i += 1
            continue
        }
        positional.append(arg)
        i += 1
    }
    return positional.joined(separator: " ")
}

// MARK: - Core Logic

func generateAndRender(text: String, size: Int?, invert: Bool) {
    guard let matrix = generateQRMatrix(from: text) else {
        fputs("Error: failed to generate QR code for input\n", stderr)
        exit(1)
    }

    let qrModules = matrix.count
    let totalModules = qrModules + 4 // quiet zone
    let termWidth = terminalWidth()

    let moduleSize: Int
    if let s = size {
        moduleSize = max(1, s)
    } else {
        let maxSize = termWidth / totalModules
        moduleSize = max(1, min(2, maxSize))
    }

    renderQR(matrix, invert: invert, moduleSize: moduleSize)
}

// MARK: - Entry Point

@main
struct FledgeQR {
    static func main() {
        let command = parseArgs()

        switch command {
        case .generate(let text, let size, let invert):
            generateAndRender(text: text, size: size, invert: invert)

        case .text(let text, let size, let invert):
            generateAndRender(text: text, size: size, invert: invert)

        case .url(let url, let size, let invert):
            generateAndRender(text: url, size: size, invert: invert)

        case .wifi(let ssid, let password, let security, let size, let invert):
            let encoded = wifiString(ssid: ssid, password: password, security: security)
            generateAndRender(text: encoded, size: size, invert: invert)

        case .help:
            printUsage()

        case .version:
            print("fledge-qr 0.1.0")
        }
    }
}
