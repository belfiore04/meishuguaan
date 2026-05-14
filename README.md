# 美书馆 (Meishuguan)

一款 AI 读书伴侣 iOS app 的 prototype。

## 当前进度

第一周 prototype — 验证单链路：拍书 → 与 AI 聊 → 生成 3D 展品。

## 怎么打开

需要 macOS + Xcode 16+。

**方式 A — 用 XcodeGen 生成 Xcode 项目（推荐）**

```bash
brew install xcodegen
cd meishuguan
xcodegen generate
open Meishuguan.xcodeproj
```

**方式 B — 手动建 Xcode 项目**

在 Xcode 里 `File → New → Project → iOS App`，命名 `Meishuguan`，
Interface 选 `SwiftUI`，Language 选 `Swift`，Deployment Target 17.0。
然后把本仓库 `Meishuguan/` 下的所有 `.swift` 文件拖进项目。
按 `project.yml` 里 `info.properties` 给 Info.plist 加权限说明。

## 配置 API key

在项目根目录创建 `Meishuguan/Resources/Secrets.plist`，内容：

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>ANTHROPIC_API_KEY</key>
    <string>sk-ant-...</string>
    <key>MESHY_API_KEY</key>
    <string>msy_...</string>
</dict>
</plist>
```

> `Secrets.plist` 已在 `.gitignore` 里，不会提交。

需要的 key：
- Anthropic Claude — 在 console.anthropic.com 申请
- Meshy — 在 meshy.ai 申请

## 技术栈

- SwiftUI + SceneKit (iOS 17+)
- Anthropic Claude (LLM + Vision)
- Meshy (text-to-3D)
- Apple Speech.framework (语音转文字)
- 无后端 — 全部 client 直连
