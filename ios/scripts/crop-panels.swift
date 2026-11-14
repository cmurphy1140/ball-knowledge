// Cuts a 2 x 3 "Historic NFL Games" collage into one picture per game.
// Usage: swift crop-panels.swift <collage> <dest folder> <key1> ... <key6>
// Panels run left to right, top to bottom. A key of "-" skips that panel.
import AppKit

let args = CommandLine.arguments
guard args.count == 9, let src = NSImage(contentsOfFile: args[1]),
      let cg = src.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    FileHandle.standardError.write("usage: crop-panels.swift <collage> <dest> <6 keys>\n".data(using: .utf8)!)
    exit(1)
}
// Panel geometry measured on a 1024 x 1024 collage, just inside each panel's border.
let scale = CGFloat(cg.width) / 1024
let xs: [CGFloat] = [33, 531], ys: [CGFloat] = [133, 433, 733]
let w: CGFloat = 460, h: CGFloat = 266
for (i, key) in args[3...].enumerated() where key != "-" {
    let rect = CGRect(x: xs[i % 2] * scale, y: ys[i / 2] * scale, width: w * scale, height: h * scale).integral
    guard let cut = cg.cropping(to: rect) else { continue }
    let rep = NSBitmapImageRep(cgImage: cut)
    guard let data = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.88]) else { continue }
    let out = URL(fileURLWithPath: args[2]).appendingPathComponent(key + ".jpg")
    try data.write(to: out)
    print("  games/\(key).jpg  <-  panel \(i + 1) of \(URL(fileURLWithPath: args[1]).lastPathComponent)")
}
