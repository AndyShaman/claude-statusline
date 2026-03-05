[![English](https://img.shields.io/badge/lang-English-blue.svg)](README.md) [![Русский](https://img.shields.io/badge/lang-Русский-red.svg)](README.ru.md)

<h1 align="center">claude-statusline</h1>

<p align="center">
  Информативная строка состояния для Claude Code - модель, контекст, лимиты, git, время сессии.<br>
  Кроссплатформенная. Одна команда для установки.
</p>

<p align="center">
  <a href="https://github.com/SfilD/claude-statusline/blob/main/LICENSE"><img src="https://img.shields.io/github/license/SfilD/claude-statusline?style=flat-square&color=green" alt="License"></a>
  <img src="https://img.shields.io/badge/bash-script-4EAA25?style=flat-square&logo=gnubash&logoColor=white" alt="Bash">
  <img src="https://img.shields.io/badge/platform-macOS%20%7C%20Linux%20%7C%20Windows-blue?style=flat-square" alt="Platform">
  <a href="https://github.com/SfilD/claude-statusline/stargazers"><img src="https://img.shields.io/github/stars/SfilD/claude-statusline?style=flat-square&color=yellow" alt="Stars"></a>
</p>

---

<p align="center">
  <img src="screenshot.jpg" alt="statusline screenshot">
</p>

## Что показывает

| Сегмент | Пример | Описание |
|---------|--------|----------|
| Модель | `[Opus 4.6]` | Текущая модель |
| Контекст | `━━━━━━ 25% (50K/200K)` | Прогресс-бар использования контекста с цветовой индикацией |
| 5-часовой лимит | `H:78% 1h34m` | Остаток квоты за скользящие 5 часов + время до сброса |
| Недельный лимит | `W:87%` | Остаток квоты за скользящие 7 дней |
| Проект | `my-app` | Имя текущей директории |
| Git-ветка | `git:(main)` | Активная ветка (скрыта вне git-репозиториев) |
| MCP-серверы | `3 MCPs` | Количество подключённых MCP-серверов, считывается из кэша плагинов (скрыто при 0) |
| Время сессии | `⏱ 12m` | Продолжительность текущей сессии, определяется по timestamps в JSONL-транскрипте (разрыв >30 мин = новая сессия) |

Цветовая кодировка лимитов: 🟢 > 50% - 🟡 20–50% - 🔴 < 20%.

## Установка

### Быстрая (из GitHub)

```bash
curl -fsSL https://raw.githubusercontent.com/SfilD/claude-statusline/main/install.sh | bash
```

### Ручная

```bash
curl -fsSL https://raw.githubusercontent.com/SfilD/claude-statusline/main/statusline.sh -o ~/.claude/statusline.sh
chmod +x ~/.claude/statusline.sh
```

Добавьте в `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash ~/.claude/statusline.sh"
  }
}
```

Перезапустите Claude Code.

## Зависимости

| Пакет | Назначение | macOS | Linux | Windows |
|-------|-----------|-------|-------|---------|
| `jq` | Парсинг JSON | `brew install jq` | `sudo apt install jq` | `winget install jq` |
| `python3` | Расчёт времени | предустановлен | предустановлен | `winget install python` |
| `curl` | Запрос к API | предустановлен | предустановлен | встроен в Git Bash |

## Как работает

Claude Code запускает скрипт после каждого сообщения ассистента, передавая на stdin JSON с данными сессии (модель, контекст, пути, MCP-серверы). Скрипт парсит JSON, получает лимиты из API и выводит форматированную строку с ANSI-цветами.

---

## Лимиты использования - `H:` и `W:`

Сегменты `H:78% 1h34m` и `W:87%` показывают остаток вашей квоты Claude Code (Pro/Max подписки).

| Лимит | Расшифровка |
|-------|-------------|
| **H** (hourly) | Квота за скользящее 5-часовое окно. Сбрасывается постепенно. |
| **W** (weekly) | Квота за скользящее 7-дневное окно. Сбрасывается постепенно. |

Процент - это **остаток** (100% = полная ёмкость, 0% = лимит достигнут). Время после `H:` - когда окно полностью обновится.

### Как скрипт получает данные

```
┌─────────────────────┐     ┌──────────────────────┐     ┌─────────────────────┐
│ 1. OAUTH-ТОКЕН      │────▶│ 2. ЗАПРОС К API      │────▶│ 3. ПАРСИНГ          │
│                     │     │                      │     │                     │
│ Чтение из файла     │     │ GET /api/oauth/usage │     │ remaining = 100 -   │
│ креденшалов или     │     │ Bearer <token>       │     │   utilization       │
│ защищённого         │     │ Кэш на 2 минуты      │     │ Цвет по уровню      │
│ хранилища ОС        │     │                      │     │ Время до сброса     │
└─────────────────────┘     └──────────────────────┘     └─────────────────────┘
```

**Шаг 1** - Когда вы входите через `claude login`, Claude Code сохраняет OAuth-токен. Скрипт читает его из `~/.claude/.credentials.json` (при наличии) или из защищённого хранилища ОС:

```json
{
  "claudeAiOauth": {
    "accessToken": "coa-abc123...",
    "refreshToken": "...",
    "expiresAt": "..."
  }
}
```

**Шаг 2** - Запрос к API Anthropic:

```bash
curl -sf "https://api.anthropic.com/api/oauth/usage" \
    -H "Authorization: Bearer $token" \
    -H "anthropic-beta: oauth-2025-04-20"
```

**Ответ API:**

```json
{
  "five_hour": {
    "utilization": 22.5,
    "resets_at": "2026-02-28T12:30:00Z"
  },
  "seven_day": {
    "utilization": 13.2,
    "resets_at": "2026-03-01T00:00:00Z"
  }
}
```

- `utilization` - процент **использованной** квоты (0–100)
- `resets_at` - ISO 8601 время полного сброса окна

**Шаг 3** - Расчёт: `remaining = 100 - utilization`, вычисление оставшегося времени, выбор цвета.

**Кэширование** - API вызывается не чаще раза в 2 минуты. Кэш: `~/.claude/.usage-cache.json` (права 600).

---

## Настройка по платформам

Скрипт автоматически определяет ОС. На всех платформах сначала проверяется файл `~/.claude/.credentials.json`, затем - защищённое хранилище ОС.

| Платформа | Хранилище | Команда проверки |
|-----------|-----------|-----------------|
| **macOS** | Keychain Access | `security find-generic-password -s "Claude Code-credentials" -w` |
| **Linux** | `~/.claude/.credentials.json` → libsecret | `cat ~/.claude/.credentials.json` |
| **Windows** (Git Bash) | `~/.claude/.credentials.json` → Credential Manager | `cat ~/.claude/.credentials.json` |
| **WSL** | `~/.claude/.credentials.json` | `cat ~/.claude/.credentials.json` |

### macOS

**Работает из коробки.** Токен хранится в **Keychain Access** (связка ключей).

```bash
security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print('OK - token expires:', d['claudeAiOauth'].get('expiresAt', '?'))"
```

### Linux

Скрипт сначала проверяет файл `~/.claude/.credentials.json` (используется Claude Code в WSL и headless-окружениях). Если файла нет - читает токен через **libsecret** (GNOME Keyring / KWallet).

```bash
# Проверить файловые креденшалы:
cat ~/.claude/.credentials.json 2>/dev/null \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print('OK - token expires:', d['claudeAiOauth'].get('expiresAt', '?'))"
```

Если файла нет - установите `secret-tool` для keyring:

```bash
sudo apt install libsecret-tools   # Ubuntu / Debian
sudo dnf install libsecret         # Fedora
sudo pacman -S libsecret           # Arch
```

### Windows - Git Bash / MSYS2

Скрипт сначала проверяет файл `~/.claude/.credentials.json`. Если файла нет - читает токен из **Windows Credential Manager** через PowerShell.

Для чтения через Credential Manager требуется PowerShell-модуль:

```powershell
# Запустите PowerShell от администратора:
Install-Module -Name CredentialManager -Force
```

### Windows - WSL

В WSL Claude Code хранит токен в файле `~/.claude/.credentials.json` (не в libsecret и не в Credential Manager). Скрипт читает его автоматически - **дополнительная настройка не требуется**.

```bash
# Проверить:
cat ~/.claude/.credentials.json 2>/dev/null \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print('OK - token expires:', d['claudeAiOauth'].get('expiresAt', '?'))"
```

### Устранение проблем

| Симптом | Решение |
|---------|---------|
| `H:` и `W:` не отображаются | Токен не найден - проверьте инструкции для вашей платформы |
| Показывает `H:?% W:?%` | API вернул ошибку - токен мог истечь, выполните `claude login` |
| Числа не обновляются | Кэш (2 мин) - подождите или удалите `~/.claude/.usage-cache.json` |
| Скрипт не запускается | Проверьте `jq`: `echo '{}'\| jq .` - если ошибка, установите jq |
| Время сессии неверно на Windows | Скрипт конвертирует backslash в пути транскрипта через `sed` - убедитесь в актуальной версии скрипта |

Принудительное обновление:

```bash
rm ~/.claude/.usage-cache.json
```

---

## Кастомизация

Редактируйте `~/.claude/statusline.sh` или используйте встроенную команду Claude Code:

```
/statusline add cost tracking
/statusline remove git branch
/statusline show only model and context
```

### Стиль прогресс-бара

```bash
bar+="━"   # Линии (по умолчанию)
bar+="█"   # Блоки (заполненный)
bar+="░"   # Блоки (пустой)
bar+="●"   # Точки (заполненный)
bar+="○"   # Точки (пустой)
```

### Ширина прогресс-бара

```bash
bar_len=10  # по умолчанию 6
```

### Убрать сегмент

Закомментируйте соответствующую строку `parts+=()` в конце скрипта.

### Отключить лимиты

Если вы используете API-ключ без OAuth:

```bash
# Закомментируйте строку ~120:
# usage_data=$(get_usage)
```

## Обновление

**macOS / Linux / WSL:**

```bash
curl -fsSL https://raw.githubusercontent.com/SfilD/claude-statusline/main/statusline.sh \
  -o ~/.claude/statusline.sh
```

**Windows (PowerShell 7):**

```powershell
curl.exe -fsSL https://raw.githubusercontent.com/SfilD/claude-statusline/main/statusline.sh `
  -o "$env:USERPROFILE\.claude\statusline.sh"

(Get-Content "$env:USERPROFILE\.claude\statusline.sh" -Raw) `
  -replace 'python3', 'python' |
  Set-Content "$env:USERPROFILE\.claude\statusline.sh" -NoNewline
```

Перезапуск не нужен - скрипт запускается при каждом сообщении ассистента.

## Удаление

```bash
rm ~/.claude/statusline.sh ~/.claude/.usage-cache.json
# Удалите ключ "statusLine" из ~/.claude/settings.json
```

Или внутри Claude Code: `/statusline remove it`

## Лицензия

[MIT](LICENSE) - основан на [AndyShaman/claude-statusline](https://github.com/AndyShaman/claude-statusline)
