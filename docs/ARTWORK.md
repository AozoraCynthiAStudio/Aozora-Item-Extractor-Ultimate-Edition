# 素材维护

- 当前运行素材在 assets/mascots、watermarks、decorative 和图标目录。
- 用户提供的设计原件在 docs/design；它们不参与运行包。
- corner2 / corner3 在本轮使用内置 imagegen 修复腿部连接；原 PNG 在 assets/mascots/originals。
- 编辑要求：保留角色、衣服、表情、机器人、补给箱及透明背景，理顺两个膝盖、小腿到两只鞋的连接。生成结果并非逐像素局部修改。
- 运行通过 MountImage -> img:// -> Loader，DDS 单 mip BC3；不要改为 SWF 内嵌 PNG 或新增装饰 mask。
