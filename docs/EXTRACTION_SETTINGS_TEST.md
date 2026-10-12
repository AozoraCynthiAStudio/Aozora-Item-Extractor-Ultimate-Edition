# 提取设置与搜索状态测试版

- 武器附赠弹药：MCM 滑块 0–1000，步长100；0关闭。
- 弹药每组数量：左右切档 1 / 10 / 50 / 100 / 500 / 1000，默认100。
- MCM设置保存后，下次打开提取菜单生效。
- 自定义数量位于 Data/F4SE/Plugins/AozoraItemExtractor.ini 的 [ItemCount]：Ammo、WeaponAmmo。仅更改MCM选择时覆盖自定义值；只打开MCM不会覆盖。
- [MCMState] 为同步记录，不要修改；INI 自定义只修改 [ItemCount]。
- 非预设INI数量仍使用原值；MCM显示最近保存的档位，操作MCM后使用所选档位。
- 赠送关闭后隐藏武器气泡，其他数量提示显示实际配置。
- 输入模式增加完整边框、较明显底色与输入中提示。Tab、Esc、Enter保持退出输入并保留查询。

Native、Papyrus、SWF编译通过；需要用户在游戏内验收MCM设置、INI自定义及搜索状态。
