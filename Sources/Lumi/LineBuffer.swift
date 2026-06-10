import Foundation

/// Accumulates raw stream chunks and yields complete newline-terminated lines.
struct LineBuffer {
    private var buffer = Data()

    mutating func append(_ chunk: Data) -> [Data] {
        buffer.append(chunk)
        var lines: [Data] = []
        while let newlineIndex = buffer.firstIndex(of: 0x0A) {
            let line = buffer.subdata(in: buffer.startIndex..<newlineIndex)
            buffer.removeSubrange(buffer.startIndex...newlineIndex)
            if !line.isEmpty {
                lines.append(line)
            }
        }
        return lines
    }
}
