<h1 align="center">claude-statusline</h1>

<p align="center">
  Информативная строка состояния для Claude Code — модель, контекст, лимиты, git, время сессии.<br>
  Кроссплатформенная. Одна команда для установки.
</p>

<p align="center">
  <a href="https://github.com/AndyShaman/claude-statusline/blob/main/LICENSE"><img src="https://img.shields.io/github/license/AndyShaman/claude-statusline?style=flat-square&color=green" alt="License"></a>
  <img src="https://img.shields.io/badge/bash-script-4EAA25?style=flat-square&logo=gnubash&logoColor=white" alt="Bash">
  <img src="https://img.shields.io/badge/platform-macOS%20%7C%20Linux%20%7C%20Windows-blue?style=flat-square" alt="Platform">
  <a href="https://github.com/AndyShaman/claude-statusline/stargazers"><img src="https://img.shields.io/github/stars/AndyShaman/claude-statusline?style=flat-square&color=yellow" alt="Stars"></a>
</p>

<p align="center">
  <a href="https://t.me/AI_Handler"><img src="https://img.shields.io/badge/Telegram-канал автора-2CA5E0?style=for-the-badge&logo=telegram&logoColor=white" alt="Telegram"></a>
  &nbsp;
  <a href="https://www.youtube.com/channel/UCLkP6wuW_P2hnagdaZMBtCw"><img src="https://img.shields.io/badge/YouTube-канал автора-FF0000?style=for-the-badge&logo=youtube&logoColor=white" alt="YouTube"></a>
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
| MCP-серверы | `3 MCPs` | Количество MCP-серверов из settings и plugin cache (скрыто при 0) |
| Время сессии | `⏱ 12m` | Продолжительность текущей сессии (определяется по timestamps в JSONL-транскрипте) |

Цветовая кодировка лимитов: 🟢 > 50% — 🟡 20–50% — 🔴 < 20%.

## Установка

### Быстрая (из GitHub)

```bash
curl -fsSL https://raw.githubusercontent.com/AndyShaman/claude-statusline/main/install.sh | bash
```

### Ручная

```bash
# 1. Скачайте скрипт
curl -fsSL https://raw.githubusercontent.com/AndyShaman/claude-statusline/main/statusline.sh -o ~/.claude/statusline.sh
chmod +x ~/.claude/statusline.sh

# 2. Добавьте в ~/.claude/settings.json (или создайте файл):
```

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash ~/.claude/statusline.sh"
  }
}
```

```bash
# 3. Перезапустите Claude Code
```

### Из архива

```bash
unzip claude-statusline.zip
cd claude-statusline
bash install.sh
```

## Зависимости

| Пакет | Назначение | macOS | Linux | Windows |
|-------|-----------|-------|-------|---------|
| `jq` | Парсинг JSON | `brew install jq` | `sudo apt install jq` | встроен в Git Bash |
| `python3` | Расчёт времени | предустановлен | предустановлен | `winget install python` |
| `curl` | Запрос к API | предустановлен | предустановлен | встроен в Git Bash |

## Как работает

Claude Code запускает скрипт после каждого сообщения ассистента, передавая на stdin JSON с данными сессии (модель, контекст, пути). Скрипт парсит JSON, получает лимиты из API и выводит форматированную строку с ANSI-цветами.

---

## Лимиты использования — `H:` и `W:`

Сегменты `H:78% 1h34m` и `W:87%` показывают остаток вашей квоты Claude Code (Pro/Max подписки).

| Лимит | Расшифровка |
|-------|-------------|
| **H** (hourly) | Квота за скользящее 5-часовое окно. Сбрасывается постепенно. |
| **W** (weekly) | Квота за скользящее 7-дневное окно. Сбрасывается постепенно. |

Процент — это **остаток** (100% = полная ёмкость, 0% = лимит достигнут). Время после `H:` — когда окно полностью обновится.

### Как скрипт получает данные

```
┌─────────────────────┐     ┌──────────────────────┐     ┌─────────────────────┐
│ 1. OAUTH-ТОКЕН      │────▶│ 2. ЗАПРОС К API      │────▶│ 3. ПАРСИНГ          │
│                     │     │                      │     │                     │
│ Чтение из защищён-  │     │ GET /api/oauth/usage │     │ remaining = 100 -   │
│ ного хранилища ОС   │     │ Bearer <token>       │     │   utilization       │
│ (Keychain / Keyring │     │ Кэш на 2 минуты      │     │ Цвет по уровню      │
│  / Credential Mgr)  │     │                      │     │ Время до сброса     │
└─────────────────────┘     └──────────────────────┘     └─────────────────────┘
```

**Шаг 1** — Когда вы входите через `claude login`, Claude Code сохраняет OAuth-токен в защищённое хранилище ОС. Скрипт читает его обратно:

```json
{
  "claudeAiOauth": {
    "accessToken": "coa-abc123...",
    "refreshToken": "...",
    "expiresAt": "..."
  }
}
```

**Шаг 2** — Запрос к API Anthropic:

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

- `utilization` — процент **использованной** квоты (0–100)
- `resets_at` — ISO 8601 время полного сброса окна

**Шаг 3** — Расчёт: `remaining = 100 - utilization`, вычисление оставшегося времени, выбор цвета.

**Кэширование** — API вызывается не чаще раза в 2 минуты. Кэш: `~/.claude/.usage-cache.json` (права 600).

---

## Настройка по платформам

Скрипт автоматически определяет ОС и использует нужный способ чтения токена. Ниже — детали для каждой платформы.

### macOS

**Работает из коробки.** Токен хранится в **Keychain Access** (связка ключей).

```bash
# Команда, которую использует скрипт:
security find-generic-password -s "Claude Code-credentials" -w
```

Проверить вручную:

```bash
security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print('OK — token expires:', d['claudeAiOauth'].get('expiresAt', '?'))"
```

### Linux

Скрипт сначала проверяет файл `~/.claude/.credentials.json`. Если файла нет — читает токен через **libsecret** (GNOME Keyring / KWallet) с помощью `secret-tool`.

**Установка `secret-tool`:**

```bash
# Ubuntu / Debian
sudo apt install libsecret-tools

# Fedora
sudo dnf install libsecret

# Arch
sudo pacman -S libsecret
```

```bash
# Команда, которую использует скрипт:
secret-tool lookup service "Claude Code-credentials"
```

Проверить вручную:

```bash
secret-tool lookup service "Claude Code-credentials" 2>/dev/null \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print('OK — token expires:', d['claudeAiOauth'].get('expiresAt', '?'))"
```

**Headless Linux / SSH (без keyring):**

Если keyring недоступен, Claude Code может использовать файловое хранилище. Проверьте:

```bash
cat ~/.claude/.credentials 2>/dev/null \
  | python3 -c "import sys,json; json.load(sys.stdin); print('OK — file-based credentials found')"
```

Если токен в файле — замените Linux-ветку в `fetch_usage()`:

```bash
cred_json=$(cat "$HOME/.claude/.credentials" 2>/dev/null)
```

### Windows — Git Bash / MSYS2

Скрипт сначала проверяет файл `~/.claude/.credentials.json`. Если файла нет — читает токен из **Windows Credential Manager** через PowerShell.

**PowerShell-модуль (если файл credentials отсутствует):**

```powershell
# Запустите PowerShell от администратора:
Install-Module -Name CredentialManager -Force
```

```bash
# Команда, которую использует скрипт (из Git Bash):
powershell.exe -NoProfile -Command \
  '[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String((Get-StoredCredential -Target "Claude Code-credentials" -AsCredentialObject).Password))'
```

Проверить вручную (из Git Bash):

```bash
powershell.exe -NoProfile -Command \
  '[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String((Get-StoredCredential -Target "Claude Code-credentials" -AsCredentialObject).Password))' 2>/dev/null \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print('OK — token found')"
```

**Без модуля `CredentialManager`** — проверьте файловый fallback:

```bash
cat "$APPDATA/claude/.credentials" 2>/dev/null \
  || cat "$LOCALAPPDATA/claude/.credentials" 2>/dev/null
```

### Windows — WSL

В WSL Claude Code ведёт себя как Linux — используйте **инструкции для Linux** выше.

Если Claude Code установлен на стороне Windows, а statusline запускается из WSL:

```bash
# Достать токен из Windows Credential Manager через WSL:
cred_json=$(/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe -NoProfile -Command \
  '[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String((Get-StoredCredential -Target "Claude Code-credentials" -AsCredentialObject).Password))' 2>/dev/null)
```

### Устранение проблем

| Симптом | Решение |
|---------|---------|
| `H:` и `W:` не отображаются | Токен не найден — проверьте инструкции для вашей платформы |
| Показывает `H:?% W:?%` | API вернул ошибку — токен мог истечь, выполните `claude login` |
| Числа не обновляются | Кэш (2 мин) — подождите или удалите `~/.claude/.usage-cache.json` |
| Время сессии неверно (Windows) | Убедитесь в актуальной версии скрипта — она конвертирует backslash в путях автоматически |
| Скрипт не запускается | Проверьте `jq`: `echo '{}' \| jq .` — если ошибка, установите jq |

Принудительное обновление:

```bash
rm ~/.claude/.usage-cache.json
# Следующее сообщение в Claude Code вызовет свежий запрос к API
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
# Линии (по умолчанию)
bar+="━"

# Блоки
bar+="█" / bar+="░"

# Точки
bar+="●" / bar+="○"
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

## Удаление

```bash
rm ~/.claude/statusline.sh ~/.claude/.usage-cache.json
# Удалите ключ "statusLine" из ~/.claude/settings.json
```

Или внутри Claude Code: `/statusline remove it`

## Лицензия

[MIT](LICENSE)

**[@AndyShaman](https://github.com/AndyShaman)** · [claude-statusline](https://github.com/AndyShaman/claude-statusline)

---

<h1 align="center">claude-statusline</h1>

<p align="center">
  A rich statusline for Claude Code — model, context, usage limits, git, session time.<br>
  Cross-platform. One command to install.
</p>

<p align="center">
  <a href="https://t.me/AI_Handler"><img src="https://img.shields.io/badge/Telegram-Author's_Channel-2CA5E0?style=for-the-badge&logo=telegram&logoColor=white" alt="Telegram"></a>
  &nbsp;
  <a href="https://www.youtube.com/channel/UCLkP6wuW_P2hnagdaZMBtCw"><img src="https://img.shields.io/badge/YouTube-Author's_Channel-FF0000?style=for-the-badge&logo=youtube&logoColor=white" alt="YouTube"></a>
</p>

---

## What it shows

| Segment | Example | Description |
|---------|---------|-------------|
| Model | `[Opus 4.6]` | Current model name |
| Context bar | `━━━━━━ 25% (50K/200K)` | Visual progress bar with token count. Green → yellow → red |
| Hourly limit | `H:78% 1h34m` | Remaining 5-hour usage quota + time until reset |
| Weekly limit | `W:87%` | Remaining 7-day usage quota |
| Project | `my-app` | Current directory name |
| Git branch | `git:(main)` | Active branch (hidden outside git repos) |
| MCP servers | `3 MCPs` | MCP server count from settings and plugin cache (hidden if 0) |
| Session time | `⏱ 12m` | Session duration (detected from transcript JSONL timestamps) |

Color coding: 🟢 > 50% — 🟡 20–50% — 🔴 < 20%.

## Installation

### Quick (from GitHub)

```bash
curl -fsSL https://raw.githubusercontent.com/AndyShaman/claude-statusline/main/install.sh | bash
```

### Manual

```bash
curl -fsSL https://raw.githubusercontent.com/AndyShaman/claude-statusline/main/statusline.sh -o ~/.claude/statusline.sh
chmod +x ~/.claude/statusline.sh
```

Add to `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash ~/.claude/statusline.sh"
  }
}
```

Restart Claude Code.

## Requirements

| Package | Purpose | macOS | Linux | Windows |
|---------|---------|-------|-------|---------|
| `jq` | JSON parsing | `brew install jq` | `sudo apt install jq` | included in Git Bash |
| `python3` | Time calculations | preinstalled | preinstalled | `winget install python` |
| `curl` | API requests | preinstalled | preinstalled | included in Git Bash |

## How usage limits work (`H:` and `W:`)

The `H:78% 1h34m` and `W:87%` segments show remaining Claude Code rate limit quota (Pro/Max subscriptions).

| Limit | Meaning |
|-------|---------|
| **H** (hourly) | Rolling 5-hour window quota |
| **W** (weekly) | Rolling 7-day window quota |

Percentage shows **remaining** capacity (100% = full, 0% = limit reached). Time after `H:` shows when the 5-hour window fully resets.

### How it works under the hood

1. **Read OAuth token** from OS credential storage (Keychain / libsecret / Credential Manager)
2. **Call** `GET https://api.anthropic.com/api/oauth/usage` with `Bearer <token>`
3. **Calculate** `remaining = 100 - utilization`, format time until reset
4. **Cache** results for 2 minutes at `~/.claude/.usage-cache.json`

### Platform-specific token access

| Platform | Storage | Command |
|----------|---------|---------|
| **macOS** | Keychain Access | `security find-generic-password -s "Claude Code-credentials" -w` |
| **Linux** | `~/.claude/.credentials.json` → libsecret fallback | `cat ~/.claude/.credentials.json` |
| **Windows** (Git Bash) | `~/.claude/.credentials.json` → Credential Manager fallback | `cat ~/.claude/.credentials.json` |
| **WSL** | `~/.claude/.credentials.json` | `cat ~/.claude/.credentials.json` |

> **Linux / Windows / WSL**: the script checks `~/.claude/.credentials.json` first. If absent, falls back to libsecret on Linux (`sudo apt install libsecret-tools`) or Credential Manager on Windows (`Install-Module -Name CredentialManager -Force`).

Verify your token is accessible:

```bash
# macOS
security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print('OK')"

# Linux
secret-tool lookup service "Claude Code-credentials" 2>/dev/null \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print('OK')"

# Windows (Git Bash)
powershell.exe -NoProfile -Command \
  '[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String((Get-StoredCredential -Target "Claude Code-credentials" -AsCredentialObject).Password))' 2>/dev/null \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print('OK')"
```

If nothing prints, run `claude login` to re-authenticate.

### Troubleshooting

| Symptom | Fix |
|---------|-----|
| `H:` and `W:` missing | Token not found — verify with commands above |
| Shows `H:?% W:?%` | API error — token may be expired, run `claude login` |
| Numbers seem stuck | Cache is active (2 min) — wait or `rm ~/.claude/.usage-cache.json` |
| Script won't run | Check `jq`: `echo '{}' \| jq .` — install if missing |
| Session time wrong (Windows) | Update to the latest version — it converts backslashes via `sed` automatically |

## Customization

Edit `~/.claude/statusline.sh` directly, or use inside Claude Code:

```
/statusline add cost tracking
/statusline remove git branch
/statusline show only model and context
```

## Uninstall

```bash
rm ~/.claude/statusline.sh ~/.claude/.usage-cache.json
```

Remove the `statusLine` key from `~/.claude/settings.json`.

## License

[MIT](LICENSE)

**[@AndyShaman](https://github.com/AndyShaman)** · [claude-statusline](https://github.com/AndyShaman/claude-statusline)
