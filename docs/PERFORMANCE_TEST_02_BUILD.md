# Test 02 构建记录

2026-10-18，Windows x64，项目版本1.0.6，独立Performance Test 02包。

- 修改前与2026-10-18审查包01_Aozora_Current的Native/AS3/Papyrus/Lua源码逐字节对比一致。
- Native：在src/native执行 `xmake f -m releasedbg --preview_spike=n -y`，然后 `xmake -j2`，最终编译/链接成功。
- AS3：`tools/build-swf.ps1 -FlexSdk ./vendor/flex-sdk`，最终173821字节，SHA256为 E2FAB46221FA7AFA7D7247F88E4EDE76395DA0B64F9164D2567FC65A59AB4E4F。
- 没有修改Papyrus、ESP记录、纹理或美术资源，保留已有运行文件。
- 打包要求DLL带performance-test-02-20261018，且不含PreviewSpike07或AIE-EXAMINE-OBS01标记；仍使用已有正式打包器的PreviewSpike保护。
- 不覆盖package/formal，不上传GitHub，不创建新正式版本。
- 进行的是编译、源码审计和包内文件核对；没有运行Fallout4，没有新跑自动化功能测试，没有宣称性能、OG/NG/AE、中文输入或保存/读档验收通过。

完整修改、字段说明、回归矩阵及停止/Test03决策见PERFORMANCE_TEST_02.md。
