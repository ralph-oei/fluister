import AppKit

// Genereert een 1024x1024 macOS-app-icoon: squircle met diagonaal kleurverloop
// (diep indigo → levendig blauw) en een witte mic.fill-glyph. Schrijft PNG naar arg1.

let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon_1024.png"
let S: CGFloat = 1024

let image = NSImage(size: NSSize(width: S, height: S))
image.lockFocus()
guard let ctx = NSGraphicsContext.current?.cgContext else { fatalError("geen context") }

// --- squircle-body (macOS-grid: ~9% marge, continue hoeken) ---
let inset: CGFloat = S * 0.092
let body = CGRect(x: inset, y: inset, width: S - 2*inset, height: S - 2*inset)
let radius = body.width * 0.2237
let path = CGPath(roundedRect: body, cornerWidth: radius, cornerHeight: radius, transform: nil)

// subtiele slagschaduw onder de body
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -S*0.012), blur: S*0.03,
              color: NSColor.black.withAlphaComponent(0.28).cgColor)
ctx.addPath(path); ctx.setFillColor(NSColor.black.cgColor); ctx.fillPath()
ctx.restoreGState()

// --- kleurverloop ---
ctx.saveGState()
ctx.addPath(path); ctx.clip()
let top = NSColor(srgbRed: 0.42, green: 0.36, blue: 0.96, alpha: 1).cgColor    // indigo-violet #6B5CF5
let bottom = NSColor(srgbRed: 0.14, green: 0.20, blue: 0.62, alpha: 1).cgColor // diep indigo #24339E
let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                      colors: [top, bottom] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(grad, start: CGPoint(x: body.minX, y: body.maxY),
                       end: CGPoint(x: body.maxX, y: body.minY), options: [])

// zachte glans bovenaan (radiale highlight)
let glow = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
    colors: [NSColor.white.withAlphaComponent(0.22).cgColor,
             NSColor.white.withAlphaComponent(0.0).cgColor] as CFArray, locations: [0, 1])!
ctx.drawRadialGradient(glow,
    startCenter: CGPoint(x: body.midX, y: body.maxY - body.height*0.12), startRadius: 0,
    endCenter: CGPoint(x: body.midX, y: body.maxY - body.height*0.12), endRadius: body.width*0.7,
    options: [])
ctx.restoreGState()

// --- witte mic.fill-glyph, gecentreerd ---
let glyphPointSize = body.width * 0.55
let cfg = NSImage.SymbolConfiguration(pointSize: glyphPointSize, weight: .medium)
    .applying(NSImage.SymbolConfiguration(paletteColors: [.white]))
if let sym = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: nil)?
    .withSymbolConfiguration(cfg) {
    let gs = sym.size
    let rect = CGRect(x: body.midX - gs.width/2,
                      y: body.midY - gs.height/2,
                      width: gs.width, height: gs.height)
    // lichte schaduw onder de glyph voor diepte
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -S*0.006), blur: S*0.012,
                  color: NSColor(srgbRed: 0.10, green: 0.13, blue: 0.45, alpha: 0.55).cgColor)
    sym.draw(in: rect)
    ctx.restoreGState()
}

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    fatalError("PNG-encode faalde")
}
try! png.write(to: URL(fileURLWithPath: outPath))
print("geschreven: \(outPath)")
