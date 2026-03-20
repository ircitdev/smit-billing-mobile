# Инструкции: Выпуск iOS-приложения СмИТ Биллинг

## Два способа сборки

| Способ | Когда использовать |
|--------|-------------------|
| **GitHub Actions (основной)** | Автоматически при `git push main`. Работает с любого компьютера |
| **Локальная сборка** | На Mac с macOS 14+ и Xcode 16+. Три команды |

---

## Способ 1: GitHub Actions (автоматический)

Каждый push в `main` автоматически собирает IPA и загружает в TestFlight.

### 1. Обновить build number

В `pubspec.yaml` увеличить число после `+`:

```yaml
version: 1.2.0+8   # build number должен быть больше предыдущего (текущий: 7)
```

### 2. Закоммитить и запушить

```bash
git add -A
git commit -m "v1.2.0+8: описание изменений"
git push
```

### 3. Готово

Через ~20 минут сборка появится в TestFlight. Проверить статус:

```bash
gh run list --repo ircitdev/smit-billing-mobile --limit 3
```

Если сборка упала:

```bash
RUN_ID=<id из списка>
gh run view $RUN_ID --repo ircitdev/smit-billing-mobile --log-failed | tail -30
```

---

## Способ 2: Локальная сборка (macOS 14+)

### Требования

- macOS 14 (Sonoma) или новее
- Xcode 16.2+
- Flutter 3.24.5+
- CocoaPods (`sudo gem install cocoapods`)
- Apple Developer аккаунт (добавлен в Xcode → Settings → Accounts)

### Сборка

```bash
# 1. Зависимости
flutter pub get
cd ios && pod install && cd ..

# 2. Собрать IPA
flutter build ipa --release --export-options-plist=ios/ExportOptions.plist
```

IPA будет в `build/ios/ipa/`

### Загрузка в App Store Connect

**Через Xcode (проще всего):**

```bash
open ios/Runner.xcworkspace
```

Xcode → Product → Archive → Distribute App → App Store Connect → Upload

**Через CLI:**

```bash
xcrun altool --upload-app \
  --type ios \
  --file build/ios/ipa/*.ipa \
  --apiKey D23K22BL7G \
  --apiIssuer bc2f87f4-bf23-4c81-b115-c53f2da3e0d6
```

**Через Transporter:**

1. Открыть Transporter (из Mac App Store)
2. Перетащить IPA
3. Нажать «Доставить»

### Настройка подписи (первый раз)

```bash
open ios/Runner.xcworkspace
```

В Xcode:
1. Target **Runner** → вкладка **Signing & Capabilities**
2. Team: выбрать Apple Developer Team (`6LX2W6558K`)
3. Bundle Identifier: `ru.smit34.smitBilling`
4. Signing Certificate: **Apple Distribution**
5. Xcode автоматически создаст provisioning profile

---

## После загрузки: TestFlight и App Store

### TestFlight

1. Сборка появится через 5–15 минут после загрузки
2. App Store Connect → Мои приложения → СмИТ Биллинг → TestFlight
3. Внутренние тестеры (до 100 человек) — без ревью Apple
4. Внешние тестеры — нужен Beta App Review (1–2 дня)

### Публикация в App Store

1. App Store Connect → СмИТ Биллинг → App Store
2. Заполнить:

| Поле | Значение |
|------|----------|
| Описание (RU) | Мобильное приложение абонента интернет-провайдера СмИТ... |
| Категория | Utilities |
| Возрастной рейтинг | 4+ |
| Политика конфиденциальности | `https://billing.smit34.ru/privacy` |
| Поддержка | `https://billing.smit34.ru/support` |
| Скриншоты 6.7" | iPhone 15 Pro Max (1290×2796) — обязательно |
| Скриншоты 6.5" | iPhone 14 Plus (1284×2778) — обязательно |
| Скриншоты 5.5" | iPhone 8 Plus (1242×2208) — обязательно |

3. Выбрать сборку из TestFlight
4. Отправить на ревью (1–3 дня)

### Review Notes (для проверяющих Apple)

Указать в «App Review Information → Notes»:

```
This app is for existing subscribers of SMIT ISP (Internet Service Provider).
Users receive login credentials from the provider upon signing a service contract.
New accounts cannot be created within the app.

Demo account for review:
Login: 0828
Password: admin
Server: https://demo.billing.smit34.ru
```

---

## Конфигурация проекта

| Параметр | Значение |
|----------|----------|
| Bundle ID | `ru.smit34.smitBilling` |
| Display Name | СмИТ Биллинг |
| Team ID | `6LX2W6558K` |
| Min iOS | 13.0 |
| Flutter | 3.24.5 |
| Firebase | `GoogleService-Info.plist` в `ios/Runner/` |
| API URL | `https://demo.billing.smit34.ru/mobile-api/v1` |
| GitHub | `ircitdev/smit-billing-mobile` |
| CI/CD | GitHub Actions (`macos-14`, Xcode 16.2) |
| API Key ID | `D23K22BL7G` |
| Issuer ID | `bc2f87f4-bf23-4c81-b115-c53f2da3e0d6` |

---

## Чеклист перед отправкой на ревью

- [ ] Build number в `pubspec.yaml` увеличен
- [ ] `lib/` содержит актуальный код
- [ ] `GoogleService-Info.plist` на месте в `ios/Runner/`
- [ ] API URL указывает на нужный сервер
- [ ] Иконка приложения без альфа-канала
- [ ] Скриншоты загружены для 6.7", 6.5" и 5.5"
- [ ] Политика конфиденциальности опубликована по URL
- [ ] Страница поддержки опубликована по URL
- [ ] Тестовый аккаунт для ревью работает
- [ ] Информация о шифровании заполнена (Export Compliance)
- [ ] Контакт для ревью указан

---

## Частые проблемы

| Проблема | Решение |
|----------|---------|
| `pod install` ошибка | `pod repo update && pod install` |
| Альфа-канал в иконках | `sips -s format bmp icon.png --out /tmp/t.bmp && sips -s format png /tmp/t.bmp --out icon.png` |
| Нет ориентаций iPad | Добавить `UIInterfaceOrientationPortraitUpsideDown` в Info.plist |
| Firebase не компилируется | Проверить версии: `firebase_core: ^2.32.0`, `firebase_messaging: ^14.9.4` |
| Signing failed | Xcode → Runner → Signing & Capabilities → выбрать Team и Distribution сертификат |
| Build number уже использован | Увеличить число после `+` в `pubspec.yaml` |

---

## Быстрый путь

```bash
# Обновить build number в pubspec.yaml, затем:
git add -A && git commit -m "v1.2.0+8: release" && git push
# GitHub Actions сделает всё остальное → IPA в TestFlight через ~20 мин
```
