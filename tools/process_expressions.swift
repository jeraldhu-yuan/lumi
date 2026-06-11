import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// Slices a green-screen expression sheet into uniform 256x256 transparent
// frames and packs them into a horizontal strip sheet.
//
//   swift tools/process_expressions.swift <input.png> <output-dir>

let frameNames = ["pleading", "talk_point", "talk_raise", "talk_gesture", "dizzy", "celebrate", "listen"]
let frameSize = 256

guard CommandLine.arguments.count == 3 else {
    fatalError("usage: process_expressions.swift <input.png> <output-dir>")
}
let inputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outputDir = URL(fileURLWithPath: CommandLine.arguments[2])
try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

guard let source = CGImageSourceCreateWithURL(inputURL as CFURL, nil),
      let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
    fatalError("could not load \(inputURL.path)")
}

let width = image.width
let height = image.height
var pixels = [UInt8](repeating: 0, count: width * height * 4)
let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!

pixels.withUnsafeMutableBytes { raw in
    let ctx = CGContext(
        data: raw.baseAddress,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
}

// Chroma key: drop saturated green, despill the rest.
for i in stride(from: 0, to: pixels.count, by: 4) {
    let r = Int(pixels[i]), g = Int(pixels[i + 1]), b = Int(pixels[i + 2])
    if g > 90, g * 2 > r * 3, g * 2 > b * 3 {
        pixels[i] = 0
        pixels[i + 1] = 0
        pixels[i + 2] = 0
        pixels[i + 3] = 0
    } else if g > max(r, b) {
        pixels[i + 1] = UInt8(max(r, b))
    }
}

func alpha(_ x: Int, _ y: Int) -> UInt8 {
    pixels[(y * width + x) * 4 + 3]
}

// Find the sprites as horizontal runs of occupied columns, so each frame's
// crop is masked to its own sprite and neighbors' wings can't bleed in.
let slotCount = frameNames.count
struct Box { var minX: Int; var minY: Int; var maxX: Int; var maxY: Int }

var occupied = [Bool](repeating: false, count: width)
for x in 0..<width {
    for y in 0..<height where alpha(x, y) > 16 {
        occupied[x] = true
        break
    }
}

var runs: [(start: Int, end: Int)] = []
var current: (start: Int, end: Int)?
var gap = 0
for x in 0..<width {
    if occupied[x] {
        if current == nil { current = (x, x) } else { current!.end = x }
        gap = 0
    } else if current != nil {
        gap += 1
        if gap > 8 {
            runs.append(current!)
            current = nil
            gap = 0
        }
    }
}
if let current { runs.append(current) }
runs.removeAll { $0.end - $0.start < 12 }

// Detached sparkle clusters become their own runs; merge across the
// smallest gaps until one run per sprite remains.
while runs.count > slotCount {
    var bestGap = Int.max
    var bestIndex = 0
    for i in 0..<(runs.count - 1) {
        let g = runs[i + 1].start - runs[i].end
        if g < bestGap {
            bestGap = g
            bestIndex = i
        }
    }
    runs[bestIndex] = (runs[bestIndex].start, runs[bestIndex + 1].end)
    runs.remove(at: bestIndex + 1)
}
guard runs.count == slotCount else {
    fatalError("found \(runs.count) sprites, expected \(slotCount)")
}

var boxes: [Box] = []
for run in runs {
    var box = Box(minX: .max, minY: .max, maxX: .min, maxY: .min)
    for y in 0..<height {
        for x in run.start...run.end where alpha(x, y) > 16 {
            box.minX = min(box.minX, x)
            box.maxX = max(box.maxX, x)
            box.minY = min(box.minY, y)
            box.maxY = max(box.maxY, y)
        }
    }
    guard box.maxX >= box.minX else { fatalError("empty sprite run at \(run)") }
    boxes.append(box)
}

// One global scale so the character is the same size in every frame.
let globalExtent = boxes.map { max($0.maxX - $0.minX + 1, $0.maxY - $0.minY + 1) }.max()!
let side = Int(Double(globalExtent) * 1.05)
let bottomPad = Int(Double(side) * 0.02)

func renderFrame(_ box: Box) -> [UInt8] {
    let maskMinX = box.minX - 2
    let maskMaxX = box.maxX + 2
    let centerX = (box.minX + box.maxX) / 2
    let originX = centerX - side / 2
    let originY = box.maxY + bottomPad - side
    let scale = Double(side) / Double(frameSize)

    var out = [UInt8](repeating: 0, count: frameSize * frameSize * 4)
    for dy in 0..<frameSize {
        for dx in 0..<frameSize {
            let sx0 = originX + Int(Double(dx) * scale)
            let sx1 = originX + Int(Double(dx + 1) * scale)
            let sy0 = originY + Int(Double(dy) * scale)
            let sy1 = originY + Int(Double(dy + 1) * scale)
            var sums = [0, 0, 0, 0]
            var count = 0
            for sy in sy0..<max(sy0 + 1, sy1) {
                for sx in sx0..<max(sx0 + 1, sx1) {
                    count += 1
                    guard sx >= maskMinX, sx <= maskMaxX, sx >= 0, sx < width, sy >= 0, sy < height else { continue }
                    let s = (sy * width + sx) * 4
                    for c in 0..<4 { sums[c] += Int(pixels[s + c]) }
                }
            }
            let d = (dy * frameSize + dx) * 4
            for c in 0..<4 { out[d + c] = UInt8(sums[c] / max(1, count)) }
        }
    }
    return out
}

func writePNG(_ buffer: [UInt8], width: Int, height: Int, to url: URL) {
    var copy = buffer
    let cgImage: CGImage = copy.withUnsafeMutableBytes { raw in
        let ctx = CGContext(
            data: raw.baseAddress,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        return ctx.makeImage()!
    }
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, cgImage, nil)
    guard CGImageDestinationFinalize(dest) else { fatalError("could not write \(url.path)") }
}

var sheet = [UInt8](repeating: 0, count: frameSize * slotCount * frameSize * 4)
for (index, box) in boxes.enumerated() {
    let frame = renderFrame(box)
    let name = String(format: "%02d-%@.png", index, frameNames[index])
    writePNG(frame, width: frameSize, height: frameSize, to: outputDir.appendingPathComponent(name))

    let sheetRowBytes = frameSize * slotCount * 4
    for y in 0..<frameSize {
        let src = y * frameSize * 4
        let dst = y * sheetRowBytes + index * frameSize * 4
        sheet.replaceSubrange(dst..<(dst + frameSize * 4), with: frame[src..<(src + frameSize * 4)])
    }
}

writePNG(sheet, width: frameSize * slotCount, height: frameSize, to: outputDir.appendingPathComponent("expressions-sheet.png"))
print("Wrote \(slotCount) frames + expressions-sheet.png (side=\(side)px source scale) to \(outputDir.path)")
