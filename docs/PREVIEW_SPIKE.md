# 3D Preview Spike 01

本实验基于当前 Scaleform Ultimate Edition 1.0.2 源码。

## 测试方式

用独立测试包替换当前安装，避免同时启用两份同名 DLL。
打开提取器，进入任意插件的物品页。测试与选择行无关，固定尝试 Fallout4.esm 10mm 手枪。
返回插件页、关闭菜单、打开控制台隐藏界面后检查是否留下模型。
日志：Data/F4SE/Plugins/AIE_PreviewSpike.log。

## 本轮链路

TESObjectWEAP -> 引擎 IFormFactory 临时 TESObjectREFR -> Load3D(true)
-> NiAVObject -> 独立 Interface3D::Renderer screen-attached 3D。

不放置世界引用，不向玩家背包添加测试物品。正式功能开关默认关闭。
该路径是测试引擎引用加载和 Interface3D 展示的替代实验，尚未验证 Inventory3DManager
的 inventory/model/OMOD 选择逻辑，不能据此声称所有物品与改装实例已支持。

## 结果边界

原生编译已通过；没有进行游戏内验证，没有截图证据。
SetViewport 的坐标含义、主屏幕 camera/scale、独立引用 background Load3D 的支持情况
仍需实测。若日志到 renderer enabled 但模型不可见，下一步检查 camera 与 viewport；
若停在 Load3D，继续追踪 Inventory3DManager 的原版请求入口，不改成同步纹理加载。
AE relocation 覆盖尚未单独验证。

## 编译

在 src/native 执行：

    xmake f -m releasedbg --preview_spike=y -y
    xmake -j2

正常构建使用 --preview_spike=n。

## 关闭与风险

Clear 顺序为 Disable -> 移除 screen attached root -> 清灯 -> Release renderer
-> 释放模型 -> 清引用 3D -> SetWantsDelete -> 释放临时引用。
加载等待限制为 300 次菜单更新，失败后当次页面不重试。
此顺序仍需引擎实测，尤其是关闭发生在 background Load3D 尚未完成时；
不要用重要存档测试，不保存实验引用状态。该实验不构成正式发布版本。
