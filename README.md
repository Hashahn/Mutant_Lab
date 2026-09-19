# Mutant Lab
Первая версия Roblox-игры: создать двух Blob → объединить в Toxic Blob → пройти Test Chamber → получить BioCoins → купить нового Blob.

**Начните с [статуса](docs/STATUS.md).** План: [ROADMAP](docs/ROADMAP.md). Продолжение другим агентом: [HANDOFF](docs/HANDOFF.md).

## Быстрый запуск (Windows x64)
Нужен Roblox Studio. Инструменты сборки устанавливаются только в папку проекта.
Из PowerShell в корне:
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/bootstrap.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check.ps1
```
Откройте **build/MutantLab.rbxlx** в Roblox Studio и нажмите Play. Для этого способа плагин Rojo не нужен.
В Studio по умолчанию используется память: после остановки сервера прогресс сбрасывается. Это ожидаемо.

Для синхронизации изменений установите официальный плагин [Rojo](https://rojo.space/docs/v7/getting-started/installation/), затем:
```powershell
.\.tools\rojo.exe serve default.project.json
```
Подключите плагин к localhost:34872 в отдельной тестовой place. Исходники редактируйте в src; прямые изменения скриптов в Studio не попадают автоматически в Git.
После изменения серверных скриптов остановите и снова запустите Play.

## Проверки
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check.ps1
# Для применения форматирования:
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check.ps1 -Format
```
Скрипт проверяет формат/синтаксический разбор StyLua, выполняет Luau-тесты Lune, собирает place через Rojo.
Это **не** проверка Roblox API, полного Luau typecheck или реального сетевого/GUI runtime. Чек-лист Studio: [MANUAL_TESTS](docs/MANUAL_TESTS.md).
Закреплённые версии и SHA256: tools.json. macOS/Linux: установите те же версии из официальных releases, выполните stylua --check src tests, lune run tests/run, rojo build -o build/MutantLab.rbxlx.
GitHub workflow повторяет Windows-проверки после отправки репозитория на GitHub.

## Multiplayer
В Studio выберите локальный сервер и 2 клиента (Server & Clients в разделе тестирования). Пройдите цикл каждым игроком. Проверьте отдельные деньги, инвентарь и награды.
Визуальная лаборатория пока личная и создаётся клиентом; совместное отображение мутантов не входит в v0.1.

## Сохранения
Конфигурация: src/server/Config/PersistenceConfig.luau. Перед тестами прочитайте комментарии в файле.
Используйте отдельную опубликованную **test experience**, не просто вторую place внутри production experience: DataStore общие внутри experience.
Studio по умолчанию не обращается к DataStore. Для реального теста включите режим сохранения, задайте ID тестовой experience и разрешите API access только там.
При ошибке загрузки игра не начинает новую сессию с пустым профилем. Незавершённые бои при выходе отменяются.
Для production понадобится отдельный namespace и приёмка сценариев из MANUAL_TESTS; просто зелёной сборки недостаточно.

## Структура
```text
src/
  client/             интерфейс, локальная лаборатория, визуализация боя
  server/
    Domain/           чистые правила и модель состояния, rate limiter
    Services/         сохранения, аналитика
    Config/           режим/параметры сохранений
    Main.server.luau  связывание сети и сервисов
  shared/
    Config/           баланс
    Types/            типы
tests/                автоматические Luau-тесты
scripts/              установка и проверка инструментов
skills/               переносимый навык продолжения
docs/                 план, контракты, приёмка, статус
default.project.json  Rojo mapping
tools.json            версии и контрольные суммы
```

## Git и передача проекта
Локальная история находится в .git. Удалённая копия пока не подключена.
Создайте пустой **private** репозиторий в своём GitHub/GitLab, затем:
```powershell
git remote add origin <URL-вашего-репозитория>
git push -u origin HEAD
```
Не добавляйте в Git .tools, build, ключи, токены и личные файлы. Следующему агенту достаточно клонировать репозиторий и прочитать AGENTS.md + docs/HANDOFF.md.
