Scriptname AIE_ControllerQuestScript extends Quest

Form Property ControllerItem Auto

Event OnInit()
    Actor akPlayer = Game.GetPlayer()
    If akPlayer != None && ControllerItem != None && akPlayer.GetItemCount(ControllerItem) <= 0
        akPlayer.AddItem(ControllerItem, 1, True)
    EndIf
EndEvent
