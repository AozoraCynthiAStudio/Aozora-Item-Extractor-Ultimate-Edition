# Inventory Launcher Toggle — Test 01 / 1.0.8

## 范围及调用关系

- Native main.cpp：IsLauncherEnabled -> ReconcileLauncherInventory；QueueLauncherReconcile 在游戏任务中持互斥锁执行，排队标记防重复。
- 复用 StartMonitor，约1.5～2秒核对一次特定启动物品，无新增线程、全背包枚举或序列化。
- PrewarmAndScan 在加载完成后允许核对；跨读档 generation 丢弃旧预热及核对任务。
- Papyrus ControllerQuest.OnInit / Launcher.OnEffectStart 只请求 RequestLauncherSync，不再独立 AddItem。Launcher 的 OpenFromLauncher 及关闭 Pip-Boy 路径保持原样。
- g_launcherWorldReady、保存标记、游戏菜单门禁、Pip-Boy动画、提取任务和启动等待状态均会阻止本轮物品操作；下一轮重试。
- ON且count=0添加一个；已有多个不删除。OFF且count>0仅移除玩家背包中现有启动物品。没有查询其他容器或世界副本。

## 配置

MCM 快捷键区域新增“背包启动物品 / Inventory Launcher Item”，Switcher，默认ON。
General/bInventoryLauncherEnabled 明确存在时优先；否则读取 F4SE INI 的 General/AddLauncherOnLoad（默认1）。
首次安全核对时将旧值迁移到 MCM/Settings/AozoraItemExtractor.ini；MCM未安装也执行同一读取规则。
发布的 Settings 文件故意不预填新键，防止覆盖旧用户的 AddLauncherOnLoad=0；迁移后的新键为唯一有效开关，旧键仅作为迁移回退。
MCM关闭后下一个安全检查生效，无需重启。保存文件不存储此开关，读旧档不会重置它。

## 修改文件

- src/native/src/main.cpp、src/native/xmake.lua、VERSION.txt。
- Data/Scripts/Source/User/{AIE_ControllerQuestScript,AIE_LauncherScript,AozoraItemExtractorNative}.psc 及对应PEX。
- mcm/MCM/Config/AozoraItemExtractor/config.json、Settings/AozoraItemExtractor.ini 及Data/MCM发布副本。
- translations/AozoraItemExtractor_{en,cn}.txt 及Data中英文发布表。
- 本说明。SWF、ESP、启动FormID、提取/归还业务未修改。

## 构建与静态核对

Native releasedbg / --preview_spike=n 编译通过；Caprica四脚本编译通过。
打包需核对Native marker、PEX字节、MCM选项及双语键；ESP/SWF与1.0.7逐字节比较。
静态核对不代表游戏内测试通过。

## 待用户实机回归（全部待测）

| 场景 | 预期 |
|---|---|
| 新装/旧档默认ON，背包没有 | 安全时机补一个 |
| ON已有一个或多个 | 不重复添加、不删除多余副本 |
| 使用启动物品 | 原有菜单正常打开，关闭后补回 |
| 丢弃/出售/放入容器 | 返回安全游戏状态后补一个；外部副本保持原样 |
| ON到OFF：背包0/1/多个 | 分别无操作/移除一个/全部移除，只针对启动物品 |
| OFF重开游戏、普通保存、快速保存、读旧档 | 不补发；热键仍正常 |
| OFF到ON，多次往返切换 | 恢复一个，无重复或循环 |
| 无MCM、旧INI=0/1 | 分别保持OFF/ON；首次核对后迁移 |
| 手柄收藏使用启动物品 | 菜单打开和补发正常；核对收藏标记是否保留 |
| Take/Return/Batch及图标搜索 | 与1.0.7行为一致 |
| 使用 -> 关闭菜单 -> QuickSave -> Load | 无CTD，入口状态正常 |
| OFF -> 移除 -> QuickSave -> Load | 无CTD，仍保持OFF |

不发布正式Release，等待本轮实机结果。

## Test 02 修正

Test 01 实机发现：MCM OFF且点击不保存，Native仍补发。根因是新键未在MCM启动读取的INI中注册，运行时写入Settings不能创建MCM缓存中的新键。
新增Config/AozoraItemExtractor/settings.ini注册默认ON（用户Settings仍优先）；首次从旧INI迁移时通过可选MCM静态接口同步缓存。未安装MCM时不调用接口。
必须完全退出游戏并重新启动，让MCM注册新键；重新进菜单不足以完成注册。
本次MCM实际切换、移除和存读档仍待用户验证。

## 正式版本整理

2026-10-18：用户确认Test02已可用，并授权整理1.0.8正式包及GitHub发布。正式构建仅更换构建标记，未扩展功能。上文“待测”为测试时的原始清单，不代表每个场景均已获得独立实测证据。
