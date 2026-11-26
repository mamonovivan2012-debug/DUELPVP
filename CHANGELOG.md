# CHANGELOG — Dark Fantasy Update

- Подключены фон крепости и новая боевая арена из пользовательского листа ассетов.
- Добавлены пять портретов персонажей для боевого HUD и сохранён полный исходный атлас.
- Обновлены подписи глав кампании на запрошенные названия; добавлены описания, цели, противники и награды.
- Добавлено плавное появление панели главного меню.
- Для Abyss Dominion добавлена отдельная текстовая обратная связь при активации и визуальный импульс при завершении; параметры способности сохранены.
- Обновлён README с инструкцией, управлением и честным описанием ограничений/проверок.

## Исправление совместимости GDScript

- Исправлен вывод типов в `scripts/main.gd`: переменные `just` в четырёх функциях обработки нажатий явно объявлены как `bool`.
- Переменная `tint` в `_draw_campaign_arena_tint()` явно объявлена как `Color`.
- Это устраняет пять указанных ошибок `Cannot infer the type` при разборе скрипта в Godot 4.x.

## Визуальная корректировка после обратной связи
- Заменены пиксельные игровые фигурки на пять новых полноразмерных иллюстраций с прозрачным фоном в едином Dark Fantasy стиле.
- Новые фигуры сохраняют пропорции исходных изображений при отрисовке и больше не растягиваются как квадратные пиксельные спрайты.
- Добавлены контактные тени под персонажами, чтобы они визуально стояли на поверхности арены.
- Старые игровые спрайты сохранены в проекте для совместимости; новые иллюстрации используются только для отображения персонажей в бою.


## Обновление главного меню — 26.11.2026

- Полностью перестроена композиция главного меню: крупный заголовок и герой слева, отдельная навигационная панель справа.
- Убрана длинная прокручиваемая колонка кнопок и настроек.
- Выбор двух персонажей и сложности бота перенесён в отдельную компактную панель.
- Поле IP расположено рядом с действием подключения к PvP.
- Кнопки получили единые состояния normal/hover/pressed/focus и более спокойную золотисто-каменную палитру.
- Сохранены существующие действия режимов, настройки, кампании и выхода.
- Ослаблено затемнение фоновой крепости, чтобы изображение было заметнее.
- Изменения меню не затрагивают боевую систему и механику персонажей.


## Combat Gameplay & Animation Pass

- Reworked the battle presentation so fighters no longer stand as static cutouts: added idle breathing, movement bob, directional lean, attack commitment/lunge, recoil, and hit flash.
- Added three-step melee combo chaining with escalating damage and varied slash direction.
- Replaced generic semicircle melee swipes with directional blade trails, impact bursts, and flying sparks.
- Replaced the Guardian ground-slam ring with radial ground cracks.
- Added short hit-stop and camera shake feedback on confirmed hits and abilities.
- Added knockback and clearer hit reactions while preserving character stats, ability cooldowns, campaign, PvP/PvB, and Abyss Dominion rules.
- Corrected movement lock while rooted for both fighters.

**Verification:** ZIP integrity and referenced resource paths are checked. A Godot executable is not available in this environment, so engine parsing and an in-game playtest are not claimed.
