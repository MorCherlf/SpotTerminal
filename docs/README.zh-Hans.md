# SpotTerminal

[![CI](https://github.com/MorCherlf/SpotTerminal/actions/workflows/ci.yml/badge.svg)](https://github.com/MorCherlf/SpotTerminal/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/MorCherlf/SpotTerminal?include_prereleases&label=release)](https://github.com/MorCherlf/SpotTerminal/releases)
[![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-0A84FF)](#系统要求)
[![Swift](https://img.shields.io/badge/Swift-5.9-FA7343?logo=swift&logoColor=white)](../Package.swift)
[![Downloads](https://img.shields.io/github/downloads/MorCherlf/SpotTerminal/total)](https://github.com/MorCherlf/SpotTerminal/releases)
[![License](https://img.shields.io/badge/license-Apache%202.0-blue)](../LICENSE)

SpotTerminal 是一款原生 macOS 终端工具，核心特色是 Spotlight 风格的悬浮命令面板。通过快捷键随时呼出，快速执行单行命令，在菜单栏监控后台任务，需要时一键展开为完整终端。

[English](../README.md) | [繁體中文](README.zh-Hant.md) | [日本語](README.ja.md) | [Русский](README.ru.md)

![SpotTerminal hero](assets/spotterminal-hero.png)

## 主要功能

- 快捷键呼出悬浮命令面板，支持命令候选和 Tab 补全。
- 完整终端窗口，支持标签页、分屏、主题、透明度和字体缩放。
- 快速命令一键展开为交互式终端。
- 菜单栏后台任务监控。

## 截图

| 主界面 |
| --- |
| ![SpotTerminal 主界面](assets/MainWindow.png) |

| 执行快速命令 | 悬浮命令面板 |
| --- | --- |
| ![执行快速命令](assets/HelloWorld.png) | ![悬浮命令面板](assets/FloatWindow.png) |

| 运行中的会话 |
| --- |
| ![菜单栏展示运行中的会话](assets/runningsessions.png) |

## 系统要求

- macOS 14 Sonoma 或更高版本。
- 支持 Apple Silicon 和 Intel Mac。

## 安装

1. 从 [GitHub Releases](https://github.com/MorCherlf/SpotTerminal/releases) 下载最新发布的 `.dmg` 文件。
2. 打开下载好的 `.dmg` 文件，根据箭头指示将 `SpotTerminal` 拖入 `Applications`。
3. 启动 SpotTerminal。

SpotTerminal 目前未经过 Apple 公证。如果 macOS 提示”无法验证开发者”，请按以下步骤操作：

1. 打开系统设置。
2. 进入隐私与安全性。
3. 找到被拦截的 SpotTerminal 提示，点击仍要打开。
4. 根据 macOS 的提示，再次确认时选择打开。

## 从源码构建

```bash
swift test
./script/build_and_run.sh --dmg
```

## 安全与隐私

SpotTerminal 仅在你的 Mac 本地运行命令。它不提供网络服务、远程 Shell API，也没有外部命令控制接口。

不包含任何遥测或数据收集功能。

## 诊断日志

SpotTerminal 可以生成本地诊断日志，帮助反馈和定位问题。日志不收集用户个人信息或设备标识符。

你可以在设置 → 诊断中打开或清理日志。

## 依赖与许可证

SpotTerminal 使用 Apache License 2.0。详见 [LICENSE](../LICENSE)。

第三方组件和许可证说明见 [THIRD_PARTY_NOTICES.md](../THIRD_PARTY_NOTICES.md)。

## AI 辅助开发

本项目大量使用 AI 辅助开发。如果你发现 bug、安全问题或异常行为，请向我们提交 issue。

## 反馈

请通过 [GitHub Issues](https://github.com/MorCherlf/SpotTerminal/issues) 反馈问题。
