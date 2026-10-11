# PreviewSpike05 — AE对照实验

Spike04只获得空的10mmReceiverParentObject。本版换成Fallout4.esm原版警棍（0008C14D），仍通过引擎Load3D(true)获取，不猜NIF路径、不同步加载、不修改背包或放置世界物品。

这是隔离“枪械组件组装”和“通用加载/渲染链路”问题的对照实验，不是Inventory3DManager完整实现。现有CommonLib缺少提交物品和更新加载任务的封装，不能安全照搬旧版本地址。

日志新增记录测试FormID、引擎模型字段、模板/内置组件是否存在。后续节点检查沿用Spike04日志标记。完全退出游戏，禁用旧实验包，启用本包后进入提取页约10秒，再关闭菜单，提供AIE_PreviewSpike.log及画面结果。

编译开关默认关闭，正式Data不替换。仅编译与打包验证，不代表AE运行验证。恢复时禁用本实验包，启用正式版。
