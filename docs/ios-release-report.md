# Отчёт: Сборка и публикация iOS-приложения «СмИТ Биллинг» в App Store

**Дата:** 17 марта 2026
**Проект:** SmIT Billing Mobile App (Flutter)
**Bundle ID:** `ru.smit34.smitBilling`
**Версия:** 1.1.0

---

## 1. Исходное состояние

- **macOS:** 12.7.6 (Monterey) на MacBook Pro 2016 (Intel i7-6700HQ)
- **Flutter:** 3.16.5 (Dart 3.2.3)
- **Xcode:** отсутствовал (только Command Line Tools)
- **Git-репозиторий:** не инициализирован
- **Сертификаты подписи:** отсутствовали
- **Apple Developer аккаунт:** оплачен, но не настроен на данном Mac

---

## 2. Выполненные шаги

### 2.1. Установка Xcode

- Попытки установить `mas` и `xcodes` через Homebrew не удались — обе утилиты требуют Xcode для компиляции Swift (замкнутый круг)
- **Решение:** установка Xcode 14.2 вручную из Mac App Store
- Выполнены `xcode-select -s` и `xcodebuild -license accept`

### 2.2. Настройка сертификатов

- Добавлен Apple Developer аккаунт в Xcode (Settings → Accounts)
- Создан сертификат **Apple Development** (автоматически)
- Создан сертификат **Apple Distribution** (вручную через Manage Certificates)

### 2.3. Обновление Flutter

- Flutter 3.16.5 (Dart 3.2.3) не совместим с зависимостями проекта (`url_launcher >=6.3.1` требует Dart >=3.3.0)
- Попытка `flutter upgrade` до 3.41.4 провалилась — новый Dart требует macOS 14+
- **Решение:** переключение на Flutter 3.24.5 (Dart 3.5.4) — последняя версия, совместимая с macOS 12

### 2.4. Решение проблем совместимости зависимостей

- **Firebase:** `firebase_core ^3.8.1` и `firebase_messaging ^15.1.6` тянули Firebase iOS SDK 11.x, который использует Swift 6 фичи (`sending` keyword), несовместимые с Xcode 14.2 (Swift 5.7)
- **Решение:** понижение до `firebase_core ^2.32.0` и `firebase_messaging ^14.9.4` (Firebase iOS SDK 10.x)
- **iOS Deployment Target:** повышен с 12.0 до 13.0 в Podfile (требование Firebase)
- **CocoaPods specs:** обновлены через `pod repo update`

### 2.5. Первая локальная сборка IPA

- Команда `flutter build ipa --release` успешно создала IPA (103.2 МБ)
- **Исправлены ошибки валидации:**
  - Добавлена ориентация `UIInterfaceOrientationPortraitUpsideDown` для iPad в Info.plist
  - Удалён альфа-канал из всех иконок приложения (конвертация PNG → BMP → PNG через `sips`)

### 2.6. Попытка загрузки через Transporter

- IPA загружена в Transporter, но отклонена Apple:
  > *"All iOS and iPadOS apps must be built with the iOS 18 SDK or later, included in Xcode 16 or later"*
- **Причина:** Xcode 14.2 содержит iOS 16.2 SDK, а Apple с 2025 года требует iOS 18 SDK
- **Xcode 16 требует macOS 14 (Sonoma)**, а MacBook Pro 2016 поддерживает максимум macOS 12

### 2.7. Переход на облачную сборку

#### Попытка с Codemagic
- Установлен GitHub CLI (`gh`) — скачан бинарник напрямую (brew не смог собрать)
- Создан приватный GitHub-репозиторий `ircitdev/smit-billing-mobile`
- Создан `codemagic.yaml` с конфигурацией сборки
- **Проблемы Codemagic:**
  - Долгая загрузка конфигурации (тяжёлый репозиторий)
  - Приложение привязано к Personal Account вместо Team с API ключом
  - Зависания интерфейса авторизации
- **Решение:** переход на GitHub Actions

#### GitHub Actions
- Создан workflow `.github/workflows/ios-release.yml`
- Настроены GitHub Secrets:
  - `P12_BASE64` — экспортированный сертификат Distribution
  - `P12_PASSWORD` — пароль сертификата
  - `KEYCHAIN_PASSWORD` — пароль временного keychain
  - `APP_STORE_API_KEY_ID` — ID ключа App Store Connect API (D23K22BL7G)
  - `APP_STORE_API_ISSUER_ID` — Issuer ID (bc2f87f4-bf23-4c81-b115-c53f2da3e0d6)
  - `APP_STORE_API_KEY_P8` — содержимое .p8 файла
  - `PROVISION_PROFILE_BASE64` — provisioning profile

### 2.8. Итеративное исправление ошибок сборки в GitHub Actions

| # | Ошибка | Решение |
|---|--------|---------|
| 1 | iOS 18.2 SDK not installed (macos-15 runner) | Переключение на `macos-14` runner |
| 2 | Non-modular header in firebase_messaging | Флаг `CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES=YES` в xcodebuild |
| 3 | Signing requires development team | Добавлен `DEVELOPMENT_TEAM=6LX2W6558K` |
| 4 | No profiles for bundle ID (export) | Создан App Store provisioning profile через Apple API |
| 5 | Cloud signing permission error | Ручная подпись в ExportOptions.plist с указанием профиля |
| 6 | IPA file not found for upload | `destination: upload` в ExportOptions уже загружает IPA автоматически |

### 2.9. Создание provisioning profile через Apple API

- Сгенерирован JWT-токен для App Store Connect API (PyJWT + cryptography)
- Проверена регистрация Bundle ID `ru.smit34.smitBilling` (ID: 2F8V8XVA9J)
- Найден сертификат Distribution (ID: 9MMMWKNCS9)
- Создан профиль "SmIT Billing AppStore" типа `IOS_APP_STORE` через REST API

### 2.10. Оптимизация репозитория

- Удалены тяжёлые файлы из git: `store/` (скриншоты, 15 МБ), `.aab`, `.jks`
- Пересоздана чистая git-история (orphan branch) для ускорения клонирования

---

## 3. Результат

- **4 сборки (builds 3–6)** успешно загружены в **TestFlight**
- Сборки 3, 4, 5 — статус **"Завершено"**
- Сборка 6 — статус **"Обработка"**
- CI/CD полностью автоматизирован: каждый push в `main` → сборка → загрузка в App Store Connect
- Создан скилл `/publish-ios` для быстрой публикации

---

## 4. Архитектура CI/CD

```
git push main
    ↓
GitHub Actions (macos-14, Xcode 16.2)
    ↓
flutter pub get → pod install → xcodebuild archive
    ↓
xcodebuild -exportArchive (destination: upload)
    ↓
App Store Connect / TestFlight
```

---

## 5. Выводы

1. **macOS 12 + Xcode 14.2 недостаточны** для публикации в App Store в 2026 году. Apple требует iOS 18 SDK (Xcode 16+, macOS 14+). Облачная сборка — единственный вариант для старых Mac.

2. **GitHub Actions — оптимальное решение** для CI/CD на Flutter iOS. Runner `macos-14` предоставляет Xcode 16.2 с нужным SDK. Бесплатный лимит (2000 минут/мес для приватных репо) достаточен для регулярных сборок.

3. **Firebase SDK версионирование критично.** Firebase iOS SDK 11.x использует Swift 6 фичи и несовместим со старыми версиями Xcode. При облачной сборке с Xcode 16 можно вернуться на актуальные версии Firebase.

4. **Автоматическая подпись через API Key** — самый надёжный подход для CI. Xcode автоматически создаёт и обновляет provisioning profiles при наличии `-allowProvisioningUpdates` и API Key.

5. **ExportOptions.plist с `destination: upload`** позволяет загрузить IPA напрямую из `xcodebuild -exportArchive`, без отдельного вызова `xcrun altool`.

---

## 6. Конфигурация для воспроизведения

| Параметр | Значение |
|----------|----------|
| GitHub Repo | `ircitdev/smit-billing-mobile` |
| Bundle ID | `ru.smit34.smitBilling` |
| Team ID | `6LX2W6558K` |
| API Key ID | `D23K22BL7G` |
| Issuer ID | `bc2f87f4-bf23-4c81-b115-c53f2da3e0d6` |
| Runner | `macos-14` |
| Xcode | 16.2 |
| Flutter | 3.24.5 |
| Signing | Manual (Apple Distribution) |
| Profile | SmIT Billing AppStore (IOS_APP_STORE) |

---

## 7. Рекомендации

- **Обновить Firebase** до актуальных версий (`firebase_core ^3.x`, `firebase_messaging ^15.x`) — на Xcode 16 в CI это будет работать
- **Добавить скриншоты** в App Store Connect для публикации в App Store
- **Заполнить экспортные документы** (информация о шифровании) в TestFlight
- **Рассмотреть обновление macOS** на Mac (через OpenCore Legacy Patcher) или приобретение Mac с Apple Silicon для локальной разработки
