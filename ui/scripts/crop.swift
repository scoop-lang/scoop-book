// 裁剪 PNG：保留从 (x, y) 开始、宽 w 高 h 的区域，单位为像素；省略 w、h 时一直保留到右边和底边。
// 用法：swift scripts/crop.swift 输入.png 输出.png x y [w h]
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

func fail(_ message: String, _ code: Int32) -> Never {
    FileHandle.standardError.write((message + "\n").data(using: .utf8)!)
    exit(code)
}

let args = CommandLine.arguments
guard args.count == 5 || args.count == 7,
      let x = Int(args[3]), let y = Int(args[4]) else {
    fail("用法：crop.swift 输入.png 输出.png x y [w h]", 2)
}
guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: args[1]) as CFURL, nil),
      let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
    fail("无法读取 \(args[1])", 1)
}
let width = args.count == 7 ? Int(args[5])! : image.width - x
let height = args.count == 7 ? Int(args[6])! : image.height - y
guard let cropped = image.cropping(to: CGRect(x: x, y: y, width: width, height: height)),
      let destination = CGImageDestinationCreateWithURL(
          URL(fileURLWithPath: args[2]) as CFURL, UTType.png.identifier as CFString, 1, nil) else {
    fail("无法裁剪 \(args[1])", 1)
}
CGImageDestinationAddImage(destination, cropped, nil)
guard CGImageDestinationFinalize(destination) else { fail("无法写入 \(args[2])", 1) }
print("\(args[2])：\(cropped.width)×\(cropped.height)")
