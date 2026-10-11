# 构建与打包

- Native: 在 src/native 执行 xmake f -m releasedbg -y，再执行 xmake -j2。COMMONLIBF4_ROOT 指向 CommonLibF4，要求 xmake 3.0+、VS C++ 工具链。
- SWF: tools/build-swf.ps1 -FlexSdk <Apache Flex SDK>，Flash 11.2 / SWF 15。
- Papyrus: tools/Compile_Papyrus.ps1，AIE_CAPRICA_ROOT 指向 Caprica 和 FO4 源码。
- 运行文件放在 Data，MCM 原始配置放在 mcm/MCM；打包时同步到 Data/MCM。
- 正式包由 tools/package_release.py 直接从当前文件生成，不依赖任何历史 ZIP。Python 3 标准库即可。
- tools/Build_Release.ps1 完成构建和打包，可显式指定 Python、FlexSdk。
- 原始透明 PNG 在 assets/mascots，texconv 转换 BC3 单 mip 1024x1536；AS3 恢复坐姿素材1122x1402比例。
- 版本见 VERSION.txt。修改功能后更新源码和运行文件，再打包。
