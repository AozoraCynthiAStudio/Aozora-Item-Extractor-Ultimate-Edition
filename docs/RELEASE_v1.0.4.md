# v1.0.4

## ⚠️ 重要修复 / Important Fix

1.0.3 打包时，我误将实验性3D预览代码编入正式包，导致保存时CTD。对此很抱歉。现已从正式构建中移除，并增加打包检查，防止再次混入。已在AE确认保存恢复正常。

I accidentally included experimental 3D preview code in the v1.0.3 release, causing CTDs when saving. I’m sorry for this packaging mistake. The code has been removed from release builds, with packaging checks added to prevent it from happening again. Saving has been confirmed working on AE.

## ✨ 新增功能 / New Features

- **武器附赠弹药**：MCM滑块0–1000，步长100；0关闭。
- **弹药每组数量**：MCM左右切档1 / 10 / 50 / 100 / 500 / 1000，默认100。
- 两项支持INI自定义；修改MCM设置会覆盖INI自定义值，下次打开菜单生效。
- 搜索输入状态更明显；Tab、Enter退出输入并保留搜索内容。

- **Weapon bonus ammo**: MCM slider from 0–1000, step 100; 0 disables it.
- **Ammo per group**: MCM stepper with 1 / 10 / 50 / 100 / 500 / 1000, default 100.
- Both support custom INI values; changing their MCM settings overrides custom values and takes effect next time the menu opens.
- Clearer search input feedback; Tab and Enter finish input without clearing the query.
