# 中文输入兼容测试

本次修改发布于 1.0.5，开发测试基于 1.0.4，包含滚动条拖动、轨道点击和右摇杆滚动修改。

## 调查的输入模组

- Chinese Input for Fallout 4（RIME）：https://www.nexusmods.com/fallout4/mods/90872
- NA Input Support：https://www.nexusmods.com/fallout4/mods/99121
- 旧版 ChineseInput-F4SE：https://github.com/kassent/ChineseInput-F4SE
- Scaleform Copy Paste（剪贴板输入辅助）：https://www.nexusmods.com/fallout4/mods/77094

旧版 ChineseInput-F4SE 源码用于了解标准文本输入入口，不代表已检查当前 RIME 版本实现。以上模组不成为提取器的新前置；请选择适合游戏运行时的输入模组分别测试。

## 本次修改

搜索模式启用游戏标准文本输入状态，优先调用 F4SE AllowTextInput，无法调用时使用引擎入口。退出搜索、隐藏或关闭菜单时配对释放。输入框获得真实文本焦点；输入文字与接收搜索结果时保留同一个输入框，减少输入法被刷新打断的机会。保留单一字符处理路径，避免重复输入，并让 Ctrl+A/C/V/X 交给标准文本框处理。

## 游戏内验证

1. 点击搜索框或按 F，确认不会额外输入 f。
2. 用输入法提交中文，检查文字显示、插件名和物品名搜索结果。
3. 输入 WASD，确认只输入字母；检查退格、删除、光标移动。
4. 按 Enter 或 Tab 退出输入，再打开搜索；关闭整个菜单后检查输入法状态恢复。
5. 使用匹配游戏版本的剪贴板辅助模组时，另行验证中文粘贴。
6. 检查滚动条拖动及右摇杆滚动后，选中行仍完整显示。

玩家已确认鼠标滚动条操作、Chinese Input（RIME）和 NA Input Support 中文输入正常。剪贴板辅助及其他输入模组仍需分别验证。

如失败，提供 Documents/My Games/Fallout4/F4SE/AozoraItemExtractor.log，以及输入模组名称、版本和游戏版本。日志中的 SEARCH_TEXT_ENTRY 记录输入状态入口，SEARCH_UNICODE 记录收到的非 ASCII 字符。
