import Foundation

enum ReadmeService {
    static func exists(at directory: URL) -> Bool {
        let file = directory.appendingPathComponent("README.md")
        return FileManager.default.fileExists(atPath: file.path)
            || (try? FileManager.default.destinationOfSymbolicLink(atPath: file.path)) != nil
    }

    /// 排他创建也保护并发出现的文件和符号链接，不覆盖任何已有内容。
    static func create(at directory: URL) throws {
        try Data().write(to: directory.appendingPathComponent("README.md"), options: .withoutOverwriting)
    }
}
