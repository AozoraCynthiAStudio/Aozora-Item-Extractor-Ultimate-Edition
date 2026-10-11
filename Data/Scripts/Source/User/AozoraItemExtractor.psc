Scriptname AozoraItemExtractor Hidden

Function OnMcmMenuHotkey() Global
    If AozoraItemExtractorNative.IsMenuOpen()
        AozoraItemExtractorNative.CloseMenu()
    Else
        AozoraItemExtractorNative.OpenMenu()
    EndIf
EndFunction
