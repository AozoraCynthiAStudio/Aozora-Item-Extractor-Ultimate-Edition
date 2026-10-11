package aozora.extractor
{
    import flash.display.Sprite;
    import flash.geom.ColorTransform;

    // User-supplied vectors supplement the existing Favorites fallback set.
    public final class ExtractorIconFactory
    {
        [Embed(source="../../../../assets/extractor-icons/ESP.svg")]
        private static const StandardPlugin:Class;
        [Embed(source="../../../../assets/extractor-icons/esl.svg")]
        private static const LightPlugin:Class;
        [Embed(source="../../../../assets/extractor-icons/Ammo.svg")]
        private static const Ammo:Class;
        [Embed(source="../../../../assets/extractor-icons/Materials.svg")]
        private static const Materials:Class;
        [Embed(source="../../../../assets/extractor-icons/Miscellaneous.svg")]
        private static const Miscellaneous:Class;

        public static function create(category:String, kind:String = ""):Sprite
        {
            var asset:Class;
            if (category == "plugin") asset = kind.toUpperCase() == "ESL" ? LightPlugin : StandardPlugin;
            else if (category == "ammo") asset = Ammo;
            else if (category == "junk") asset = Materials;
            else asset = Miscellaneous;
            var icon:Sprite = new asset() as Sprite;
            icon.mouseEnabled = false;
            icon.mouseChildren = false;

            return icon;
        }
    }
}
