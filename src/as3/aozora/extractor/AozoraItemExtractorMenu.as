package aozora.extractor
{
    import flash.display.MovieClip;
    import flash.events.Event;

    public class AozoraItemExtractorMenu extends MovieClip
    {
        public var BGSCodeObj:Object;
        public var Menu_mc:AozoraItemExtractorPanel;

        public function AozoraItemExtractorMenu()
        {
            super();
            BGSCodeObj = new Object();
            Menu_mc = new AozoraItemExtractorPanel();
            Menu_mc.name = "Menu_mc";
            Menu_mc.BGSCodeObj = BGSCodeObj;
            BGSCodeObj.ProcessUserEvent = Menu_mc.ProcessUserEvent;
            addChild(Menu_mc);
            addEventListener(Event.ENTER_FRAME, initializeMenu);
        }

        public function onF4SEObjCreated(codeObject:Object):void
        {
            if (Menu_mc) Menu_mc.OnF4SEObjCreated(codeObject);
        }

        private function initializeMenu(event:Event):void
        {
            removeEventListener(Event.ENTER_FRAME, initializeMenu);
            Menu_mc.InitializeAfterNativeBinding();
        }
    }
}
