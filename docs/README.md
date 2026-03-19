# СмИТ Биллинг — Мобильное приложение

**Мобильное приложение личного кабинета абонента интернет-провайдера СмИТ (г. Волгоград)**

| Параметр | Значение |
|----------|----------|
| Платформа | iOS, Android |
| Фреймворк | Flutter 3.24.5 (Dart 3.5.4) |
| Версия | 1.1.0 |
| Bundle ID (iOS) | `ru.smit34.smitBilling` |
| Package (Android) | `ru.smit34.smit_billing` |
| Минимальная iOS | 13.0 |
| Минимальный Android | 6.0 (API 23) |
| CI/CD | GitHub Actions → App Store Connect |
| Оператор | ООО «СмИТ», smit34.ru |

---

## Содержание

1. [Возможности приложения](#1-возможности-приложения)
2. [Архитектура](#2-архитектура)
3. [Структура проекта](#3-структура-проекта)
4. [Экраны приложения](#4-экраны-приложения)
5. [API и сервисы](#5-api-и-сервисы)
6. [Модели данных](#6-модели-данных)
7. [Аутентификация](#7-аутентификация)
8. [Платёжная система](#8-платёжная-система)
9. [Push-уведомления](#9-push-уведомления)
10. [UI и дизайн](#10-ui-и-дизайн)
11. [CI/CD и публикация](#11-cicd-и-публикация)
12. [Документы для App Store](#12-документы-для-app-store)
13. [Настройка окружения](#13-настройка-окружения)
14. [Отчёт о публикации iOS](#14-отчёт-о-публикации-ios)

---

## 1. Возможности приложения

### Для абонента
- Просмотр баланса, тарифа и статуса подключения
- Пополнение счёта банковской картой через ЮKassa
- Активация обещанного платежа
- История финансовых операций с фильтрацией по периодам
- Смена тарифного плана
- Обращения в техподдержку (тикет-система с чатом)
- Добровольная блокировка услуг (на время отпуска)
- Смена пароля
- Push-уведомления о состоянии счёта

### Безопасность
- JWT-авторизация (access + refresh токены)
- Вход по биометрии (Face ID / Touch ID)
- OAuth через ВКонтакте и Telegram
- Зашифрованное хранение данных (iOS Keychain)
- Передача данных только по HTTPS

### Аналитика
- Спарклайн-график баланса (последние 30 операций)
- Сводка по доходам/расходам за период
- Информация о последнем платеже

---

## 2. Архитектура

### Общая схема

```
┌─────────────────────────────────┐
│         Flutter App             │
│                                 │
│  ┌──────────┐  ┌─────────────┐ │
│  │ Screens  │  │  Widgets    │ │
│  │ (UI)     │  │             │ │
│  └────┬─────┘  └──────┬──────┘ │
│       │               │        │
│  ┌────▼───────────────▼──────┐ │
│  │      Providers            │ │
│  │  (State Management)       │ │
│  │  - AuthProvider           │ │
│  │  - AccountProvider        │ │
│  └────┬──────────────────────┘ │
│       │                        │
│  ┌────▼──────────────────────┐ │
│  │       Services            │ │
│  │  - ApiClient (HTTP)       │ │
│  │  - PushService (FCM)      │ │
│  └────┬──────────────────────┘ │
│       │                        │
│  ┌────▼──────────────────────┐ │
│  │       Models              │ │
│  │  - AccountStatus          │ │
│  │  - Tariff                 │ │
│  │  - FinanceOperation       │ │
│  └───────────────────────────┘ │
└───────────┬───────────────────┘
            │ HTTPS
            ▼
┌───────────────────────────────┐
│    СмИТ Биллинг API           │
│  demo.billing.smit34.ru       │
│  /mobile-api/v1               │
└───────────────────────────────┘
```

### Паттерны
- **State Management:** Provider (ChangeNotifier)
- **HTTP:** Собственный ApiClient-обёртка над `http` package
- **Навигация:** MaterialPageRoute (императивная)
- **Хранение:** FlutterSecureStorage (токены), SharedPreferences (настройки)

---

## 3. Структура проекта

```
lib/
├── main.dart                          # Точка входа, тема, роутинг
├── models/
│   ├── account_status.dart            # Модель статуса абонента
│   ├── tariff.dart                    # Модель тарифа
│   └── finance_operation.dart         # Модель финансовой операции
├── providers/
│   ├── auth_provider.dart             # Аутентификация, биометрия
│   └── account_provider.dart          # Данные абонента, финансы, тикеты
├── services/
│   ├── api_client.dart                # HTTP-клиент, JWT, refresh
│   └── push_service.dart              # Firebase Cloud Messaging
├── screens/
│   ├── splash_screen.dart             # Загрузка, автовход
│   ├── login_screen.dart              # Авторизация
│   ├── home_screen.dart               # Главный экран (BottomNav)
│   ├── dashboard_tab.dart             # Дашборд (баланс, тариф)
│   ├── finance_tab.dart               # Финансы (история, обещанный платёж)
│   ├── payment_screen.dart            # Экран оплаты (ЮKassa)
│   ├── services_tab.dart              # Тарифы и услуги
│   ├── support_tab.dart               # Обращения в поддержку
│   ├── ticket_detail_screen.dart      # Чат по тикету
│   └── profile_tab.dart               # Профиль, настройки
└── widgets/
    └── balance_card.dart              # Виджет карточки баланса

docs/
├── README.md                          # Этот файл
├── ios-release-report.md              # Отчёт о публикации iOS
├── privacy.html                       # Политика конфиденциальности
├── support.html                       # Страница поддержки
└── copyright.html                     # Авторские права

ios/
├── Runner/
│   ├── Info.plist                     # Метаданные приложения
│   ├── GoogleService-Info.plist       # Firebase конфигурация
│   └── Assets.xcassets/               # Иконки приложения
├── ExportOptions.plist                # Настройки экспорта IPA
└── Podfile                            # CocoaPods зависимости

.github/
└── workflows/
    └── ios-release.yml                # CI/CD pipeline

.claude/
└── commands/
    └── ios-app.md                     # Навык Claude Code для публикации
```

---

## 4. Экраны приложения

### 4.1. SplashScreen (Загрузка)
- Инициализация приложения
- Проверка сохранённых токенов
- Автовход или переход к логину
- Биометрическая аутентификация (если включена)

### 4.2. LoginScreen (Авторизация)
- Поля: номер договора + пароль
- Кнопки OAuth: ВКонтакте, Telegram
- VK OAuth URL: `https://demo.billing.smit34.ru/lk/oauth/vk/`
- Telegram: `https://t.me/SMITSupport_bot?start=login`

### 4.3. HomeScreen (Главный)
- BottomNavigationBar с 4 вкладками:
  1. **Главная** → DashboardTab
  2. **Финансы** → FinanceTab
  3. **Поддержка** → SupportTab
  4. **Профиль** → ProfileTab

### 4.4. DashboardTab (Дашборд)
- Приветствие с именем пользователя
- Карточка баланса с информацией о последнем платеже
- Спарклайн-график баланса (до 30 операций, `fl_chart`)
- Информация о тарифе (скорость, стоимость)
- Статус аккаунта (договор, адрес, блокировка)
- Баннер уведомлений от оператора
- Предупреждение о блокировке

### 4.5. FinanceTab (Финансы)
- Баннер обещанного платежа (активация/отмена)
- Фильтр периода: Месяц, 3 месяца, Год, Всё время
- Сводные чипы: Приход, Расход, Всего операций
- Список операций с датами и суммами
- Pull-to-refresh
- Кнопка перехода к оплате

### 4.6. PaymentScreen (Оплата)
- Текущий баланс
- Поле ввода суммы
- Быстрые кнопки: 100, 300, 500, 1000 руб.
- Оплата через ЮKassa (открытие внешнего URL)
- Автообновление баланса через 2 сек после возврата

### 4.7. ServicesTab (Тарифы)
- Текущий тариф (выделен)
- Список доступных тарифов
- Смена тарифа с диалогом подтверждения
- Детали: название, стоимость, скорость, описание

### 4.8. SupportTab (Поддержка)
- Вкладки: Активные / Закрытые обращения
- Список тикетов со статусом, датой, превью
- FAB для создания нового обращения
- Форма создания в BottomSheet
- Цвета статусов: зелёный (активный), оранжевый (ожидание), серый (закрыт)

### 4.9. TicketDetailScreen (Чат по тикету)
- ID тикета и статус
- Лента сообщений (клиент / оператор)
- Пузыри сообщений с временными метками
- Поле ответа (для активных/ожидающих тикетов)

### 4.10. ProfileTab (Профиль)
- Аватар с инициалами
- Имя и номер договора
- Информация об аккаунте: адрес, тариф, баланс
- Контакты: email, SMS
- Безопасность:
  - Смена пароля
  - Вкл/выкл биометрии
  - Добровольная блокировка
- Социальные входы: ВК, Telegram (привязка/отвязка)
- Выход из аккаунта
- Версия приложения

---

## 5. API и сервисы

### Базовый URL

```
https://demo.billing.smit34.ru/mobile-api/v1
```

### Эндпоинты

| Метод | URL | Описание |
|-------|-----|----------|
| POST | `/auth/login` | Авторизация (логин + пароль) |
| POST | `/auth/refresh` | Обновление JWT токена |
| GET | `/account/status` | Статус абонента и баланс |
| GET | `/account/tariffs` | Список доступных тарифов |
| POST | `/account/tariff` | Смена тарифа |
| POST | `/account/change_password` | Смена пароля |
| GET | `/account/voluntary_block` | Статус добровольной блокировки |
| POST | `/account/voluntary_block` | Вкл/выкл блокировки |
| GET | `/finance/history` | История операций (пагинация) |
| GET | `/finance/promise_pay` | Статус обещанного платежа |
| POST | `/finance/promise_pay` | Активация обещанного платежа |
| DELETE | `/finance/promise_pay` | Отмена обещанного платежа |
| POST | `/finance/pay` | Создание платежа → URL ЮKassa |
| GET | `/support/tickets` | Список тикетов поддержки |
| GET | `/support/tickets/{id}` | Детали тикета (переписка) |
| POST | `/support/tickets` | Создание тикета |
| POST | `/support/tickets/{id}` | Ответ в тикете |
| POST | `/push/register` | Регистрация FCM токена |

### HTTP-клиент (ApiClient)

- Обёртка над `http` package
- Автоматический refresh токена при 401
- JWT access + refresh токены
- Secure Storage для хранения токенов
- Автовход по сохранённым токенам

---

## 6. Модели данных

### AccountStatus

| Поле | Тип | Описание |
|------|-----|----------|
| `abonentId` | int | ID абонента |
| `name` | String | ФИО |
| `contractNumber` | String | Номер договора |
| `balance` | double | Баланс (руб.) |
| `tariffName` | String | Название тарифа |
| `tariffId` | int | ID тарифа |
| `speedMbit` | int | Скорость (Мбит/с) |
| `monthlyCost` | double | Стоимость/месяц |
| `isBlocked` | bool | Заблокирован ли |
| `blockReason` | String? | Причина блокировки |
| `hasPromisePay` | bool | Обещанный платёж активен |
| `promisePayEnd` | DateTime? | Окончание обещанного платежа |
| `address` | String? | Адрес подключения |
| `email` | String? | Email |
| `sms` | String? | Телефон для SMS |
| `notification` | String? | Уведомление от оператора |
| `lastPayment` | Map? | Последний платёж |

### Tariff

| Поле | Тип | Описание |
|------|-----|----------|
| `id` | int | ID тарифа |
| `name` | String | Название |
| `monthlyCost` | double | Стоимость/месяц |
| `speedMbit` | int? | Скорость (Мбит/с) |
| `description` | String? | Описание |
| `isCurrent` | bool | Текущий тариф |
| `canSwitch` | bool | Можно переключиться |

### FinanceOperation

| Поле | Тип | Описание |
|------|-----|----------|
| `id` | int | ID операции |
| `date` | DateTime | Дата/время |
| `amount` | double | Сумма (+/-) |
| `description` | String | Описание |
| `typeName` | String | Тип операции |
| `isIncome` | bool | Приход (amount > 0) |

---

## 7. Аутентификация

### Способы входа

1. **Логин + пароль** — номер договора и пароль от ЛК
2. **Биометрия** — Face ID / Touch ID (вкл. в профиле)
3. **OAuth** — ВКонтакте, Telegram (внешний переход)

### Механизм JWT

```
Login → access_token + refresh_token
          │
          ▼
  Сохранение в SecureStorage
          │
          ▼
  Каждый API-запрос: Authorization: Bearer <access_token>
          │
          ▼
  При 401 → POST /auth/refresh → новые токены
          │
          ▼
  При ошибке refresh → разлогин
```

### Биометрия

- Проверка доступности через `local_auth`
- При включении сохраняются логин/пароль в SecureStorage
- При входе — биометрия → достать пароль → обычный логин

---

## 8. Платёжная система

### ЮKassa (YooKassa)

```
Пользователь вводит сумму
        │
        ▼
POST /finance/pay { amount, system: 'yookassa' }
        │
        ▼
Сервер возвращает redirect_url
        │
        ▼
url_launcher открывает браузер
        │
        ▼
Оплата на стороне ЮKassa
        │
        ▼
Возврат в приложение
        │
        ▼
Автообновление баланса (через 2 сек)
```

- Минимальная сумма: 1 руб.
- Быстрые кнопки: 100, 300, 500, 1000 руб.
- Данные карты НЕ проходят через приложение

---

## 9. Push-уведомления

### Firebase Cloud Messaging

- **Firebase Project:** `smitbilling`
- **GCM Sender ID:** `254603607098`
- **iOS Config:** `GoogleService-Info.plist`
- **Android Config:** `google-services.json`

### Поток

```
App Launch → requestPermission (iOS)
    │
    ▼
getToken → POST /push/register { token }
    │
    ▼
onTokenRefresh → POST /push/register { new_token }
    │
    ▼
Incoming Push → система отображает уведомление
```

### Зависимости Firebase

```yaml
firebase_core: ^2.32.0       # Firebase SDK 10.x
firebase_messaging: ^14.9.4  # FCM
```

> **Примечание:** Используются Firebase SDK 10.x из-за несовместимости SDK 11.x (Swift 6) со старыми версиями Xcode. При сборке через GitHub Actions с Xcode 16+ можно обновить до актуальных версий.

---

## 10. UI и дизайн

### Цветовая схема

- **Основной цвет:** `#5BA89D` (бирюзовый/морской зелёный)
- **Тема:** Material 3 (Material Design 3)
- **Режим:** Системный (светлый/тёмный автоматически)

### Компоненты

- Material 3 карточки с тенями
- Градиентный фон карточки баланса
- Цветовая индикация статусов:
  - Красный: отрицательный баланс, блокировка
  - Оранжевый: низкий баланс, ожидание
  - Зелёный: положительный баланс, приход
  - Синий: основные действия
- Pull-to-refresh на главных экранах
- SnackBar для уведомлений
- BottomSheet для форм
- Анимации переходов

### Шрифты

- Google Fonts (через пакет `google_fonts`)
- Material Icons

---

## 11. CI/CD и публикация

### Архитектура пайплайна

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

### GitHub Actions Workflow

**Файл:** `.github/workflows/ios-release.yml`

**Триггеры:**
- Push в `main`
- Ручной запуск (workflow_dispatch)

**Runner:** `macos-14` (Xcode 16.2, timeout 45 мин)

**Шаги:**
1. Checkout кода
2. Выбор Xcode 16.2
3. Установка Flutter 3.24.5
4. `flutter pub get`
5. Удаление альфа-канала из иконок
6. Установка сертификата Apple Distribution (.p12)
7. Установка provisioning profile
8. Настройка API Key App Store Connect (.p8)
9. Настройка ручной подписи в проекте
10. `xcodebuild archive`
11. `xcodebuild -exportArchive` (автозагрузка в ASC)

### GitHub Secrets

| Secret | Описание |
|--------|----------|
| `P12_BASE64` | Сертификат Apple Distribution (.p12) в base64 |
| `P12_PASSWORD` | Пароль сертификата |
| `KEYCHAIN_PASSWORD` | Пароль keychain (любой) |
| `APP_STORE_API_KEY_ID` | ID ключа API (`D23K22BL7G`) |
| `APP_STORE_API_ISSUER_ID` | Issuer ID |
| `APP_STORE_API_KEY_P8` | Содержимое .p8 файла |
| `PROVISION_PROFILE_BASE64` | Provisioning profile в base64 |

### Конфигурация подписи

| Параметр | Значение |
|----------|----------|
| Team ID | `6LX2W6558K` |
| Bundle ID | `ru.smit34.smitBilling` |
| Signing | Manual (Apple Distribution) |
| Profile | SmIT Billing AppStore (IOS_APP_STORE) |

### Навык Claude Code

Для быстрой публикации доступен навык `/ios-app`:
1. Увеличивает build number
2. Коммитит и пушит
3. Отслеживает сборку в GitHub Actions
4. Сообщает результат

---

## 12. Документы для App Store

Для публикации в App Store подготовлены HTML-документы:

| Документ | Файл | URL |
|----------|------|-----|
| Политика конфиденциальности | `docs/privacy.html` | billing.smit34.ru/privacy |
| Страница поддержки | `docs/support.html` | billing.smit34.ru/support |
| Авторские права | `docs/copyright.html` | billing.smit34.ru/copyright |

### Политика конфиденциальности
- Какие данные собираются (авторизация, контакты, операции, FCM token)
- Цели обработки (авторизация, отображение информации, платежи, уведомления)
- Третьи лица: ЮKassa (платежи), Google Firebase (push), законодательство РФ
- Хранение: iOS Keychain (локально), данные с сервера не кешируются
- Защита: HTTPS, JWT, биометрия
- Без cookie, без аналитики, без рекламных трекеров

### Страница поддержки
- Контакты: email support@smit34.ru, телефон
- Обращение через приложение (Поддержка → + Новое обращение)
- FAQ: вход, оплата, обещанный платёж, Face ID, блокировка, push, удаление аккаунта

---

## 13. Настройка окружения

### Требования для разработки

- **Flutter:** 3.24.5 (Dart 3.5.4)
- **macOS:** 12+ для разработки, 14+ для Xcode 16 (локальная сборка iOS)
- **Xcode:** 14.2 для разработки, 16+ для публикации
- **CocoaPods:** установлен через Ruby gems
- **Android Studio:** для Android-разработки

### Установка

```bash
# Клонирование
git clone https://github.com/ircitdev/smit-billing-mobile.git
cd smit-billing-mobile

# Установка зависимостей
flutter pub get

# iOS
cd ios && pod install && cd ..

# Запуск
flutter run
```

### Локальная сборка (для тестирования)

```bash
# iOS (симулятор)
flutter run -d ios

# Android
flutter run -d android

# Release IPA (требует Xcode 16+, macOS 14+)
flutter build ipa --release
```

> **Важно:** Для публикации в App Store требуется iOS 18 SDK (Xcode 16+, macOS 14+). На старых Mac используйте облачную сборку через GitHub Actions.

---

## 14. Отчёт о публикации iOS

Подробный отчёт о процессе сборки и публикации iOS-приложения доступен в файле [`ios-release-report.md`](ios-release-report.md).

### Краткие итоги

- **4 сборки** успешно загружены в TestFlight
- CI/CD полностью автоматизирован
- Основные преодолённые проблемы:
  - macOS 12 + Xcode 14.2 → облачная сборка через GitHub Actions
  - Firebase SDK 11.x (Swift 6) → понижение до SDK 10.x
  - Xcode code signing → App Store Connect API Key
  - Альфа-канал в иконках → конвертация через `sips`

### Рекомендации

1. Обновить Firebase до актуальных версий (3.x/15.x) — в CI с Xcode 16 будет работать
2. Загрузить скриншоты в App Store Connect
3. Заполнить экспортные документы (шифрование) в TestFlight
4. Рассмотреть обновление macOS на Mac или приобретение Mac с Apple Silicon

---

## Зависимости

### Основные пакеты

| Пакет | Версия | Назначение |
|-------|--------|------------|
| `provider` | ^6.1.2 | State management |
| `http` | ^1.2.1 | HTTP-клиент |
| `flutter_secure_storage` | ^9.2.2 | Безопасное хранение |
| `jwt_decoder` | ^2.0.1 | Декодирование JWT |
| `local_auth` | ^2.3.0 | Биометрия |
| `firebase_core` | ^2.32.0 | Firebase SDK |
| `firebase_messaging` | ^14.9.4 | Push-уведомления |
| `url_launcher` | ^6.3.1 | Открытие URL (платежи, OAuth) |
| `intl` | ^0.19.0 | Форматирование дат/чисел |
| `shared_preferences` | ^2.3.3 | Локальные настройки |
| `google_fonts` | ^6.2.1 | Шрифты |
| `fl_chart` | ^0.69.2 | Графики |
| `cupertino_icons` | ^1.0.8 | iOS иконки |

---

*Документация актуальна на 19 марта 2026 г.*
*ООО «СмИТ», г. Волгоград — smit34.ru*
