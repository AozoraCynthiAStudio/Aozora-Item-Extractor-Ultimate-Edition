# Performance Test 02 — 诊断构建与证据报告

日期：2026-10-18。基线为审查包 `01_Aozora_Current`，修改前已逐字节对照源码文件一致。
版本仍为1.0.6，启动标记为 `performance-test-02-20261018`；不替换GitHub正式Release。

## 1. 当前产品状况与本轮结论

用户认为日常体验良好，多数ESP/ESL流畅，Fallout4.esm也未观察到卡顿。只有部分大型框架、武器包被反馈进入较慢；没有具体问题插件与同环境分段耗时。因此没有证据支持“普遍存在严重性能缺陷”或必须重构。

本轮只诊断和修复已确认的配置/失效问题。完成构建后停止，不自动进入Test03。
允许最终结论为：现有性能符合项目需求，保持架构并结束本轮优化。

## 2. 保留的Test01改动：价值与回归风险

| 改动 | 实际代码价值 | 仍需游戏验证 |
|---|---|---|
| session-only inventory | 只为会话内有净提取量且仍可归还的物品构造左栏 | 消耗/丢弃/装备后归还、提取前已有数量、批量归还上限 |
| 静态行缓存 | 重复进入无需重建名称/图标行数据 | 改配置、读档、重复扫描、长期访问很多插件 |
| FIS标签索引 | 保持最后定义优先；关键词中选择最大规则索引 | 自定义附加规则、显式标签、AutoTags、关键词与兜底是否一致 |
| AS3分类缓存 | 全部分类不再复制筛选数组，其他分类可复用 | 搜索进入定位、分类切换、会话刷新、鼠标/手柄滚动 |

这些是合理的低风险候选；没有实测就不能宣布比旧版更好，Test01的游戏验收仍待完成。

## 3. Test02全部代码修改

- `Performance.h`：steady_clock微秒计时、进入trace上下文、可关闭的阶段日志；不新增游戏线程或引擎对象。
- `main.cpp`：记录进入请求、原有游戏任务排队、锁等待、OpenPluginInternal、BuildUISnapshot、会话构建、静态行首次构建/复制、类别分布与缓存情况。游戏对象工作仍通过原有QueueGameTask执行；没有新增后台扫描。
- 确认旧逻辑仅在重新打开菜单时更新Ammo，其他ItemEntry的groupCount可能陈旧。现在保存扫描时的thrownWeapon分类，在下一次打开时刷新Weapon/Armor/Aid/Grenade/Junk/Misc/Ammo全部组数量；复制缓存行后也按当前配置更新显示。Take和TakeAll使用刷新后的ItemEntry，Batch仍选择实际数量，Return仍使用会话首次提取时保存的组数量和基线。菜单打开期间不新增实时热重读配置。
- `FISIconResolver.*`：按section聚合名称标签、AutoTags、关键词、缓存命中与耗时；记录正则尝试次数和规则首次加载时间。没有逐物品性能日志，没有改变FIS优先级。
- 确认Test01只清除行缓存，旧FIS缓存没有明确读档/重扫描失效入口。现在在ScanLoadedData和ResetRuntimeState清空图标及规则缓存，下次按原顺序重读规则。菜单普通关闭/重开不清除，以保留热缓存。游戏运行中其他模组任意修改名称/关键词后仍无专门变更事件；这项边界记录在此，不扩展新系统。
- `ScaleformMenu.*`：快照携带trace与原生请求时间；统计快照复制、插件列表、CreateItems、字符串数量/UTF-8字节及ApplySnapshot。增加一个只报告指标的GFx回调；无分页、无数据协议重构、无新异步任务。
- AS3：ApplySnapshot/render使用原生begin/end回调测量微秒窗口，同时保留本地毫秒；ENTER_FRAME回执作为下一帧可交互候选代理；记录图标库完成/失败与重绘次数，滚动/一般重绘日志各限每秒一条。未更改行复用、图标加载或滚动实现。

## 4. 日志开关与字段

完整日志：`Documents/My Games/Fallout4/F4SE/AozoraItemExtractor.log`。
MO2 overwrite中的旧日志不包含全部REX诊断，不能单独用于分析。
筛选 `[AIE-P02]`，按trace分组；插件名有引号。`trace=0`表示启动、重新扫描或会话刷新等非进入请求阶段。

测试包默认开启。在 `Data/F4SE/Plugins/AozoraItemExtractor.ini` 添加：

```ini
[General]
bPerformanceDiagnostics=0
```

0关闭新增诊断，1开启；下次重新打开菜单读取。无需新增MCM项。此开关不会关闭原有功能日志。
测试包以1为默认值；正式发布前应重新评估是否保留诊断及默认值。

| stage | 字段含义 |
|---|---|
| EnterRequest | 原生收到进入操作，创建唯一trace |
| EnterQueue | queue-us=从请求到原有游戏任务开始；lock-us=取得g_mutex的等待；visit=本次扫描周期内进入该插件次数 |
| OnEnterPlugin / OpenPluginInternal | 函数包围耗时，包含其子调用；不是可相加的互斥阶段 |
| ScanLoadedData | 原有扫描过程包围耗时 |
| StaticRows | cache=hit/miss，rows，首次行构建或缓存访问us，已缓存插件数 |
| StaticRowsCopy | 从行缓存复制到本次快照的us |
| Distribution | 六大显示分类数量；当前插件行vector容量字节、字符串capacity估算，不是进程总内存 |
| BuildInventoryRows | 会话查询、名称/图标与排序的包围耗时 |
| SnapshotCounts / BuildUISnapshot | items/session/plugins数量、会话与整个快照阶段耗时 |
| FISSection | section与calls/hit/miss；resolve-us总包围；name-us/autotag-us/keyword-us；regex-tests尝试次数 |
| FISTotal | 本次快照或会话刷新聚合；规则加载us、图标缓存数量、规则数 |
| FISReset | 读档/扫描失效前缓存规模；冷启动中可能多次清空空缓存，属正常 |
| CreateItems | kind；rows/objects；每行4个managed字符串、9个成员字段；utf8-bytes仅四个字符串内容长度之和；us含对象/字段/字符串构造 |
| PushSnapshot | copy-lock-us包含g_stateMutex等待与g_snapshot复制；plugins/items/session/metadata-us；apply-us=Invoke同步耗时；total-us=本次PushSnapshot |
| AS3-render / AS3-as-apply | local-ms是AS3本地getTimer差；native-window-us是两个原生回调接收点之间的steady_clock差 |
| AS3-frame-ready | native-since-request-us是请求到ENTER_FRAME回执的原生同源差；local-ms是AS3 Apply到该帧；detail含本地进入耗时及仍加载图标库数量 |
| AS3-icon-library | 仅库加载完成/失败事件；count为本Movie累计完成次数，非该插件独占 |
| AS3-viewport | 可见列表重建的本地毫秒采样，最多每秒一条 |

### 时间口径与限制

C++使用steady_clock微秒，不使用墙钟；Windows下具体有效分辨率由标准库/系统决定。
AS3 getTimer精度为毫秒，没有伪装成微秒。跨语言不相减：native-window/native-since-request都完全在C++时间域内；AS3耗时完全在AS3时间域内。

`frame-ready`是ENTER_FRAME时主列表已构建、事件处理器可用的代理，不证明显卡Present、屏幕可见或操作系统输入实际响应。仍可能有异步FIS图标库加载，应结合icon-library事件和人的体感。没有Present hook或新增引擎渲染生命周期。

各包围指标有嵌套，禁止把它们全部相加。FIS规则加载可能落在第一次name-us中，rules-load-us与该指标重叠。native-window包含回调往返开销，不是纯AS3 CPU时间。
诊断会引入计时/统计/日志开销；聚合每物品只计数、不写日志。要做体感对照可在同一测试包关闭诊断后复测。
GFx仍沿用项目既有菜单/Invoke执行路径；本轮没有通过新线程操作GFx。日志保留线程号便于检查调用上下文；没有实机证据就不宣称完成线程上下文验收。

## 5. 审计结果和可疑瓶颈（均未实测定因）

### 缓存生命周期

g_itemRowsCache以插件为键，持有值类型与字符串，不持有TESForm指针。仅缓存进入过的插件；关闭整个菜单后保留，读档重置和重新扫描时clear。内存随访问的插件累计；上界与已加载且访问过的物品规模相关，没有LRU预算。clear后分配器/map/vector容量行为不等于进程立刻返还内存。现阶段先看缓存规模，不因理论增长添加新管理系统。

FIS图标缓存按FormID，规则按当前安装文件；本轮补上扫描/读档失效。额外代价是读档后首次规则解析和FIS匹配变冷，需记录冷/热差异。规则优先级保持名称标签→AutoTags→关键词、后定义标签覆盖、原有正则/wildcard顺序。

### 可疑阶段与证据位置

- main.cpp BuildUISnapshot首次构建仍处理全部条目及FIS，可观察StaticRows/FISSection。当前ScanLoadedData不直接扫描OMOD表；玩家说的改造配件需确认是否是MISC松散配件，不能直接诊断为OMOD表瓶颈。
- ScaleformMenu.cpp PushSnapshot复制g_snapshot；CreateItems为右栏每条创建对象及四个字符串。大插件的构造/传输开销候选，由CreateItems和PushSnapshot区分。
- Panel.as ApplySnapshot调用render；onIconLibraryLoaded会再次完整render。这样可以把已显示兜底替换为FIS图标，并让类定义可用后正确实例化，但可能每个独立库完成一次再重绘。未证明这是用户等待主因，本轮只计数。
- Panel.as drawItemRows已仅画可见行，rebuildItemViewport仍销毁再创建可见控件。它更可能影响连续滚动，与首次进入延迟不能混为一谈。
- main.cpp BuildInventoryRows在Test01已缩到会话集合，读背包现量必须保持游戏线程；不能缓存returnable而不核对真实背包。
- INI数量原本允许任意uint读取，极端超INT32数值/负值输入校验属于既有边界，本轮不新增数量语义。回归使用有效正整数、赠送0等正常支持设置。

### SAM对照

参考仓库 https://github.com/maximusmaxy/ScreenArcherMenu ，审查快照97ce9c286b2ffcd91eed9d51f847631ff51664d6。

inventory.cpp GetItemList按一个类别选择数组（包含arrOMOD）后返回该类别全部结果，没有在这条路径看到分页协议。forms.h SearchModForFullnameForms并行遍历类型数组，按所属插件筛选、读名称并收集；Push用mutex，最终std::sort。并行遍历不等于整套菜单异步无阻塞；线程访问引擎对象、名称指针和共享容器的安全条件不能照搬到我们的TESForm/GFx路径。

gfx.h GFxResult::PushItem传名称和值两个数组；SliderList.as预建最多15个行控件并在updatePosition复用。SAM这条列表路径数据更轻、默认按类别工作，其设计目标和FIS/会话需求不同。源码说明技术差异，不是我们必须匹配其体感的性能基准。

## 6. 实机回归矩阵（全部待用户执行）

在同一OG/NG/AE环境内对比，先普通插件，再中型、大型装备/框架及Fallout4.esm。无需强制每个人都安装同一超大包；注明插件名、条目数、FIS安装情况、游戏版本。

| 场景 | 操作 | 验收与记录 |
|---|---|---|
| 普通/中型/大型/原版主文件 | 各冷进入、返回再热进入 | 无明显日常退化；trace、visit、StaticRows、FIS、CreateItems、frame-ready |
| 冷定义 | 重启游戏首次；读档首进另记 | 不把重开菜单当冷启动，不混同OS文件缓存冷/热 |
| 分类与搜索 | 全部/各分类、中文英文插件名/物品名进入 | 搜索范围/排序/首项定位不变，类别数量一致 |
| 滚动与焦点 | 滚轮、拖动、轨道、右摇杆、键盘 | 完整可见选中行，悬停不残留，不抢焦点 |
| FIS | 有标签/AutoTags/关键词/未装或失败兜底 | 相同物品图标与优先级不变，主题着色正常 |
| 会话保护 | 已有10件再提取5件；消耗/丢弃部分后归还 | 不归还原有基线物品、不负数、不重复操作 |
| Take/Return/Batch/All | 左右栏及切分类后执行 | 实际数量正确；All不受当前分类限制 |
| 数量配置 | 关菜单，逐项改Weapon/Armor/Aid/Grenade/Junk/Misc/Ammo；再开 | 右栏组数量、默认Take、TakeAll一致；Batch是实际数量；Return按会话记录；特殊武器赠送0/100/1000正确 |
| 缓存失效 | 改数量后重开、读档、重扫后首进 | 无旧group、无跨读档缓存错配；冷缓存日志合理 |
| UI及生命周期 | 主题、角色开关、关闭/重开、控制台、暂停 | 布局/装饰/输入释放/暂停恢复无回归 |
| 保存 | 退出菜单后快速保存、手动保存、读档 | 无CTD、无残留输入锁或菜单 |
| 日志开关 | bPerformanceDiagnostics=0/1，重开菜单 | 0无新增AIE-P02输出；两种状态功能一致 |

## 7. 待真实日志后的Test03决策

优先按同环境用户体感和多次进入指标判断，不能仅凭一条极端样本或理论复杂度继续修改。

| 实测结果 | 后续建议（尚未实施） |
|---|---|
| 普通/中型体验良好，大型延迟也可接受 | 保持架构，完成回归后结束优化；不做Test03 |
| queue/lock占主要等待 | 查阻塞的原有任务及锁持有者，先消除可证明的重复工作 |
| 首次StaticRows且FIS名称/正则占主要等待 | 看section及规则命中数据，优先索引/缓存等小改；没有证据不做延迟图标 |
| CreateItems/快照复制占主要等待 | 先查重复推送，再评估轻量更新；不直接改完整协议 |
| render或库完成后重绘明显 | 核对重复次数，考虑仅更新必要图标；不先重写全部组件 |
| 仅连续滚动明显 | 独立评估可见行复用，避免与加载优化绑成一次大改 |
| Test01出现图标/数量/会话回归 | 先修或回退相应优化，不以提速掩盖语义变化 |

## 8. 验证范围

交付时另附构建记录。编译与包内检查只说明构建完整，不说明实机性能、图标、输入、保存或OG/NG/AE验收通过。
本轮不添加预览、不启用PreviewSpike、不创建REFR、不修改背包/存档来改善性能、不新增多线程扫描/分页/图标延迟协议。原有提取功能正常的Add/Remove操作不属于本轮性能实现。
