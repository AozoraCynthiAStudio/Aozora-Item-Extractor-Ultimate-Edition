# Preview Spike 02 — AE viewport correction

Spike01 在 AE 实测中没有显示模型，并把整个提取器菜单缩到右侧。
SetViewport 接收主菜单 Movie；它不能当作独立模型 viewport 使用。
Spike02 移除此调用，保留同一模型加载路径和独立渲染器，不修改主菜单 viewport。

使用独立包替换 Spike01，然后进入任意插件的提取页。关闭菜单后再重新打开一次。
请提供 Data/F4SE/Plugins/AIE_PreviewSpike.log；新增日志以 PreviewSpike02 开头。
日志里 NiAVObject obtained 表示已取得模型，不表示模型已实际显示。
renderer enabled 之后不可见需要继续检查 camera、模型位置和 renderer scene 的设置。

已通过原生编译；尚未完成 AE 游戏内复测。此版仅修正已识别的 UI 副作用，
没有声称模型展示已修复。仍使用测试存档，不保存实验状态。
