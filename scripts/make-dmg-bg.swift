import AppKit

// Genereert de DMG-achtergrond (640x400 @2x = 1280x800): titel, een indigo pijl
// van links (app) naar rechts (Programma's) en een instructie-caption. De twee
// icoon-plekken (Finder tekent ze erover) blijven leeg.

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "dmg-bg.png"
let scale: CGFloat = 2
let W: CGFloat = 640 * scale
let H: CGFloat = 400 * scale

let img = NSImage(size: NSSize(width: W, height: H))
img.lockFocus()
let ctx = NSGraphicsContext.current!.cgContext

// achtergrond: zacht off-white met heel subtiele indigo-tint bovenaan
let bg = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [
    NSColor(srgbRed: 0.96, green: 0.96, blue: 0.99, alpha: 1).cgColor,
    NSColor(srgbRed: 0.99, green: 0.99, blue: 1.00, alpha: 1).cgColor,
] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(bg, start: CGPoint(x: 0, y: H), end: CGPoint(x: 0, y: 0), options: [])

// Finder-icoonrij ligt op y_finder≈210 (CG-y = H - 210*scale). Icoon-midpunten:
// app op x_finder≈165, Programma's op x_finder≈475.
func cgY(_ finderY: CGFloat) -> CGFloat { H - finderY * scale }
let rowY = cgY(200)

// --- indigo pijl in de tussenruimte (x_finder ~255 → ~385) ---
let indigo = NSColor(srgbRed: 0.42, green: 0.36, blue: 0.96, alpha: 1)
let ax0 = 258 * scale, ax1 = 382 * scale
let shaftH = 7 * scale
ctx.setFillColor(indigo.cgColor)
// schacht
ctx.fill(CGRect(x: ax0, y: rowY - shaftH/2, width: (ax1 - ax0) - 18*scale, height: shaftH))
// pijlpunt
ctx.beginPath()
let tipX = ax1, baseX = ax1 - 22*scale, half = 15*scale
ctx.move(to: CGPoint(x: tipX, y: rowY))
ctx.addLine(to: CGPoint(x: baseX, y: rowY + half))
ctx.addLine(to: CGPoint(x: baseX, y: rowY - half))
ctx.closePath()
ctx.fillPath()

// --- teksten ---
func draw(_ s: String, size: CGFloat, weight: NSFont.Weight, color: NSColor, centerX: CGFloat, finderY: CGFloat) {
    let font = NSFont.systemFont(ofSize: size * scale, weight: weight)
    let para = NSMutableParagraphStyle(); para.alignment = .center
    let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color, .paragraphStyle: para]
    let str = NSAttributedString(string: s, attributes: attrs)
    let sz = str.size()
    // finderY = baseline-ish bovenkant; teken met CG-y
    let y = cgY(finderY) - sz.height/2
    str.draw(in: CGRect(x: centerX - W, y: y, width: 2*W, height: sz.height))
}

let ink = NSColor(srgbRed: 0.11, green: 0.11, blue: 0.17, alpha: 1)
let sub = NSColor(srgbRed: 0.42, green: 0.42, blue: 0.50, alpha: 1)
draw("Fluister installeren", size: 26, weight: .bold, color: ink, centerX: W/2, finderY: 60)
draw("Sleep het Fluister-icoon naar de map Programma's", size: 14, weight: .regular, color: sub, centerX: W/2, finderY: 300)
draw("Open daarna Fluister vanuit Launchpad of Programma's", size: 12.5, weight: .regular, color: sub, centerX: W/2, finderY: 330)

img.unlockFocus()
let tiff = img.tiffRepresentation!
let rep = NSBitmapImageRep(data: tiff)!
// Cruciaal: tag als Retina @2x. Zonder dit toont Finder de 1280×800-afbeelding
// op 1:1 (1280 punten) en zie je maar de linkerhelft in het 640pt-venster.
rep.size = NSSize(width: W / scale, height: H / scale)   // 1280×800 px @144dpi → 640×400 pt
let png = rep.representation(using: .png, properties: [:])!
try! png.write(to: URL(fileURLWithPath: out))
print("geschreven: \(out) (\(Int(W))×\(Int(H))px als \(Int(W/scale))×\(Int(H/scale))pt)")
