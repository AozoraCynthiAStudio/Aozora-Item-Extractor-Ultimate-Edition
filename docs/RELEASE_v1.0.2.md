# 首个可用版本 / First usable release

Aozora Item Extractor Ultimate Edition 的首个可用发布版本。采用 Aozora 风格界面，支持键鼠和手柄，并整合社区同类工具中实用的功能思路。

## 中文

- 已加载插件浏览与插件名/物品名搜索，进入搜索结果后定位匹配物品。
- 双栏提取与归还，支持按组、指定数量批量、全部提取及全部归还。
- 默认弹药每组 100 发，其余类别每组 1 个，可在 INI 配置；批量弹窗选择的是实际数量。
- 有基础弹药的武器，每次提取操作附送固定 1000 发；赠送弹药不会随武器归还自动收回。
- HUD / 内置配色、随机角色和提示气泡、可关闭角色的单页 MCM。
- 手柄分类切换 LT/RT，背包启动物品支持无 MCM 打开菜单。
- 新增弹药按组领取提示，数字读取当前配置。
- 完整简体中文补丁；中文 MCM 名称“青空物品提取器终极版”，主菜单品牌标题保留英文。

全部提取作用于当前插件全部物品；全部归还作用于本次菜单会话全部可归还物品，均不局限于当前分类。关闭菜单结束归还会话。

## English

- Loaded plugin browsing and plugin/item search with matching-item navigation.
- Two-pane extraction/return, configurable group counts, selected batch quantities, Take All and Return All.
- Ammo defaults to 100 rounds per group; other categories default to 1. Batch quantities are actual counts, not group multipliers.
- Weapons with base ammo grant a fixed 1000-round stack per extraction action; returning the gun does not reclaim bonus ammo.
- HUD/preset palettes, randomized mascots and tips, and a single-page optional MCM with a mascot toggle.
- LT/RT category controls, inventory Aid launcher, and a new configurable ammo-group hint.
- Separate full Simplified Chinese overlay patch; branding/header stays English.

Take All covers the current plugin, while Return All covers returnable items from the whole current menu session. Neither is limited by the active category. Closing the menu ends the return session.

## 下载 / Downloads

- **EN**: English core / 英文主体。
- **CHS Patch**: Install after EN; replaces older Chinese patches / 安装在主体后，替换旧汉化补丁。
- **Source**: Source, artwork and build tools / 源码、素材和构建工具。
- **SHA256SUMS**: File hashes / 校验清单。

Requires matching F4SE and Address Library. MCM optional. Chinese fonts required for CHS. Prior baseline user-tested; LT/RT and the new ammo-group hint are compiled but await in-game confirmation.
