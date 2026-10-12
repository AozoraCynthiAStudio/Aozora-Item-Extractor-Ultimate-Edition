# OG / AE 保存闪退调查（2026-10-12）

## 当前证据

- OG crash：Fallout4.exe+0CEB1DC，BGSSaveLoadInitialData::SaveInitialData，rax=0，读取+0x14。
- AE overwrite/AIE_PreviewSpike.log 在本次测试时间写入临时引用创建与释放记录。
- 本地正式包v1.0.2 DLL没有PreviewSpike07；正式包v1.0.3、设置测试包及最初诊断DLL带有该标记。
- src/native/.xmake 的 preview_spike=true 被后续构建沿用。仅 set_default(false) 不会清掉旧配置。
- 实验进入提取页面即通过 IFormFactory 创建临时 TESObjectREFR，关闭后 SetWantsDelete，不保证该引用的保存生命周期安全。

## 修正

- 重新配置 --preview_spike=n，重新构建DLL；检查不含PreviewSpike07/临时引用创建标记。
- Build_Release.ps1 显式禁用；package_release.py 检测实验DLL并拒绝打包。
- 保留提取/关闭/保存诊断日志，同时输出Data路径和F4SE标准Documents日志，记录runtime及禁用标记。

## 验收边界

已确认构建串入实验代码的问题；它与本次存档崩溃吻合，但修正后是否完全解决仍等待OG/AE游戏测试。
不得把本次编译或二进制标记检查写成游戏内保存验证通过。
已发布v1.0.3包尚未在GitHub替换；需要先验证修正包，再安排正式修复发布。
