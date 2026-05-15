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

仓库里有一个模板 `Meishuguan/Resources/Secrets.example.plist`，复制一份成 `Secrets.plist` 后填值：

```bash
cp Meishuguan/Resources/Secrets.example.plist Meishuguan/Resources/Secrets.plist
# 用 Xcode 或任意编辑器打开 Secrets.plist，把 key 填进去
```

> `Secrets.plist` 已在 `.gitignore` 里，不会提交。

**必需**：
- `DASHSCOPE_API_KEY` — 阿里云通义千问 Qwen-VL，用于拍封面那一次书名识别（Vision），在 https://dashscope.console.aliyun.com 开通服务后申请
- `DEEPSEEK_API_KEY` — 用于聊天和总结（极便宜，~¥几厘一次对话），在 https://platform.deepseek.com 申请

**可选**（按生成质量从高到低，从贵到免费）：
- `MESHY_API_KEY`（真 3D，付费订阅）— 暂未启用，留作未来切换
- `REPLICATE_API_TOKEN`（2D 图，~$0.003/张，flux-schnell，质量好）— 在 https://replicate.com 注册，最低充 $5
- 都不填 — 自动走 **Pollinations**，完全免费、无 key、效果一般但能跑通整条链路

只填两个必需 key 就能完整跑通 prototype。

## 跑不通时排查

- **报 "Qwen-VL API 出错" / 401**：DashScope key 不对，或者还没在阿里云控制台开通"模型服务灵积"。去 https://dashscope.console.aliyun.com 开通一下。
- **想换 Vision model**：去 `Meishuguan/Config.swift` 把 `qwenVisionModel` 换成 `qwen-vl-max`（更强）或 `qwen-vl-plus-latest`（最新）。
- **报 "缺少 DASHSCOPE_API_KEY" / "缺少 DEEPSEEK_API_KEY"**：`Secrets.plist` 没建好，或者 plist 里 key 字段是空字符串。
- **xcodegen 报找不到 Resources**：确保 `Meishuguan/Resources/` 目录存在（仓库里有 `.gitkeep` 占位）。
- **真机跑要先填 DEVELOPMENT_TEAM**：`project.yml` 里 `DEVELOPMENT_TEAM: ""` 改成你的 Apple Developer Team ID。模拟器跑不需要。

## 技术栈

- SwiftUI + SceneKit (iOS 17+)
- 阿里云 Qwen-VL — 仅书封识别（Vision）
- DeepSeek — 聊天 + 总结（便宜）
- 图像生成：Pollinations（免费）/ Replicate flux-schnell（少花钱）
- Apple Speech.framework (语音转文字)
- 无后端 — 全部 client 直连
