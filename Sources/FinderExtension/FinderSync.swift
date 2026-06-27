import Cocoa
import FinderSync

@objc(FinderSync)
class FinderSync: FIFinderSync {
    
    private let menuTagBase = 42000
    
    override init() {
        super.init()
        let rootURL = URL(fileURLWithPath: "/")
        FIFinderSyncController.default().directoryURLs = [rootURL]
    }
    
    override var toolbarItemName: String {
        return "QuickRightMenu"
    }
    
    override var toolbarItemToolTip: String {
        return "QuickRightMenu"
    }
    
    override var toolbarItemImage: NSImage {
        return menuIconNamed("filemenu.and.selection")
    }
    
    override func menu(for whichMenu: FIMenuKind) -> NSMenu? {
        let menu = NSMenu(title: "QuickRightMenu")
        
        let createItem = NSMenuItem(title: "新建文件", action: nil, keyEquivalent: "")
        createItem.image = menuIconNamed("doc.badge.plus")
        let createMenu = NSMenu(title: "新建文件")
        addItem(title: "TXT", key: "newTxt", action: "txt", symbol: "doc.plaintext", toMenu: createMenu)
        addItem(title: "Markdown", key: "newMarkdown", action: "md", symbol: "doc.text", toMenu: createMenu)
        addItem(title: "JSON", key: "newJson", action: "json", symbol: "curlybraces", toMenu: createMenu)
        addItem(title: "CSV", key: "newCsv", action: "csv", symbol: "tablecells", toMenu: createMenu)
        addItem(title: "HTML", key: "newHtml", action: "html", symbol: "chevron.left.forwardslash.chevron.right", toMenu: createMenu)
        addItem(title: "YAML", key: "newYaml", action: "yaml", symbol: "doc.text", toMenu: createMenu)
        addItem(title: "XML", key: "newXml", action: "xml", symbol: "chevron.left.forwardslash.chevron.right", toMenu: createMenu)
        addItem(title: "Shell", key: "newShell", action: "sh", symbol: "terminal", toMenu: createMenu)
        addItem(title: "Python", key: "newPython", action: "py", symbol: "chevron.left.forwardslash.chevron.right", toMenu: createMenu)
        addItem(title: "JavaScript", key: "newJavaScript", action: "js", symbol: "curlybraces", toMenu: createMenu)
        addItem(title: "TypeScript", key: "newTypeScript", action: "ts", symbol: "curlybraces", toMenu: createMenu)
        addItem(title: "CSS", key: "newCss", action: "css", symbol: "paintbrush", toMenu: createMenu)
        addItem(title: "Word", key: "newWord", action: "docx", symbol: "doc.richtext", toMenu: createMenu)
        addItem(title: "Excel", key: "newExcel", action: "xlsx", symbol: "tablecells", toMenu: createMenu)
        addItem(title: "PowerPoint", key: "newPowerPoint", action: "pptx", symbol: "rectangle.on.rectangle", toMenu: createMenu)
        if createMenu.numberOfItems > 0 {
            createItem.submenu = createMenu
            menu.addItem(createItem)
        }
        
        let copyItem = NSMenuItem(title: "复制", action: nil, keyEquivalent: "")
        copyItem.image = menuIconNamed("doc.on.clipboard")
        let copyMenu = NSMenu(title: "复制")
        addItem(title: "路径", key: "copyPath", action: "copy-path", symbol: "doc.on.clipboard", toMenu: copyMenu)
        addItem(title: "文件名", key: "copyName", action: "copy-name", symbol: "textformat", toMenu: copyMenu)
        addItem(title: "父目录", key: "copyParent", action: "copy-parent", symbol: "folder", toMenu: copyMenu)
        addItem(title: "file URL", key: "copyFileURL", action: "copy-file-url", symbol: "link", toMenu: copyMenu)
        addItem(title: "Markdown 链接", key: "copyMarkdownLink", action: "copy-markdown-link", symbol: "link.badge.plus", toMenu: copyMenu)
        if copyMenu.numberOfItems > 0 {
            copyItem.submenu = copyMenu
            menu.addItem(copyItem)
        }
        
        let copyToItem = NSMenuItem(title: "复制到", action: nil, keyEquivalent: "")
        copyToItem.image = menuIconNamed("doc.on.doc")
        let copyToMenu = NSMenu(title: "复制到")
        addDestinationItems(prefix: "copy-to", featurePrefix: "copyTo", toMenu: copyToMenu)
        addFavoriteDestinationItems(prefix: "copy-to", toMenu: copyToMenu)
        addItem(title: "选择文件夹...", key: "copyToChoose", action: "copy-to-choose", symbol: "folder.badge.plus", toMenu: copyToMenu)
        if copyToMenu.numberOfItems > 0 {
            copyToItem.submenu = copyToMenu
            menu.addItem(copyToItem)
        }
        
        let moveToItem = NSMenuItem(title: "移动到", action: nil, keyEquivalent: "")
        moveToItem.image = menuIconNamed("folder")
        let moveToMenu = NSMenu(title: "移动到")
        addDestinationItems(prefix: "move-to", featurePrefix: "moveTo", toMenu: moveToMenu)
        addFavoriteDestinationItems(prefix: "move-to", toMenu: moveToMenu)
        addItem(title: "选择文件夹...", key: "moveToChoose", action: "move-to-choose", symbol: "folder.badge.plus", toMenu: moveToMenu)
        if moveToMenu.numberOfItems > 0 {
            moveToItem.submenu = moveToMenu
            menu.addItem(moveToItem)
        }
        
        let fileOpsItem = NSMenuItem(title: "文件操作", action: nil, keyEquivalent: "")
        fileOpsItem.image = menuIconNamed("folder")
        let fileOpsMenu = NSMenu(title: "文件操作")
        addItem(title: "批量重命名", key: "batchRename", action: "batch-rename", symbol: "text.cursor", toMenu: fileOpsMenu)
        if fileOpsMenu.numberOfItems > 0 {
            fileOpsItem.submenu = fileOpsMenu
            menu.addItem(fileOpsItem)
        }
        
        let imageToolsItem = NSMenuItem(title: "图片工具", action: nil, keyEquivalent: "")
        imageToolsItem.image = menuIconNamed("photo")
        let imageToolsMenu = NSMenu(title: "图片工具")
        addItem(title: "复制图片尺寸", key: "copyImageSize", action: "image-copy-size", symbol: "ruler", toMenu: imageToolsMenu)
        addItem(title: "压缩图片", key: "compressImage", action: "image-compress", symbol: "arrow.down.right.and.arrow.up.left", toMenu: imageToolsMenu)
        addItem(title: "转换为 PNG", key: "convertPng", action: "image-convert-png", symbol: "photo", toMenu: imageToolsMenu)
        addItem(title: "转换为 JPEG", key: "convertJpeg", action: "image-convert-jpeg", symbol: "photo", toMenu: imageToolsMenu)
        addItem(title: "转换为 WebP", key: "convertWebp", action: "image-convert-webp", symbol: "photo", toMenu: imageToolsMenu)
        if imageToolsMenu.numberOfItems > 0 {
            imageToolsItem.submenu = imageToolsMenu
            menu.addItem(imageToolsItem)
        }
        
        let textToolsItem = NSMenuItem(title: "文本工具", action: nil, keyEquivalent: "")
        textToolsItem.image = menuIconNamed("doc.text")
        let textToolsMenu = NSMenu(title: "文本工具")
        addItem(title: "统计字数", key: "textStats", action: "text-stats", symbol: "number", toMenu: textToolsMenu)
        addItem(title: "转 UTF-8", key: "textToUtf8", action: "text-to-utf8", symbol: "character.cursor.ibeam", toMenu: textToolsMenu)
        addItem(title: "快速预览纯文本", key: "textPreview", action: "text-preview", symbol: "eye", toMenu: textToolsMenu)
        if textToolsMenu.numberOfItems > 0 {
            textToolsItem.submenu = textToolsMenu
            menu.addItem(textToolsItem)
        }
        
        if isFeatureEnabled("terminal") {
            let item = NSMenuItem(title: "在终端打开", action: #selector(handleMenuItem(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = "terminal"
            item.tag = tagForAction("terminal")
            item.image = menuIconNamed("terminal")
            menu.addItem(item)
        }
        
        return menu
    }
    
    private func addItem(title: String, key: String, action: String, symbol: String, toMenu menu: NSMenu) {
        if isFeatureEnabled(key) {
            let item = NSMenuItem(title: title, action: #selector(handleMenuItem(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = action
            item.tag = tagForAction(action)
            item.image = menuIconNamed(symbol)
            menu.addItem(item)
        }
    }
    
    private func addDestinationItems(prefix: String, featurePrefix: String, toMenu menu: NSMenu) {
        let destinations = [
            ["key": "Desktop", "title": "桌面", "symbol": "desktopcomputer"],
            ["key": "Documents", "title": "文稿", "symbol": "doc.text"],
            ["key": "Downloads", "title": "下载", "symbol": "arrow.down.circle"],
            ["key": "Pictures", "title": "图片", "symbol": "photo"],
            ["key": "Movies", "title": "影片", "symbol": "film"],
            ["key": "Music", "title": "音乐", "symbol": "music.note"]
        ]
        for destination in destinations {
            guard let key = destination["key"], let title = destination["title"], let symbol = destination["symbol"] else { continue }
            let featureKey = featurePrefix + key
            let action = "\(prefix)-\(key.lowercased())"
            addItem(title: title, key: featureKey, action: action, symbol: symbol, toMenu: menu)
        }
    }
    
    private func addFavoriteDestinationItems(prefix: String, toMenu menu: NSMenu) {
        let settings = settingsDictionary()
        var addedSeparator = false
        for i in 1...3 {
            let pathKey = "favoriteDir\(i)Path"
            let nameKey = "favoriteDir\(i)Name"
            guard let path = settings[pathKey] as? String, !path.isEmpty else { continue }
            if !addedSeparator && menu.numberOfItems > 0 {
                menu.addItem(NSMenuItem.separator())
                addedSeparator = true
            }
            let name = settings[nameKey] as? String ?? ""
            let title = !name.isEmpty ? name : URL(fileURLWithPath: path).lastPathComponent
            let action = "\(prefix)-favorite\(i)"
            let item = NSMenuItem(title: title, action: #selector(handleMenuItem(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = action
            item.tag = tagForAction(action)
            item.image = menuIconNamed("folder")
            menu.addItem(item)
        }
    }
    
    private func menuIconNamed(_ name: String) -> NSImage {
        let canvasSize = NSMakeSize(22, 22)
        let result = NSImage(size: canvasSize)
        result.lockFocus()
        
        let background = NSBezierPath(roundedRect: NSMakeRect(1.5, 1.5, 19, 19), xRadius: 5, yRadius: 5)
        NSColor(calibratedWhite: 1.0, alpha: 1.0).set()
        background.fill()
        NSColor(calibratedWhite: 0.84, alpha: 1.0).set()
        background.lineWidth = 0.7
        background.stroke()
        
        let tint = tintColorForSymbol(name)
        drawFilledGlyphNamed(name, tint: tint, inRect: NSMakeRect(4, 4, 14, 14))
        
        if name.contains("badge.plus") {
            let badge = NSBezierPath(ovalIn: NSMakeRect(11.5, 11.5, 8, 8))
            NSColor(calibratedRed: 0.25, green: 0.86, blue: 0.45, alpha: 1.0).set()
            badge.fill()
            NSColor.white.set()
            let h = NSBezierPath()
            h.move(to: NSMakePoint(14, 15.5))
            h.line(to: NSMakePoint(17, 15.5))
            h.move(to: NSMakePoint(15.5, 14))
            h.line(to: NSMakePoint(15.5, 17))
            h.lineWidth = 1.3
            h.stroke()
        }
        
        result.unlockFocus()
        result.size = canvasSize
        return result
    }
    
    private func drawFilledGlyphNamed(_ name: String, tint: NSColor, inRect rect: NSRect) {
        tint.set()
        
        if name.contains("terminal") {
            let screen = NSBezierPath(roundedRect: NSMakeRect(rect.origin.x, rect.origin.y + 1, rect.size.width, rect.size.height - 2), xRadius: 2, yRadius: 2)
            screen.fill()
            NSColor.white.set()
            let prompt = NSBezierPath()
            prompt.move(to: NSMakePoint(rect.origin.x + 3, rect.origin.y + 8.5))
            prompt.line(to: NSMakePoint(rect.origin.x + 5.3, rect.origin.y + 7))
            prompt.line(to: NSMakePoint(rect.origin.x + 3, rect.origin.y + 5.5))
            prompt.lineWidth = 1.2
            prompt.stroke()
            let cursor = NSBezierPath()
            cursor.move(to: NSMakePoint(rect.origin.x + 7.2, rect.origin.y + 5.8))
            cursor.line(to: NSMakePoint(rect.origin.x + 10.5, rect.origin.y + 5.8))
            cursor.lineWidth = 1.2
            cursor.stroke()
            return
        }
        
        if name.contains("folder") {
            let tab = NSBezierPath(roundedRect: NSMakeRect(rect.origin.x + 1, rect.origin.y + 9, 6, 3.5), xRadius: 1, yRadius: 1)
            tab.fill()
            let body = NSBezierPath(roundedRect: NSMakeRect(rect.origin.x, rect.origin.y + 2, rect.size.width, 10), xRadius: 2, yRadius: 2)
            body.fill()
            return
        }
        
        if name.contains("photo") {
            let frame = NSBezierPath(roundedRect: NSMakeRect(rect.origin.x, rect.origin.y + 1, rect.size.width, rect.size.height - 2), xRadius: 2, yRadius: 2)
            frame.fill()
            NSColor(calibratedWhite: 1.0, alpha: 0.95).set()
            let sun = NSBezierPath(ovalIn: NSMakeRect(rect.origin.x + 9.5, rect.origin.y + 9, 2.8, 2.8))
            sun.fill()
            let mountain = NSBezierPath()
            mountain.move(to: NSMakePoint(rect.origin.x + 2.2, rect.origin.y + 3.2))
            mountain.line(to: NSMakePoint(rect.origin.x + 5.4, rect.origin.y + 7.4))
            mountain.line(to: NSMakePoint(rect.origin.x + 7.8, rect.origin.y + 4.9))
            mountain.line(to: NSMakePoint(rect.origin.x + 10.4, rect.origin.y + 8.2))
            mountain.line(to: NSMakePoint(rect.origin.x + 12.2, rect.origin.y + 3.2))
            mountain.close()
            mountain.fill()
            return
        }
        
        if name.contains("tablecells") {
            let table = NSBezierPath(roundedRect: NSMakeRect(rect.origin.x + 1, rect.origin.y + 1, rect.size.width - 2, rect.size.height - 2), xRadius: 2, yRadius: 2)
            table.fill()
            NSColor.white.set()
            let grid = NSBezierPath()
            for i in 1...2 {
                let x = rect.origin.x + 1 + (rect.size.width - 2) * CGFloat(i) / 3.0
                grid.move(to: NSMakePoint(x, rect.origin.y + 2))
                grid.line(to: NSMakePoint(x, rect.origin.y + rect.size.height - 2))
                let y = rect.origin.y + 1 + (rect.size.height - 2) * CGFloat(i) / 3.0
                grid.move(to: NSMakePoint(rect.origin.x + 2, y))
                grid.line(to: NSMakePoint(rect.origin.x + rect.size.width - 2, y))
            }
            grid.lineWidth = 0.75
            grid.stroke()
            return
        }
        
        if name.contains("link") {
            let left = NSBezierPath(roundedRect: NSMakeRect(rect.origin.x + 1, rect.origin.y + 4.5, 7, 4.5), xRadius: 2.2, yRadius: 2.2)
            let right = NSBezierPath(roundedRect: NSMakeRect(rect.origin.x + 6, rect.origin.y + 5.5, 7, 4.5), xRadius: 2.2, yRadius: 2.2)
            left.lineWidth = 2.2
            right.lineWidth = 2.2
            left.stroke()
            right.stroke()
            return
        }
        
        if name.contains("ruler") {
            NSGraphicsContext.current?.saveGraphicsState()
            let transform = NSAffineTransform()
            transform.translateX(by: rect.origin.x + 7, yBy: rect.origin.y + 7)
            transform.rotate(byDegrees: -30)
            transform.translateX(by: -(rect.origin.x + 7), yBy: -(rect.origin.y + 7))
            transform.concat()
            let ruler = NSBezierPath(roundedRect: NSMakeRect(rect.origin.x + 1, rect.origin.y + 5, 12, 4), xRadius: 1.5, yRadius: 1.5)
            ruler.fill()
            NSGraphicsContext.current?.restoreGraphicsState()
            return
        }
        
        if name.contains("arrow.down") || name.contains("arrow.up") {
            let box = NSBezierPath(roundedRect: NSMakeRect(rect.origin.x + 1, rect.origin.y + 1, rect.size.width - 2, rect.size.height - 2), xRadius: 3, yRadius: 3)
            box.fill()
            NSColor.white.set()
            let arrows = NSBezierPath()
            arrows.move(to: NSMakePoint(rect.origin.x + 4, rect.origin.y + 10))
            arrows.line(to: NSMakePoint(rect.origin.x + 8, rect.origin.y + 6))
            arrows.move(to: NSMakePoint(rect.origin.x + 8, rect.origin.y + 6))
            arrows.line(to: NSMakePoint(rect.origin.x + 8, rect.origin.y + 9.5))
            arrows.lineWidth = 1.2
            arrows.stroke()
            return
        }
        
        if name.contains("number") {
            let bubble = NSBezierPath(roundedRect: NSMakeRect(rect.origin.x + 1, rect.origin.y + 2, rect.size.width - 2, rect.size.height - 4), xRadius: 3, yRadius: 3)
            bubble.fill()
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.boldSystemFont(ofSize: 8),
                .foregroundColor: NSColor.white
            ]
            ("#" as NSString).draw(in: NSMakeRect(rect.origin.x + 4.5, rect.origin.y + 3.3, 8, 8), withAttributes: attrs)
            return
        }
        
        if name.contains("character") || name.contains("textformat") {
            let bubble = NSBezierPath(roundedRect: NSMakeRect(rect.origin.x + 1, rect.origin.y + 2, rect.size.width - 2, rect.size.height - 4), xRadius: 3, yRadius: 3)
            bubble.fill()
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.boldSystemFont(ofSize: 9),
                .foregroundColor: NSColor.white
            ]
            ("T" as NSString).draw(in: NSMakeRect(rect.origin.x + 4.4, rect.origin.y + 2.5, 8, 9), withAttributes: attrs)
            return
        }
        
        if name.contains("curlybraces") || name.contains("chevron") {
            let code = NSBezierPath(roundedRect: NSMakeRect(rect.origin.x + 1, rect.origin.y + 1.5, rect.size.width - 2, rect.size.height - 3), xRadius: 3, yRadius: 3)
            code.fill()
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.boldSystemFont(ofSize: 8),
                .foregroundColor: NSColor.white
            ]
            ("<>" as NSString).draw(in: NSMakeRect(rect.origin.x + 2.6, rect.origin.y + 3.2, 11, 8), withAttributes: attrs)
            return
        }
        
        if name.contains("paintbrush") {
            let drop = NSBezierPath(ovalIn: NSMakeRect(rect.origin.x + 2, rect.origin.y + 1.5, 10, 10))
            drop.fill()
            NSColor.white.set()
            let shine = NSBezierPath(ovalIn: NSMakeRect(rect.origin.x + 5, rect.origin.y + 6.5, 3, 3))
            shine.fill()
            return
        }
        
        if name.contains("doc") || name.contains("filemenu") {
            let doc = NSBezierPath(roundedRect: NSMakeRect(rect.origin.x + 3, rect.origin.y + 1, 8, 12), xRadius: 1.6, yRadius: 1.6)
            doc.fill()
            let fold = NSBezierPath()
            NSColor(calibratedWhite: 1.0, alpha: 0.72).set()
            fold.move(to: NSMakePoint(rect.origin.x + 8.2, rect.origin.y + 13))
            fold.line(to: NSMakePoint(rect.origin.x + 11, rect.origin.y + 10.2))
            fold.line(to: NSMakePoint(rect.origin.x + 8.2, rect.origin.y + 10.2))
            fold.close()
            fold.fill()
            return
        }
        
        let fallback = NSBezierPath(roundedRect: NSMakeRect(rect.origin.x + 2, rect.origin.y + 2, rect.size.width - 4, rect.size.height - 4), xRadius: 3, yRadius: 3)
        fallback.fill()
    }
    
    private func tintColorForSymbol(_ name: String) -> NSColor {
        if name.contains("terminal") {
            return NSColor(calibratedRed: 0.16, green: 0.18, blue: 0.22, alpha: 1.0)
        }
        if name.contains("folder") {
            return NSColor(calibratedRed: 0.16, green: 0.42, blue: 0.92, alpha: 1.0)
        }
        if name.contains("photo") {
            return NSColor(calibratedRed: 0.22, green: 0.76, blue: 0.38, alpha: 1.0)
        }
        if name.contains("tablecells") {
            return NSColor(calibratedRed: 0.12, green: 0.68, blue: 0.34, alpha: 1.0)
        }
        if name.contains("link") {
            return NSColor(calibratedRed: 0.18, green: 0.75, blue: 0.64, alpha: 1.0)
        }
        if name.contains("ruler") || name.contains("arrow") {
            return NSColor(calibratedRed: 0.96, green: 0.58, blue: 0.20, alpha: 1.0)
        }
        if name.contains("number") || name.contains("character") {
            return NSColor(calibratedRed: 0.58, green: 0.38, blue: 0.90, alpha: 1.0)
        }
        if name.contains("doc") {
            return NSColor(calibratedRed: 0.20, green: 0.52, blue: 0.92, alpha: 1.0)
        }
        return NSColor(calibratedRed: 0.24, green: 0.56, blue: 0.92, alpha: 1.0)
    }
    
    private func symbolImageNamed(_ name: String) -> NSImage? {
        if #available(macOS 11.0, *) {
            let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)
            image?.size = NSMakeSize(16, 16)
            return image
        }
        return nil
    }
    
    @objc func handleMenuItem(_ sender: NSMenuItem) {
        guard let action = actionForMenuItem(sender) else { return }
        let directory = targetDirectory()
        log("menu title=\(sender.title) parent=\(sender.menu?.title ?? "") action=\(action) directory=\(directory.path) selected=\(selectedPathsString())")
        
        switch action {
        case "txt", "md", "json", "csv", "html", "yaml", "xml", "sh", "py", "js", "ts", "css", "docx", "xlsx", "pptx":
            sendCommand("create", directory: directory, extension: action)
        case "copy-path", "copy-name", "copy-parent", "copy-file-url", "copy-markdown-link",
             "batch-rename", "image-copy-size", "image-compress", "image-convert-png", "image-convert-jpeg", "image-convert-webp",
             "text-stats", "text-to-utf8", "text-preview", "terminal":
            sendCommand(action, directory: directory, extension: nil)
        default:
            if action.hasPrefix("copy-to-") || action.hasPrefix("move-to-") {
                sendCommand(action, directory: directory, extension: nil)
            } else {
                log("unknown menu item \(sender.title)")
            }
        }
    }
    
    private func actionForMenuItem(_ item: NSMenuItem) -> String? {
        if let taggedAction = actionForTag(item.tag) {
            return taggedAction
        }
        if let representedAction = item.representedObject as? String {
            return representedAction
        }
        
        let title = item.title
        let menuTitle = item.menu?.title ?? ""
        
        if menuTitle == "复制到" || menuTitle == "移动到" {
            let prefix = (menuTitle == "复制到") ? "copy-to" : "move-to"
            if let destination = destinationActionKeyForTitle(title) {
                return "\(prefix)-\(destination)"
            }
        }
        
        if menuTitle == "复制" {
            if title.contains("Markdown 链接") { return "copy-markdown-link" }
            if title.contains("file URL") { return "copy-file-url" }
            if title.contains("文件名") { return "copy-name" }
            if title.contains("父目录") { return "copy-parent" }
            if title.contains("路径") { return "copy-path" }
        }
        
        if title.contains("Markdown 链接") { return "copy-markdown-link" }
        if title.contains("file URL") { return "copy-file-url" }
        if title.contains("文件名") { return "copy-name" }
        if title.contains("父目录") { return "copy-parent" }
        if title.contains("路径") { return "copy-path" }
        
        if title.contains("TXT") { return "txt" }
        if title.contains("Markdown") { return "md" }
        if title.contains("JSON") { return "json" }
        if title.contains("CSV") { return "csv" }
        if title.contains("HTML") { return "html" }
        if title.contains("YAML") { return "yaml" }
        if title.contains("XML") { return "xml" }
        if title.contains("Shell") { return "sh" }
        if title.contains("Python") { return "py" }
        if title.contains("JavaScript") { return "js" }
        if title.contains("TypeScript") { return "ts" }
        if title.contains("CSS") { return "css" }
        if title.contains("Word") { return "docx" }
        if title.contains("Excel") { return "xlsx" }
        if title.contains("PowerPoint") { return "pptx" }
        if title.contains("终端") { return "terminal" }
        
        return nil
    }
    
    private func actionTags() -> [String: Int] {
        return [
            "txt": menuTagBase + 1,
            "md": menuTagBase + 2,
            "json": menuTagBase + 3,
            "csv": menuTagBase + 4,
            "html": menuTagBase + 5,
            "yaml": menuTagBase + 6,
            "xml": menuTagBase + 7,
            "sh": menuTagBase + 8,
            "py": menuTagBase + 9,
            "js": menuTagBase + 10,
            "ts": menuTagBase + 11,
            "css": menuTagBase + 12,
            "docx": menuTagBase + 13,
            "xlsx": menuTagBase + 14,
            "pptx": menuTagBase + 15,
            "copy-path": menuTagBase + 20,
            "copy-name": menuTagBase + 21,
            "copy-parent": menuTagBase + 22,
            "copy-file-url": menuTagBase + 23,
            "copy-markdown-link": menuTagBase + 24,
            "copy-to-desktop": menuTagBase + 30,
            "copy-to-documents": menuTagBase + 31,
            "copy-to-downloads": menuTagBase + 32,
            "copy-to-pictures": menuTagBase + 33,
            "copy-to-movies": menuTagBase + 34,
            "copy-to-music": menuTagBase + 35,
            "copy-to-choose": menuTagBase + 36,
            "copy-to-favorite1": menuTagBase + 37,
            "copy-to-favorite2": menuTagBase + 38,
            "copy-to-favorite3": menuTagBase + 39,
            "move-to-desktop": menuTagBase + 40,
            "move-to-documents": menuTagBase + 41,
            "move-to-downloads": menuTagBase + 42,
            "move-to-pictures": menuTagBase + 43,
            "move-to-movies": menuTagBase + 44,
            "move-to-music": menuTagBase + 45,
            "move-to-choose": menuTagBase + 46,
            "move-to-favorite1": menuTagBase + 47,
            "move-to-favorite2": menuTagBase + 48,
            "move-to-favorite3": menuTagBase + 49,
            "batch-rename": menuTagBase + 60,
            "image-copy-size": menuTagBase + 70,
            "image-compress": menuTagBase + 71,
            "image-convert-png": menuTagBase + 72,
            "image-convert-jpeg": menuTagBase + 73,
            "image-convert-webp": menuTagBase + 74,
            "text-stats": menuTagBase + 80,
            "text-to-utf8": menuTagBase + 81,
            "text-preview": menuTagBase + 82,
            "terminal": menuTagBase + 90
        ]
    }
    
    private func tagForAction(_ action: String) -> Int {
        return actionTags()[action] ?? 0
    }
    
    private func actionForTag(_ tag: Int) -> String? {
        if tag == 0 { return nil }
        for (action, t) in actionTags() {
            if t == tag {
                return action
            }
        }
        return nil
    }
    
    private func destinationActionKeyForTitle(_ title: String) -> String? {
        if title.contains("选择文件夹") { return "choose" }
        if title.contains("桌面") { return "desktop" }
        if title.contains("文稿") { return "documents" }
        if title.contains("下载") { return "downloads" }
        if title.contains("图片") { return "pictures" }
        if title.contains("影片") { return "movies" }
        if title.contains("音乐") { return "music" }
        return nil
    }
    
    private func isFeatureEnabled(_ key: String) -> Bool {
        let settings = settingsDictionary()
        if let val = settings[key] as? Bool {
            return val
        }
        return true
    }
    
    private func settingsDictionary() -> [String: Any] {
        let stored = NSDictionary(contentsOf: settingsURL())
        return (stored as? [String: Any]) ?? [:]
    }
    
    private func settingsURL() -> URL {
        let path = (NSHomeDirectory() as NSString).appendingPathComponent("Library/Application Support/QuickRightMenu/settings.plist")
        return URL(fileURLWithPath: path)
    }
    
    private func targetDirectory() -> URL {
        let controller = FIFinderSyncController.default()
        if let selectedURLs = controller.selectedItemURLs(), selectedURLs.count == 1, let selectedURL = selectedURLs.first {
            var isDirectory: AnyObject?
            try? (selectedURL as NSURL).getResourceValue(&isDirectory, forKey: .isDirectoryKey)
            if let isDir = isDirectory as? Bool, isDir {
                return selectedURL
            }
            return selectedURL.deletingLastPathComponent()
        }
        if let targetedURL = controller.targetedURL() {
            return targetedURL
        }
        return URL(fileURLWithPath: NSHomeDirectory())
    }
    
    private func sendCommand(_ command: String, directory: URL, extension ext: String?) {
        var components = URLComponents()
        components.scheme = "quickrightmenu"
        components.host = command
        
        var queryItems = [URLQueryItem(name: "dir", value: directory.path)]
        let paths = selectedPathsString()
        if !paths.isEmpty {
            queryItems.append(URLQueryItem(name: "paths", value: paths))
        }
        if let extensionStr = ext {
            queryItems.append(URLQueryItem(name: "ext", value: extensionStr))
        }
        components.queryItems = queryItems
        
        guard let url = components.url else {
            log("command URL build failed")
            return
        }
        
        writeCommandFile(url.absoluteString)
    }
    
    private func writeCommandFile(_ urlString: String) {
        let directoryPath = (NSHomeDirectory() as NSString).appendingPathComponent("Library/Application Support/QuickRightMenuCommands")
        do {
            try FileManager.default.createDirectory(atPath: directoryPath, withIntermediateDirectories: true, attributes: nil)
        } catch {
            log("command directory create failed \(error.localizedDescription)")
            return
        }
        
        let filename = String(format: "command-%lld-%u.cmd",
                              Int64(Date().timeIntervalSince1970 * 1000),
                              arc4random_uniform(1000000))
        let filePath = (directoryPath as NSString).appendingPathComponent(filename)
        let fileURL = URL(fileURLWithPath: filePath)
        do {
            try urlString.write(to: fileURL, atomically: true, encoding: .utf8)
            log("write command file \(fileURL.path) \(urlString)")
        } catch {
            log("write command file failed \(error.localizedDescription)")
        }
    }
    
    private func selectedPathsString() -> String {
        let selectedURLs = FIFinderSyncController.default().selectedItemURLs() ?? []
        let paths = selectedURLs.map { $0.path }.filter { !$0.isEmpty }
        return paths.joined(separator: "\n")
    }
    
    private func log(_ message: String) {
        let line = "\(Date()) Extension: \(message)\n"
        let fileURL = URL(fileURLWithPath: "/tmp/QuickRightMenu.log")
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
}
