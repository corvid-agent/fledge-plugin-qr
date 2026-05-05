# fledge-plugin-qr

Generate QR codes in the terminal -- text, URLs, WiFi, and more.

A [fledge](https://github.com/CorvidLabs/fledge) plugin that renders QR codes directly in your terminal using Unicode half-block characters. Uses macOS CoreImage for QR generation -- no external dependencies.

## Install

```bash
fledge plugins install corvid-agent/fledge-plugin-qr
```

## Commands

| Command | Description |
|---------|-------------|
| `fledge qr generate <text>` | Generate a QR code from text |
| `fledge qr text <text>` | Alias for generate |
| `fledge qr url <url>` | Generate a QR code from a URL |
| `fledge qr wifi` | Generate a WiFi QR code |

### Options

- `--size <n>` -- Module size (default: auto-detect based on terminal width)
- `--invert` -- Invert colors for light terminal backgrounds

### WiFi options

- `--ssid <name>` -- WiFi network name (required)
- `--password <pass>` -- WiFi password (required)
- `--security <type>` -- Security type: WPA, WEP, nopass (default: WPA)

## Examples

```bash
# Generate a QR code from text
fledge qr generate "Hello, World!"

# Generate a QR code from a URL
fledge qr url https://example.com

# Generate a WiFi QR code
fledge qr wifi --ssid MyNetwork --password secret123

# Invert colors for light terminals
fledge qr generate "Hello" --invert

# Set module size
fledge qr url https://example.com --size 1
```

## Requirements

- macOS 12+ (uses CoreImage for QR generation)
- Swift 5.7+

## Development

```bash
swift build -c release
./build.sh
```

## License

MIT
