Полный цикл подготовки и публикации iOS-приложения «СмИТ Биллинг» в App Store.

## Контекст проекта

- **Приложение:** СмИТ Биллинг (Flutter)
- **Bundle ID:** `ru.smit34.smitBilling`
- **Team ID:** `6LX2W6558K`
- **GitHub:** `ircitdev/smit-billing-mobile`
- **CI/CD:** GitHub Actions (macos-14, Xcode 16.2, Flutter 3.24.5)
- **Подпись:** Apple Distribution, профиль "SmIT Billing AppStore"
- **API Key ID:** `D23K22BL7G`
- **Документация:** `docs/privacy.html`, `docs/support.html`, `docs/copyright.html`

## Шаги

### 1. Проверь текущее состояние
- Прочитай `pubspec.yaml` — текущая версия и build number
- Проверь статус git: `git status`
- Проверь последние сборки: `gh run list --repo ircitdev/smit-billing-mobile --limit 5`

### 2. Подготовь релиз
Спроси пользователя, что нужно сделать:
- **Обновить версию** — измени `version` в `pubspec.yaml` (формат: `major.minor.patch+buildNumber`)
- **Обновить код** — внеси необходимые изменения в исходный код
- **Обновить документацию** — если нужно, обнови файлы в `docs/`

### 3. Увеличь build number
Увеличь число после `+` в поле `version` в `pubspec.yaml` на 1. Это обязательно для каждой загрузки в App Store Connect.

### 4. Закоммить и запушить
```bash
git add -A && git commit -m "описание изменений" && git push
```

### 5. Отследи сборку
```bash
sleep 5 && RUN_ID=$(gh run list --repo ircitdev/smit-billing-mobile --limit 1 --json databaseId -q '.[0].databaseId') && echo "Build started: $RUN_ID"
gh run watch $RUN_ID --repo ircitdev/smit-billing-mobile --exit-status
```

### 6. Обработай результат
- **Успех:** Сообщи что IPA загружена в App Store Connect / TestFlight
- **Ошибка:** Покажи лог ошибки:
```bash
gh run view $RUN_ID --repo ircitdev/smit-billing-mobile --log-failed | tail -30
```

### 7. Проверь статус в App Store Connect (опционально)
Напомни пользователю:
- Проверить сборку в TestFlight (обработка занимает 5-30 минут)
- Заполнить метаданные приложения (описание, скриншоты, категория)
- Отправить на ревью Apple если готово к публикации

## Важно
- Каждая загрузка в App Store Connect требует уникальный build number
- Секреты (сертификаты, API ключи) настроены в GitHub Secrets
- Сборка автоматически загружается через ExportOptions.plist (destination: upload)
- При ошибках подписи — проверь срок действия сертификата и provisioning profile
- Документы (privacy, support, copyright) доступны по URL: `https://billing.smit34.ru/privacy` и т.д.
