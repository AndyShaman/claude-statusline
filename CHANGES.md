Форкнул Ваш проект [claude-statusline](https://github.com/AndyShaman/claude-statusline) и обнаружил несколько проблем, которые воспроизводятся не только у меня. Хочу сделать PR — заранее описываю, что там будет:

## Исправления (кросс-платформенные)

🕐 **Session time всегда "1m" на Linux/Windows** — скрипт использует `stat -c %Y` (mtime), но транскрипт постоянно перезаписывается → время всегда "сейчас". На macOS у Вас уже `stat -f %B` (birth time) — правильно. Исправление: `stat -c %W` с fallback на `%Y` для ФС без birth time.

📦 **MCP server count всегда 0** — Claude Code не передаёт поле `mcpServers` в JSON для statusline вовсе. Исправление: считать из `~/.claude/plugins/cache/*.mcp.json`.

⚙️ **Cache stat ломается на MSYS2** — `stat -f %m` на Git Bash не падает с ошибкой, а возвращает info о файловой системе → кэш лимитов не работает молча. Исправление: явная проверка `$OSTYPE`.

## Улучшение совместимости

🔑 **Credentials file fallback** — оригинал на Windows требует `Install-Module CredentialManager`, на Linux — `secret-tool`. Многие этого не делают. Claude Code хранит токен в `~/.claude/.credentials.json` — добавил приоритетный fallback на файл перед обращением к Keychain/Credential Manager/libsecret. Работает на Windows и Linux без доп. зависимостей.

🗂️ **Backslash в путях на Windows** — Claude Code передаёт пути с `\`, а `printf '%b'` интерпретирует `\c` как "стоп вывод" → путь обрезается. Исправление: `sed 's|\\|/|g'` при извлечении из JSON.
