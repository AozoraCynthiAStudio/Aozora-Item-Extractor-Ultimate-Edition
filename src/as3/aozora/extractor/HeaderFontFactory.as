package aozora.extractor
{
    import flash.text.Font;
    public final class HeaderFontFactory
    {
        [Embed(source="../../../../assets/fonts/BarlowCondensed-Bold.ttf", fontName="AIEBrand", fontWeight="bold", unicodeRange="U+0020-U+024F,U+2026", embedAsCFF="false")]
        private static const BrandFont:Class;
        [Embed(source="../../../../assets/fonts/BarlowCondensed-SemiBold.ttf", fontName="AIETitle", fontWeight="normal", unicodeRange="U+0020-U+024F,U+2026", embedAsCFF="false")]
        private static const TitleFont:Class;
        [Embed(source="../../../../assets/fonts/BarlowCondensed-Medium.ttf", fontName="AIEContext", fontWeight="normal", unicodeRange="U+0020-U+024F,U+2026", embedAsCFF="false")]
        private static const ContextFont:Class;
        private static var registered:Boolean = false;
        public static function initialize():void
        {
            if (registered) return;
            Font.registerFont(BrandFont); Font.registerFont(TitleFont); Font.registerFont(ContextFont);
            registered = true;
        }
        public static function supports(family:String, value:String):Boolean
        {
            var font:Font = family == "AIEBrand" ? new BrandFont() as Font :
                (family == "AIETitle" ? new TitleFont() as Font : new ContextFont() as Font);
            return font != null && font.hasGlyphs(value);
        }
    }
}
