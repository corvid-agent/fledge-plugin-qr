import SwiftQR
import Foundation

// MARK: - Terminal Rendering

func renderQR(_ qr: QRCode, invert: Bool, moduleSize: Int) {
    let size = qr.size
    let quietZone = 2
    let totalHeight = size + 2 * quietZone
    let totalWidth = size + 2 * quietZone

    func isDark(_ row: Int, _ col: Int) -> Bool {
        let r = row - quietZone
        let c = col - quietZone
        if r < 0 || r >= size || c < 0 || c >= size { return false }
        let val = qr.module(at: c, y: r)
        return invert ? !val : val
    }

    var row = 0
    while row < totalHeight {
        var line = ""
        for col in 0..<totalWidth {
            let topDark = isDark(row, col)
            let botDark = (row + 1 < totalHeight) ? isDark(row + 1, col) : false

            let ch: String
            if topDark && botDark {
                ch = "\u{2588}"
            } else if topDark && !botDark {
                ch = "\u{2580}"
            } else if !topDark && botDark {
                ch = "\u{2584}"
            } else {
                ch = " "
            }

            for _ in 0..<moduleSize {
                line += ch
            }
        }
        print(line)
        row += 2
    }
}

// MARK: - WiFi String

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

// MARK: - Terminal Width

func terminalWidth() -> Int {
    var ws = winsize()
    if ioctl(STDOUT_FILENO, TIOCGWINSZ, &ws) == 0 && ws.ws_col > 0 {
        return Int(ws.ws_col)
    }
    return 80
}

// MARK: - CLI

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

func findFlag(_ name: String, in args: [String]) -> Bool {
    args.contains(name)
}

func findValue(_ name: String, in args: [String]) -> String? {
    guard let idx = args.firstIndex(of: name), idx + 1 < args.count else { return nil }
    return args[idx + 1]
}

func collectPositionalArgs(from args: [String]) -> String {
    var positional: [String] = []
    var i = 0
    while i < args.count {
        let arg = args[i]
        if arg == "--size" || arg == "--ssid" || arg == "--password" || arg == "--security" {
            i += 2
            continue
        }
        if arg == "--invert" || arg.hasPrefix("-") {
            i += 1
            continue
        }
        positional.append(arg)
        i += 1
    }
    return positional.joined(separator: " ")
}

func generateAndRender(text: String, size: Int?, invert: Bool) {
    do {
        let qr = try QRCode.encode(text, errorCorrection: .low)
        let totalModules = qr.size + 4
        let termWidth = terminalWidth()

        let moduleSize: Int
        if let s = size {
            moduleSize = max(1, s)
        } else {
            let maxSize = termWidth / totalModules
            moduleSize = max(1, min(2, maxSize))
        }

        renderQR(qr, invert: invert, moduleSize: moduleSize)
    } catch {
        fputs("Error: failed to generate QR code — \(error)\n", stderr)
        exit(1)
    }
}

// MARK: - Entry Point

@main
struct FledgeQR {
    static func main() {
        let args = Array(CommandLine.arguments.dropFirst())

        if args.isEmpty {
            printUsage()
            return
        }

        let invert = findFlag("--invert", in: args)
        let sizeStr = findValue("--size", in: args)
        let size = sizeStr.flatMap { Int($0) }

        let command = args[0].lowercased()

        switch command {
        case "generate", "text":
            let text = collectPositionalArgs(from: Array(args.dropFirst()))
            if text.isEmpty {
                fputs("Error: \(command) requires text argument\n", stderr)
                printUsage()
                exit(1)
            }
            generateAndRender(text: text, size: size, invert: invert)

        case "url":
            let url = collectPositionalArgs(from: Array(args.dropFirst()))
            if url.isEmpty {
                fputs("Error: url requires a URL argument\n", stderr)
                printUsage()
                exit(1)
            }
            generateAndRender(text: url, size: size, invert: invert)

        case "wifi":
            guard let ssid = findValue("--ssid", in: args) else {
                fputs("Error: wifi requires --ssid\n", stderr)
                exit(1)
            }
            guard let password = findValue("--password", in: args) else {
                fputs("Error: wifi requires --password\n", stderr)
                exit(1)
            }
            let security = findValue("--security", in: args) ?? "WPA"
            if !["WPA", "WEP", "nopass"].contains(security) {
                fputs("Error: --security must be one of: WPA, WEP, nopass\n", stderr)
                exit(1)
            }
            let encoded = wifiString(ssid: ssid, password: password, security: security)
            generateAndRender(text: encoded, size: size, invert: invert)

        case "help", "-h", "--help":
            printUsage()

        case "version", "--version", "-v":
            print("fledge-qr 0.1.0")

        default:
            let text = args.joined(separator: " ")
            generateAndRender(text: text, size: size, invert: invert)
        }
    }
}
