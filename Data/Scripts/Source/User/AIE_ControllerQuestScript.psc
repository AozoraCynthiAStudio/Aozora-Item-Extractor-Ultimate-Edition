Scriptname AIE_ControllerQuestScript extends Quest

Form Property ControllerItem Auto

Event OnInit()
    AozoraItemExtractorNative.RequestLauncherSync()
EndEvent
