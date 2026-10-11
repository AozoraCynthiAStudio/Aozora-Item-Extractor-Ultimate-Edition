# 首个可用版本 / First usable release

## 中文介绍

**青空物品提取器终极版**为 Fallout 4 提供统一的模组物品查找、提取和归还菜单。它采用 Aozora 风格界面，适配键盘、鼠标和手柄，并借鉴社区同类工具中成熟、实用的功能思路。

### 查找模组与物品

浏览当前已加载的 ESM、ESP 和 ESL 插件。可以直接搜索插件名称，也可以输入物品名称，查找包含该物品的插件。进入搜索结果后，匹配物品会显示在列表顶部，方便继续提取。

### 提取、批量与归还

右栏显示当前插件的可提取物品，左栏显示本次菜单会话中仍可归还的已提取物品。切换栏位后，底部操作提示会相应变为“提取／批量提取／全部提取”或“归还／批量归还／全部归还”。

- **普通提取按组获得。** 默认弹药每组 100 发，武器、护甲、辅助、垃圾、杂项等每组 1 个；组大小可在 INI 中调整。
- **批量操作选择实际数量。** 例如弹药选择 x10，获得的是 10 发，并不是 10 组。
- **全部提取**：当前插件的全部可提取物品各获得一组，不受当前分类筛选限制。
- **全部归还**：归还本次菜单会话中全部仍可归还的物品，不受当前分类限制。
- 归还数量受到会话净提取量和背包原有数量基线的限制；已经消耗、丢弃的数量可能无法归还。返回插件选择页保留会话，关闭整个菜单则结束会话。

### 武器附送弹药与数量提醒

提取具有基础弹药记录的武器时，每次操作附送固定 1000 发基础弹药。一次批量提取多把武器，也只附送这一组 1000 发。归还武器不会自动收回附送弹药。

选中弹药物品时，辐射娘会提示“弹药按组领取，每组 100 发哦！”。提示中的数量读取实际配置，修改组大小后也会随之变化。选中会附送弹药的武器时，她会提示附送弹药的信息。

### Aozora 界面、辐射娘与配色

界面采用统一的双栏布局、分类标签、物品图标和底部操作提示。颜色可以跟随玩家的 HUD 设置，也可以在 MCM 中选择六种内置配色。

菜单旁的装饰角色是 **Aozora 辐射娘**：插件选择页使用探头姿势，提取页使用坐在废土补给箱旁的姿势。每次进入页面会选择一张角色素材；滚动列表或刷新物品时不会反复更换。人物附近的对话气泡说明搜索方法、武器附送弹药和弹药按组领取规则。

MCM 将外观、热键和说明放在一个页面中分组展示。“显示辐射娘”开关可以同时隐藏角色和提示气泡。

### 键鼠、手柄与启动方式

键鼠和手柄均可浏览、搜索、切换分类、提取及归还。手柄使用 **LT/RT** 切换分类，数量弹窗使用左右方向选择。可以在 MCM 中绑定菜单热键；也可以使用 Pip-Boy“辅助”分类中的启动物品打开菜单，因此 MCM 不是必须安装的依赖。

### 安装与下载

需要与游戏版本匹配的 F4SE、Address Library 和 VC++ x64 运行库。

- **EN**：英文主体，安装后启用 AozoraItemExtractor.esp。
- **CHS Patch**：先安装英文主体，再安装此补丁即可汉化；需要游戏支持中文字体。
- **Source**：当前源码、素材和构建工具。
- **SHA256SUMS**：下载文件的校验清单。

汉化覆盖功能文字、MCM 和启动物品名称。菜单头部 **AOZORA / ITEM EXTRACTOR** 保留英文；中文 MCM 名称为“青空物品提取器终极版”。物品名称沿用游戏和对应模组提供的数据。

---

## English overview

**Aozora Item Extractor Ultimate Edition** brings plugin discovery, item extraction and session returns into one Fallout 4 menu. It combines an Aozora-styled interface, keyboard/mouse and controller controls, and practical features inspired by community item extractors.

### Find plugins by filename or item name

Browse loaded ESM, ESP and ESL plugins. Search a plugin filename directly, or search an item name to discover which plugin contains it. Opening an item-search result places the matching item at the top of the list for easy access.

### Take, batch and return items

The right pane lists extractable items from the selected plugin. The left pane lists extracted items that remain returnable in the current menu session. Footer actions change with the active pane: Take / Batch Extract / Take All, or Return / Batch Return / Return All.

- **Normal extraction uses a configured group.** Ammo defaults to 100 rounds; weapons, armor, aid, junk and miscellaneous items default to 1. Group sizes can be changed in the INI.
- **Batch quantities are actual item counts.** Selecting x10 ammo gives ten rounds, not ten groups.
- **Take All** gives one group of every extractable item in the selected plugin, regardless of the active category filter.
- **Return All** returns all remaining returnable items from the current menu session, regardless of category.
- Returns are capped by the session's net extracted quantity and the inventory amount above the original baseline. Consumed or discarded items may no longer be returnable. Returning to the plugin browser preserves the session; closing the whole menu ends it.

### Starter ammo and quantity guidance

Taking a weapon with a base-ammo record grants a fixed stack of 1000 rounds per extraction action. Taking several guns in one batch still grants just that 1000-round stack. Returning a weapon does not automatically reclaim bonus ammo.

Selecting an ammo row displays a mascot tip explaining its configured group size. The number follows the actual INI setting. Selecting an eligible weapon displays a tip about its starter ammo.

### Aozora visuals, mascot and theme colors

The interface uses a consistent two-pane layout, category tabs, item icons and footer controls. Colors can follow the player's HUD settings or use one of six built-in MCM palettes.

The illustrated companion is the **Aozora mascot**: she peeks around the plugin browser and sits beside wasteland supply crates on the extraction page. A pose is selected when entering a page and stays stable while scrolling or refreshing the list. Speech bubbles explain searching, starter ammunition and ammo group sizes.

The optional MCM groups Appearance, Hotkeys and About on a single page. The Show mascot switch hides both the character and her speech bubbles.

### Keyboard, mouse and controller

All three input methods support browsing, search, categories, extraction and returns. Controllers use **LT/RT** for categories and left/right for batch quantities. Open the menu with an MCM hotkey or the Aid launcher item in Pip-Boy; MCM is optional.

### Installation and downloads

Requires matching F4SE, Address Library and the VC++ x64 runtime.

- **EN**: English core. Install it and enable AozoraItemExtractor.esp.
- **CHS Patch**: Install after the English core to enable Simplified Chinese. Chinese-capable game fonts are required.
- **Source**: Current source code, artwork and build tools.
- **SHA256SUMS**: Download checksums.

The Chinese patch translates functional UI, MCM and launcher names. The AOZORA / ITEM EXTRACTOR header remains English; item names come from the game and their respective mods.

### Build and runtime status / 构建与实机情况

Earlier functionality was confirmed in the user's game environment. The latest LT/RT mapping and configurable ammo-group tip compile successfully and await in-game confirmation. This release does not claim testing every game runtime or mod list.
