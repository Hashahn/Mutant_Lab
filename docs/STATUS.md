# Статус проекта
Обновлено: 2026-09-19.
Этап: M1 (игровой цикл) — автоматическая верификация и сборка пройдены.
Субагенты: модель gpt-5.6-sol по требованию владельца.

## Выполненные изменения:
- Подключен встроенный Roblox Studio MCP Server (`roblox-studio-mcp.bat`, `C:\Users\ASUTP\.gemini\config\mcp_config.json`).
- Настроены навыки: `.agents/skills/mutant-lab-development/`, `.agents/skills/roblox-studio-mcp/`, `skills/roblox-assistant-skill.md`.
- Исправлен тест `tests/domain.spec.luau` (установка `TutorialCompleted = true` для проверки `MUTANT_BUSY` в `Merge`).
- Выполнено форматирование StyLua всего исходного кода.

## Реально выполненные команды:
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check.ps1 -Format` (StyLua format + 7 Lune suites + Rojo build)
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check.ps1` (чистый прогон: 7/7 сьютов PASS, сборка `build/MutantLab.rbxlx` успешна)

## Пройденная ручная проверка в Studio (Milestone M1):
- Дата: 2026-09-19 | Режим: Memory | Клиентов: 1 | Ошибок в Output: 0.
- Полный 3-минутный игровой цикл успешно завершён:
  - Создание двух бесплатных Blob (баланс 100).
  - Слияние (Merge) двух Blob в Toxic Blob (баланс 100).
  - Успешный 6-секундный тренировочный бой (START TRAINING) $\rightarrow$ награда +35 BioCoins $\rightarrow$ баланс 135, завершение обучения.
  - Платная покупка Blob за 50 BioCoins $\rightarrow$ баланс 85.
  - Проверка отпускания мутантов (Release) с подтверждением и запретом удаления последнего мутанта.

## Оставшиеся проверки:
- Мультиплеер (2 клиента в Studio):
  - Изоляция баланса, инвентаря и сессий боя при одновременной игре.
- Проверка интерфейса на мобильном размере экрана (Device Simulator).

## Конкретный следующий шаг:
- Провести тест на 2 клиента в Roblox Studio (Test -> Local Server: 2 Players) для завершения приёмки изоляции M1/M2.

