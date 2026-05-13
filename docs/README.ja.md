# SpotTerminal

[![CI](https://github.com/MorCherlf/SpotTerminal/actions/workflows/ci.yml/badge.svg)](https://github.com/MorCherlf/SpotTerminal/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/MorCherlf/SpotTerminal?include_prereleases&label=release)](https://github.com/MorCherlf/SpotTerminal/releases)
[![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-0A84FF)](#システム要件)
[![Swift](https://img.shields.io/badge/Swift-5.9-FA7343?logo=swift&logoColor=white)](../Package.swift)
[![Downloads](https://img.shields.io/github/downloads/MorCherlf/SpotTerminal/total)](https://github.com/MorCherlf/SpotTerminal/releases)
[![License](https://img.shields.io/badge/license-Apache%202.0-blue)](../LICENSE)

SpotTerminal は、Spotlight スタイルのフローティングコマンドパネルを備えたネイティブ macOS ターミナルツールです。ショートカットキーでいつでも呼び出し、ワンライナーをすばやく実行、メニューバーからバックグラウンドタスクを監視、必要に応じてフルターミナルに展開できます。

[English](../README.md) | [简体中文](README.zh-Hans.md) | [繁體中文](README.zh-Hant.md) | [Русский](README.ru.md)

![SpotTerminal hero](assets/spotterminal-hero.png)

## 主な機能

- ショートカットキーでフローティングコマンドパネルを呼び出し、コマンド候補と Tab 補完に対応。
- タブ、画面分割、テーマ、透明度、フォントズームに対応したフルターミナルウィンドウ。
- クイックコマンドをワンクリックでインタラクティブターミナルに展開。
- メニューバーでのバックグラウンドタスク監視。

## スクリーンショット

| メインウィンドウ |
| --- |
| ![SpotTerminal メインウィンドウ](assets/MainWindow.png) |

| クイックコマンドの実行 | フローティングコマンドパネル |
| --- | --- |
| ![クイックコマンドの実行](assets/HelloWorld.png) | ![フローティングコマンドパネル](assets/FloatWindow.png) |

| 実行中のセッション |
| --- |
| ![メニューバーに表示された実行中のセッション](assets/runningsessions.png) |

## システム要件

- macOS 14 Sonoma 以降。
- Apple Silicon および Intel Mac に対応。

## インストール

1. [GitHub Releases](https://github.com/MorCherlf/SpotTerminal/releases) から最新の `.dmg` ファイルをダウンロードします。
2. ダウンロードした `.dmg` ファイルを開き、矢印の指示に従って `SpotTerminal` を `Applications` にドラッグします。
3. SpotTerminal を起動します。

SpotTerminal は現在 Apple の公証を受けていません。macOS が「開発元を確認できません」と表示した場合は、以下の手順で対処してください：

1. システム設定を開きます。
2. プライバシーとセキュリティに移動します。
3. ブロックされた SpotTerminal のメッセージを見つけ、「このまま開く」をクリックします。
4. macOS の確認画面で再度「開く」を選択します。

## ソースからビルド

```bash
swift test
./script/build_and_run.sh --dmg
```

## セキュリティとプライバシー

SpotTerminal はコマンドを Mac 上でローカルに実行します。ネットワークサーバー、リモートシェル API、外部コマンド制御インターフェースは提供していません。

テレメトリやデータ収集機能は一切含まれていません。

## 診断ログ

SpotTerminal はバグ報告に役立つローカル診断ログを生成できます。ログには個人情報やデバイス識別子は含まれません。

設定 → 診断からログの表示やクリアができます。

## 依存関係とライセンス

SpotTerminal は Apache License 2.0 の下で提供されています。詳細は [LICENSE](../LICENSE) をご覧ください。

サードパーティコンポーネントとライセンスの詳細は [THIRD_PARTY_NOTICES.md](../THIRD_PARTY_NOTICES.md) に記載されています。

## AI 支援開発

本プロジェクトは AI を活用して開発されています。バグ、セキュリティの問題、予期しない動作を発見された場合は、issue を作成してください。

## フィードバック

[GitHub Issues](https://github.com/MorCherlf/SpotTerminal/issues) からバグを報告してください。
