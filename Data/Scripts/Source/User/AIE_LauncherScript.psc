Scriptname AIE_LauncherScript extends ActiveMagicEffect

Form Property ControllerItem Auto

Event OnEffectStart(Actor akTarget, Actor akCaster)
    If UI.IsMenuOpen("PipboyMenu")
        UI.CloseMenu("PipboyMenu")
    EndIf
    ; The native launcher path waits for Pip-Boy and its close animation to finish.
    AozoraItemExtractorNative.OpenFromLauncher()

    AozoraItemExtractorNative.RequestLauncherSync()
EndEvent
