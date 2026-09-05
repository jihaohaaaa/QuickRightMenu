import SwiftUI
import Cocoa

// MARK: - Premium Color System & UI Modifiers

struct PremiumCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(NSColor.windowBackgroundColor).opacity(0.4))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.1), radius: 6, x: 0, y: 3)
    }
}

extension View {
    func premiumCardStyle() -> some View {
        self.modifier(PremiumCardModifier())
    }
}

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

// MARK: - Main Settings View (Premium UI/UX)

struct SettingsView: View {
    @State private var selection: String = "permissions"
    
    private let primaryGradient = LinearGradient(
        colors: [Color.blue, Color.purple],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    var body: some View {
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 0) {
                // Brand Header with Premium Gradient
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Image(systemName: "contextualmenu.and.cursorarrow")
                            .font(.title)
                            .foregroundStyle(primaryGradient)
                        
                        Text("QuickRightMenu")
                            .font(.title3)
                            .bold()
                            .foregroundStyle(.primary)
                    }
                    Text("极速访达右键增强工具")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 20)
                
                Divider()
                    .padding(.horizontal, 16)
                
                List(selection: $selection) {
                    Section("引导") {
                        NavigationLink(value: "permissions") {
                            Label("权限指引", systemImage: "hand.raised.fill")
                        }
                    }
                    Section("配置偏好") {
                        NavigationLink(value: "menu") {
                            Label("右键菜单", systemImage: "list.bullet.rectangle.portrait.fill")
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
                    Section("系统信息") {
                        NavigationLink(value: "login") {
                            Label("开机启动", systemImage: "power")
                        }
                        NavigationLink(value: "update") {
                            Label("软件更新", systemImage: "arrow.clockwise.circle.fill")
                        }
                    }
                }
                .listStyle(.sidebar)
            }
            .background(.ultraThinMaterial)
            .navigationSplitViewColumnWidth(min: 220, ideal: 240, max: 260)
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    // Header Area of selected panel
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(titleForSelection(selection))
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(primaryGradient)
                            Text(descForSelection(selection))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.bottom, 8)
                    
                    // Specific View Content
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
                        Text("请在侧边栏选择配置项")
                    }
                }
                .padding(36)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(
                Color(NSColor.windowBackgroundColor)
                    .overlay(
                        RadialGradient(
                            colors: [Color.blue.opacity(0.04), Color.purple.opacity(0.04), Color.clear],
                            center: .topTrailing,
                            startRadius: 0,
                            endRadius: 500
                        )
                    )
            )
        }
    }
    
    private func titleForSelection(_ sel: String) -> String {
        switch sel {
        case "permissions": return "权限配置指引"
        case "menu": return "右键功能开关"
        case "templates": return "文件新建模板"
        case "favorites": return "常用目标目录"
        case "terminal": return "集成终端偏好"
        case "login": return "系统开机自启"
        case "update": return "软件版本检查"
        default: return "设置"
        }
    }
    
    private func descForSelection(_ sel: String) -> String {
        switch sel {
        case "permissions": return "确保权限完整配置，使得右键菜单加载及后台文件操作畅通无阻。"
        case "menu": return "动态配置您想展示的快捷命令，可选择分类开启/关闭。"
        case "templates": return "定义新建各类型文本文件时的预填入模板内容。"
        case "favorites": return "添加至多三个快速文件夹，直接呼出“复制到”/“移动到”二级菜单。"
        case "terminal": return "设置“在终端打开”功能触发时，默认调用的终端应用类型。"
        case "login": return "开启后在系统每次登录时自动运行后台轮询守护进程。"
        case "update": return "在线检测 GitHub 最新 release，一键下载并覆盖安装最新版本。"
        default: return ""
        }
    }
}

// MARK: - Premium Subviews

// 1. Permission Guide
struct PermissionGuideView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            stepRow(
                num: "1",
                title: "启动宿主应用授权",
                desc: "如果是首次运行，系统安全层可能会弹出提示，请至“系统设置 -> 隐私与安全性”底部点击“仍要打开”以完成软件认证。"
            )
            
            stepRow(
                num: "2",
                title: "激活访达插件扩展",
                desc: "启用 Finder Sync 插件，使 QuickRightMenu 能够在桌面的右键菜单中渲染出功能选项。",
                buttonTitle: "跳转开启扩展设置",
                buttonIcon: "arrow.up.forward.app.fill",
                action: {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.ExtensionsPreferences")!)
                }
            )
            
            stepRow(
                num: "3",
                title: "授予完全磁盘访问权限",
                desc: "赋予主应用磁盘访问权限，避免跨沙盒创建文件、复制和剪切文件夹时被系统权限拦截阻挡。",
                buttonTitle: "跳转完全磁盘访问权限",
                buttonIcon: "lock.shield.fill",
                action: {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!)
                }
            )
            
            stepRow(
                num: "4",
                title: "重启 Finder 进程生效",
                desc: "配置完成后，必须重新启动一次访达进程以清空系统缓存，使扩展和右键菜单项目重新渲染载入。",
                buttonTitle: "立即重启 Finder",
                buttonIcon: "arrow.clockwise.circle.fill",
                action: {
                    let task = Process()
                    task.launchPath = "/usr/bin/killall"
                    task.arguments = ["Finder"]
                    try? task.run()
                }
            )
        }
    }
    
    @State private var isHoveringButton = false
    
    @ViewBuilder
    private func stepRow(num: String, title: String, desc: String, buttonTitle: String? = nil, buttonIcon: String? = nil, action: (() -> Void)? = nil) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Text(num)
                .font(.system(.title3, design: .rounded))
                .bold()
                .foregroundColor(.white)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(LinearGradient(colors: [Color.blue, Color.indigo], startPoint: .top, endPoint: .bottom))
                )
                .shadow(color: Color.blue.opacity(0.3), radius: 4, x: 0, y: 2)
            
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(desc)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineSpacing(4)
                
                if let btnTitle = buttonTitle, let act = action {
                    Button(action: act) {
                        HStack {
                            if let icon = buttonIcon {
                                Image(systemName: icon)
                            }
                            Text(btnTitle)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(num == "4" ? Color.red.opacity(0.85) : Color.blue.opacity(0.85))
                    .padding(.top, 6)
                }
            }
            Spacer()
        }
        .premiumCardStyle()
    }
}

// 2. Menu View
struct MenuView: View {
    @ObservedObject var manager = SettingsManager.shared
    
    private var categories: [String] {
        Array(Set(manager.featureRows.map { $0.category })).sorted()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(spacing: 12) {
                Button(action: {
                    for row in manager.featureRows {
                        manager.settings[row.key] = true
                    }
                    manager.saveSettings()
                }) {
                    Label("全部启用", systemImage: "checkmark.circle.fill")
                }
                .buttonStyle(.bordered)
                
                Button(action: {
                    manager.settings = manager.defaultSettings()
                    manager.saveSettings()
                }) {
                    Label("恢复默认值", systemImage: "arrow.uturn.backward.circle.fill")
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button(action: {
                    let url = CentralStorage.rootURL
                    NSWorkspace.shared.selectFile(CentralStorage.configFileURL.path, inFileViewerRootedAtPath: url.path)
                }) {
                    Label("打开配置目录", systemImage: "folder")
                }
                .buttonStyle(.bordered)
                .help("在访达中打开 ~/.quickrightmenu/")
            }
            .padding(.bottom, 4)
            
            ForEach(categories, id: \.self) { cat in
                VStack(alignment: .leading, spacing: 12) {
                    Text(cat)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 4)
                    
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 180, maximum: 240))], spacing: 12) {
                        ForEach(manager.featureRows.filter { $0.category == cat }) { row in
                            Toggle(isOn: Binding(
                                get: { manager.settings[row.key] as? Bool ?? true },
                                set: { val in
                                    manager.settings[row.key] = val
                                    manager.saveSettings()
                                }
                            )) {
                                Text(row.title)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            .toggleStyle(.checkbox)
                            .padding(10)
                            .background(Color(NSColor.controlBackgroundColor).opacity(0.2))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
                            )
                        }
                    }
                }
                .padding(16)
                .background(Color(NSColor.windowBackgroundColor).opacity(0.3))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
            }
        }
    }
}

// 3. Templates View
struct TemplatesView: View {
    @ObservedObject var manager = SettingsManager.shared
    @State private var selectedTemplateId: String? = nil
    
    private var selectedTemplateBinding: Binding<CustomFileTemplate>? {
        guard let id = selectedTemplateId,
              let index = manager.customTemplates.firstIndex(where: { $0.id == id }) else {
            return nil
        }
        return Binding<CustomFileTemplate>(
            get: {
                if index < manager.customTemplates.count {
                    return manager.customTemplates[index]
                }
                return CustomFileTemplate(title: "", extensionName: "")
            },
            set: { updated in
                var list = manager.customTemplates
                if index < list.count {
                    list[index] = updated
                    manager.customTemplates = list
                }
            }
        )
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Left list of templates
            VStack(spacing: 0) {
                HStack {
                    Text("模板列表")
                        .font(.headline)
                        .fontWeight(.semibold)
                    Spacer()
                    Text("\(manager.customTemplates.count) 项")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                
                Divider()
                
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(manager.customTemplates) { tpl in
                            let isSelected = (tpl.id == selectedTemplateId)
                            HStack(spacing: 8) {
                                Toggle("", isOn: Binding(
                                    get: { tpl.isEnabled },
                                    set: { newValue in
                                        var list = manager.customTemplates
                                        if let idx = list.firstIndex(where: { $0.id == tpl.id }) {
                                            list[idx].isEnabled = newValue
                                            manager.customTemplates = list
                                        }
                                    }
                                ))
                                .labelsHidden()
                                .toggleStyle(.switch)
                                .scaleEffect(0.7)
                                .frame(width: 36)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(tpl.title.isEmpty ? "未命名模板" : tpl.title)
                                        .font(.subheadline)
                                        .fontWeight(isSelected ? .semibold : .regular)
                                        .lineLimit(1)
                                    
                                    Text(".\(tpl.extensionName)")
                                        .font(.system(.caption2, design: .monospaced))
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 1)
                                        .background(Color.blue.opacity(0.12))
                                        .foregroundColor(.blue)
                                        .cornerRadius(4)
                                }
                                
                                Spacer()
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(isSelected ? Color.accentColor.opacity(0.18) : Color.clear)
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedTemplateId = tpl.id
                            }
                        }
                    }
                    .padding(8)
                }
                .frame(minHeight: 340)
                
                Divider()
                
                // Toolbar: Add & Delete
                HStack(spacing: 12) {
                    Button(action: addNewTemplate) {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.borderless)
                    .help("新建模板")
                    
                    Button(action: deleteSelectedTemplate) {
                        Image(systemName: "minus")
                    }
                    .buttonStyle(.borderless)
                    .disabled(selectedTemplateId == nil || manager.customTemplates.count <= 1)
                    .help("删除所选模板")
                    
                    Spacer()
                    
                    Button(action: resetToDefault) {
                        Image(systemName: "arrow.counterclockwise")
                    }
                    .buttonStyle(.borderless)
                    .help("恢复为默认模板")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .frame(width: 220)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.35))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            
            // Right detail editor
            VStack(alignment: .leading, spacing: 14) {
                if let binding = selectedTemplateBinding {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("模板名称")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        TextField("例如：Markdown 文档、React 组件", text: binding.title)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("文件扩展名")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        HStack {
                            Text(".")
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.secondary)
                            TextField("例如：md、tsx、py", text: Binding(
                                get: { binding.wrappedValue.extensionName },
                                set: { raw in
                                    let sanitized = raw.trimmingCharacters(in: CharacterSet(charactersIn: "."))
                                    binding.wrappedValue.extensionName = sanitized
                                }
                            ))
                            .textFieldStyle(.roundedBorder)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("预填模板内容")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("纯文本 / 源码")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        TextEditor(text: binding.content)
                            .font(.system(.body, design: .monospaced))
                            .padding(8)
                            .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
                            .cornerRadius(8)
                            .frame(minHeight: 220)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                            )
                    }
                    
                    HStack {
                        Spacer()
                        Text("自动保存所有修改")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                } else {
                    VStack(spacing: 12) {
                        Spacer()
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        Text("请在左侧选择一个模板，或点击加号新建")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, minHeight: 380)
                }
            }
            .padding(16)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.2))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        .onAppear {
            if selectedTemplateId == nil, let first = manager.customTemplates.first {
                selectedTemplateId = first.id
            }
        }
    }
    
    private func addNewTemplate() {
        let newTpl = CustomFileTemplate(
            title: "新模板",
            extensionName: "txt",
            content: "",
            isEnabled: true
        )
        var list = manager.customTemplates
        list.append(newTpl)
        manager.customTemplates = list
        selectedTemplateId = newTpl.id
    }
    
    private func deleteSelectedTemplate() {
        guard let id = selectedTemplateId else { return }
        var list = manager.customTemplates
        guard list.count > 1 else { return }
        if let idx = list.firstIndex(where: { $0.id == id }) {
            list.remove(at: idx)
            manager.customTemplates = list
            selectedTemplateId = list.first?.id
        }
    }
    
    private func resetToDefault() {
        let defaultTpl = CustomFileTemplate(title: "纯文本", extensionName: "txt", content: "", isEnabled: true)
        manager.customTemplates = [defaultTpl]
        selectedTemplateId = defaultTpl.id
    }
}

// 4. Favorites View
struct FavoritesView: View {
    @ObservedObject var manager = SettingsManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            ForEach(1...3, id: \.self) { i in
                let nameKey = "favoriteDir\(i)Name"
                let pathKey = "favoriteDir\(i)Path"
                let name = manager.settings[nameKey] as? String ?? ""
                let path = manager.settings[pathKey] as? String ?? ""
                
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Image(systemName: "\(i).circle.fill")
                                .foregroundColor(.blue)
                                .font(.title3)
                            Text("常用目标槽位 \(i)")
                                .font(.headline)
                                .fontWeight(.bold)
                        }
                        
                        if !path.isEmpty {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(name)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text(path)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.leading, 28)
                        } else {
                            Text("未绑定任何目录。右键菜单中该槽位将被隐藏。")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.leading, 28)
                        }
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        chooseFolder(forSlot: i)
                    }) {
                        Label(path.isEmpty ? "设定目录" : "重新选取", systemImage: "folder.fill.badge.plus")
                    }
                    .buttonStyle(.bordered)
                }
                .padding(18)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.15))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
            }
            
            Button(action: {
                for i in 1...3 {
                    manager.settings["favoriteDir\(i)Name"] = ""
                    manager.settings["favoriteDir\(i)Path"] = ""
                }
                manager.saveSettings()
            }) {
                Label("清空所有槽位", systemImage: "trash")
            }
            .buttonStyle(.bordered)
            .foregroundColor(.red)
            .padding(.top, 4)
        }
    }
    
    private func chooseFolder(forSlot slot: Int) {
        let panel = NSOpenPanel()
        panel.title = "选择常用目标路径"
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
            Picker("默认终端应用: ", selection: $selection) {
                Text("系统终端 (Terminal.app)").tag("terminal")
                Text("iTerm2.app").tag("iterm")
                Text("Warp.app").tag("warp")
            }
            .pickerStyle(.radioGroup)
            .onChange(of: selection, initial: true) { _, newSel in
                manager.settings["terminalPreference"] = newSel
                manager.saveSettings()
            }
            .onAppear {
                selection = manager.settings["terminalPreference"] as? String ?? "terminal"
            }
            .padding(8)
        }
        .premiumCardStyle()
    }
}

// 6. Login View
struct LoginView: View {
    @State private var isEnabled = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: isEnabled ? "power.circle.fill" : "power.circle")
                    .font(.system(size: 36))
                    .foregroundColor(isEnabled ? .green : .secondary)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("系统登录自启动进程")
                        .font(.headline)
                    Text("开机并自动登录 macOS 系统时，是否立即在后台拉起此服务。")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
            
            HStack {
                Text("开机自启状态:")
                    .bold()
                Text(isEnabled ? "已启用" : "未开启")
                    .foregroundColor(isEnabled ? .green : .secondary)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button(action: {
                    toggleLoginItem()
                }) {
                    Text(isEnabled ? "停用开机自启" : "启用开机自启")
                }
                .buttonStyle(.borderedProminent)
                .tint(isEnabled ? Color.red.opacity(0.8) : Color.blue)
            }
        }
        .premiumCardStyle()
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
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 16) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("QuickRightMenu")
                        .font(.headline)
                    Text("当前版本: 1.5.7")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            
            Divider()
            
            if updateManager.updateAvailable {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .foregroundColor(.green)
                        Text("发现可用的全新版本：\(updateManager.latestVersion)")
                            .font(.headline)
                            .foregroundColor(.green)
                    }
                    Text("新版包含功能修复与体验优化。可直接点击下方按钮一键前往 GitHub 下载最新安装包覆盖安装。")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineSpacing(4)
                }
                .padding(14)
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
            } else if updateManager.updateCheckFinished {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundColor(.green)
                    Text("您的应用已是最新版本，无需更新。")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            } else {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("正在静默检测云端最新 Release 版本...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            HStack(spacing: 12) {
                Button(action: {
                    updateManager.updateCheckFinished = false
                    updateManager.checkForUpdatesSilently()
                }) {
                    Label("手动检查更新", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                
                Button(action: {
                    let urlStr = updateManager.updateAvailable ? updateManager.latestDownloadURL : "https://github.com/weaiw/QuickRightMenu/releases/latest"
                    if let url = URL(string: urlStr) {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    Label(updateManager.updateAvailable ? "立即下载新版" : "访问 GitHub 主页", systemImage: "safari")
                }
                .buttonStyle(.borderedProminent)
                .tint(updateManager.updateAvailable ? Color.green : Color.blue)
            }
        }
        .premiumCardStyle()
    }
}
