# SpotTerminal

[![CI](https://github.com/MorCherlf/SpotTerminal/actions/workflows/ci.yml/badge.svg)](https://github.com/MorCherlf/SpotTerminal/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/MorCherlf/SpotTerminal?include_prereleases&label=release)](https://github.com/MorCherlf/SpotTerminal/releases)
[![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-0A84FF)](#системные-требования)
[![Swift](https://img.shields.io/badge/Swift-5.9-FA7343?logo=swift&logoColor=white)](../Package.swift)
[![Downloads](https://img.shields.io/github/downloads/MorCherlf/SpotTerminal/total)](https://github.com/MorCherlf/SpotTerminal/releases)
[![License](https://img.shields.io/badge/license-Apache%202.0-blue)](../LICENSE)

SpotTerminal — нативный терминал для macOS с плавающей командной панелью в стиле Spotlight. Вызывайте её горячей клавишей в любой момент, быстро выполняйте команды, отслеживайте фоновые задачи в строке меню и разворачивайте панель в полноценный терминал, когда нужно больше места.

[English](../README.md) | [简体中文](README.zh-Hans.md) | [繁體中文](README.zh-Hant.md) | [日本語](README.ja.md)

![SpotTerminal hero](assets/spotterminal-hero.png)

## Основные возможности

- Плавающая командная панель с подсказками команд и автодополнением по Tab.
- Полноценное окно терминала с вкладками, разделением экрана, темами, прозрачностью и масштабированием шрифта.
- Быстрая команда разворачивается в интерактивный терминал одним нажатием.
- Мониторинг фоновых задач в строке меню.

## Скриншоты

| Главное окно |
| --- |
| ![Главное окно SpotTerminal](assets/MainWindow.png) |

| Выполнение быстрой команды | Плавающая командная панель |
| --- | --- |
| ![Выполнение быстрой команды](assets/HelloWorld.png) | ![Плавающая командная панель](assets/FloatWindow.png) |

| Запущенные сессии |
| --- |
| ![Строка меню с запущенными сессиями](assets/runningsessions.png) |

## Системные требования

- macOS 14 Sonoma или новее.
- Поддерживаются Apple Silicon и Intel Mac.

## Установка

1. Скачайте последний `.dmg` файл со страницы [GitHub Releases](https://github.com/MorCherlf/SpotTerminal/releases).
2. Откройте скачанный `.dmg` файл и перетащите `SpotTerminal` в `Applications` по указателю-стрелке.
3. Запустите SpotTerminal.

SpotTerminal в настоящее время не проходил нотаризацию Apple. Если macOS показывает предупреждение «Не удаётся проверить разработчика», выполните следующие шаги:

1. Откройте Системные настройки.
2. Перейдите в раздел Конфиденциальность и безопасность.
3. Найдите сообщение о заблокированном SpotTerminal и нажмите «Всё равно открыть».
4. Подтвердите выбор, нажав «Открыть» в повторном запросе macOS.

## Сборка из исходного кода

```bash
swift test
./script/build_and_run.sh --dmg
```

## Безопасность и конфиденциальность

SpotTerminal выполняет команды локально на вашем Mac. Он не предоставляет сетевой сервер, удалённый Shell API или внешний интерфейс управления.

Телеметрия и сбор данных отсутствуют.

## Диагностика

SpotTerminal может вести локальный журнал диагностики для помощи в отчётах об ошибках. Журнал не собирает личные данные или идентификаторы устройства.

Открыть или очистить журнал можно в Настройки → Диагностика.

## Зависимости и лицензии

SpotTerminal распространяется под лицензией Apache License 2.0. Подробнее см. [LICENSE](../LICENSE).

Сторонние компоненты и лицензии перечислены в [THIRD_PARTY_NOTICES.md](../THIRD_PARTY_NOTICES.md).

## Разработка с помощью ИИ

Этот проект активно использует ИИ в процессе разработки. Если вы обнаружите баг, проблему безопасности или неожиданное поведение, пожалуйста, создайте issue.

## Обратная связь

Сообщайте об ошибках через [GitHub Issues](https://github.com/MorCherlf/SpotTerminal/issues).
