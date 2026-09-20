| Правило | Доказательство | Статус |
| --- | --- | --- |
| Никогда не регистрировать класс в plugin_init — только в plugin_precache | Чтение исходников ZP 5.0.8a на пине | Подтверждено |
| Никогда не вызывать zp_class_zombie_register_model, _claw, _kb с чужим или непроверенным id класса | Чтение исходников ZP 5.0.8a на пине | Подтверждено |
| Не считать регистрацию успешной, не проверив возврат | Чтение исходников ZP 5.0.8a на пине | Подтверждено |
| Никогда не задавать клавишу способности кодом символа или номером клавиши | Чтение исходников ZP 5.0.8a на пине | Подтверждено |
| Не читать значение квaра в plugin_precache, если квaр создаётся в plugin_init | Чтение исходников на пине | Подтверждено |
| Не оставлять способность, неуязвимость, свечение и задачу включёнными после смерти, конца раунда и выхода игрока | Чтение исходников ZP 5.0.8a на пине | Подтверждено |
| Не смешивать модульную линейку zp50_* и совместимость zp_* из zombieplague.inc | Чтение исходников ZP 5.0.8a на пине | Подтверждено |
| Не игнорировать порядок строк в plugins.ini | Исходники ZP 5.0.8a (zp50_gamemode_infection.sma:37-41, zp50_ambience_sounds.sma:30-104), AMXX meta_api.cpp:548, лог сборки 19.09.2026 | Подтверждено |
| Регистрировать класс первым делом в plugin_precache, handle держать в глобальной переменной | Чтение исходников ZP 5.0.8a на пине | Подтверждено |
| Сигнатуру брать из заголовка, а не по памяти | Чтение исходников ZP 5.0.8a на пине | Подтверждено |
| Модель игрока передавать именем без пути, claw — полным путём | Чтение исходников ZP 5.0.8a на пине | Подтверждено |
| Помнить, что параметры класса живут в конфиге: код задаёт умолчание, zp_zombieclasses.ini перекрывает | Чтение исходников ZP 5.0.8a на пине | Подтверждено |
| Способность по клавише вешать на FM_CmdStart с get_uc(handle, UC_Buttons) | Чтение исходников ZP 5.0.8a на пине | Подтверждено |
| Подписываться на форварды ядра, а не искать свои точки входа | Чтение исходников ZP 5.0.8a на пине | Подтверждено |
| Состояние проверять функцией ядра | Чтение исходников ZP 5.0.8a на пине | Подтверждено |
| Свою задачу по игроку снимать явно и по всем выходам | Чтение исходников ZP 5.0.8a на пине | Подтверждено |
| Хуки Ham ставить и для ботов | Чтение исходников ZP 5.0.8a на пине | Подтверждено |
| Принадлежность классу проверять по id класса, а не по имени | Чтение исходников ZP 5.0.8a на пине | Подтверждено |
| Отсчёт на экране делать задачей с интервалом не меньше 0.1 секунды | Чтение исходников на пине | Подтверждено |
| Помнить, что plugin_natives менеджера выполняется при загрузке плагина, раньше любого plugin_precache | Исходники ZP 5.0.8a (zp50_gamemodes.sma:100-107) + лог рабочей сборки 19.09.2026 | Подтверждено |
| Помнить, что id класса — индекс, а не константа | Чтение исходников ZP 5.0.8a на пине | Подтверждено |
| Помнить, что имя класса — ключ секции в zp_zombieclasses.ini | Чтение исходников ZP 5.0.8a на пине | Подтверждено |
| Модель класса не выставлять самому | Чтение исходников ZP 5.0.8a на пине | Подтверждено |
| Меню выбора класса расширять через natives и форварды класса, а не своим меню | Чтение исходников ZP 5.0.8a на пине | Подтверждено |
| Помнить, что настроек два файла: zombieplague.ini и zombieplague.cfg для режима игры, zp_zombieclasses.ini и zp_humanclasses.ini для классов | Чтение исходников ZP 5.0.8a на пине | Подтверждено |
| Перед ArrayGetCell проверять размер массива | Лог рабочей сборки 19.09.2026 («Invalid index 1 (count: 0)»), zp50_ambience_sounds.sma:30-104, plugins.ini:58 против :60-66 | Подтверждено |
| Помнить, что ZP 5.0.8a — закрытая линейка: автор не поддерживает её с 2011 года | Сверка 111 файлов .sma/.inc сборки с релизом 5.0.8a по md5; публичные описания форков | Подтверждено |
| Никогда не пытаться отменить действие на форварде, возврат которого игнорируется | Все вызовы CreateMultiForward в ZP 5.0.8a: 14 ET_CONTINUE, 24 ET_IGNORE; zp50_core.sma:58-69 | Подтверждено |
| Не переводить исходник ZP 5.0.8a на ReAPI внутри базовой сборки | Сверка исходника с релизом; 87 из 102 Ham-регистраций имеют прямой эквивалент ReAPI | Подтверждено; отдельный новый мод не запрещён |
| Регистрировать в правильной фазе: режимы и классы — в plugin_precache, предметы — в plugin_init | zp50_gamemode_infection.sma:37-41, zp50_class_zombie_classic.sma:27-33, zp50_item_antidote.sma:25-31 | Подтверждено |
| В хуке Ham_TakeDamage сперва отсечь не-игрока, и только потом сравнивать attacker | zp50_human_armor.sma:47, zp50_zombie_damage.sma:31, zp50_gamemodes.sma:74, zp50_spawn_protection.sma:39 и ещё шесть плагинов; hlds.run тред 725 (22.08.2026) | Подтверждено чтением; живой тест лавы — нет |
| Для клавиши M сохранять порядок zp50_main_menu.amxx перед zp50_gameplay_fixes.amxx | zp50_main_menu.sma:53, 105-113; zp50_gameplay_fixes.sma:69, 150-159 | Подтверждено чтением |
| Паузу у `zp50_gamemode_*` не считать дефектом: менеджер режимов штатно держит их на паузе | Замер на живом сервере: 91 плагин, 84 running, 7 paused — семь режимов | Подтверждено |
| Разделять обязательную зависимость через #pragma reqlib и необязательную через LibraryExists | zp50_core.inc:9, zp50_class_zombie.inc:10; optional checks в zp50_main_menu.sma и других | Подтверждено чтением |

Где прочитано: архив релиза ZP 5.0.8a `Sh1ft0x0EF/Zombie-Plague-Mod`, ветка `5.0.8a`, коммит `bc98c31990b17570bbd1399d2043825d3c1fe2d4`. Сверка с рабочей сборкой: 111 файлов `.sma` и `.inc` совпали по md5, отличий нет. Ключевые файлы: `zp50_class_zombie.inc` (67, 76, 85, 94, 175, 183), `zp50_core.inc` (23, 107-146), `zp50_gamemodes.inc` (128, 137), `zp50_class_zombie.sma` (25, 341-360, 418, 440, 452-467, 481-541), `zp50_class_zombie_light.sma` (27-39), `zp50_leap.sma` (145), `zp50_flashlight.sma` (55, 143), `zp50_spawn_protection.sma` (35-42, 57, 80, 116, 130), `zp50_grenade_frost.sma` (162, 243, 257, 280), `zp50_class_zombie_rage.sma` (67), `zp50_zp43_compat.sma` (311-327), `zp50_class_zombie_const.inc` (8, 11-13), `zp50_ambience_sounds.sma` (30-104), `zp50_gamemode_infection.sma` (37-41), `zp50_gamemodes.sma` (100-107), `zp50_class_zombie_classic.sma` (27-33), `zp50_item_antidote.sma` (25-31), `zp50_human_armor.sma` (47, 127), `zp50_zombie_damage.sma` (31, 72), `zp50_spawn_protection.sma` (39), `zp50_core.sma` (58-69, все CreateMultiForward), AMXX `amxmodx/meta_api.cpp` (548, порядок plugin_precache до plugin_init).

Проверено 19–20.09.2026. Стек, на котором проверено: HLDS 8684, ReHLDS 3.15.0.896, ReGameDLL 5.30.0.814, Metamod-R 1.3.0.149, AMX Mod X 1.10.0.5484, ReAPI 5.29.0.358, Zombie Plague 5.0.8a.

## Форварды ZP 5.0.8a: блокируемые и нет

Замерено по всем вызовам `CreateMultiForward` в поставке.

Блокируемые (`ET_CONTINUE` — возврат читается, отменить можно), 14:
`zp_fw_core_infect_pre`, `zp_fw_core_cure_pre`, `zp_user_infect_attempt`, `zp_user_humanize_attempt`, `zp_extra_item_selected`, `zp_fw_items_select_pre`, `zp_fw_gamemodes_choose_pre`, `zp_fw_class_zombie_select_pre`, `zp_fw_class_zombie_select_post`, `zp_fw_class_human_select_pre`, `zp_fw_class_human_select_post`, `zp_fw_grenade_fire_pre`, `zp_fw_grenade_frost_pre`, `zp_fw_deathmatch_respawn_pre`

Неблокируемые (`ET_IGNORE` — возврат игнорируется, только узнать), 24:
`zp_fw_core_infect`, `zp_fw_core_infect_post`, `zp_fw_core_cure`, `zp_fw_core_cure_post`, `zp_fw_core_last_zombie`, `zp_fw_core_last_human`, `zp_fw_core_spawn_post`, `zp_fw_items_select_post`, `zp_fw_gamemodes_start`, `zp_fw_gamemodes_end`, `zp_fw_gamemodes_choose_post`, `zp_fw_grenade_frost_unfreeze`, `zp_round_started`, `zp_round_ended`, `zp_user_infected_pre`, `zp_user_infected_post`, `zp_user_humanized_pre`, `zp_user_humanized_post`, `zp_user_last_zombie`, `zp_user_last_human`, `zp_user_unfrozen`, `event_gamestart`, `event_infect`, `event_infect2`, `event_teamwin`
