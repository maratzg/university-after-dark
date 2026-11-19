import AppKit
import Foundation
let output = CommandLine.arguments[1]
let image = NSImage(size: NSSize(width: 1024, height: 1024))
image.lockFocus()
let rect = NSRect(x: 48, y: 48, width: 928, height: 928)
let background = NSBezierPath(roundedRect: rect, xRadius: 205, yRadius: 205)
NSColor(calibratedRed: 0.035, green: 0.03, blue: 0.04, alpha: 1).setFill(); background.fill()
let shadow = NSShadow(); shadow.shadowColor = NSColor(calibratedRed: 0.76, green: 0.07, blue: 0.21, alpha: 0.45); shadow.shadowBlurRadius = 90
NSGraphicsContext.saveGraphicsState(); shadow.set()
let card = NSBezierPath(roundedRect: NSRect(x: 237, y: 175, width: 550, height: 680), xRadius: 32, yRadius: 32)
NSColor(calibratedRed: 0.18, green: 0.045, blue: 0.075, alpha: 1).setFill(); card.fill()
NSColor(calibratedRed: 0.75, green: 0.07, blue: 0.2, alpha: 1).setStroke(); card.lineWidth = 4; card.stroke()
NSGraphicsContext.restoreGraphicsState()
let inset = NSBezierPath(roundedRect: NSRect(x: 258, y: 196, width: 508, height: 638), xRadius: 18, yRadius: 18)
NSColor(calibratedRed: 0.79, green: 0.65, blue: 0.42, alpha: 0.3).setStroke(); inset.lineWidth = 2; inset.stroke()
let style = NSMutableParagraphStyle(); style.alignment = .center
let font = NSFont(name: "Baskerville", size: 410) ?? NSFont.systemFont(ofSize: 410)
("?" as NSString).draw(in: NSRect(x: 237, y: 270, width: 550, height: 490), withAttributes: [.font: font, .foregroundColor: NSColor(calibratedRed: 1, green: 0.14, blue: 0.31, alpha: 1), .paragraphStyle: style])
("U N I V E R S I T Y" as NSString).draw(in: NSRect(x: 237, y: 740, width: 550, height: 50), withAttributes: [.font: NSFont.systemFont(ofSize: 25, weight: .medium), .foregroundColor: NSColor(calibratedRed: 0.79, green: 0.65, blue: 0.42, alpha: 1), .paragraphStyle: style])
("A F T E R  D A R K" as NSString).draw(in: NSRect(x: 237, y: 240, width: 550, height: 55), withAttributes: [.font: NSFont.systemFont(ofSize: 29, weight: .medium), .foregroundColor: NSColor.white, .paragraphStyle: style])
image.unlockFocus()
let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: output))
