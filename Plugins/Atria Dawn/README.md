# Round & Player Statistics Manager (RPS)

Плагин AMX Mod X / ReAPI для Counter-Strike 1.6 + Zombie Plague 5.0.8a.
Собирает статистику игроков и раундов, определяет фазы раунда, хранит
результаты и предоставляет API другим плагинам.

## Состав

| Файл | Назначение |
| --- | --- |
| `rps_stats.sma` | исходный текст плагина |
| `rps_stats.inc` | публичный API: natives, forwards, константы |
| `rps_stats.cfg` | конфигурация (CVAR), опционально |
| `rps_stats.amxx` | собранный плагин |

## Установка

1. Скопировать `rps_stats.amxx` в `cstrike/addons/amxmodx/plugins/`.
2. Прописать плагин в `cstrike/addons/amxmodx/configs/plugins.ini`:
   `rps_stats.amxx`
3. (опционально) Скопировать `rps_stats.cfg` в `cstrike/addons/amxmodx/configs/`
   и поправить значения. Если файл лежит рядом с плагином в `plugins/`,
   он тоже будет прочитан.
4. Перезапустить сервер или сменить карту.

Зависимости: AMX Mod X 1.10, ReAPI, Zombie Plague 5.0.8a (`zp50_core`,
`zp50_gamemodes`). Подключение плагина требует загруженного ядра ZP — это
указано как обязательная зависимость (`#pragma reqlib`).

## Что считается

Статистика по игроку: убийства, смерти, хедшоты, заражения людей (игрок был
зомби), исцеления зомби (игрок был человеком), нанесённый и полученный урон.

Три уровня хранения:

- **Текущий раунд** (`RPS_SCOPE_ROUND`) — с момента старта раунда.
- **Сессия** (`RPS_SCOPE_SESSION`) — за всю карту, раунд засчитывается только
  если на сервере было не меньше `rps_min_players` игроков.
- **Сохранённое** (`rps_get_saved_stat`) — накопительное между картами, в
  хранилище `rps_stats` (nvault). Ключ — SteamID игрока; на LAN-серверах и для
  ботов к нему добавляется имя игрока, чтобы статистика не сливалась.

## Фазы раунда

Плагин ведёт конечный автомат:

```
INACTIVE -> FREEZE -> LIVE -> ENDED -> FREEZE (следующий раунд) -> ...
```

- `FREEZE` — раунд начался (событие HLTV, как в самом Zombie Plague), идёт
  заморозка. Если `mp_freezetime` равен нулю, раунд сразу переходит в `LIVE`.
- `LIVE` — после `RG_CSGameRules_OnRoundFreezeEnd`.
- `ENDED` — по хуку `RG_RoundEnd` (с известным победителем) или по лог-событию
  `Round_End` как запасному пути. Обработка идёт ровно один раз за раунд.
- `INACTIVE` — до первого раунда и после полного рестарта игры
  (`#Game_will_restart_in`), при этом номер раунда и статистика сессии
  сбрасываются.

## Команды (админ)

| Команда | Флаг | Описание |
| --- | --- | --- |
| `rps_stats` | `ADMIN_KICK` (флаг c) | меню игроков со статистикой |
| `rps_top` | `ADMIN_KICK` | топ-10 игроков карты по очкам |
| `rps_round` | `ADMIN_KICK` | сводка по текущему раунду и прошлому |
| `rps_reset` | `ADMIN_CVAR` (флаг g) | сброс статистики сессии |

## CVAR

| CVAR | Значение | Описание |
| --- | --- | --- |
| `rps_score_kill` | 100 | очки за убийство |
| `rps_score_infect` | 50 | очки за заражение |
| `rps_score_headshot` | 25 | очки за хедшот |
| `rps_score_damage_div` | 100 | очки за каждые N единиц урона |
| `rps_min_players` | 4 | минимум игроков для учёта раунда |
| `rps_save` | 1 | сохранять статистику между картами |
| `rps_announce_round_end` | 1 | итоги раунда в чат |
| `rps_log` | 1 | вести лог `rps_stats.log` |

Очки считаются по формуле:
`kills*rps_score_kill + headshots*rps_score_headshot + infect*rps_score_infect
+ damage/rps_score_damage_div`.

## API для других плагинов

Подключить `#include <rps_stats>`. Плагин требует загруженный `rps_stats`
(обязательная зависимость).

**Natives**

```pawn
rps_get_user_stat(id, RPS_STAT:stat, scope = RPS_SCOPE_SESSION)
rps_get_user_score(id, scope = RPS_SCOPE_SESSION)
rps_get_saved_stat(id, RPS_STAT:stat)
rps_reset_user_stats(id = 0)
rps_get_round_number()
RPS_ROUND_STATE:rps_get_round_state()
rps_get_round_gamemode()              // идентификатор режима ZP или RPS_NO_GAME_MODE
rps_get_round_gamemode_name(dest[], len)
WinStatus:rps_get_round_winner()
Float:rps_get_round_time()
```

**Forwards** (все `ET_IGNORE`, ничего отменить нельзя)

```pawn
rps_fw_round_start(round_number, game_mode_id)
rps_fw_round_end(round_number, winner_status, game_mode_id)
rps_fw_score_updated(id)
```

**Пример**

```pawn
#include <amxmodx>
#include <rps_stats>

public plugin_init()
{
    register_plugin("RPS example", "1.0", "x");
}

public rps_fw_round_end(round, winner, mode)
{
    log_amx("Раунд %d завершён, победитель %d, режим %d", round, winner, mode);
}

public client_putinserver(id)
{
    set_task(3.0, "ShowWelcome", id);
}

public ShowWelcome(id)
{
    if (!is_user_connected(id)) return;

    client_print(id, print_chat, "[RPS] Убийств сохранено: %d",
        rps_get_saved_stat(id, RPS_STAT_KILLS));
}
```

## Технические детали

- Урон и смерти учитываются через цепочки ReAPI (`RG_CBasePlayer_TakeDamage`,
  `RG_CBasePlayer_Killed`), хуки пост-фазовые. Подписки на хоты движка
  (`FM_PlayerPreThink` и подобные) не используются.
- Заражения и исцеления приходят через форварды Zombie Plague
  (`zp_fw_core_infect`, `zp_fw_core_cure`), игровая сторона плагином не
  отменяется.
- Индексы игроков нигде не хранятся между кадрами; состояние слота очищается
  в `client_putinserver` и `client_disconnected`, поэтому данные ушедшего
  игрока не достаются новому.
- Хранилище открывается лениво, только когда включён `rps_save`. Имя хранилища
  — литерал в коде, не из конфига.
- Меню создаются заново на каждый показ; в обработчиках пунктов проверяется
  `is_user_connected` на цель.
- Лог плагина пишется в `addons/amxmodx/logs/rps_stats.log` только при
  `rps_log 1`.

## Проверка

- Компилятор: AMX Mod X Compiler 1.10.0.5484.
- Сборка: `amxxpc.exe rps_stats.sma -i<path\include> -i<каталог плагина> -d1 -orps_stats.amxx`
  — 0 ошибок, 0 предупреждений, код возврата 0.
- Отпечаток собранного плагина: `rps_stats.amxx`, 9194 байт,
  sha256 `C3B00DD7BE4A576ABF50122E30C36BCF9DE79693C1E88AF3357C0841D43F4B56`.
- Дополнительно скомпилирован тестовый плагин-потребитель API: все natives,
  forwards, константы и типы из `rps_stats.inc` компилируются без ошибок и
  предупреждений.
- Проверка на живом сервере не проводилась: окружение TEST-R1 использовалось
  как read-only эталон. Поведение подтверждено чтением исходников ZP/ReAPI, а
  не замерами на запущенном сервере.
