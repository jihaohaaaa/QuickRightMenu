import SwiftUI
import Cocoa
import Carbon

@main
struct QuickRightMenuApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @ObservedObject var settingsManager = SettingsManager.shared
    
    var body: some Scene {
        MenuBarExtra {
            Text("QuickRightMenu 正在运行")
            Divider()
            Button("设置...") {
                showSettingsWindow()
            }
            .keyboardShortcut(",", modifiers: .command)
            Button("退出") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        } label: {
            Image(systemName: "contextualmenu.and.cursorarrow")
        }
    }
    
    private func showSettingsWindow() {
        SettingsWindowController.shared.show()
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    
    private var commandTimer: Timer?
    private var processedCommandPaths = Set<String>()
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 首次打开逻辑与事件绑定
        setupAppleEvents()
        
        // 开启 0.3s 定时器轮询命令文件
        commandTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            self?.pollCommandFiles()
        }
        
        // 自动检查更新
        UpdateManager.shared.checkForUpdatesSilently()
        
        // 如果是首次启动，自动弹出设置页面展示权限指引
        let hasSeenGuide = SettingsManager.shared.settings["hasSeenPermissionGuide"] as? Bool ?? false
        if !hasSeenGuide {
            DispatchQueue.main.async {
                SettingsWindowController.shared.show()
            }
        }
    }
    
    private func setupAppleEvents() {
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleGetURLEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }
    
    @objc private func handleGetURLEvent(_ event: NSAppleEventDescriptor, withReplyEvent replyEvent: NSAppleEventDescriptor) {
        if let urlString = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue {
            handleCommandURLString(urlString, source: "URL event")
        }
    }
    
    private func pollCommandFiles() {
        let fileManager = FileManager.default
        let directory = commandDirectoryURL()
        guard let files = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) else {
            return
        }
        
        for fileURL in files {
            guard fileURL.pathExtension == "cmd" else { continue }
            if processedCommandPaths.contains(fileURL.path) { continue }
            
            processedCommandPaths.insert(fileURL.path)
            if let urlString = try? String(contentsOf: fileURL, encoding: .utf8) {
                handleCommandURLString(urlString, source: "command file")
            }
            try? fileManager.removeItem(at: fileURL)
        }
    }
    
    private func commandDirectoryURL() -> URL {
        return CentralStorage.commandsDirectoryURL
    }
    
    func log(_ message: String) {
        NSLog("QuickRightMenu App: %@", message)
        let line = "\(Date()) App: \(message)\n"
        let fileURL = CentralStorage.logFileURL
        if let data = line.data(using: .utf8) {
            if let handle = try? FileHandle(forWritingTo: fileURL) {
                handle.seekToEndOfFile()
                handle.write(data)
                handle.closeFile()
            } else {
                try? data.write(to: fileURL, options: .atomic)
            }
        }
    }
    
    private func handleCommandURLString(_ urlString: String, source: String) {
        log("\(source) \(urlString)")
        guard let components = URLComponents(string: urlString), components.scheme == "quickrightmenu" else { return }
        
        let command = components.host ?? ""
        var params: [String: String] = [:]
        if let queryItems = components.queryItems {
            for item in queryItems {
                if let val = item.value {
                    params[item.name] = val
                }
            }
        }
        
        let directory = URL(fileURLWithPath: params["dir"] ?? NSHomeDirectory())
        let pathsString = params["paths"] ?? ""
        
        switch command {
        case "create":
            let templateId = params["tid"] ?? ""
            let fallbackExt = params["ext"] ?? "txt"
            let (extensionName, contents) = templateForIdOrExtension(templateId: templateId, fallbackExt: fallbackExt)
            createFile(in: directory, baseName: "Untitled", extensionName: extensionName, contents: contents)
        case "copy-path":
            copyToPasteboard(copyValueForMode("path", paths: pathsString, directory: directory), label: "paths")
        case "copy-name":
            copyToPasteboard(copyValueForMode("name", paths: pathsString, directory: directory), label: "names")
        case "copy-parent":
            copyToPasteboard(copyValueForMode("parent", paths: pathsString, directory: directory), label: "parents")
        case "copy-file-url":
            copyToPasteboard(copyValueForMode("file-url", paths: pathsString, directory: directory), label: "file URLs")
        case "copy-markdown-link":
            copyToPasteboard(copyValueForMode("markdown-link", paths: pathsString, directory: directory), label: "markdown links")
        case "batch-rename":
            batchRenamePaths(pathsString, directory: directory)
        case "image-copy-size":
            copyImageSizes(pathsString, directory: directory)
        case "image-compress":
            convertImages(pathsString, directory: directory, format: "jpg-compressed")
        case "image-convert-png":
            convertImages(pathsString, directory: directory, format: "png")
        case "image-convert-jpeg":
            convertImages(pathsString, directory: directory, format: "jpg")
        case "image-convert-webp":
            convertImages(pathsString, directory: directory, format: "webp")
        case "text-stats":
            showTextStats(pathsString, directory: directory)
        case "text-to-utf8":
            convertTextFilesToUTF8(pathsString, directory: directory)
        case "text-preview":
            previewText(pathsString, directory: directory)
        case "terminal":
            openTerminal(at: directory)
        case "vscode":
            openVSCode(paths: pathsString, directory: directory)
        default:
            if command.hasPrefix("copy-to-") {
                let key = String(command.dropFirst("copy-to-".count))
                transferPaths(pathsString, directory: directory, destinationKey: key, move: false)
            } else if command.hasPrefix("move-to-") {
                let key = String(command.dropFirst("move-to-".count))
                transferPaths(pathsString, directory: directory, destinationKey: key, move: true)
            } else {
                log("unknown command \(command)")
            }
        }
    }
    
    // MARK: - Core Functions Implementation
    
    private func templateForIdOrExtension(templateId: String, fallbackExt: String) -> (String, String) {
        let templates = SettingsManager.shared.customTemplates
        if !templateId.isEmpty {
            if let found = templates.first(where: { $0.id == templateId }) {
                return (found.extensionName, found.content)
            }
        }
        if let found = templates.first(where: { $0.extensionName.lowercased() == fallbackExt.lowercased() }) {
            return (found.extensionName, found.content)
        }
        return (fallbackExt, "")
    }
    
    private func createFile(in directory: URL, baseName: String, extensionName: String, contents: String) {
        let fileURL = uniqueFileURL(in: directory, baseName: baseName, extensionName: extensionName)
        if isOfficeExtension(extensionName) {
            createOfficeFile(at: fileURL, extensionName: extensionName)
            return
        }
        
        do {
            try contents.write(to: fileURL, atomically: true, encoding: .utf8)
            log("created \(fileURL.path)")
            NSWorkspace.shared.activateFileViewerSelecting([fileURL])
        } catch {
            log("create failed \(error.localizedDescription)")
            showError("创建文件失败：\(error.localizedDescription)")
        }
    }
    
    private func isOfficeExtension(_ ext: String) -> Bool {
        return ext == "docx" || ext == "xlsx" || ext == "pptx"
    }
    
    private func createOfficeFile(at fileURL: URL, extensionName: String) {
        let tempRoot = (NSTemporaryDirectory() as NSString).appendingPathComponent("QuickRightMenuOffice-\(UUID().uuidString)-\(arc4random_uniform(1000000))")
        let tempURL = URL(fileURLWithPath: tempRoot)
        let fileManager = FileManager.default
        
        var prepared = false
        do {
            try fileManager.createDirectory(at: tempURL, withIntermediateDirectories: true, attributes: nil)
            prepared = try writeOfficePackage(at: tempURL, extensionName: extensionName)
            if prepared && fileManager.fileExists(atPath: fileURL.path) {
                try fileManager.removeItem(at: fileURL)
            }
            if prepared {
                prepared = try zipDirectory(at: tempURL, to: fileURL)
            }
        } catch {
            log("office create preparation failed: \(error.localizedDescription)")
        }
        
        try? fileManager.removeItem(at: tempURL)
        
        if prepared {
            log("created \(fileURL.path)")
            NSWorkspace.shared.activateFileViewerSelecting([fileURL])
        } else {
            log("office create failed")
            showError("创建 Office 文件失败")
        }
    }
    
    private func writeOfficePackage(at rootURL: URL, extensionName: String) throws -> Bool {
        if extensionName == "docx" {
            try writeOfficeFile("[Content_Types].xml", contents: "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\"><Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/><Default Extension=\"xml\" ContentType=\"application/xml\"/><Override PartName=\"/word/document.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml\"/></Types>\n", rootURL: rootURL)
            try writeOfficeFile("_rels/.rels", contents: "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument\" Target=\"word/document.xml\"/></Relationships>\n", rootURL: rootURL)
            try writeOfficeFile("word/document.xml", contents: "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:body><w:p/><w:sectPr><w:pgSz w:w=\"11906\" w:h=\"16838\"/><w:pgMar w:top=\"1440\" w:right=\"1440\" w:bottom=\"1440\" w:left=\"1440\"/></w:sectPr></w:body></w:document>\n", rootURL: rootURL)
            return true
        }
        if extensionName == "xlsx" {
            try writeOfficeFile("[Content_Types].xml", contents: "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\"><Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/><Default Extension=\"xml\" ContentType=\"application/xml\"/><Override PartName=\"/xl/workbook.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml\"/><Override PartName=\"/xl/worksheets/sheet1.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml\"/></Types>\n", rootURL: rootURL)
            try writeOfficeFile("_rels/.rels", contents: "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument\" Target=\"xl/workbook.xml\"/></Relationships>\n", rootURL: rootURL)
            try writeOfficeFile("xl/workbook.xml", contents: "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n<workbook xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\"><sheets><sheet name=\"Sheet1\" sheetId=\"1\" r:id=\"rId1\"/></sheets></workbook>\n", rootURL: rootURL)
            try writeOfficeFile("xl/_rels/workbook.xml.rels", contents: "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet\" Target=\"worksheets/sheet1.xml\"/></Relationships>\n", rootURL: rootURL)
            try writeOfficeFile("xl/worksheets/sheet1.xml", contents: "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n<worksheet xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\"><sheetData/></worksheet>\n", rootURL: rootURL)
            return true
        }
        if extensionName == "pptx" {
            try writeOfficeFile("[Content_Types].xml", contents: "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\"><Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/><Default Extension=\"xml\" ContentType=\"application/xml\"/><Override PartName=\"/ppt/presentation.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml\"/><Override PartName=\"/ppt/slides/slide1.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.presentationml.slide+xml\"/></Types>\n", rootURL: rootURL)
            try writeOfficeFile("_rels/.rels", contents: "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument\" Target=\"ppt/presentation.xml\"/></Relationships>\n", rootURL: rootURL)
            try writeOfficeFile("ppt/presentation.xml", contents: "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n<p:presentation xmlns:p=\"http://schemas.openxmlformats.org/presentationml/2006/main\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\"><p:sldIdLst><p:sldId id=\"256\" r:id=\"rId1\"/></p:sldIdLst><p:sldSz cx=\"9144000\" cy=\"5143500\" type=\"screen16x9\"/></p:presentation>\n", rootURL: rootURL)
            try writeOfficeFile("ppt/_rels/presentation.xml.rels", contents: "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide\" Target=\"slides/slide1.xml\"/></Relationships>\n", rootURL: rootURL)
            try writeOfficeFile("ppt/slides/slide1.xml", contents: "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n<p:sld xmlns:p=\"http://schemas.openxmlformats.org/presentationml/2006/main\" xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\"><p:cSld><p:spTree><p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr><a:xfrm><a:off x=\"0\" y=\"0\"/><a:ext cx=\"0\" cy=\"0\"/><a:chOff x=\"0\" y=\"0\"/><a:chExt cx=\"0\" cy=\"0\"/></a:xfrm></p:grpSpPr></p:spTree></p:cSld></p:sld>\n", rootURL: rootURL)
            return true
        }
        return false
    }
    
    private func writeOfficeFile(_ relativePath: String, contents: String, rootURL: URL) throws {
        let fileURL = rootURL.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
        try contents.write(to: fileURL, atomically: true, encoding: .utf8)
    }
    
    private func zipDirectory(at directoryURL: URL, to fileURL: URL) throws -> Bool {
        let task = Process()
        task.launchPath = "/usr/bin/zip"
        task.currentDirectoryURL = directoryURL
        task.arguments = ["-qr", fileURL.path, "."]
        try task.run()
        task.waitUntilExit()
        return task.terminationStatus == 0
    }
    
    private func copyToPasteboard(_ value: String, label: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(value, forType: .string)
        log("copied \(label) \(value)")
    }
    
    private func copyValueForMode(_ mode: String, paths: String, directory: URL) -> String {
        let items = pathListFromString(paths, fallback: directory.path)
        var values: [String] = []
        for path in items {
            switch mode {
            case "path":
                values.append(path)
            case "name":
                values.append(URL(fileURLWithPath: path).lastPathComponent)
            case "parent":
                values.append(URL(fileURLWithPath: path).deletingLastPathComponent().path)
            case "file-url":
                values.append(URL(fileURLWithPath: path).absoluteString)
            case "markdown-link":
                let name = URL(fileURLWithPath: path).lastPathComponent
                let url = URL(fileURLWithPath: path).absoluteString
                values.append("[\(name.isEmpty ? path : name)](\(url))")
            default:
                break
            }
        }
        return values.joined(separator: "\n")
    }
    
    private func pathListFromString(_ paths: String, fallback: String?) -> [String] {
        var items = paths.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        if items.isEmpty, let fallbackStr = fallback {
            items.append(fallbackStr)
        }
        return items
    }
    
    private func transferPaths(_ paths: String, directory: URL, destinationKey: String, move: Bool) {
        log("transfer move=\(move) destination=\(destinationKey) paths=\(paths) directory=\(directory.path)")
        
        var destDir: URL?
        if destinationKey.lowercased() == "choose" {
            destDir = chooseDestinationDirectory(move: move)
        } else {
            destDir = destinationDirectoryForKey(destinationKey)
        }
        
        guard let destinationDirectory = destDir else { return }
        
        let items = pathListFromString(paths, fallback: nil)
        if items.isEmpty {
            log("transfer failed: empty selected paths")
            showError("没有拿到选中的文件。请先选中文件后再用“复制到/移动到”。")
            return
        }
        
        let fileManager = FileManager.default
        do {
            try fileManager.createDirectory(at: destinationDirectory, withIntermediateDirectories: true, attributes: nil)
        } catch {
            showError("创建目标目录失败：\(error.localizedDescription)")
            return
        }
        
        var completedURLs: [URL] = []
        for path in items {
            let sourceURL = URL(fileURLWithPath: path)
            let targetURL = uniqueDestinationURL(for: sourceURL, in: destinationDirectory)
            do {
                if move {
                    try fileManager.moveItem(at: sourceURL, to: targetURL)
                } else {
                    try fileManager.copyItem(at: sourceURL, to: targetURL)
                }
                log("transfer ok \(sourceURL.path) -> \(targetURL.path)")
                completedURLs.append(targetURL)
            } catch {
                let verb = move ? "移动" : "复制"
                log("transfer failed \(sourceURL.path) -> \(targetURL.path) \(error.localizedDescription)")
                showError("\(verb)失败：\(sourceURL.path)\n\(error.localizedDescription)")
                return
            }
        }
        
        if !completedURLs.isEmpty {
            NSWorkspace.shared.activateFileViewerSelecting(completedURLs)
        }
    }
    
    private func chooseDestinationDirectory(move: Bool) -> URL? {
        NSApp.activate(ignoringOtherApps: true)
        let panel = NSOpenPanel()
        panel.title = move ? "选择移动到的文件夹" : "选择复制到的文件夹"
        panel.prompt = move ? "移动到这里" : "复制到这里"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        
        if panel.runModal() == .OK {
            return panel.url
        }
        return nil
    }
    
    private func destinationDirectoryForKey(_ key: String) -> URL? {
        if key.lowercased().hasPrefix("favorite") {
            let slot = String(key.lowercased().dropFirst("favorite".count))
            if let path = SettingsManager.shared.settings["favoriteDir\(slot)Path"] as? String, !path.isEmpty {
                return URL(fileURLWithPath: path)
            }
            return nil
        }
        
        let mapping: [String: FileManager.SearchPathDirectory] = [
            "desktop": .desktopDirectory,
            "documents": .documentDirectory,
            "downloads": .downloadsDirectory,
            "pictures": .picturesDirectory,
            "movies": .moviesDirectory,
            "music": .musicDirectory
        ]
        
        guard let searchDir = mapping[key.lowercased()] else { return nil }
        return FileManager.default.urls(for: searchDir, in: .userDomainMask).first
    }
    
    private func uniqueDestinationURL(for sourceURL: URL, in directory: URL) -> URL {
        let filename = !sourceURL.lastPathComponent.isEmpty ? sourceURL.lastPathComponent : "Untitled"
        var candidate = directory.appendingPathComponent(filename)
        if !FileManager.default.fileExists(atPath: candidate.path) {
            return candidate
        }
        
        let ext = sourceURL.pathExtension
        let baseName = !ext.isEmpty ? sourceURL.deletingPathExtension().lastPathComponent : filename
        var index = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            let nextName = !ext.isEmpty ? "\(baseName) \(index).\(ext)" : "\(baseName) \(index)"
            candidate = directory.appendingPathComponent(nextName)
            index += 1
        }
        return candidate
    }
    
    private func uniqueFileURL(in directory: URL, baseName: String, extensionName: String) -> URL {
        var candidate = directory.appendingPathComponent("\(baseName).\(extensionName)")
        var index = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = directory.appendingPathComponent("\(baseName) \(index).\(extensionName)")
            index += 1
        }
        return candidate
    }
    
    private func batchRenamePaths(_ paths: String, directory: URL) {
        let items = pathListFromString(paths, fallback: nil).sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        if items.isEmpty {
            showError("没有拿到选中的文件。请先选中文件后再批量重命名。")
            return
        }
        
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "批量重命名"
        alert.informativeText = "输入新文件名前缀。会保留原扩展名，并自动添加 001、002、003。"
        alert.addButton(withTitle: "重命名")
        alert.addButton(withTitle: "取消")
        
        let input = NSTextField(frame: NSMakeRect(0, 0, 280, 28))
        input.stringValue = "文件"
        alert.accessoryView = input
        
        if alert.runModal() != .alertFirstButtonReturn { return }
        
        let prefix = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if prefix.isEmpty {
            showError("文件名前缀不能为空")
            return
        }
        
        let fileManager = FileManager.default
        var renamedURLs: [URL] = []
        var index = 1
        let width = max(3, String(items.count).count)
        
        for path in items {
            let sourceURL = URL(fileURLWithPath: path)
            let ext = sourceURL.pathExtension
            let number = String(format: "%0*ld", width, index)
            let filename = !ext.isEmpty ? "\(prefix) \(number).\(ext)" : "\(prefix) \(number)"
            
            var targetURL = sourceURL.deletingLastPathComponent().appendingPathComponent(filename)
            targetURL = uniqueDestinationURL(for: targetURL, in: sourceURL.deletingLastPathComponent())
            
            do {
                try fileManager.moveItem(at: sourceURL, to: targetURL)
                renamedURLs.append(targetURL)
                index += 1
            } catch {
                showError("重命名失败：\(sourceURL.path)\n\(error.localizedDescription)")
                return
            }
        }
        
        if !renamedURLs.isEmpty {
            NSWorkspace.shared.activateFileViewerSelecting(renamedURLs)
        }
    }
    
    private func copyImageSizes(_ paths: String, directory: URL) {
        let items = pathListFromString(paths, fallback: nil)
        if items.isEmpty {
            showError("没有拿到选中的图片文件")
            return
        }
        
        var lines: [String] = []
        for path in items {
            guard let info = imageInfo(at: path) else { continue }
            lines.append("\(URL(fileURLWithPath: path).lastPathComponent): \(info.width) x \(info.height) px")
        }
        
        if lines.isEmpty {
            showError("没有识别到可读取尺寸的图片")
            return
        }
        
        let result = lines.joined(separator: "\n")
        copyToPasteboard(result, label: "image sizes")
        showInfo("图片尺寸已复制", details: result)
    }
    
    private struct ImageInfo {
        let width: Int
        let height: Int
    }
    
    private func imageInfo(at path: String) -> ImageInfo? {
        let url = URL(fileURLWithPath: path)
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] else { return nil }
        guard let width = properties[kCGImagePropertyPixelWidth as String] as? Int,
              let height = properties[kCGImagePropertyPixelHeight as String] as? Int else { return nil }
        return ImageInfo(width: width, height: height)
    }
    
    private func convertImages(_ paths: String, directory: URL, format: String) {
        let items = pathListFromString(paths, fallback: nil)
        if items.isEmpty {
            showError("没有拿到选中的图片文件")
            return
        }
        
        var createdURLs: [URL] = []
        for path in items {
            let sourceURL = URL(fileURLWithPath: path)
            let targetURL = imageTargetURL(for: sourceURL, format: format)
            let uti = imageUTI(for: format)
            let quality = (format == "jpg-compressed") ? 0.72 : 0.9
            
            do {
                try writeImage(at: sourceURL, to: targetURL, uti: uti, quality: quality)
                createdURLs.append(targetURL)
            } catch {
                showError("图片处理失败：\(sourceURL.path)\n\(error.localizedDescription)")
                return
            }
        }
        
        if !createdURLs.isEmpty {
            NSWorkspace.shared.activateFileViewerSelecting(createdURLs)
        }
    }
    
    private func imageUTI(for format: String) -> String {
        if format == "png" {
            return "public.png"
        }
        if format == "webp" {
            return "org.webmproject.webp"
        }
        return "public.jpeg"
    }
    
    private func imageTargetURL(for sourceURL: URL, format: String) -> URL {
        var ext = "jpg"
        var suffix = ""
        if format == "png" {
            ext = "png"
        } else if format == "webp" {
            ext = "webp"
        } else if format == "jpg-compressed" {
            ext = "jpg"
            suffix = "-compressed"
        }
        let baseName = sourceURL.deletingPathExtension().lastPathComponent
        let filename = "\(baseName.isEmpty ? "Untitled" : baseName)\(suffix).\(ext)"
        let targetURL = sourceURL.deletingLastPathComponent().appendingPathComponent(filename)
        return uniqueDestinationURL(for: targetURL, in: sourceURL.deletingLastPathComponent())
    }
    
    private func writeImage(at sourceURL: URL, to targetURL: URL, uti: String, quality: Double) throws {
        guard let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil) else {
            throw NSError(domain: "QuickRightMenu", code: 1, userInfo: [NSLocalizedDescriptionKey: "无法读取图片"])
        }
        guard let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw NSError(domain: "QuickRightMenu", code: 2, userInfo: [NSLocalizedDescriptionKey: "无法解码图片"])
        }
        guard let destination = CGImageDestinationCreateWithURL(targetURL as CFURL, uti as CFString, 1, nil) else {
            throw NSError(domain: "QuickRightMenu", code: 3, userInfo: [NSLocalizedDescriptionKey: "系统不支持写入该格式"])
        }
        
        let options = [kCGImageDestinationLossyCompressionQuality as String: quality]
        CGImageDestinationAddImage(destination, image, options as CFDictionary)
        
        if !CGImageDestinationFinalize(destination) {
            throw NSError(domain: "QuickRightMenu", code: 4, userInfo: [NSLocalizedDescriptionKey: "图片写入失败"])
        }
    }
    
    private func showTextStats(_ paths: String, directory: URL) {
        let items = pathListFromString(paths, fallback: nil)
        if items.isEmpty {
            showError("没有拿到选中的文本文件")
            return
        }
        
        var lines: [String] = []
        for path in items {
            guard let text = textContents(at: path) else { continue }
            // 过滤空白字符统计字数
            let cleanText = text.replacingOccurrences(of: "\\s", with: "", options: .regularExpression)
            let chars = cleanText.count
            let words = text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
            let linesCount = text.components(separatedBy: .newlines).count
            
            lines.append("\(URL(fileURLWithPath: path).lastPathComponent): 字符 \(chars)，词 \(words.count)，行 \(linesCount)")
        }
        
        if lines.isEmpty {
            showError("没有可读取的文本文件")
            return
        }
        
        let result = lines.joined(separator: "\n")
        copyToPasteboard(result, label: "text stats")
        showInfo("字数统计已复制", details: result)
    }
    
    private func convertTextFilesToUTF8(_ paths: String, directory: URL) {
        let items = pathListFromString(paths, fallback: nil)
        if items.isEmpty {
            showError("没有拿到选中的文本文件")
            return
        }
        
        var createdURLs: [URL] = []
        for path in items {
            guard let text = textContents(at: path) else {
                showError("无法读取文本：\(path)")
                return
            }
            let sourceURL = URL(fileURLWithPath: path)
            let targetURL = utf8TargetURL(for: sourceURL)
            do {
                try text.write(to: targetURL, atomically: true, encoding: .utf8)
                createdURLs.append(targetURL)
            } catch {
                showError("转 UTF-8 失败：\(path)\n\(error.localizedDescription)")
                return
            }
        }
        
        if !createdURLs.isEmpty {
            NSWorkspace.shared.activateFileViewerSelecting(createdURLs)
        }
    }
    
    private func utf8TargetURL(for sourceURL: URL) -> URL {
        let ext = sourceURL.pathExtension
        let baseName = sourceURL.deletingPathExtension().lastPathComponent
        let filename = !ext.isEmpty ? "\(baseName.isEmpty ? "Untitled" : baseName)-utf8.\(ext)" : "\(baseName.isEmpty ? "Untitled" : baseName)-utf8"
        let targetURL = sourceURL.deletingLastPathComponent().appendingPathComponent(filename)
        return uniqueDestinationURL(for: targetURL, in: sourceURL.deletingLastPathComponent())
    }
    
    private func previewText(_ paths: String, directory: URL) {
        let items = pathListFromString(paths, fallback: nil)
        guard let path = items.first else {
            showError("没有拿到选中的文本文件")
            return
        }
        guard let text = textContents(at: path) else {
            showError("无法读取文本：\(path)")
            return
        }
        
        // 发送通知，显示 SwiftUI 的预览弹窗 (这里我们用原生 NSWindow 来完成轻量的预览，以便无缝过渡，不需要庞大的 Window 管理状态)
        showTextPreviewWindow(text, title: URL(fileURLWithPath: path).lastPathComponent)
    }
    
    private func textContents(at path: String) -> String? {
        if let text = try? String(contentsOfFile: path, encoding: .utf8) {
            return text
        }
        if let data = FileManager.default.contents(atPath: path) {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }
    
    private func showTextPreviewWindow(_ text: String, title: String) {
        DispatchQueue.main.async {
            let window = NSWindow(
                contentRect: NSMakeRect(0, 0, 780, 560),
                styleMask: [.titled, .closable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = title
            window.isReleasedWhenClosed = false
            window.center()
            
            let scrollView = NSScrollView(frame: window.contentView!.bounds)
            scrollView.autoresizingMask = [.width, .height]
            scrollView.hasVerticalScroller = true
            scrollView.hasHorizontalScroller = true
            
            let textView = NSTextView(frame: scrollView.contentView.bounds)
            textView.autoresizingMask = [.width, .height]
            textView.isEditable = false
            textView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
            textView.string = text
            
            scrollView.documentView = textView
            window.contentView = scrollView
            
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
        }
    }
    
    private func openTerminal(at directory: URL) {
        let preference = SettingsManager.shared.settings["terminalPreference"] as? String ?? "terminal"
        var bundleIdentifier = "com.apple.Terminal"
        var displayName = "Terminal.app"
        if preference == "iterm" {
            bundleIdentifier = "com.googlecode.iterm2"
            displayName = "iTerm2.app"
        } else if preference == "warp" {
            bundleIdentifier = "dev.warp.Warp-Stable"
            displayName = "Warp.app"
        }
        
        guard let terminalURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            showError("找不到 \(displayName)")
            return
        }
        
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.open([directory], withApplicationAt: terminalURL, configuration: configuration) { _, error in
            if let error = error {
                self.showError("打开终端失败：\(error.localizedDescription)")
            }
        }
    }
    
    private func openVSCode(paths pathsString: String, directory: URL) {
        guard let vscodeURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.microsoft.VSCode") else {
            showError("未检测到 Visual Studio Code，请确认是否已安装")
            return
        }
        
        let targetURLs: [URL]
        let trimmed = pathsString.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            let paths = trimmed.components(separatedBy: "\n").filter { !$0.isEmpty }
            targetURLs = paths.map { URL(fileURLWithPath: $0) }
        } else {
            targetURLs = [directory]
        }
        
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.open(targetURLs, withApplicationAt: vscodeURL, configuration: configuration) { _, error in
            if let error = error {
                self.showError("在 VS Code 中打开失败：\(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Alerts Helper
    
    func showError(_ message: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "提示"
            alert.informativeText = message
            alert.alertStyle = .warning
            alert.addButton(withTitle: "确定")
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
        }
    }
    
    func showInfo(_ title: String, details: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = title
            alert.informativeText = details
            alert.alertStyle = .informational
            alert.addButton(withTitle: "确定")
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
        }
    }
}

// MARK: - Settings Window Controller

class SettingsWindowController: NSObject, NSWindowDelegate {
    static let shared = SettingsWindowController()
    private var window: NSWindow?
    
    func show() {
        if let window = window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let settingsView = SettingsView()
            .onAppear {
                let manager = SettingsManager.shared
                if !(manager.settings["hasSeenPermissionGuide"] as? Bool ?? false) {
                    manager.settings["hasSeenPermissionGuide"] = true
                    manager.saveSettings()
                }
            }
        
        let hostingView = NSHostingView(rootView: settingsView)
        let newWindow = NSWindow(
            contentRect: NSMakeRect(0, 0, 950, 650),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        newWindow.title = "QuickRightMenu 设置"
        newWindow.contentView = hostingView
        newWindow.center()
        newWindow.isReleasedWhenClosed = false
        newWindow.delegate = self
        
        self.window = newWindow
        newWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func windowWillClose(_ notification: Notification) {
        // 关闭时清理，下次点击重新创建
        self.window = nil
    }
}

// MARK: - Central Storage Configuration

struct CentralStorage {
    static var userHomeDirectory: String {
        if let pw = getpwuid(getuid()), let dir = pw.pointee.pw_dir {
            return String(cString: dir)
        }
        return NSHomeDirectory()
    }
    
    static var rootURL: URL {
        return URL(fileURLWithPath: userHomeDirectory).appendingPathComponent(".quickrightmenu", isDirectory: true)
    }
    
    static var configFileURL: URL {
        return rootURL.appendingPathComponent("config.json", isDirectory: false)
    }
    
    static var commandsDirectoryURL: URL {
        return rootURL.appendingPathComponent("commands", isDirectory: true)
    }
    
    static var logFileURL: URL {
        return rootURL.appendingPathComponent("app.log", isDirectory: false)
    }
    
    static func ensureDirectoriesExist() {
        let fm = FileManager.default
        try? fm.createDirectory(at: rootURL, withIntermediateDirectories: true, attributes: nil)
        try? fm.createDirectory(at: commandsDirectoryURL, withIntermediateDirectories: true, attributes: nil)
    }
}

// MARK: - Custom File Template Model

struct CustomFileTemplate: Identifiable, Codable, Equatable {
    var id: String
    var title: String
    var extensionName: String
    var content: String
    var isEnabled: Bool
    
    init(id: String = UUID().uuidString, title: String, extensionName: String, content: String = "", isEnabled: Bool = true) {
        self.id = id
        self.title = title
        self.extensionName = extensionName
        self.content = content
        self.isEnabled = isEnabled
    }
    
    var dictionary: [String: Any] {
        return [
            "id": id,
            "title": title,
            "extensionName": extensionName,
            "content": content,
            "isEnabled": isEnabled
        ]
    }
    
    static func from(dict: [String: Any]) -> CustomFileTemplate? {
        guard let title = dict["title"] as? String,
              let ext = dict["extensionName"] as? String else {
            return nil
        }
        let id = dict["id"] as? String ?? UUID().uuidString
        let content = dict["content"] as? String ?? ""
        let isEnabled = dict["isEnabled"] as? Bool ?? true
        return CustomFileTemplate(id: id, title: title, extensionName: ext, content: content, isEnabled: isEnabled)
    }
}

// MARK: - Settings Manager

class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    @Published var settings: [String: Any] = [:]
    
    private init() {
        CentralStorage.ensureDirectoriesExist()
        self.settings = loadSettings()
        saveSettings()
    }
    
    var customTemplates: [CustomFileTemplate] {
        get {
            guard let rawList = settings["customTemplates"] as? [[String: Any]] else {
                return [CustomFileTemplate(title: "纯文本", extensionName: "txt", content: "", isEnabled: true)]
            }
            let parsed = rawList.compactMap { CustomFileTemplate.from(dict: $0) }
            return parsed.isEmpty ? [CustomFileTemplate(title: "纯文本", extensionName: "txt", content: "", isEnabled: true)] : parsed
        }
        set {
            settings["customTemplates"] = newValue.map { $0.dictionary }
            saveSettings()
        }
    }
    
    var settingsURL: URL {
        return CentralStorage.configFileURL
    }
    
    func defaultSettings() -> [String: Any] {
        var defaults: [String: Any] = [:]
        for row in featureRows {
            defaults[row.key] = true
        }
        let initialTemplates = [
            CustomFileTemplate(title: "纯文本", extensionName: "txt", content: "", isEnabled: true).dictionary
        ]
        defaults["customTemplates"] = initialTemplates
        defaults["terminalPreference"] = "terminal"
        defaults["hasSeenPermissionGuide"] = false
        for i in 1...3 {
            defaults["favoriteDir\(i)Name"] = ""
            defaults["favoriteDir\(i)Path"] = ""
        }
        return defaults
    }
    
    func loadSettings() -> [String: Any] {
        var merged = defaultSettings()
        let configURL = CentralStorage.configFileURL
        if let data = try? Data(contentsOf: configURL),
           let json = (try? JSONSerialization.jsonObject(with: data, options: [])) as? [String: Any] {
            for (key, val) in json {
                if merged[key] != nil {
                    merged[key] = val
                }
            }
        }
        return merged
    }
    
    func saveSettings() {
        CentralStorage.ensureDirectoriesExist()
        guard let data = try? JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .sortedKeys]) else {
            return
        }
        try? data.write(to: CentralStorage.configFileURL, options: .atomic)
    }
    
    struct FeatureRow: Identifiable {
        let id = UUID()
        let key: String
        let title: String
        let category: String
    }
    
    let featureRows = [
        FeatureRow(key: "copyPath", title: "复制路径", category: "基础操作"),
        FeatureRow(key: "copyName", title: "复制文件名", category: "基础操作"),
        FeatureRow(key: "copyParent", title: "复制父目录", category: "基础操作"),
        FeatureRow(key: "copyFileURL", title: "复制 file URL", category: "基础操作"),
        FeatureRow(key: "copyMarkdownLink", title: "复制 Markdown 链接", category: "基础操作"),
        FeatureRow(key: "copyToDesktop", title: "复制到桌面", category: "文件操作"),
        FeatureRow(key: "copyToDocuments", title: "复制到文稿", category: "文件操作"),
        FeatureRow(key: "copyToDownloads", title: "复制到下载", category: "文件操作"),
        FeatureRow(key: "copyToPictures", title: "复制到图片", category: "文件操作"),
        FeatureRow(key: "copyToMovies", title: "复制到影片", category: "文件操作"),
        FeatureRow(key: "copyToMusic", title: "复制到音乐", category: "文件操作"),
        FeatureRow(key: "copyToChoose", title: "复制到选择文件夹", category: "文件操作"),
        FeatureRow(key: "moveToDesktop", title: "移动到桌面", category: "文件操作"),
        FeatureRow(key: "moveToDocuments", title: "移动到文稿", category: "文件操作"),
        FeatureRow(key: "moveToDownloads", title: "移动到下载", category: "文件操作"),
        FeatureRow(key: "moveToPictures", title: "移动到图片", category: "文件操作"),
        FeatureRow(key: "moveToMovies", title: "移动到影片", category: "文件操作"),
        FeatureRow(key: "moveToMusic", title: "移动到音乐", category: "文件操作"),
        FeatureRow(key: "moveToChoose", title: "移动到选择文件夹", category: "文件操作"),
        FeatureRow(key: "batchRename", title: "批量重命名", category: "文件操作"),
        FeatureRow(key: "copyImageSize", title: "复制图片尺寸", category: "图片工具"),
        FeatureRow(key: "compressImage", title: "压缩图片", category: "图片工具"),
        FeatureRow(key: "convertPng", title: "转换为 PNG", category: "图片工具"),
        FeatureRow(key: "convertJpeg", title: "转换为 JPEG", category: "图片工具"),
        FeatureRow(key: "convertWebp", title: "转换为 WebP", category: "图片工具"),
        FeatureRow(key: "textStats", title: "统计字数", category: "文本工具"),
        FeatureRow(key: "textToUtf8", title: "转 UTF-8", category: "文本工具"),
        FeatureRow(key: "textPreview", title: "快速预览纯文本", category: "文本工具"),
        FeatureRow(key: "vscode", title: "在 VS Code 中打开", category: "基础操作"),
        FeatureRow(key: "terminal", title: "在终端打开", category: "基础操作")
    ]
}
