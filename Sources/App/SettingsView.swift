import SwiftUI
import Cocoa

// MARK: - Update Manager

class UpdateManager: ObservableObject {
    static let shared = UpdateManager()
    
    @Published var updateAvailable = false
    @Published var updateCheckFinished = false
    @Published var latestVersion = ""
    @Published var latestDownloadURL = ""
    
    private init() {}
    
    func checkForUpdatesSilently() {
        guard let url = URL(string: "https://api.github.com/repos/weaiw/QuickRightMenu/releases/latest") else { return }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 12)
        request.setValue("QuickRightMenu", forHTTPHeaderField: "User-Agent")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                DispatchQueue.main.async {
                    self.updateCheckFinished = true
                }
                return
            }
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let tag = json["tag_name"] as? String ?? ""
                let htmlURL = json["html_url"] as? String ?? ""
                let version = tag.hasPrefix("v") || tag.hasPrefix("V") ? String(tag.dropFirst()) : tag
                
                var downloadURL = htmlURL
                if let assets = json["assets"] as? [[String: Any]] {
                    for asset in assets {
                        if let name = asset["name"] as? String, name.contains("macOS.zip"),
                           let urlStr = asset["browser_download_url"] as? String {
                            downloadURL = urlStr
                            break
                        }
                    }
                }
                
                let isNewer = self.isVersion(version, newerThan: "1.5.7")
                DispatchQueue.main.async {
                    self.latestVersion = version
                    self.latestDownloadURL = downloadURL
                    self.updateAvailable = isNewer
                    self.updateCheckFinished = true
                }
            }
        }.resume()
    }
    
    private func isVersion(_ candidate: String, newerThan current: String) -> Bool {
        let left = candidate.components(separatedBy: ".").compactMap { Int($0) }
        let right = current.components(separatedBy: ".").compactMap { Int($0) }
        let count = max(left.count, right.count)
        for i in 0..<count {
            let a = i < left.count ? left[i] : 0
            let b = i < right.count ? right[i] : 0
            if a > b { return true }
            if a < b { return false }
        }
        return false
    }
}

// MARK: - Main Settings View

struct SettingsView: View {
    @State private var selection: String = "menu"
    
    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section("引导") {
                    NavigationLink(value: "permissions") {
                        Label("权限指引", systemImage: "hand.raised.fill")
                    }
                }
                Section("设置") {
                    NavigationLink(value: "menu") {
                        Label("右键菜单", systemImage: "list.bullet.rectangle")
                    }
                    NavigationLink(value: "templates") {
                        Label("文件模板", systemImage: "doc.text.fill")
                    }
                    NavigationLink(value: "favorites") {
                        Label("常用目录", systemImage: "star.fill")
                    }
                    NavigationLink(value: "terminal") {
                        Label("终端偏好", systemImage: "terminal.fill")
                    }
                }
                Section("系统") {
                    NavigationLink(value: "login") {
                        Label("开机启动", systemImage: "power")
                    }
                    NavigationLink(value: "update") {
                        Label("软件更新", systemImage: "arrow.clockwise.circle.fill")
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("设置导航")
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    switch selection {
                    case "permissions":
                        PermissionGuideView()
                    case "menu":
                        MenuView()
                    case "templates":
                        TemplatesView()
                    case "favorites":
                        FavoritesView()
                    case "terminal":
                        TerminalView()
                    case "login":
                        LoginView()
                    case "update":
                        UpdateView()
                    default:
                        Text("请选择一个选项")
                    }
                }
                .padding(32)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle(titleForSelection(selection))
        }
    }
    
    private func titleForSelection(_ sel: String) -> String {
        switch sel {
        case "permissions": return "权限指引"
        case "menu": return "右键菜单"
        case "templates": return "文件模板"
        case "favorites": return "常用目录"
        case "terminal": return "终端偏好"
        case "login": return "开机启动"
        case "update": return "软件更新"
        default: return "设置"
        }
    }
}

// MARK: - Subviews

// 1. Permission Guide
struct PermissionGuideView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("首次安装后按顺序完成下面几步，Finder 右键菜单才能稳定显示并执行文件操作。")
                .foregroundColor(.secondary)
                .font(.body)
                .padding(.bottom, 8)
            
            stepRow(
                num: "1",
                title: "打开一次 QuickRightMenu",
                desc: "如果 macOS 提示来自未认证开发者，请前往系统设置的“隐私与安全性”底部点击“仍要打开”。"
            )
            
            stepRow(
                num: "2",
                title: "启用 Finder 扩展",
                desc: "启用后插件才能在访达的右键菜单中渲染出功能选项。",
                actionButton: Button("打开 Finder 扩展设置") {
                    openSystemSettings(url: "x-apple.systempreferences:com.apple.ExtensionsPreferences")
                }
            )
            
            stepRow(
                num: "3",
                title: "添加完全磁盘访问权限",
                desc: "进入“完全磁盘访问”打开本软件开关，避免创建、复制、移动文件时被系统安全层拦截。",
                actionButton: Button("打开完全磁盘访问") {
                    openSystemSettings(url: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")
                }
            )
            
            stepRow(
                num: "4",
                title: "重启 Finder 生效",
                desc: "完成上述权限配置后，重启访达进程，然后就可以在桌面或 Finder 中测试右键菜单了。",
                actionButton: Button("重启 Finder") {
                    restartFinder()
                }
            )
        }
    }
    
    @ViewBuilder
    private func stepRow(num: String, title: String, desc: String, actionButton: Button<Text>? = nil) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text(num)
                .font(.title2)
                .bold()
                .foregroundColor(.white)
                .frame(width: 32, height: 32)
                .background(Circle().fill(Color.blue))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(desc)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if let btn = actionButton {
                    btn
                        .buttonStyle(.borderedProminent)
                        .padding(.top, 4)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private func openSystemSettings(url: String) {
        if let nsURL = URL(string: url) {
            NSWorkspace.shared.open(nsURL)
        }
    }
    
    private func restartFinder() {
        let task = Process()
        task.launchPath = "/usr/bin/killall"
        task.arguments = ["Finder"]
        try? task.run()
    }
}

// 2. Menu View
struct MenuView: View {
    @ObservedObject var manager = SettingsManager.shared
    
    private var categories: [String] {
        Array(Set(manager.featureRows.map { $0.category })).sorted()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("勾选后将显示在访达右键菜单中。新建文件、复制到、移动到会折叠至二级菜单中。")
                .foregroundColor(.secondary)
                .font(.subheadline)
            
            ForEach(categories, id: \.self) { cat in
                VStack(alignment: .leading, spacing: 8) {
                    Text(cat)
                        .font(.headline)
                        .foregroundColor(.blue)
                        .padding(.top, 8)
                    
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 180))], spacing: 10) {
                        ForEach(manager.featureRows.filter { $0.category == cat }) { row in
                            Toggle(row.title, isOn: Binding(
                                get: { manager.settings[row.key] as? Bool ?? true },
                                set: { val in
                                    manager.settings[row.key] = val
                                    manager.saveSettings()
                                }
                            ))
                            .toggleStyle(.checkbox)
                        }
                    }
                }
            }
            
            HStack(spacing: 12) {
                Button("全部启用") {
                    for row in manager.featureRows {
                        manager.settings[row.key] = true
                    }
                    manager.saveSettings()
                }
                
                Button("恢复默认") {
                    manager.settings = manager.defaultSettings()
                    manager.saveSettings()
                }
            }
            .padding(.top, 16)
        }
    }
}

// 3. Templates View
struct TemplatesView: View {
    @ObservedObject var manager = SettingsManager.shared
    @State private var selectedExt = "md"
    @State private var templateContent = ""
    
    private let extensions = ["txt", "md", "json", "csv", "html", "yaml", "xml", "sh", "py", "js", "ts", "css"]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("选择文件类型并直接编辑默认内容。新建文件时将以此内容作为模板填充。")
                .foregroundColor(.secondary)
                .font(.subheadline)
            
            HStack {
                Text("文件类型:")
                    .bold()
                Picker("", selection: $selectedExt) {
                    ForEach(extensions, id: \.self) { ext in
                        Text(ext.uppercased()).tag(ext)
                    }
                }
                .frame(width: 140)
                .onChange(of: selectedExt, initial: true) { _, newExt in
                    loadTemplateContent(for: newExt)
                }
            }
            
            TextEditor(text: $templateContent)
                .font(.system(.body, design: .monospaced))
                .frame(height: 280)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.3), lineWidth: 1))
            
            HStack(spacing: 12) {
                Button("保存模板") {
                    let key = "template_\(selectedExt)"
                    manager.settings[key] = templateContent
                    manager.saveSettings()
                }
                .buttonStyle(.borderedProminent)
                
                Button("恢复默认") {
                    let key = "template_\(selectedExt)"
                    if let defaultVal = manager.defaultSettings()[key] as? String {
                        templateContent = defaultVal
                        manager.settings[key] = defaultVal
                        manager.saveSettings()
                    }
                }
            }
        }
    }
    
    private func loadTemplateContent(for ext: String) {
        let key = "template_\(ext)"
        templateContent = manager.settings[key] as? String ?? ""
    }
}

// 4. Favorites View
struct FavoritesView: View {
    @ObservedObject var manager = SettingsManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("设置常用目录后，它会显示在右键的“复制到”和“移动到”二级菜单中。")
                .foregroundColor(.secondary)
                .font(.subheadline)
            
            ForEach(1...3, id: \.self) { i in
                let nameKey = "favoriteDir\(i)Name"
                let pathKey = "favoriteDir\(i)Path"
                let name = manager.settings[nameKey] as? String ?? ""
                let path = manager.settings[pathKey] as? String ?? ""
                
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("常用槽位 \(i)")
                            .font(.headline)
                        if !path.isEmpty {
                            Text("\(name) (\(path))")
                                .font(.subheadline)
                                .foregroundColor(.primary)
                        } else {
                            Text("未设置目录")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    Button("选择文件夹") {
                        chooseFolder(forSlot: i)
                    }
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.08)))
            }
            
            Button("清空全部") {
                for i in 1...3 {
                    manager.settings["favoriteDir\(i)Name"] = ""
                    manager.settings["favoriteDir\(i)Path"] = ""
                }
                manager.saveSettings()
            }
            .buttonStyle(.bordered)
            .padding(.top, 8)
        }
    }
    
    private func chooseFolder(forSlot slot: Int) {
        let panel = NSOpenPanel()
        panel.title = "选择常用文件夹"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        
        NSApp.activate(ignoringOtherApps: true)
        if panel.runModal() == .OK, let url = panel.url {
            let name = !url.lastPathComponent.isEmpty ? url.lastPathComponent : url.path
            manager.settings["favoriteDir\(slot)Name"] = name
            manager.settings["favoriteDir\(slot)Path"] = url.path
            manager.saveSettings()
        }
    }
}

// 5. Terminal View
struct TerminalView: View {
    @ObservedObject var manager = SettingsManager.shared
    @State private var selection = "terminal"
    
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("设置“在终端打开”功能所使用的终端类型。")
                .foregroundColor(.secondary)
                .font(.subheadline)
            
            Picker("默认终端: ", selection: $selection) {
                Text("Terminal.app").tag("terminal")
                Text("iTerm2.app").tag("iterm")
                Text("Warp.app").tag("warp")
            }
            .pickerStyle(.radioGroup)
            .onChange(of: selection, initial: true) { _, newSel in
                // 在加载或变化时保存
                manager.settings["terminalPreference"] = newSel
                manager.saveSettings()
            }
            .onAppear {
                selection = manager.settings["terminalPreference"] as? String ?? "terminal"
            }
        }
    }
}

// 6. Login View
struct LoginView: View {
    @State private var isEnabled = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("开机后自动登录 macOS 时是否自动运行 QuickRightMenu 后台进程。")
                .foregroundColor(.secondary)
                .font(.subheadline)
            
            Text("当前状态: \(isEnabled ? "已开启" : "未开启")")
                .font(.headline)
                .foregroundColor(isEnabled ? .green : .secondary)
            
            Button(isEnabled ? "关闭开机启动" : "开启开机启动") {
                toggleLoginItem()
            }
            .buttonStyle(.borderedProminent)
        }
        .onAppear {
            checkLoginItemStatus()
        }
    }
    
    private var plistURL: URL {
        let path = (NSHomeDirectory() as NSString).appendingPathComponent("Library/LaunchAgents/com.liaowenbin.QuickRightMenu.plist")
        return URL(fileURLWithPath: path)
    }
    
    private func checkLoginItemStatus() {
        isEnabled = FileManager.default.fileExists(atPath: plistURL.path)
    }
    
    private func toggleLoginItem() {
        if isEnabled {
            try? FileManager.default.removeItem(at: plistURL)
        } else {
            let appPath = Bundle.main.bundlePath
            let escapedPath = appPath.replacingOccurrences(of: "&", with: "&amp;")
                .replacingOccurrences(of: "<", with: "&lt;")
                .replacingOccurrences(of: ">", with: "&gt;")
                .replacingOccurrences(of: "\"", with: "&quot;")
            
            let plist = """
            <?xml version="1.0" encoding="UTF-8"?>
            <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
            <plist version="1.0">
            <dict>
              <key>Label</key>
              <string>com.liaowenbin.QuickRightMenu</string>
              <key>ProgramArguments</key>
              <array>
                <string>/usr/bin/open</string>
                <string>\(escapedPath)</string>
              </array>
              <key>RunAtLoad</key>
              <true/>
            </dict>
            </plist>
            """
            
            try? FileManager.default.createDirectory(at: plistURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? plist.write(to: plistURL, atomically: true, encoding: .utf8)
        }
        checkLoginItemStatus()
    }
}

// 7. Update View
struct UpdateView: View {
    @ObservedObject var updateManager = UpdateManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("软件启动时会自动静默检测最新版本信息，也可在此处手动触发。")
                .foregroundColor(.secondary)
                .font(.subheadline)
            
            if updateManager.updateAvailable {
                VStack(alignment: .leading, spacing: 8) {
                    Text("发现新版本：\(updateManager.latestVersion)")
                        .font(.headline)
                        .foregroundColor(.green)
                    Text("请点击下方按钮前往下载，下载解压后覆盖替换原 App 即可。")
                        .font(.subheadline)
                }
            } else if updateManager.updateCheckFinished {
                Text("当前已是最新版本：1.5.7")
                    .font(.headline)
                    .foregroundColor(.secondary)
            } else {
                Text("正在检查更新...")
                    .font(.headline)
            }
            
            HStack(spacing: 12) {
                Button("立即检查") {
                    updateManager.updateCheckFinished = false
                    updateManager.checkForUpdatesSilently()
                }
                
                Button(updateManager.updateAvailable ? "下载新版本" : "打开 Release 页面") {
                    let urlStr = updateManager.updateAvailable ? updateManager.latestDownloadURL : "https://github.com/weaiw/QuickRightMenu/releases/latest"
                    if let url = URL(string: urlStr) {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
            .padding(.top, 8)
        }
    }
}
