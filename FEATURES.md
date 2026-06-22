# QuickRightMeniu 功能清单

## 1.5.5 已完成

- 新建 TXT
- 新建 Markdown
- 新建 JSON
- 新建 CSV
- 新建 HTML
- 新建 YAML
- 新建 XML
- 新建 Shell
- 新建 Python
- 新建 JavaScript
- 新建 TypeScript
- 新建 CSS
- 新建 Word
- 新建 Excel
- 新建 PowerPoint
- 复制路径
- 复制文件名
- 复制父目录
- 复制 file URL
- 复制 Markdown 链接
- 复制到桌面 / 文稿 / 下载 / 图片 / 影片 / 音乐
- 移动到桌面 / 文稿 / 下载 / 图片 / 影片 / 音乐
- 复制到自选文件夹
- 移动到自选文件夹
- 批量重命名
- 复制图片尺寸
- 压缩图片
- 转换 PNG / JPEG / WebP
- 统计字数
- 转 UTF-8
- 快速预览纯文本
- 自定义菜单开关
- 文件模板设置
- 常用目录设置
- 终端偏好
- 开机启动
- 在终端打开
- 设置界面
- App 图标

实现说明：
- FinderSync 扩展只负责写入命令文件。
- 主 App 常驻菜单栏并轮询命令文件执行动作。
- 这个设计绕开了 FinderSync 沙盒对 `openURL` 和分布式通知的限制。

## 下一批可加

- 终端增强：支持 iTerm2 / Warp / VS Code 终端。
- 打开方式：用 VS Code 打开、用 Cursor 打开、用默认编辑器打开。
- 文件操作：按日期归档、自定义常用目录。
- 图片工具：去除 EXIF、调整尺寸。
- 文本工具：大小写转换、换行格式转换。
- 设置界面：更细的分类页、搜索菜单项。
- 开机启动：状态检测和启动项修复。
