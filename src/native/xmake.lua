set_xmakever("3.0.0")

set_project("AozoraItemExtractor")
set_version("1.0.5")
set_arch("x64")
set_languages("c++23")
set_warnings("allextra")
set_encodings("utf-8")

option("preview_spike")
    set_default(false)
    set_showmenu(true)
option_end()

local commonlibRoot = os.getenv("COMMONLIBF4_ROOT")
if commonlibRoot == nil or commonlibRoot == "" then
    commonlibRoot = "Y:/Games/MODCreation/Workspace/commonlibf4-frakkin64"
end
includes(commonlibRoot)

target("AozoraItemExtractor", function()
    add_rules("commonlibf4.plugin", {
        name = "AozoraItemExtractor",
        author = "Aozora",
        plugin_template = "commonlibf4-plugin.cpp.in"
    })

    add_files("src/**.cpp")
    add_includedirs("src")
    if has_config("preview_spike") then
        add_defines("AIE_PREVIEW_SPIKE")
    end
end)

