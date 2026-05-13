# SpotTerminal

[![CI](https://github.com/MorCherlf/SpotTerminal/actions/workflows/ci.yml/badge.svg)](https://github.com/MorCherlf/SpotTerminal/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/MorCherlf/SpotTerminal?include_prereleases&label=release)](https://github.com/MorCherlf/SpotTerminal/releases)
[![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-0A84FF)](#系統需求)
[![Swift](https://img.shields.io/badge/Swift-5.9-FA7343?logo=swift&logoColor=white)](../Package.swift)
[![Downloads](https://img.shields.io/github/downloads/MorCherlf/SpotTerminal/total)](https://github.com/MorCherlf/SpotTerminal/releases)
[![License](https://img.shields.io/badge/license-Apache%202.0-blue)](../LICENSE)

SpotTerminal 是一款原生 macOS 終端工具，核心特色是 Spotlight 風格的懸浮命令面板。透過快捷鍵隨時呼出，快速執行單行命令，在選單列監控背景任務，需要時一鍵展開為完整終端。

[English](../README.md) | [简体中文](README.zh-Hans.md) | [日本語](README.ja.md) | [Русский](README.ru.md)

![SpotTerminal hero](assets/spotterminal-hero.png)

## 主要功能

- 快捷鍵呼出懸浮命令面板，支援命令候選和 Tab 補全。
- 完整終端視窗，支援分頁、分割畫面、主題、透明度和字型縮放。
- 快速命令一鍵展開為互動式終端。
- 選單列背景任務監控。

## 截圖

| 主介面 |
| --- |
| ![SpotTerminal 主介面](assets/MainWindow.png) |

| 執行快速命令 | 懸浮命令面板 |
| --- | --- |
| ![執行快速命令](assets/HelloWorld.png) | ![懸浮命令面板](assets/FloatWindow.png) |

| 執行中的工作階段 |
| --- |
| ![選單列顯示執行中的工作階段](assets/runningsessions.png) |

## 系統需求

- macOS 14 Sonoma 或更新版本。
- 支援 Apple Silicon 和 Intel Mac。

## 安裝

1. 從 [GitHub Releases](https://github.com/MorCherlf/SpotTerminal/releases) 下載最新的 `.dmg` 檔案。
2. 開啟下載的 `.dmg` 檔案，依照箭頭指示將 `SpotTerminal` 拖入 `Applications`。
3. 啟動 SpotTerminal。

SpotTerminal 目前未經過 Apple 公證。如果 macOS 顯示「無法驗證開發者」，請依照以下步驟操作：

1. 開啟系統設定。
2. 前往隱私權與安全性。
3. 找到被攔截的 SpotTerminal 提示，點選仍要打開。
4. 依照 macOS 提示，再次確認時選擇打開。

## 從原始碼建置

```bash
swift test
./script/build_and_run.sh --dmg
```

## 安全與隱私

SpotTerminal 僅在你的 Mac 本機執行命令。它不提供網路服務、遠端 Shell API，也沒有外部命令控制介面。

不包含任何遙測或資料收集功能。

## 診斷記錄

SpotTerminal 可以產生本機診斷記錄，協助回報與定位問題。記錄不會收集使用者個人資訊或裝置識別碼。

你可以在設定 → 診斷中開啟或清理記錄。

## 相依套件與授權

SpotTerminal 使用 Apache License 2.0。詳見 [LICENSE](../LICENSE)。

第三方元件和授權說明見 [THIRD_PARTY_NOTICES.md](../THIRD_PARTY_NOTICES.md)。

## AI 輔助開發

本專案大量使用 AI 輔助開發。如果你發現 bug、安全問題或異常行為，請提交 issue。

## 意見回饋

請透過 [GitHub Issues](https://github.com/MorCherlf/SpotTerminal/issues) 回報問題。
