# Архитектура
Rojo переносит src/shared в ReplicatedStorage.MutantLab.Shared, src/server в ServerScriptService.MutantLab, src/client в StarterPlayerScripts.MutantLab.
## Границы
Domain/GameState и GameRules — чистая Luau-логика с конфигурацией и генератором ID через параметры. Тестируется без Roblox в Lune. Профиль содержит DataVersion, BioCoins, SlotsUnlocked, Mutants и Tutorial. Бой — временное состояние, не сохраняется.
Main.server связывает профили, правила, сеть, аналитику и завершение боя по времени сервера. Операции правил синхронны и не yield: проверки и изменения атомарны в рамках Luau-планировщика.
PlayerDataService отвечает за получение/сохранение/блокировку профиля. UpdateAsync, владение токеном сессии, ограниченный срок аренды. Ошибки загрузки закрывают доступ к игре; пустой профиль создаётся только при подтверждённом отсутствии записи. Studio по умолчанию без DataStore.
Клиент рисует интерфейс и локальную лабораторию из серверного снимка, отправляет только разрешённые намерения. Контракт: NETWORK.md.
AnalyticsService — изолированная серверная обёртка: сбой аналитики не меняет исход операции. Никаких внешних библиотек в игровом runtime.
## Решения
- Rojo + Git дают переносимость между агентами; rbxlx — артефакт сборки.
- Два типа оставляют progression коротким. ReleaseMutant предотвращает заполнение всех слотов высшим tier; без возврата валюты и после обучения.
- Первая битва доступна после первого merge; это сохраняет порядок onboarding.
- Локальные визуальные модели позволяют проверить личный цикл; общая лаборатория с чужими мутантами — отдельный будущий этап.
- Бой не расходует мутанта. При выходе бой отменяется; незавершённая награда не выдаётся.
- Межсерверная блокировка не заменяет Roblox-тестов отказов; до приёмки проект не считается готовым к публичной экономике.
## Источники
Проверены 2026-09-19:
- https://rojo.space/docs/v7/project-format/
- https://create.roblox.com/docs/cloud-services/data-stores
- https://create.roblox.com/docs/cloud-services/data-stores/player-data-purchasing
- https://create.roblox.com/docs/reference/engine/classes/AnalyticsService
