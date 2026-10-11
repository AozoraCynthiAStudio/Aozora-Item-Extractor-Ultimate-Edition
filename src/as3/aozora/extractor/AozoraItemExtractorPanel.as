package aozora.extractor
{
    import flash.display.DisplayObject;
    import flash.display.Bitmap;
    import flash.display.Graphics;
    import flash.display.MovieClip;
    import flash.display.Shape;
    import flash.display.Sprite;
    import flash.events.Event;
    import flash.events.FocusEvent;
    import flash.events.MouseEvent;
    import flash.events.IOErrorEvent;
    import flash.geom.Point;
    import flash.geom.Rectangle;
    import flash.geom.ColorTransform;
    import flash.filters.DropShadowFilter;
    import flash.net.URLRequest;
    import flash.system.ApplicationDomain;
    import flash.text.TextField;
    import flash.text.TextFieldAutoSize;
    import flash.text.TextFormat;
    import flash.display.Loader;
    import flash.display.LoaderInfo;
    import flash.utils.Dictionary;
    import flash.utils.Timer;
    import flash.events.TimerEvent;
    import flash.utils.getTimer;

    public class AozoraItemExtractorPanel extends MovieClip
    {
        private static const TEXT:Object = {
            title: "$AIE_TITLE",
            titleBrand: "$AIE_TITLE_BRAND",
            titleFunction: "$AIE_TITLE_FUNCTION",
            currentPlugin: "$AIE_CURRENT_PLUGIN",
            extracted: "$AIE_EXTRACTED",
            modItems: "$AIE_MOD_ITEMS",
            select: "$AIE_SELECT",
            filter: "$AIE_FILTER",
            search: "$AIE_SEARCH",
            enter: "$AIE_ENTER",
            close: "$AIE_BACK",
            pane: "$AIE_PANE",
            category: "$AIE_CATEGORY",
            take: "$AIE_TAKE",
            returnItem: "$AIE_RETURN",
            batch: "$AIE_BATCH",
            allItems: "$AIE_ALL",
            takeAll: "$AIE_TAKE_ALL",
            returnAll: "$AIE_RETURN_ALL",
            weapon: "$AIE_WEAPONS",
            armor: "$AIE_ARMOR",
            aid: "$AIE_AID",
            ammo: "$AIE_AMMO",
            junk: "$AIE_JUNK",
            misc: "$AIE_MISC",
            searchPlaceholder: "$AIE_SEARCH_PLACEHOLDER",
            noPlugins: "$AIE_NO_PLUGINS",
            noSessionItems: "$AIE_NO_EXTRACTED_ITEMS",
            noModItems: "$AIE_NO_MOD_ITEMS",
            batchReturn: "$AIE_BATCH_RETURN",
            batchTake: "$AIE_BATCH_EXTRACT",
            modalGamepad: "$AIE_MODAL_GAMEPAD",
            modalKeyboard: "$AIE_MODAL_KEYBOARD"
        };

        public var BGSCodeObj:Object;

        private static const STAGE_W:Number = 1280;
        private static const STAGE_H:Number = 720;
        private static const NAV_PANEL_WIDTH:Number = 448;
        private static const NAV_PANEL_HEIGHT:Number = 660;
        private static const NAV_CONTENT_INSET:Number = 16;
        private static const NAV_LIST_TOP:Number = 144;
        private static const NAV_LIST_HEIGHT:Number = 442;
        private static const NAV_VISIBLE_ROWS:int = 14;
        private static const PLUGIN_ROW_HEIGHT:Number = 31;
        private static const PANEL_ALPHA:Number = 0.99;
        private static const LIST_ALPHA:Number = 0.93;
        private static const PRIMARY_ROW_TEXT:uint = 0xE8EEF0;
        private static const SELECTED_ROW_TEXT:uint = 0xF1F4F5;
        private static const UNAVAILABLE_ROW_TEXT:uint = 0xB8C1C4;
        private static const UNAVAILABLE_COUNT_TEXT:uint = 0xAEB7BB;
        private static const EXTRACT_PANEL_WIDTH:Number = 856;
        private static const EXTRACT_PANEL_HEIGHT:Number = 660;
        private static const EXTRACT_CONTENT_INSET:Number = 16;
        private static const EXTRACT_GUTTER:Number = 18;
        private static const EXTRACT_COLUMNS_TOP:Number = 112;
        private static const EXTRACT_COLUMNS_HEIGHT:Number = 500;
        private static const EXTRACT_LIST_TOP:Number = 30;
        private static const EXTRACT_LIST_HEIGHT_INSET:Number = 34;
        private static const MENU_SURFACE_ALPHA:Number = 0.76;
        private static const SECONDARY_ALPHA:Number = 0.88;
        private static const INACTIVE_NAV_ALPHA:Number = 0.84;
        private static const DISABLED_ALPHA:Number = 0.58;
        private static const ITEM_ROW_HEIGHT:Number = 31;
        private static const ICON_SLOT_SIZE:Number = 20;
        private static const FOCUS_RAIL_WIDTH:Number = 3;
        private static const NAV_FILTERS:Array = ["ALL", "ESP", "ESL"];
        private static const NAV_FILTER_LABELS:Object = { ALL: TEXT.allItems };
        private static const ITEM_CATEGORIES:Array = ["all", "weapon", "armor", "aid", "ammo", "junk", "misc"];
        private static const CATEGORY_LABELS:Object = {
            all: TEXT.allItems, weapon: TEXT.weapon, armor: TEXT.armor, aid: TEXT.aid,
            ammo: TEXT.ammo, junk: TEXT.junk, misc: TEXT.misc
        };

        // Favorites-derived visual layers; all hit coordinates remain in stage space.
        private var backgroundLayer:Sprite;
        private var silhouetteLayer:Sprite;
        private var contentLayer:Sprite;
        private var themeLayer:Sprite;
        private var rowLayer:Sprite;
        private var mascotLayer:Sprite;
        private var scanlineLayer:Sprite;
        private var modalLayer:Sprite;
        private var visualTarget:Sprite;
        // User-supplied classic character watermarks; reuse the existing noninteractive hook.
        private var imageBridge:Object;
        private var externalImages:Object = {};
        private var mascotLoaders:Array = [];
        private var mascotDisplays:Object = {};
        private var watermarkLoaders:Array = [];
        private var decorationLoader:Loader;
        private var decorationRequested:Boolean = false;
        private var decorationInitialized:Boolean = false;
        private var mascotKey:String = "";
        private var mascotPage:String = "";
        private static var lastPeekIndex:int = -1;
        private static var lastCornerIndex:int = -1;
        private var mascotTip:Sprite;
        private var mascotEnabled:Boolean = true;
        private var mascotArtwork:DisplayObject;
        private var headerMarkHolder:Sprite;
        private var headerTitleField:TextField;
        private var defaultRightArtwork:DisplayObject;
        private var defaultNavArtwork:DisplayObject;
        private var defaultExtractArtwork:DisplayObject;
        private var useDefaultArtwork:Boolean = true;
        private var decorativeArtwork:DisplayObject;
        private var theme:Object = { r: 0.22, g: 0.84, b: 0.91 };

        private var plugins:Array = [];
        private var items:Array = [];
        private var session:Array = [];
        private var pluginFilter:String = "ALL";
        private var pluginIndex:int = 0;
        private var query:String = "";
        private var pluginSearchTimer:Timer = new Timer(120, 1);
        private var pluginSearchQuery:String = "";
        private var pluginSearchResults:Array;
        private var pendingItemFocus:Boolean = false;
        private var pendingFocusPlugin:String = "";
        private var searchTopIndex:int = -1;
        private var searchMouseGuard:Boolean = false;
        private var searchFocused:Boolean = false;
        private var searchActivationTime:int = -1;
        private var activePlugin:String = "";
        private var page:String = "nav";
        private var inputMode:String = "keyboard";
        private var itemCategory:String = "all";
        private var pane:String = "right";
        private var leftIndex:int = 0;
        private var rightIndex:int = 0;
        private var pluginScrollStart:int = 0;
        private var leftScrollStart:int = 0;
        private var rightScrollStart:int = 0;
        private var focusSource:int = 0;
        private var mouseMovedSinceInput:Boolean = false;
        private var hasMousePosition:Boolean = false;
        private var lastMouseStageX:Number = 0;
        private var lastMouseStageY:Number = 0;
        private var hoverTabName:String = "";
        private var modalOpen:Boolean = false;
        private var modalValues:Array = [];
        private var modalIndex:int = 0;
        private var modalFormID:uint = 0;
        private var modalTake:Boolean = true;
        private var accent:uint = 0x39D7E8;
        private var focusColor:uint = 0xFFC857;
        private var panelBackground:uint = 0x071012;
        private var panelBorder:uint = 0x465158;
        private var secondaryText:uint = 0xD4DDDF;
        private var mutedText:uint = 0xCBD5D8;
        private var searchChrome:Sprite;
        private var searchArea:Rectangle;
        private var searchHovered:Boolean = false;
        private var searchField:TextField;
        private var searchCaretIndex:int = 0;
        private var rendering:Boolean = false;
        private var pluginCounter:TextField;
        private var footerPrimaryAction:TextField;
        private var footerBatchAction:TextField;
        private var footerAllAction:TextField;
        private var iconLibraryDomains:Object = {};
        private var iconLibraryLoaders:Object = {};
        private var iconLibraryFailures:Object = {};
        private var componentMetrics:Dictionary = new Dictionary(true);
        private var tabConfigs:Dictionary = new Dictionary(true);
        private var tabNodes:Array = [];
        private var modalOptionRows:Array = [];
        private var pluginRowsLayer:Sprite;
        private var leftRowsLayer:Sprite;
        private var rightRowsLayer:Sprite;
        private var selectedPluginRow:Sprite;
        private var focusedItemRow:Sprite;
        private var columnBounds:Object = {};
        private var columnFrames:Object = {};
        private var columnHeaders:Object = {};
        private var columnTitles:Object = {};
        private var columnCounts:Object = {};

        public function AozoraItemExtractorPanel()
        {
            super();
            HeaderFontFactory.initialize();
            pluginSearchTimer.addEventListener(TimerEvent.TIMER_COMPLETE, dispatchPluginSearch);
            addEventListener(Event.ADDED_TO_STAGE, onMascotAdded);
            addEventListener(Event.REMOVED_FROM_STAGE, onMascotRemoved);
            decorativeArtwork = null;
            panelBackground = blend(accent, 0x071012, 0.055);
            mouseEnabled = true;
            mouseChildren = true;
            addEventListener(MouseEvent.MOUSE_MOVE, onMouseMove, true);
            addEventListener(MouseEvent.MOUSE_OUT, onMouseOut, true);
            addEventListener(MouseEvent.MOUSE_WHEEL, onMouseWheel, true);
            addEventListener(MouseEvent.MOUSE_DOWN, onSearchOutsideClick, true);
        }

        public function InitializeAfterNativeBinding():void
        {
            if (BGSCodeObj && BGSCodeObj.Initialize is Function)
                BGSCodeObj.Initialize();
            decorationInitialized = true;
            scheduleDecorationLoad();
        }

        public function ApplySnapshot(snapshot:Object):void
        {
            if (!snapshot) return;
            var wasExtractPage:Boolean = page == "extract";
            if (snapshot.mascotEnabled != null) mascotEnabled = Boolean(snapshot.mascotEnabled);
            if (snapshot.plugins is Array) plugins = snapshot.plugins as Array;
            if (snapshot.items is Array) items = snapshot.items as Array;
            if (snapshot.session is Array) session = snapshot.session as Array;
            if (snapshot.inputMode != null) inputMode = snapshot.inputMode == "gamepad" ? "gamepad" : "keyboard";
            if (snapshot.plugin != null) activePlugin = String(snapshot.plugin);
            if (snapshot.page != null) page = String(snapshot.page);
            if (snapshot.pluginFilter != null) pluginFilter = String(snapshot.pluginFilter);
            if (snapshot.pluginIndex != null) pluginIndex = int(snapshot.pluginIndex);
            if (snapshot.pane != null) pane = String(snapshot.pane);
            if (snapshot.itemCategory != null) {
                itemCategory = normalizeCategory(String(snapshot.itemCategory));
            } else if (!wasExtractPage && page == "extract" &&
                (snapshot.leftCategory != null || snapshot.rightCategory != null)) {
                // Read legacy snapshots without keeping separate per-pane filters.
                var legacyCategory:String = pane == "left" ?
                    String(snapshot.leftCategory != null ? snapshot.leftCategory : "all") :
                    String(snapshot.rightCategory != null ? snapshot.rightCategory : "all");
                itemCategory = normalizeCategory(legacyCategory);
            }
            if (snapshot.leftIndex != null) leftIndex = int(snapshot.leftIndex);
            if (snapshot.rightIndex != null) rightIndex = int(snapshot.rightIndex);
            if (snapshot.theme) updateTheme(snapshot.theme);
            if (pendingItemFocus && page == "extract" && snapshot.items is Array && activePlugin == pendingFocusPlugin) {
                pendingItemFocus = false;
                pane = "right"; itemCategory = "all";
                var focusTokens:Array = searchTokens(query);
                for (var searchIndex:int = 0; searchIndex < items.length; ++searchIndex) {
                    if (matchesSearch(String(items[searchIndex].name || ""), focusTokens)) {
                        rightIndex = searchIndex;
                        // Keep the discovered item in the first row, even near the tail.
                        searchTopIndex = rightIndex;
                        rightScrollStart = rightIndex;
                        searchMouseGuard = true;
                        mouseMovedSinceInput = false;
                        focusSource = 1;
                        break;
                    }
                }
            }
            render();
            captureMouseBaseline();
        }

        public function UpdateSession(value:Array):void
        {
            session = value ? value : [];
            render();
        }

        public function SetInputMode(value:String):void
        {
            inputMode = value == "gamepad" ? "gamepad" : "keyboard";
            render();
        }

        public function SetHidden(value:Boolean):void
        {
            if (visible && value) mascotPage = "";
            visible = !value;
            if (!value && mascotLayer) renderMascot();
        }

        public function HandleKey(key:String, source:int = 1):void
        {
            focusSource = source == 2 ? 2 : 1;
            mouseMovedSinceInput = false;
            if (hoverTabName.length > 0) {
                hoverTabName = "";
                updateTabAppearance();
            }
            captureMouseBaseline();
            key = String(key).toLowerCase();
            if (modalOpen) {
                if (key == "left" || key == "a") moveModal(-1);
                else if (key == "right" || key == "d") moveModal(1);
                else if (key == "confirm") confirmBatch();
                else if (key == "back") closeBatch();
                return;
            }
            if (searchFocused && page == "nav" && (key == "tab" || key == "back")) {
                setSearchFocus(false);
                return;
            }
            if (searchFocused && page == "nav") return;
            if (key == "up" || key == "w") moveSelection(-1);
            else if (key == "down" || key == "s") moveSelection(1);
            else if (key == "left" || key == "a" || key == "category-left") moveHorizontal(-1);
            else if (key == "right" || key == "d" || key == "category-right") moveHorizontal(1);
            else if (key == "category-prev") moveCategory(-1);
            else if (key == "category-next") moveCategory(1);
            else if (key == "search") {
                if (page == "nav") {
                    // The activation button and its CharacterEvent arrive separately.
                    searchActivationTime = source == 1 ? getTimer() : -1;
                    setSearchFocus(true);
                } else openBatch();
            }
            else if (key == "confirm") activate();
            else if (key == "batch") openBatch();
            else if (key == "take-all") takeAll();
            else if (key == "back") back();
        }

        public function ProcessUserEvent(code:String, value:Number):Boolean
        {
            // Native search routing owns editing. Vanilla mapped actions (including
            // Backspace cancel and WASD navigation) must not also reach the menu.
            if (searchFocused && page == "nav") return true;
            var eventName:String = String(code).toLowerCase();
            if (eventName.indexOf("up") >= 0) HandleKey("up");
            else if (eventName.indexOf("down") >= 0) HandleKey("down");
            else if (eventName.indexOf("left") >= 0) HandleKey("left");
            else if (eventName.indexOf("right") >= 0) HandleKey("right");
            else if (eventName.indexOf("accept") >= 0 || eventName.indexOf("activate") >= 0) HandleKey("confirm");
            else if (eventName.indexOf("cancel") >= 0) HandleKey("back");
            else return false;
            return true;
        }

        private function updateTheme(value:Object):void
        {
            theme = value;
            accent = themeColor(1.0);
            updateFocusColor();
            panelBackground = blend(accent, 0x071012, 0.055);
            panelBorder = themeColor(0.55);
        }

        // Ported/adapted from Aozora Favorites SkyuiLikeMenuPanel.
        private function themeComponent(key:String):Number
        {
            return theme && theme[key] is Number ? Math.max(0, Math.min(1, Number(theme[key]))) : 0.5;
        }

        // Ported/adapted from Aozora Favorites SkyuiLikeMenuPanel.
        private function themeColor(scale:Number):uint
        {
            var r:int = Math.max(0, Math.min(255, int(themeComponent("r") * 255 * scale)));
            var g:int = Math.max(0, Math.min(255, int(themeComponent("g") * 255 * scale)));
            var b:int = Math.max(0, Math.min(255, int(themeComponent("b") * 255 * scale)));
            return uint((r << 16) | (g << 8) | b);
        }

        // Ported/adapted from Aozora Favorites SkyuiLikeMenuPanel.
        private function updateFocusColor():void
        {
            var tr:Number = themeComponent("r");
            var tg:Number = themeComponent("g");
            var tb:Number = themeComponent("b");
            var yellowHud:Boolean = tr > 0.55 && tg > 0.42 && tb < 0.42 && tr >= tg * 0.78;
            var candidates:Array = [0xFFC857, 0x65E7FF, 0xD5A5FF, 0xFFFFFF];
            var best:uint = 0xFFC857;
            var bestScore:Number = -1000.0;
            for each (var candidate:uint in candidates) {
                var cr:Number = ((candidate >> 16) & 0xFF) / 255.0;
                var cg:Number = ((candidate >> 8) & 0xFF) / 255.0;
                var cb:Number = (candidate & 0xFF) / 255.0;
                var distance:Number = Math.sqrt(
                    (cr - tr) * (cr - tr) + (cg - tg) * (cg - tg) + (cb - tb) * (cb - tb));
                var themeLum:Number = 0.299 * tr + 0.587 * tg + 0.114 * tb;
                var candidateLum:Number = 0.299 * cr + 0.587 * cg + 0.114 * cb;
                var score:Number = distance * 0.72 + Math.abs(candidateLum - themeLum) * 0.28;
                if (yellowHud && candidate == 0xFFC857)
                    score -= 1.0;
                if (score > bestScore) {
                    bestScore = score;
                    best = candidate;
                }
            }
            focusColor = best;

        }

        private function colorDistance(a:uint, b:uint):Number
        {
            var r:Number = ((a >> 16) & 255) - ((b >> 16) & 255);
            var g:Number = ((a >> 8) & 255) - ((b >> 8) & 255);
            var b2:Number = (a & 255) - (b & 255);
            return Math.sqrt(r * r + g * g + b2 * b2);
        }

        private function blend(a:uint, b:uint, amount:Number):uint
        {
            var r:int = int(((a >> 16) & 255) * amount + ((b >> 16) & 255) * (1 - amount));
            var g:int = int(((a >> 8) & 255) * amount + ((b >> 8) & 255) * (1 - amount));
            var blue:int = int((a & 255) * amount + (b & 255) * (1 - amount));
            return (r << 16) | (g << 8) | blue;
        }

        private function render():void
        {
            rendering = true;
            clearChildren();
            createVisualLayers();
            componentMetrics = new Dictionary(true);
            tabConfigs = new Dictionary(true);
            tabNodes = [];
            modalOptionRows = [];
            pluginRowsLayer = null;
            leftRowsLayer = null;
            rightRowsLayer = null;
            selectedPluginRow = null;
            focusedItemRow = null;
            columnBounds = {};
            columnFrames = {};
            columnHeaders = {};
            columnTitles = {};
            columnCounts = {};
            searchField = null;
            pluginCounter = null;
            footerPrimaryAction = null; footerBatchAction = null; footerAllAction = null;
            if (page == "extract") renderExtractPage();
            else renderNavPage();
            renderMascot();
            if (modalOpen) {
                visualTarget = modalLayer;
                renderBatchModal();
                visualTarget = themeLayer;
            }
            rendering = false;
            if (searchFocused && searchField && stage) {
                stage.focus = null;
                searchCaretIndex = Math.max(0, Math.min(searchCaretIndex, searchField.text.length));
                searchField.setSelection(searchCaretIndex, searchCaretIndex);
            }
        }

        private function clearChildren():void
        {
            // Keep the loaded bitmap hierarchy on stage across snapshot redraws.
            for (var i:int = numChildren - 1; i >= 0; --i) {
                if (getChildAt(i) != mascotLayer) removeChildAt(i);
            }
        }

        private function renderNavPage():void
        {
            var width:Number = NAV_PANEL_WIDTH;
            var height:Number = NAV_PANEL_HEIGHT;
            var x:Number = (STAGE_W - width) / 2;
            var y:Number = (STAGE_H - height) / 2;
            var contentX:Number = x + NAV_CONTENT_INSET;
            var contentW:Number = width - NAV_CONTENT_INSET * 2;
            drawNavPanel(x, y, width, height);
            drawNavHeader(contentX, y + 12, contentW, TEXT.title);

            drawTabs(contentX, y + 66, contentW, NAV_FILTERS, pluginFilter, false, "", true);
            drawSearch(contentX, y + 104, contentW);

            var listX:Number = contentX;
            var listY:Number = y + NAV_LIST_TOP;
            var listW:Number = contentW;
            var listH:Number = NAV_LIST_HEIGHT;
            prepareWatermarkSlot(listX + listW * 0.68, listY + listH * 0.74);
            var shown:Array = visiblePlugins();
            pluginIndex = clampIndex(pluginIndex, shown.length);
            pluginScrollStart = ensureIndexVisible(pluginScrollStart, pluginIndex, shown.length, NAV_VISIBLE_ROWS);
            pluginRowsLayer = new Sprite();
            pluginRowsLayer.name = "pluginRowsLayer";
            rowLayer.addChild(pluginRowsLayer);
            drawRows(shown, pluginIndex, listX + 1, listY + 1, listW - 10, PLUGIN_ROW_HEIGHT,
                NAV_VISIBLE_ROWS, pluginScrollStart, "plugins", pluginRowsLayer, listX + listW - 5);
            pluginCounter = drawText(contentX + 2, y + 589, shown.length ? (pluginIndex + 1) + " / " + shown.length : "0 / 0", 12, secondaryText, SECONDARY_ALPHA);
            drawNavFooter(contentX, y + height - 44, contentW);
        }

        private function renderExtractPage():void
        {
            var bounds:Object = extractionBounds();
            var y:Number = Number(bounds.y);
            drawExtractBackdrop(Number(bounds.x), y, EXTRACT_PANEL_WIDTH, EXTRACT_PANEL_HEIGHT);
            drawNavHeader(Number(bounds.contentX), y + 12, Number(bounds.innerW), TEXT.title);
            var context:TextField = drawHeaderText(Number(bounds.contentX) + 352, y + 17,
                Number(bounds.innerW) - 474, activePlugin, 17, 0xDCE4E6, "AIEContext", false, 0.2);
            // Both fonts use their actual line ascent, rather than matching field tops.
            try {
                context.y = headerTitleField.y + headerTitleField.getLineMetrics(0).ascent - context.getLineMetrics(0).ascent;
            } catch (metricError:Error) { context.y = headerTitleField.y + 4; }
            drawTabs(Number(bounds.contentX), y + 78, Number(bounds.innerW), ITEM_CATEGORIES,
                itemCategory, true, "global", true);

            var top:Number = Number(bounds.columnY);
            var listH:Number = EXTRACT_COLUMNS_HEIGHT;
            var shownLeft:Array = visibleSessionItems(itemCategory);
            var shownRight:Array = visibleItems(items, itemCategory);
            leftIndex = clampIndex(leftIndex, shownLeft.length);
            rightIndex = clampIndex(rightIndex, shownRight.length);
            var leftMaxRows:int = itemVisibleRows(listH);
            var rightMaxRows:int = leftMaxRows;
            leftScrollStart = ensureIndexVisible(leftScrollStart, leftIndex, shownLeft.length, leftMaxRows);
            if (searchTopIndex >= 0 && itemCategory == "all" && rightIndex == searchTopIndex)
                rightScrollStart = searchTopIndex;
            else rightScrollStart = ensureIndexVisible(rightScrollStart, rightIndex, shownRight.length, rightMaxRows);
            drawColumn(Number(bounds.leftX), top, Number(bounds.leftW), listH, TEXT.extracted, shownLeft, leftIndex,
                leftScrollStart, pane == "left", "left");
            drawColumn(Number(bounds.rightX), top, Number(bounds.rightW), listH, TEXT.modItems, shownRight, rightIndex,
                rightScrollStart, pane == "right", "right");
            drawFooter(Number(bounds.contentX), y + EXTRACT_PANEL_HEIGHT - 44, Number(bounds.innerW), [
                [inputMode == "gamepad" ? "A" : "E", pane == "left" ? TEXT.returnItem : TEXT.take],
                [inputMode == "gamepad" ? "Y" : "Q", pane == "left" ? TEXT.batchReturn : TEXT.batchTake],
                [inputMode == "gamepad" ? "X" : "R", pane == "left" ? TEXT.returnAll : TEXT.takeAll],
                [inputMode == "gamepad" ? "LT/RT" : "Z/C", TEXT.category],
                [inputMode == "gamepad" ? "B" : "TAB", TEXT.close]
            ]);
        }

        private function extractionBounds():Object
        {
            var x:Number = (STAGE_W - EXTRACT_PANEL_WIDTH) / 2;
            var y:Number = (STAGE_H - EXTRACT_PANEL_HEIGHT) / 2;
            var innerW:Number = EXTRACT_PANEL_WIDTH - EXTRACT_CONTENT_INSET * 2;
            var leftW:Number = (innerW - EXTRACT_GUTTER) * 0.47;
            var leftX:Number = x + EXTRACT_CONTENT_INSET;
            return { x: x, y: y, contentX: leftX, innerW: innerW,
                leftX: leftX, leftW: leftW, rightX: leftX + leftW + EXTRACT_GUTTER,
                rightW: innerW - EXTRACT_GUTTER - leftW, columnY: y + EXTRACT_COLUMNS_TOP };
        }

        private function drawExtractBackdrop(x:Number, y:Number, width:Number, height:Number):void
        {
            drawMenuShell(x, y, width, height, EXTRACT_CONTENT_INSET);
        }

        // Ported/adapted from Favorites drawBackground; one shared menu material.
        private function drawMenuShell(x:Number, y:Number, width:Number, height:Number, inset:Number):void
        {
            var shell:Shape = new Shape();
            shell.x = x; shell.y = y;
            // Same 8px corner radius as the Favorites-derived outer rail.
            shell.graphics.beginFill(panelBackground, MENU_SURFACE_ALPHA);
            shell.graphics.drawRoundRect(1, 1, width - 2, height - 2, 16, 16);
            shell.graphics.endFill();
            shell.graphics.lineStyle(1, themeColor(0.45), 0.12);
            shell.graphics.drawRoundRect(4, 4, width - 8, height - 8, 8, 8);
            shell.graphics.lineStyle();
            drawOriginalFrame(shell.graphics, width, height);
            backgroundLayer.addChild(shell);
            scanlineLayer.x = x; scanlineLayer.y = y;
            drawScanlines(width, height);

        }

        private function drawReadingSurface(x:Number, y:Number, width:Number, height:Number, alpha:Number):void
        {
            var surface:Shape = new Shape();
            surface.graphics.beginFill(panelBackground, alpha);
            surface.graphics.drawRect(x, y, width, height);
            surface.graphics.endFill();
            visualTarget.addChild(surface);
        }

        // Adapted from Favorites drawSilhouette; behind rows, low alpha, theme tint.
        private function prepareWatermarkSlot(x:Number, y:Number, kind:String = ""):void
        {
            // A custom single-object hook remains single-object; defaults have independent panes.
            if (!useDefaultArtwork && kind == "right") return;
            var artwork:DisplayObject = decorativeArtwork;
            if (useDefaultArtwork) {
                if (page == "nav") {
                    if (!defaultNavArtwork) defaultNavArtwork = externalBitmap("watermark-nav");
                    artwork = defaultNavArtwork;
                } else if (kind == "right") {
                    if (!defaultRightArtwork) defaultRightArtwork = externalBitmap("watermark-right");
                    artwork = defaultRightArtwork;
                } else {
                    if (!defaultExtractArtwork) defaultExtractArtwork = externalBitmap("watermark-left");
                    artwork = defaultExtractArtwork;
                }
            }
            if (!artwork) return;
            var slot:Sprite = new Sprite(); slot.name = "watermarkSlot_" + kind;
            slot.x = x + (kind == "right" ? 48 : (page == "nav" ? 0 : -12));
            slot.y = y - 50 - (page == "nav" ? 20 : (kind == "right" ? 4 : 68));
            slot.mouseEnabled = false; slot.mouseChildren = false;
            silhouetteLayer.addChild(slot);
            artwork.mask = null;
            artwork.scaleX = artwork.scaleY = 1;
            var area:Rectangle = artwork.getBounds(artwork);
            // Metadata from alpha>=200 bounds: exclude transparent margins without editing PNGs.
            if (useDefaultArtwork) area = page == "nav" ? new Rectangle(517, 335, 491, 1081) :
                (kind == "right" ? new Rectangle(44, 429, 707, 989) : new Rectangle(285, 54, 686, 1341));
            var maximumHeight:Number = kind == "right" ? 285 : (page == "nav" ? 340 : 370);
            var scale:Number = Math.min(260 / Math.max(1, area.width), maximumHeight / Math.max(1, area.height));
            artwork.scaleX = scale * (useDefaultArtwork ? 1086 / 512 : 1);
            artwork.scaleY = scale * (useDefaultArtwork ? 1448 / 512 : 1);
            artwork.x = -(area.x + area.width / 2) * scale;
            artwork.y = -(area.y + area.height / 2) * scale;
            artwork.alpha = 1;
            artwork.transform.colorTransform = new ColorTransform(0, 0, 0, 0.080,
                themeComponent("r") * 255, themeComponent("g") * 255, themeComponent("b") * 255, 0);
            slot.addChild(artwork);

        }

        private function drawPanel(x:Number, y:Number, width:Number, height:Number):void
        {
            var shape:Shape = new Shape();
            shape.graphics.beginFill(panelBackground, PANEL_ALPHA);
            shape.graphics.drawRect(x, y, width, height);
            shape.graphics.endFill();
            shape.graphics.lineStyle(1, panelBorder, 0.74);
            shape.graphics.drawRect(x + 0.6, y + 0.6, width - 1.2, height - 1.2);
            visualTarget.addChild(shape);
        }

        private function drawNavPanel(x:Number, y:Number, width:Number, height:Number):void
        {
            drawMenuShell(x, y, width, height, NAV_CONTENT_INSET);
        }

        // Ported/adapted from Aozora Favorites SkyuiLikeMenuPanel.
        private function drawRoundedHorizontalRails(g:Graphics, width:Number, height:Number,
                radius:Number, inset:Number, thickness:Number, color:uint, alpha:Number):void
        {
            var left:Number = inset;
            var right:Number = width - inset;
            var top:Number = inset;
            var bottom:Number = height - inset;

            g.lineStyle(thickness, color, alpha);
            g.moveTo(left, top + radius);
            g.curveTo(left, top, left + radius, top);
            g.lineTo(right - radius, top);
            g.curveTo(right, top, right, top + radius);

            g.moveTo(left, bottom - radius);
            g.curveTo(left, bottom, left + radius, bottom);
            g.lineTo(right - radius, bottom);
            g.curveTo(right, bottom, right, bottom - radius);
        }

        private function drawNavHeader(x:Number, y:Number, width:Number, title:String):void
        {
            drawHeaderText(x, y + 4, 76, TEXT.titleBrand, 17, themeColor(0.94), "AIEBrand", true, 1.2);
            headerTitleField = drawHeaderText(x + 98, y, width > 600 ? 222 : width - 220,
                TEXT.titleFunction, 23, themeColor(1.0), "AIETitle", false, 0.5);
            var rail:Shape = new Shape();
            rail.graphics.lineStyle(1, themeColor(0.80), 0.48);
            rail.graphics.moveTo(x + 84, y + 4); rail.graphics.lineTo(x + 84, y + 25);
            if (width > 600) { rail.graphics.moveTo(x + 336, y + 4); rail.graphics.lineTo(x + 336, y + 25); }
            rail.graphics.lineStyle(1, themeColor(1.0), 0.58);
            rail.graphics.moveTo(x, y + 41); rail.graphics.lineTo(x + width - 114, y + 41);
            rail.graphics.moveTo(x, y + 41); rail.graphics.lineTo(x, y + 45);
            rail.graphics.lineStyle(2, themeColor(1.0), 0.80);
            rail.graphics.moveTo(x, y + 41); rail.graphics.lineTo(x + 30, y + 41);
            visualTarget.addChild(rail);
            drawNativeMark(x + width - 55, y + 26);
        }

        private function drawNativeMark(x:Number, y:Number):void
        {
            // User-owned Vault-Tec artwork, not a newly invented mechanical badge.
            var holder:Sprite = new Sprite(); holder.x = x; holder.y = y;
            holder.mouseEnabled = false; holder.mouseChildren = false;
            var art:DisplayObject = externalBitmap("mark");
            if (!art) return;
            var area:Rectangle = new Rectangle(42 * 512 / 1254, 352 * 512 / 1254, 1170 * 512 / 1254, 547 * 512 / 1254);
            var scale:Number = Math.min(104 / area.width, 48 / area.height);
            art.scaleX = art.scaleY = scale;
            art.x = -(area.x + area.width / 2) * scale;
            art.y = -(area.y + area.height / 2) * scale;
            art.transform.colorTransform = new ColorTransform(0, 0, 0, 0.92,
                ((themeColor(0.94) >> 16) & 255), ((themeColor(0.94) >> 8) & 255), (themeColor(0.94) & 255), 0);
            holder.addChild(art);
            themeLayer.addChild(holder);
            headerMarkHolder = holder;
        }

        private function drawHeader(x:Number, y:Number, title:String):void
        {
            var rule:Shape = new Shape();
            rule.graphics.beginFill(accent, 0.96);
            rule.graphics.drawRect(x, y + 1, 3, 34);
            rule.graphics.endFill();
            visualTarget.addChild(rule);
            drawFixedText(x + 14, y + 2, 720, String(title).toUpperCase(), 22, 0xF0F4F5, 1, true, "left");
        }

        private function paintNavTab(tab:Sprite, config:Object, metrics:Object):void
        {
            paintFavoritesTab(tab, metrics, String(config.value) == pluginFilter);
        }

        private function drawNavFooter(x:Number, y:Number, width:Number):void
        {
            drawCommandRail(x, y, width);
            drawNavHint(x, y, inputMode == "gamepad" ? "A" : "E", TEXT.enter, 28, 64);
            drawNavHint(x + 132, y, inputMode == "gamepad" ? "Y" : "F", TEXT.search, 28, 90);
            drawNavHint(x + width - 106, y, inputMode == "gamepad" ? "B" : "TAB", TEXT.close, 46, 52);
        }

        private function drawNavHint(x:Number, y:Number, key:String, label:String, keyWidth:Number, labelWidth:Number):void
        {
            // Adapt Favorites' continuous keycap and text on a shared baseline.
            var keycap:Shape = new Shape();
            keycap.graphics.lineStyle(1.2, themeColor(1.0), 0.84);
            keycap.graphics.beginFill(panelBackground, 0.06);
            strokeKeyCap(keycap.graphics, x, y, keyWidth, 25, 3);
            keycap.graphics.endFill();
            visualTarget.addChild(keycap);
            var keyField:TextField = drawFixedText(x, y + 4, keyWidth, key, 13, themeColor(1.0), 1, false, "center");
            setTextTracking(keyField, 0.2);
            var labelField:TextField = drawFixedText(x + keyWidth + 8, y + 4, labelWidth, label, 12, themeColor(0.86), 1, false, "left");
            alignHintBaseline(keyField, labelField);
        }

        private function createPluginRow(value:Object, selected:Boolean, x:Number, y:Number, width:Number, height:Number):Sprite
        {
            var row:Sprite = new Sprite();
            row.x = x; row.y = y; row.buttonMode = true; row.mouseChildren = false;
            componentMetrics[row] = { width: width, height: height, kind: "plugins", unavailable: false };
            var glyph:Sprite = new Sprite();
            glyph.name = "pluginGlyph";
            glyph.mouseEnabled = false;
            glyph.mouseChildren = false;
            drawItemIcon(glyph, value, "plugin", 22, height / 2, themeColor(1.0));
            row.addChild(glyph);
            var count:int = value.matchCount ? int(value.matchCount) : 0;
            var countWidth:Number = count > 0 ? Math.max(48, String(count).length * 8 + 18) : 0;
            var label:TextField = addTextTo(row, 42, 4, width - 52 - countWidth,
                String(value.name || ""), 14, PRIMARY_ROW_TEXT, 1, false, "left");
            if (count > 0) addTextTo(row, width - countWidth - 8, 5, countWidth,
                "\u00D7" + count, 12, secondaryText, 0.88, false, "right");
            label.name = "rowName";
            paintPluginRow(row, selected, width, height);
            return row;
        }

        private function paintPluginRow(row:Sprite, selected:Boolean, width:Number, height:Number):void
        {
            var glyph:Sprite = row.getChildByName("pluginGlyph") as Sprite;
            if (glyph) {
                var glyphColor:uint = themeColor(1.0);
                setIconColor(glyph, glyphColor);
            }
            drawRowFrame(row, selected, width, height, focusColor);
            var label:TextField = row.getChildByName("rowName") as TextField;
            if (label) {
                label.defaultTextFormat = makeFormat(14, selected ? SELECTED_ROW_TEXT : PRIMARY_ROW_TEXT, 1, false, "left");
                label.setTextFormat(label.defaultTextFormat);
            }
        }

        private function drawPluginScrollTrack(target:Sprite, x:Number, y:Number, height:Number,
            itemCount:int, visibleCount:int, start:int):void
        {
            drawScrollTrack(target, x, y, 3, height, itemCount, visibleCount, start, true);
        }

        private function drawTabs(x:Number, y:Number, width:Number, values:Array, active:String,
            compact:Boolean, paneName:String = "", textOnly:Boolean = false):void
        {
            if (textOnly) {
                var baseline:Shape = new Shape();
                baseline.graphics.lineStyle(1, themeColor(0.55), 0.36);
                baseline.graphics.moveTo(x, y + 27);
                baseline.graphics.lineTo(x + width, y + 27);
                visualTarget.addChild(baseline);
            }
            var gap:Number = textOnly ? (page == "nav" ? 18 : 30) : 3;
            var tabW:Number = page == "nav" && textOnly ? 76 : (width - gap * (values.length - 1)) / values.length;
            var cursor:Number = x;
            var height:Number = textOnly ? 28 : (compact ? 36 : 38);
            var navStyle:Boolean = page == "nav" && paneName.length == 0;
            for (var i:int = 0; i < values.length; ++i) {
                var value:String = String(values[i]);
                var tab:Sprite = new Sprite();
                tab.x = textOnly ? cursor : x + i * (tabW + gap);
                tab.y = y;
                tab.name = paneName.length > 0 ? "categoryTab_" + paneName + "_" + i : "navTab_" + i;
                tab.buttonMode = true;
                tab.mouseEnabled = true;
                tab.mouseChildren = false;
                componentMetrics[tab] = { width: tabW, height: height };
                tabConfigs[tab] = {
                    value: value,
                    label: String(compact ? CATEGORY_LABELS[value] || value :
                        (page == "nav" ? NAV_FILTER_LABELS[value] || value : value)).toUpperCase(),
                    compact: compact,
                    textOnly: textOnly,
                    paneName: paneName,
                    navStyle: navStyle
                };
                var label:TextField = addTextTo(tab, 3, textOnly ? 6 : 9, tabW - 6,
                    String(tabConfigs[tab].label), 15,
                    secondaryText, 0.92, true, "center");
                label.name = "tabLabel";
                tab.addEventListener(MouseEvent.MOUSE_OVER, onTabOver);
                tab.addEventListener(MouseEvent.MOUSE_OUT, onTabOut);
                tab.addEventListener(MouseEvent.CLICK, onTabClick);
                tabNodes.push(tab);
                visualTarget.addChild(tab);
                if (textOnly && navStyle) cursor += tabW + gap;
                if (textOnly && !navStyle) {
                    // Measure after attachment so Scaleform can resolve the complete key.
                    var measured:Number = label.textWidth;
                    if (measured <= 0 || (isLocalizedLabel(label.text) && measured > 90))
                        measured = value == "weapon" ? 70 : (value == "aid" ? 62 : String(value).length * 9 + 8);
                    var naturalWidth:Number = Math.max(28, Math.min(170, Math.ceil(measured + 16)));
                    componentMetrics[tab].width = naturalWidth;
                    label.x = 4;
                    label.width = naturalWidth - 8;
                    cursor += naturalWidth + gap;
                }
            }
            updateTabAppearance();
        }

        private function updateTabAppearance():void
        {
            for each (var tab:Sprite in tabNodes) {
                if (!tab || !tab.parent) continue;
                var config:Object = tabConfigs[tab];
                var metrics:Object = componentMetrics[tab];
                if (!config || !metrics) continue;
                paintFavoritesTab(tab, metrics, config.paneName == "global" ?
                    String(config.value) == itemCategory : String(config.value) == pluginFilter);
            }
        }

        // Adapted from Favorites updateTabAppearance; global filters never imply a pane.
        private function paintFavoritesTab(tab:Sprite, metrics:Object, active:Boolean):void
        {
            var hovered:Boolean = tab.name == hoverTabName;
            var width:Number = Number(metrics.width), height:Number = Number(metrics.height);
            tab.graphics.clear();
            fillRect(tab.graphics, 0, 0.01, 0, 0, width, height);
            if (active || hovered) {
                tab.graphics.lineStyle(2, focusColor, active ? 0.98 : 0.72);
                var pad:Number = active ? 4 : 8;
                tab.graphics.moveTo(pad, height - 1);
                tab.graphics.lineTo(width - pad, height - 1);
            }
            var label:TextField = tab.getChildByName("tabLabel") as TextField;
            setTextColor(label, active || hovered ? focusColor : themeColor(1.0));
            if (label) label.alpha = active || hovered ? 1 : INACTIVE_NAV_ALPHA;
        }

        private function onTabOver(event:MouseEvent):void
        {
            if (page == "extract" && searchMouseGuard) return;
            var tab:Sprite = event.currentTarget as Sprite;
            if (!tab) return;
            focusSource = 3;
            mouseMovedSinceInput = true;
            hoverTabName = tab.name;
            updateTabAppearance();
        }

        private function onTabOut(event:MouseEvent):void
        {
            var tab:Sprite = event.currentTarget as Sprite;
            if (!tab || hoverTabName != tab.name) return;
            hoverTabName = "";
            updateTabAppearance();
        }

        private function onTabClick(event:MouseEvent):void
        {
            var tab:Sprite = event.currentTarget as Sprite;
            if (!tab) return;
            focusSource = 3;
            mouseMovedSinceInput = true;
            hoverTabName = tab.name;
            var index:int = indexFromName(tab.name);
            if (page == "nav" && index >= 0 && index < NAV_FILTERS.length) {
                pluginFilter = NAV_FILTERS[index];
                pluginIndex = 0;
                pluginScrollStart = 0;
                hoverTabName = "";
                render();
            } else if (page == "extract" && tab.name.indexOf("categoryTab_global_") == 0 &&
                index >= 0 && index < ITEM_CATEGORIES.length) {
                itemCategory = ITEM_CATEGORIES[index];
                leftIndex = rightIndex = 0;
                leftScrollStart = rightScrollStart = 0;
                hoverTabName = "";
                render();
            }
        }

        private function drawSearch(x:Number, y:Number, width:Number):void
        {
            var previousTarget:Sprite = visualTarget;
            searchChrome = new Sprite();
            searchChrome.mouseEnabled = true; searchChrome.mouseChildren = true;
            searchArea = new Rectangle(x, y, width, 32);
            searchHovered = false;
            if (stage) searchHovered = searchArea.contains(mouseX, mouseY);
            searchChrome.addEventListener(MouseEvent.ROLL_OVER, function(event:MouseEvent):void {
                searchHovered = true; updateSearchAppearance();
            });
            searchChrome.addEventListener(MouseEvent.ROLL_OUT, function(event:MouseEvent):void {
                searchHovered = false; updateSearchAppearance();
            });
            searchChrome.addEventListener(MouseEvent.CLICK, function(event:MouseEvent):void {
                setSearchFocus(true, false); updateSearchAppearance();
            });
            previousTarget.addChild(searchChrome);
            visualTarget = searchChrome;
            updateSearchAppearance();
            searchField = new TextField();
            searchField.type = "dynamic";
            searchField.selectable = false;
            searchField.tabEnabled = false;
            searchField.width = width - 42;
            searchField.height = 26;
            searchField.x = x + 32;
            searchField.y = y + 3;
            searchField.maxChars = 80;
            searchField.text = query;
            searchField.defaultTextFormat = makeFormat(13, 0xE4EBED, 1, false, "left");
            searchField.setTextFormat(searchField.defaultTextFormat);
            searchField.addEventListener(Event.CHANGE, onSearchChanged);
            searchField.addEventListener(FocusEvent.FOCUS_IN, function(event:FocusEvent):void {
                // Automatic Scaleform field focus must not enable search mode.
                if (!rendering && !searchFocused && stage && stage.focus == searchField)
                    stage.focus = null;
            });
            searchField.addEventListener(FocusEvent.FOCUS_OUT, function(event:FocusEvent):void {
                // Field replacement during redraw is not an explicit search exit.
            });
            visualTarget.addChild(searchField);
            if (query.length == 0 && !searchFocused)
                drawFixedText(x + 34, y + 7, width - 42, TEXT.searchPlaceholder, 13, PRIMARY_ROW_TEXT, 0.78, false, "left");
            if (searchFocused) {
                var caret:Shape = new Shape();
                var prefix:TextField = new TextField();
                prefix.defaultTextFormat = searchField.defaultTextFormat;
                prefix.text = query.substr(0, searchCaretIndex);
                var caretX:Number = Math.min(x + width - 8, x + 34 + prefix.textWidth);
                caret.graphics.lineStyle(1, focusColor, 1);
                caret.graphics.moveTo(caretX, y + 7);
                caret.graphics.lineTo(caretX, y + 24);
                visualTarget.addChild(caret);
            }
            visualTarget = previousTarget;
        }

        private function updateSearchAppearance():void
        {
            if (!searchChrome || !searchArea) return;
            var g:Graphics = searchChrome.graphics;
            var color:uint = searchFocused || searchHovered ? focusColor : themeColor(0.55);
            g.clear();
            g.beginFill(color, searchFocused ? 0.09 : (searchHovered ? 0.05 : 0.001));
            g.drawRect(searchArea.x, searchArea.y, searchArea.width, searchArea.height);
            g.endFill();
            g.lineStyle(searchFocused ? 2 : 1, color, searchFocused ? 0.95 : (searchHovered ? 0.78 : 0.28));
            g.moveTo(searchArea.x, searchArea.y + 31);
            g.lineTo(searchArea.right, searchArea.y + 31);
            g.lineStyle(1.5, searchFocused || searchHovered ? focusColor : accent, searchHovered || searchFocused ? 1 : 0.80);
            g.drawCircle(searchArea.x + 13, searchArea.y + 15, 6);
            g.moveTo(searchArea.x + 18, searchArea.y + 20);
            g.lineTo(searchArea.x + 21, searchArea.y + 25);
        }

        private function onSearchChanged(event:Event):void
        {
            if (!searchField) return;
            if (!searchFocused) { searchField.text = query; return; }
            query = searchField.text;
            searchCaretIndex = searchField.caretIndex;
            pluginIndex = 0;
            pluginScrollStart = 0;
            searchQueryChanged();
            render();
        }

        public function HandleSearchCharacter(code:uint):void
        {
            if (!searchFocused || page != "nav" || !searchField) return;
            if (searchActivationTime >= 0) {
                var activationAge:int = getTimer() - searchActivationTime;
                searchActivationTime = -1;
                // Consume only the immediate character accompanying F activation.
                if (activationAge <= 100 && (code == 0x66 || code == 0x46)) return;
            }
            var inserted:String;
            if (code <= 0xFFFF) {
                inserted = String.fromCharCode(code);
            } else {
                code -= 0x10000;
                inserted = String.fromCharCode(0xD800 + (code >> 10), 0xDC00 + (code & 0x3FF));
            }
            query = query.substr(0, searchCaretIndex) + inserted + query.substr(searchCaretIndex);
            searchCaretIndex += inserted.length;
            pluginIndex = pluginScrollStart = 0;
            searchQueryChanged();
            render();
        }

        public function HandleSearchBackspace():void
        {
            if (!searchFocused || page != "nav" || searchCaretIndex <= 0) return;
            query = query.substr(0, searchCaretIndex - 1) + query.substr(searchCaretIndex);
            --searchCaretIndex;
            pluginIndex = pluginScrollStart = 0;
            searchQueryChanged();
            render();
        }

        public function HandleSearchDelete():void
        {
            if (!searchFocused || page != "nav" || searchCaretIndex >= query.length) return;
            query = query.substr(0, searchCaretIndex) + query.substr(searchCaretIndex + 1);
            pluginIndex = pluginScrollStart = 0;
            searchQueryChanged();
            render();
        }

        public function MoveSearchCaret(delta:int):void
        {
            if (!searchFocused || page != "nav") return;
            searchCaretIndex = Math.max(0, Math.min(searchCaretIndex + delta, query.length));
            render();
        }

        public function FinishSearch():void
        {
            if (searchFocused) setSearchFocus(false);
        }

        private function applySearchEdit():void
        {
            query = searchField.text;
            searchCaretIndex = searchField.caretIndex;
            pluginIndex = 0;
            pluginScrollStart = 0;
            searchQueryChanged();
            render();
        }

        private function onSearchOutsideClick(event:MouseEvent):void
        {
            if (!searchFocused || !searchChrome) return;
            var target:DisplayObject = event.target as DisplayObject;
            if (target && (target == searchChrome || searchChrome.contains(target))) return;
            setSearchFocus(false, false);
            updateSearchAppearance();
        }

        private function setSearchFocus(value:Boolean, repaint:Boolean = true):void
        {
            if (searchFocused == value) return;
            searchFocused = value;
            if (searchField) {
                searchField.type = "dynamic";
                searchField.selectable = false;
            }
            if (BGSCodeObj && BGSCodeObj.SearchFocus is Function) BGSCodeObj.SearchFocus(value);
            if (!value && searchField && stage && stage.focus == searchField) stage.focus = null;
            if (value && searchField && stage) stage.focus = null;
            if (repaint) render();
        }

        private function drawListFrame(x:Number, y:Number, width:Number, height:Number):void
        {
            var shape:Shape = new Shape();
            shape.graphics.beginFill(0x050708, LIST_ALPHA);
            shape.graphics.drawRect(x, y, width, height);
            shape.graphics.endFill();
            visualTarget.addChild(shape);
        }

        private function drawRows(source:Array, selected:int, x:Number, y:Number, width:Number,
            rowH:Number, maxRows:int, start:int, kind:String, layer:Sprite, scrollX:Number):void
        {
            if (!source || source.length == 0) {
                drawFixedText(x + 18, y + 16, width - 36, trimmedSearch(query).length ? "$AIE_NO_SEARCH_RESULTS" : TEXT.noPlugins, 14, 0x9EB1B7, 0.84, false, "left");
                return;
            }
            start = clamp(start, 0, Math.max(0, source.length - maxRows));
            var end:int = Math.min(source.length, start + maxRows);
            for (var i:int = start; i < end; ++i) {
                var row:Sprite = createPluginRow(source[i], i == selected, x, y + (i - start) * rowH, width, rowH);
                row.name = "pluginRow_" + i;
                row.addEventListener(MouseEvent.MOUSE_OVER, onPluginRowOver);
                row.addEventListener(MouseEvent.CLICK, onPluginRowClick);
                if (i == selected) selectedPluginRow = row;
                layer.addChild(row);
            }
            drawPluginScrollTrack(layer, scrollX, y, rowH * maxRows, source.length, maxRows, start);
        }

        private function drawColumn(x:Number, y:Number, width:Number, height:Number, title:String,
            source:Array, selected:int, scrollStart:int, focused:Boolean, kind:String):void
        {
            var column:Shape = new Shape();
            visualTarget.addChild(column);
            columnFrames[kind] = column;
            prepareWatermarkSlot(x + width / 2, y + height * 0.74, kind);

            var header:Shape = new Shape();
            visualTarget.addChild(header);
            columnHeaders[kind] = header;
            columnBounds[kind] = { x: x, y: y, width: width, height: height };
            columnTitles[kind] = drawFixedText(x + 14, y + 4, width - 88, title, 16,
                0xE8EEF0, 1, true, "left");
            columnCounts[kind] = drawFixedText(x + width - 62, y + 7, 48, String(source.length), 12,
                secondaryText, SECONDARY_ALPHA, false, "right");
            paintColumnChrome(kind);

            var listY:Number = y + EXTRACT_LIST_TOP;
            var listHeight:Number = height - EXTRACT_LIST_HEIGHT_INSET;
            var rowH:Number = ITEM_ROW_HEIGHT;
            var maxRows:int = itemVisibleRows(height);
            if (source.length == 0) {
                drawFixedText(x + 16, listY + 18, width - 34,
                    kind == "left" ? TEXT.noSessionItems : TEXT.noModItems,
                    13, mutedText, 0.94, false, "left");
            }
            var rowsLayer:Sprite = new Sprite();
            rowsLayer.name = "itemRows_" + kind;
            rowLayer.addChild(rowsLayer);
            if (kind == "left") leftRowsLayer = rowsLayer;
            else rightRowsLayer = rowsLayer;
            if (source.length > 0)
                drawItemRows(rowsLayer, x, y, width, height, source, selected, scrollStart, focused, kind);
        }

        private function drawItemRows(layer:Sprite, x:Number, y:Number, width:Number, height:Number,
            source:Array, selected:int, scrollStart:int, focused:Boolean, kind:String):void
        {
            clearLayer(layer);
            if (focusedItemRow && focusedItemRow.parent == layer)
                focusedItemRow = null;
            if (!source || source.length == 0) return;
            var listY:Number = y + EXTRACT_LIST_TOP;
            var listHeight:Number = height - EXTRACT_LIST_HEIGHT_INSET;
            var rowH:Number = ITEM_ROW_HEIGHT;
            var maxRows:int = itemVisibleRows(height);
            var topSearch:Boolean = kind == "right" && itemCategory == "all" && searchTopIndex >= 0 && selected == searchTopIndex;
            var start:int = clamp(scrollStart, 0, Math.max(0, source.length - (topSearch ? 1 : maxRows)));
            var end:int = Math.min(source.length, start + maxRows);
            var rowAreaX:Number = x + 2;
            var rowAreaWidth:Number = width - 13;
            for (var i:int = start; i < end; ++i) {
                var row:Sprite = createRow(source[i], focused && i == selected,
                    String(source[i].category), rowAreaX, listY + 3 + (i - start) * rowH,
                    rowAreaWidth, rowH, kind);
                row.name = "itemRow_" + kind + "_" + i;
                row.addEventListener(MouseEvent.MOUSE_OVER, onItemRowOver);
                row.addEventListener(MouseEvent.CLICK, onItemRowClick);
                if (focused && i == selected) focusedItemRow = row;
                layer.addChild(row);
            }
            drawScrollTrack(layer, x + width - 9, listY + 4, 3, listHeight - 8,
                source.length, maxRows, start, focused);
        }

        private function itemVisibleRows(height:Number):int
        {
            return Math.max(1, int(((height - EXTRACT_LIST_HEIGHT_INSET) - 8) / ITEM_ROW_HEIGHT));
        }

        private function paintColumnChrome(kind:String):void
        {
            var bounds:Object = columnBounds[kind];
            var frame:Shape = columnFrames[kind] as Shape;
            var header:Shape = columnHeaders[kind] as Shape;
            if (!bounds || !frame || !header) return;
            var x:Number = Number(bounds.x);
            var y:Number = Number(bounds.y);
            var width:Number = Number(bounds.width);
            var height:Number = Number(bounds.height);
            var focused:Boolean = pane == kind;
            frame.graphics.clear();
            // Open columns share the menu material; no pane or viewport fill/frame.
            header.graphics.clear();
            header.graphics.lineStyle(1, themeColor(focused ? 1.0 : 0.55), focused ? 0.75 : 0.36);
            header.graphics.moveTo(x + 2, y + 30);
            header.graphics.lineTo(x + width - 4, y + 30);
            if (focused) {
                header.graphics.lineStyle();
                header.graphics.beginFill(accent, 0.86);
                header.graphics.drawRect(x, y + 6, 3, 20);
                header.graphics.endFill();
            }
            var title:TextField = columnTitles[kind] as TextField;
            var count:TextField = columnCounts[kind] as TextField;
            setTextColor(title, themeColor(focused ? 1.0 : 0.68));
            setTextColor(count, themeColor(focused ? 0.92 : 0.68));
            // Repaint-only focus weight; keep both viewport contents and starts intact.
            var rows:Sprite = kind == "left" ? leftRowsLayer : rightRowsLayer;
            var scrollbar:Shape = rows ? rows.getChildByName("scrollbar") as Shape : null;
            if (scrollbar) scrollbar.alpha = focused ? 1 : 0.62;
        }

        private function drawInventoryMark(x:Number, y:Number):void
        {
            var mark:Shape = new Shape();
            mark.graphics.lineStyle(1.2, PRIMARY_ROW_TEXT, 0.78);
            mark.graphics.moveTo(x, y - 7); mark.graphics.lineTo(x + 7, y - 3);
            mark.graphics.lineTo(x + 7, y + 5); mark.graphics.lineTo(x, y + 9);
            mark.graphics.lineTo(x - 7, y + 5); mark.graphics.lineTo(x - 7, y - 3);
            mark.graphics.lineTo(x, y - 7);
            mark.graphics.moveTo(x - 7, y - 3); mark.graphics.lineTo(x, y + 1);
            mark.graphics.lineTo(x + 7, y - 3);
            mark.graphics.moveTo(x, y + 1); mark.graphics.lineTo(x, y + 9);
            visualTarget.addChild(mark);
        }

        private function updatePaneAppearance():void
        {
            paintColumnChrome("left");
            paintColumnChrome("right");
            if (footerBatchAction) footerBatchAction.text = pane == "left" ? TEXT.batchReturn : TEXT.batchTake;
            if (footerAllAction) footerAllAction.text = pane == "left" ? TEXT.returnAll : TEXT.takeAll;
            if (footerPrimaryAction) {
                footerPrimaryAction.text = pane == "left" ? TEXT.returnItem : TEXT.take;
                footerPrimaryAction.setTextFormat(footerPrimaryAction.defaultTextFormat);
            }
        }

        private function createRow(value:Object, selected:Boolean, categoryName:String, x:Number, y:Number, width:Number, height:Number, kind:String):Sprite
        {
            var row:Sprite = new Sprite();
            row.x = x; row.y = y; row.buttonMode = true; row.mouseChildren = false;
            var rowFocus:uint = focusColor;
            drawRowFrame(row, selected, width, height, rowFocus);
            var icon:Sprite = new Sprite();
            icon.name = "rowIcon";
            icon.mouseEnabled = false;
            icon.mouseChildren = false;
            drawItemIcon(icon, value, categoryName, 20, height / 2, themeColor(1.0));
            icon.alpha = selected ? 1 : 0.86;
            row.addChild(icon);
            var label:String = String(value.name || "");
            var returnable:uint = uint(value.returnable || 0);
            var unavailable:Boolean = kind == "left" && returnable == 0;
            icon.alpha = unavailable ? 0.55 : (selected ? 1 : 0.86);
            componentMetrics[row] = { width: width, height: height, kind: kind, unavailable: unavailable };
            var countWidth:Number = kind == "plugin" || kind == "plugins" ? 0 : (kind == "left" && returnable > 0 && returnable < uint(value.count || 0) ? 78 : 58);
            var nameWidth:Number = Math.max(24, width - 40 - countWidth - 18);
            var nameField:TextField = addTextTo(row, 40, 4, nameWidth, label, 14,
                unavailable ? UNAVAILABLE_ROW_TEXT : (selected ? SELECTED_ROW_TEXT : PRIMARY_ROW_TEXT),
                unavailable ? DISABLED_ALPHA : 1, false, "left");
            nameField.name = "rowName";
            var count:String;
            if (kind == "plugin" || kind == "plugins") count = "";
            else if (kind == "left") count = "x" + String(returnable);
            else count = "x" + String(value.count || value.group || 1);
            if (count.length > 0) {
                var countField:TextField = addTextTo(row, width - countWidth - 10, 5,
                    countWidth, count, 12, unavailable ? UNAVAILABLE_COUNT_TEXT : themeColor(0.92),
                    unavailable ? DISABLED_ALPHA : (selected ? 1 : SECONDARY_ALPHA), false, "right");
                countField.name = "rowCount";
            }
            return row;
        }

        private function drawItemIcon(target:Sprite, value:Object, categoryName:String, x:Number, y:Number, color:uint):void
        {
            var iconClass:String = value && value.iconClass ? String(value.iconClass) : "";
            if (iconClass.length > 0) {
                var library:String = value.iconLibrary ? String(value.iconLibrary) : "FallUI_IconLib.swf";
                library = normalizeIconLibraryPath(library);
                var domain:ApplicationDomain = iconLibraryDomains[library] as ApplicationDomain;
                if (!domain) {
                    requestIconLibrary(library);
                } else {
                    var definition:String = iconClass.indexOf("m_") == 0 ? iconClass : "m_" + iconClass;
                    if (domain.hasDefinition(definition)) {
                        try {
                            var iconType:Class = domain.getDefinition(definition) as Class;
                            var display:DisplayObject = new iconType() as DisplayObject;
                            if (display) {
                                if (display is Sprite) Sprite(display).mouseEnabled = false;
                                fitIconSlot(display, x, y);
                                target.addChild(display);
                                return;
                            }
                        } catch (error:Error) { }
                    }
                }
            }
            var fallback:Sprite;
            if (categoryName == "weapon") fallback = FallbackIconFactory.create("WEAP", "Rifle");
            else if (categoryName == "armor") fallback = FallbackIconFactory.create("ARMO", "Armor");
            else if (categoryName == "aid") fallback = FallbackIconFactory.create("ALCH", "Medicine");
            else {
                // Native kind reflects the light flag, including ESL-flagged ESPs.
                fallback = ExtractorIconFactory.create(categoryName,
                    value && value.kind ? String(value.kind) : "");
            }
            fallback.name = "fallbackGlyph";
            fitIconSlot(fallback, x, y);
            setIconColor(fallback, color);
            target.addChild(fallback);
        }

        private function fitIconSlot(display:DisplayObject, x:Number, y:Number):void
        {
            var bounds:Rectangle = display.getBounds(display);
            var size:Number = Math.max(bounds.width, bounds.height);
            if (size > 0) display.scaleX = display.scaleY = ICON_SLOT_SIZE / size;
            display.x = x - (bounds.x + bounds.width / 2) * display.scaleX;
            display.y = y - (bounds.y + bounds.height / 2) * display.scaleY;
        }

        private function requestIconLibrary(path:String):void
        {
            path = normalizeIconLibraryPath(path);
            if (!path.length || iconLibraryDomains[path] || iconLibraryLoaders[path] || iconLibraryFailures[path]) return;
            var loader:Loader = new Loader();
            loader.name = path;
            loader.contentLoaderInfo.addEventListener(Event.COMPLETE, onIconLibraryLoaded);
            loader.contentLoaderInfo.addEventListener(IOErrorEvent.IO_ERROR, onIconLibraryFailed);
            iconLibraryLoaders[path] = loader;
            loader.load(new URLRequest(path));
        }

        private function normalizeIconLibraryPath(path:String):String
        {
            path = path ? path.split("\\").join("/") : "";
            while (path.indexOf("./") == 0) path = path.substr(2);
            if (path.indexOf("Interface/") == 0) path = path.substr(10);
            return path;
        }

        private function onIconLibraryLoaded(event:Event):void
        {
            var info:LoaderInfo = event.currentTarget as LoaderInfo;
            var loader:Loader = info ? info.loader : null;
            var path:String = loader ? loader.name : "";
            if (path.length && info.applicationDomain) iconLibraryDomains[path] = info.applicationDomain;
            delete iconLibraryLoaders[path];
            render();
        }

        private function onIconLibraryFailed(event:IOErrorEvent):void
        {
            var info:LoaderInfo = event.currentTarget as LoaderInfo;
            var loader:Loader = info ? info.loader : null;
            var path:String = loader ? loader.name : "";
            delete iconLibraryLoaders[path];
            iconLibraryFailures[path] = true;
        }

        private function drawCategoryGlyph(target:Sprite, categoryName:String, x:Number, y:Number, color:uint):void
        {
            var mark:Shape = new Shape();
            mark.graphics.lineStyle(1.7, color, 0.96, true);
            var type:String = String(categoryName).toLowerCase();
            if (type == "weapon") {
                mark.graphics.moveTo(x - 6, y + 5); mark.graphics.lineTo(x + 5, y - 6);
                mark.graphics.moveTo(x - 7, y + 6); mark.graphics.lineTo(x - 3, y + 7);
                mark.graphics.moveTo(x + 3, y - 7); mark.graphics.lineTo(x + 7, y - 3);
            } else if (type == "armor") {
                mark.graphics.moveTo(x, y - 7); mark.graphics.lineTo(x + 6, y - 4);
                mark.graphics.lineTo(x + 5, y + 3); mark.graphics.lineTo(x, y + 7);
                mark.graphics.lineTo(x - 5, y + 3); mark.graphics.lineTo(x - 6, y - 4); mark.graphics.lineTo(x, y - 7);
            } else if (type == "aid") {
                mark.graphics.drawCircle(x, y, 6);
                mark.graphics.moveTo(x - 3, y); mark.graphics.lineTo(x + 3, y);
                mark.graphics.moveTo(x, y - 3); mark.graphics.lineTo(x, y + 3);
            } else if (type == "ammo") {
                mark.graphics.drawRect(x - 4, y - 6, 8, 12);
                mark.graphics.moveTo(x - 2, y - 8); mark.graphics.lineTo(x + 2, y - 8);
            } else if (type == "junk") {
                mark.graphics.drawRect(x - 6, y - 5, 12, 10);
                mark.graphics.moveTo(x - 4, y - 1); mark.graphics.lineTo(x + 4, y - 1);
                mark.graphics.moveTo(x - 3, y + 2); mark.graphics.lineTo(x + 3, y + 2);
            } else {
                mark.graphics.drawCircle(x, y, 5);
                mark.graphics.drawCircle(x, y, 1.5);
            }
            target.addChild(mark);
        }

        // Adapted from Favorites updateSelection: fixed metrics, thin focus frame.
        private function drawRowFrame(row:Sprite, selected:Boolean, width:Number, height:Number, focus:uint):void
        {
            var g:Graphics = row.graphics;
            g.clear();
            // One menu surface: normal row fill is hit-only, not a stacked card.
            fillRect(g, selected ? focus : 0x010606, selected ? 0.10 : 0.01,
                0, 0, width, height);
            g.lineStyle(1, selected ? focus : themeColor(0.55), selected ? 0.96 : 0.23);
            if (selected) strokeRect(g, 0.5, 0.5, width - 1, height - 1);
            else { g.moveTo(0, height - 0.5); g.lineTo(width, height - 0.5); }
        }

        // Adapted from Favorites updateScrollBar; no changes to scrolling/input state.
        private function drawScrollTrack(target:Sprite, x:Number, y:Number, width:Number, height:Number,
            itemCount:int, visibleCount:int, start:int, focused:Boolean):void
        {
            if (itemCount <= visibleCount) return;
            var rail:Shape = new Shape(), g:Graphics = rail.graphics;
            rail.name = "scrollbar";
            var weight:Number = focused ? 1 : 0.62;
            g.lineStyle(1, themeColor(0.60), 0.32);
            g.moveTo(x + width / 2, y + 14); g.lineTo(x + width / 2, y + height - 14);
            drawTriangle(g, x + width / 2, y + 4, 3, true, themeColor(0.80));
            drawTriangle(g, x + width / 2, y + height - 4, 3, false, themeColor(0.80));
            var thumbHeight:Number = Math.max(26, (height - 28) * visibleCount / itemCount);
            var maxStart:int = Math.max(1, itemCount - visibleCount);
            var thumbY:Number = y + 14 + (height - 28 - thumbHeight) * Math.min(1, start / maxStart);
            fillRect(g, themeColor(1.0), 0.74, x, thumbY, width, thumbHeight);
            rail.alpha = weight;
            target.addChild(rail);
        }

        private function updateRowAppearance(row:Sprite, selected:Boolean):void
        {
            if (!row) return;
            var metrics:Object = componentMetrics[row];
            if (!metrics) return;
            if (metrics.kind == "plugins") {
                paintPluginRow(row, selected, Number(metrics.width), Number(metrics.height));
                return;
            }
            drawRowFrame(row, selected, Number(metrics.width), Number(metrics.height), focusColor);
            var unavailable:Boolean = Boolean(metrics.unavailable);
            var icon:Sprite = row.getChildByName("rowIcon") as Sprite;
            if (icon) {
                icon.alpha = unavailable ? 0.55 : (selected ? 1 : 0.86);
                var fallback:Sprite = icon.getChildByName("fallbackGlyph") as Sprite;
                if (fallback) {
                    var iconColor:uint = themeColor(1.0);
                    setIconColor(fallback, iconColor);
                }
            }
            var nameField:TextField = row.getChildByName("rowName") as TextField;
            if (nameField) {
                var nameColor:uint = unavailable ? UNAVAILABLE_ROW_TEXT :
                    (selected ? SELECTED_ROW_TEXT : PRIMARY_ROW_TEXT);
                nameField.alpha = unavailable ? DISABLED_ALPHA : 1;
                nameField.defaultTextFormat = makeFormat(14, nameColor, 1, false, "left");
                nameField.setTextFormat(nameField.defaultTextFormat);
            }
            var countField:TextField = row.getChildByName("rowCount") as TextField;
            if (countField) {
                var countColor:uint = unavailable ? UNAVAILABLE_COUNT_TEXT : themeColor(0.92);
                countField.alpha = unavailable ? DISABLED_ALPHA : (selected ? 1 : SECONDARY_ALPHA);
                countField.defaultTextFormat = makeFormat(12, countColor, 1, false, "right");
                countField.setTextFormat(countField.defaultTextFormat);
            }
        }

        private function clearLayer(layer:Sprite):void
        {
            if (!layer) return;
            while (layer.numChildren > 0)
                layer.removeChildAt(layer.numChildren - 1);
        }

        private function ensureIndexVisible(start:int, selected:int, itemCount:int, visibleCount:int):int
        {
            var maxStart:int = Math.max(0, itemCount - visibleCount);
            start = clamp(start, 0, maxStart);
            if (itemCount <= 0) return 0;
            if (selected < start) start = selected;
            else if (selected >= start + visibleCount) start = selected - visibleCount + 1;
            return clamp(start, 0, maxStart);
        }

        private function drawModalOptionFrame(option:Sprite, selected:Boolean, width:Number, focus:uint):void
        {
            var g:Graphics = option.graphics;
            g.clear();
            g.beginFill(selected ? focusColor : panelBackground, selected ? 0.10 : 0.001);
            g.drawRect(0, 0, width, 37); g.endFill();
            if (selected) {
                g.lineStyle(2, focusColor, 0.95);
                g.moveTo(width * 0.28, 36); g.lineTo(width * 0.72, 36);
            }

        }

        private function drawFooter(x:Number, y:Number, width:Number, hints:Array):void
        {
            drawCommandRail(x, y, width);
            // Reserve stable localized label slots; group actions naturally on the left.
            var labelWidths:Array = [85, 73, 104, 90];
            var commandGap:Number = 26;
            var cursor:Number = x;
            for (var i:int = 0; i < hints.length; ++i) {
                var key:String = String(hints[i][0]);
                var label:String = String(hints[i][1]);
                var isBack:Boolean = i == hints.length - 1;
                var hx:Number = isBack ? x + width - 114 : cursor;
                var boxW:Number = key.length > 4 ? 62 : (key.length > 1 ? 46 : 28);
                var labelWidth:Number = isBack ? 60 : Number(labelWidths[i]);
                var box:Shape = new Shape();
                box.graphics.lineStyle(1.2, themeColor(1.0), 0.84);
                box.graphics.beginFill(panelBackground, 0.06);
                strokeKeyCap(box.graphics, hx, y + 1, boxW, 25, 3);
                box.graphics.endFill();
                visualTarget.addChild(box);
                var keyField:TextField = drawFixedText(hx + 4, y + 5, boxW - 8, key, 13, themeColor(1.0), 1, false, "center");
                setTextTracking(keyField, 0.2);
                var actionField:TextField = drawFixedText(hx + boxW + 8, y + 5, labelWidth,
                    label, 12, themeColor(0.86), 1, false, "left");
                alignHintBaseline(keyField, actionField);
                if (i == 0) footerPrimaryAction = actionField;
                else if (i == 1) footerBatchAction = actionField;
                else if (i == 2) footerAllAction = actionField;
                if (!isBack) {
                    cursor = hx + boxW + 8 + labelWidth + commandGap;
                    if (i < 2) {
                        var divider:Shape = new Shape();
                        divider.graphics.lineStyle(1, themeColor(1.0), 0.45);
                        divider.graphics.moveTo(cursor - commandGap / 2, y + 3);
                        divider.graphics.lineTo(cursor - commandGap / 2, y + 23);
                        visualTarget.addChild(divider);
                    }
                }
            }
        }

        private function drawCommandRail(x:Number, y:Number, width:Number):void
        {
            var rail:Shape = new Shape();
            rail.graphics.lineStyle(1, themeColor(1.0), 0.55);
            rail.graphics.moveTo(x, y - 8); rail.graphics.lineTo(x + width, y - 8);
            rail.graphics.moveTo(x, y - 10); rail.graphics.lineTo(x, y - 6);
            rail.graphics.moveTo(x + width, y - 10); rail.graphics.lineTo(x + width, y - 6);
            visualTarget.addChild(rail);
        }

        private function renderBatchModal():void
        {
            var shade:Shape = new Shape();
            shade.graphics.beginFill(0x000000, 0.52);
            shade.graphics.drawRect(0, 0, STAGE_W, STAGE_H);
            shade.graphics.endFill();
            visualTarget.addChild(shade);
            var width:Number = 560;
            var height:Number = 184;
            var x:Number = (STAGE_W - width) / 2;
            var y:Number = (STAGE_H - height) / 2;
            var shell:Shape = new Shape();
            shell.x = x; shell.y = y;
            shell.graphics.beginFill(panelBackground, MENU_SURFACE_ALPHA);
            shell.graphics.drawRoundRect(0, 0, width, height, 16, 16);
            shell.graphics.endFill();
            drawOriginalFrame(shell.graphics, width, height);
            visualTarget.addChild(shell);
            var modalAccent:uint = accent;
            var modalFocus:uint = focusColor;
            drawHeaderText(x + 22, y + 14, width - 44, modalTake ? TEXT.batchTake : TEXT.batchReturn,
                20, themeColor(1.0), "AIETitle", false, 0.2);
            var active:Object = currentItem();
            drawFixedText(x + 22, y + 44, width - 44, active ? String(active.name) : "",
                13, themeColor(0.78), 1, false, "left");
            var optionW:Number = (width - 44) / modalValues.length;
            for (var i:int = 0; i < modalValues.length; ++i) {
                var option:Sprite = new Sprite();
                option.x = x + 22 + i * optionW;
                option.y = y + 78;
                option.buttonMode = true;
                option.mouseChildren = false;
                var selected:Boolean = i == modalIndex;
                option.name = "batchOption_" + i;
                componentMetrics[option] = { width: optionW, height: 37 };
                drawModalOptionFrame(option, selected, optionW, modalAccent);
                var optionLabel:TextField = addTextTo(option, 0, 9, optionW, "x" + modalValues[i], 16, selected ? modalFocus : themeColor(0.88), 1, selected, "center");
                optionLabel.name = "optionLabel";
                modalOptionRows.push(option);
                option.addEventListener(MouseEvent.MOUSE_OVER, onModalOptionOver);
                option.addEventListener(MouseEvent.CLICK, onModalOptionClick);
                visualTarget.addChild(option);
                if (i > 0) {
                    var divider:Shape = new Shape();
                    divider.graphics.lineStyle(1, themeColor(0.8), 0.25);
                    divider.graphics.moveTo(option.x, option.y + 9);
                    divider.graphics.lineTo(option.x, option.y + 27);
                    visualTarget.addChild(divider);
                }
            }
            drawBatchHint(x + 22, y + 141, inputMode == "gamepad" ? "L/R" : "A/D", "$AIE_MODAL_SELECT");
            drawBatchHint(x + 208, y + 141, inputMode == "gamepad" ? "A" : "E", "$AIE_MODAL_CONFIRM");
            drawBatchHint(x + 395, y + 141, inputMode == "gamepad" ? "B" : "TAB", "$AIE_MODAL_CANCEL");
        }

        private function drawBatchHint(x:Number, y:Number, key:String, label:String):void
        {
            var width:Number = key.length > 1 ? 40 : 26;
            var box:Shape = new Shape();
            box.graphics.lineStyle(1, themeColor(1.0), 0.72);
            box.graphics.drawRect(x, y, width, 24);
            visualTarget.addChild(box);
            var keyField:TextField = drawFixedText(x + 3, y + 4, width - 6, key, 12, themeColor(1.0), 1, false, "center");
            var labelField:TextField = drawFixedText(x + width + 8, y + 4, 90, label, 12, themeColor(0.82), 1, false, "left");
            alignHintBaseline(keyField, labelField);
        }

        private function alignHintBaseline(keyField:TextField, labelField:TextField):void
        {
            // Same actual baseline even when key and localized label sizes differ.
            if (keyField.numLines > 0 && labelField.numLines > 0)
                keyField.y = labelField.y + labelField.getLineMetrics(0).ascent - keyField.getLineMetrics(0).ascent;
        }

        private function asciiLower(value:String):String
        {
            var result:String = "";
            for (var i:int = 0; i < value.length; ++i) {
                var code:int = value.charCodeAt(i);
                result += String.fromCharCode(code >= 65 && code <= 90 ? code + 32 : code);
            }
            return result;
        }

        private function searchWhitespace(code:int):Boolean
        {
            return code == 32 || (code >= 9 && code <= 13);
        }

        private function trimmedSearch(value:String):String
        {
            var first:int = 0; var last:int = value.length;
            while (first < last && searchWhitespace(value.charCodeAt(first))) ++first;
            while (last > first && searchWhitespace(value.charCodeAt(last - 1))) --last;
            return value.substring(first, last);
        }

        private function searchTokens(value:String):Array
        {
            var tokens:Array = [];
            var normalized:String = asciiLower(trimmedSearch(value));
            var i:int = 0;
            while (i < normalized.length) {
                while (i < normalized.length && searchWhitespace(normalized.charCodeAt(i))) ++i;
                var start:int = i;
                while (i < normalized.length && !searchWhitespace(normalized.charCodeAt(i))) ++i;
                if (i > start) tokens.push(normalized.substring(start, i));
            }
            return tokens;
        }

        private function matchesSearch(name:String, tokens:Array):Boolean
        {
            var normalized:String = asciiLower(name);
            for each (var token:String in tokens) if (normalized.indexOf(token) < 0) return false;
            return true;
        }

        private function searchQueryChanged():void
        {
            pluginSearchTimer.reset();
            pluginSearchResults = null;
            pluginSearchQuery = "";
            if (trimmedSearch(query).length >= 2) pluginSearchTimer.start();
        }

        private function dispatchPluginSearch(event:TimerEvent):void
        {
            if (trimmedSearch(query).length < 2 || !stage) return;
            if (BGSCodeObj && BGSCodeObj.SearchPluginsAndItems is Function)
                BGSCodeObj.SearchPluginsAndItems(query);
        }

        public function ApplyPluginSearchResults(responseQuery:String, results:Array, totalItemMatches:uint):void
        {
            if (responseQuery != query || trimmedSearch(query).length < 2) return;
            var oldList:Array = visiblePlugins();
            var selectedName:String = oldList.length ? String(oldList[clampIndex(pluginIndex, oldList.length)].name) : "";
            pluginSearchQuery = responseQuery;
            pluginSearchResults = results ? results : [];
            var shown:Array = visiblePlugins();
            pluginIndex = clampIndex(pluginIndex, shown.length);
            for (var i:int = 0; i < shown.length; ++i) {
                if (String(shown[i].name) == selectedName) { pluginIndex = i; break; }
            }
            if (page == "nav") render();
        }

        private function visiblePlugins():Array
        {
            var trimmed:String = trimmedSearch(query);
            var tokens:Array = trimmed.length ? searchTokens(query) : [];
            var nativeResults:Boolean = trimmed.length >= 2 &&
                pluginSearchQuery == query && pluginSearchResults != null;
            var source:Array = nativeResults ? pluginSearchResults : plugins;
            var result:Array = [];
            for each (var value:Object in source) {
                if (pluginFilter != "ALL" && String(value.kind).toUpperCase() != pluginFilter) continue;
                if (!trimmed.length || nativeResults || matchesSearch(String(value.name), tokens)) result.push(value);
            }
            return result;
        }

        private function visibleItems(source:Array, categoryValue:String):Array
        {
            return source.filter(function(value:Object, index:int, values:Array):Boolean {
                return categoryValue == "all" || String(value.category) == categoryValue;
            });
        }

        private function visibleSessionItems(categoryValue:String):Array
        {
            return session.filter(function(value:Object, index:int, values:Array):Boolean {
                return value != null && Number(value.returnable || 0) > 0 &&
                    (categoryValue == "all" || String(value.category) == categoryValue);
            });
        }

        private function normalizeCategory(value:String):String
        {
            return ITEM_CATEGORIES.indexOf(value) >= 0 ? value : "all";
        }

        private function currentItem():Object
        {
            var shown:Array = pane == "left" ? visibleSessionItems(itemCategory) : visibleItems(items, itemCategory);
            var index:int = pane == "left" ? leftIndex : rightIndex;
            return shown.length ? shown[clampIndex(index, shown.length)] : null;
        }

        private function moveSelection(delta:int):void
        {
            if (page == "extract") searchTopIndex = -1;
            if (page == "nav") {
                var list:Array = visiblePlugins();
                if (!list.length) return;
                pluginIndex = (pluginIndex + delta + list.length) % list.length;
                var nextPluginStart:int = ensureIndexVisible(pluginScrollStart, pluginIndex, list.length, NAV_VISIBLE_ROWS);
                if (nextPluginStart != pluginScrollStart) {
                    pluginScrollStart = nextPluginStart;
                    rebuildPluginViewport();
                } else {
                    selectPluginRow(pluginIndex);
                }
            } else {
                var shown:Array = pane == "left" ? visibleSessionItems(itemCategory) : visibleItems(items, itemCategory);
                if (!shown.length) return;
                if (pane == "left") leftIndex = (leftIndex + delta + shown.length) % shown.length;
                else rightIndex = (rightIndex + delta + shown.length) % shown.length;
                var selectedIndex:int = pane == "left" ? leftIndex : rightIndex;
                var scrollStart:int = pane == "left" ? leftScrollStart : rightScrollStart;
                var nextStart:int = ensureIndexVisible(scrollStart, selectedIndex, shown.length, itemVisibleRows(EXTRACT_COLUMNS_HEIGHT));
                if (pane == "left") leftScrollStart = nextStart;
                else rightScrollStart = nextStart;
                if (nextStart != scrollStart) rebuildItemViewport(pane);
                else selectItemRow(pane, selectedIndex);
            }
            updateMascotTip();
        }

        private function moveHorizontal(delta:int):void
        {
            if (page == "nav") {
                var index:int = NAV_FILTERS.indexOf(pluginFilter);
                pluginFilter = NAV_FILTERS[(index + delta + NAV_FILTERS.length) % NAV_FILTERS.length];
                pluginIndex = 0;
                pluginScrollStart = 0;
                render();
            } else {
                setActivePane(delta < 0 ? "left" : "right");
            }
        }

        private function moveCategory(delta:int):void
        {
            searchTopIndex = -1;
            if (page != "extract") return;
            var index:int = ITEM_CATEGORIES.indexOf(itemCategory);
            itemCategory = ITEM_CATEGORIES[(index + delta + ITEM_CATEGORIES.length) % ITEM_CATEGORIES.length];
            leftIndex = 0;
            rightIndex = 0;
            leftScrollStart = 0;
            rightScrollStart = 0;
            render();
        }

        private function activate():void
        {
            if (page == "nav") { enterPlugin(); return; }
            var item:Object = currentItem();
            if (pane == "left" && item && uint(item.returnable || 0) == 0) return;
            if (item && BGSCodeObj && BGSCodeObj.TransferItem is Function)
                BGSCodeObj.TransferItem(uint(item.formID), pane == "right", 0);
        }

        private function enterPlugin():void
        {
            if (page != "nav") return;
            var shown:Array = visiblePlugins();
            if (!shown.length) return;
            var selected:Object = shown[clampIndex(pluginIndex, shown.length)];
            activePlugin = String(selected.name);
            pendingItemFocus = selected.matchCount && int(selected.matchCount) > 0;
            pendingFocusPlugin = activePlugin;
            searchTopIndex = -1;
            searchMouseGuard = false;
            page = "extract"; itemCategory = "all"; pane = "right"; leftIndex = rightIndex = 0;
            leftScrollStart = rightScrollStart = 0;
            items = []; session = []; modalOpen = false;
            if (BGSCodeObj && BGSCodeObj.EnterPlugin is Function) BGSCodeObj.EnterPlugin(activePlugin);
            render();
        }

        private function takeAll():void
        {
            if (page != "extract" || !BGSCodeObj) return;
            if (pane == "left") {
                if (BGSCodeObj.ReturnAll is Function) BGSCodeObj.ReturnAll();
            } else if (items.length && BGSCodeObj.TakeAll is Function) BGSCodeObj.TakeAll();
        }

        private function openBatch():void
        {
            if (page != "extract" || modalOpen || !currentItem()) return;
            var active:Object = currentItem();
            var configured:int = Math.max(1, int(active.group || 1));
            var limit:int = pane == "left" ? int(active.returnable || 0) : 1000;
            if (limit < 1) return;
            modalValues = [1, 10, 50, 100, 1000].filter(function(value:int, index:int, values:Array):Boolean { return value <= limit; });
            if (modalValues.indexOf(Math.min(configured, limit)) < 0) modalValues.push(Math.min(configured, limit));
            if (modalValues.indexOf(limit) < 0) modalValues.push(limit);
            modalValues.sort(Array.NUMERIC);
            modalIndex = modalValues.indexOf(Math.min(configured, limit));
            modalFormID = uint(active.formID);
            modalTake = pane == "right";
            modalOpen = true;
            render();
        }

        private function moveModal(delta:int):void
        {
            if (!modalValues.length) return;
            selectModalOption((modalIndex + delta + modalValues.length) % modalValues.length);
        }

        private function confirmBatch():void
        {
            if (!modalOpen || !modalFormID || modalIndex < 0 || modalIndex >= modalValues.length ||
                !BGSCodeObj || !(BGSCodeObj.TransferItem is Function)) { closeBatch(); return; }
            modalOpen = false;
            BGSCodeObj.TransferItem(modalFormID, modalTake, uint(modalValues[modalIndex]));
            render();
        }

        private function closeBatch():void { modalOpen = false; render(); }

        private function back():void
        {
            if (modalOpen) { closeBatch(); return; }
            if (searchFocused) { setSearchFocus(false); return; }
            if (page == "extract") {
                page = "nav"; activePlugin = ""; items = []; session = [];
                if (BGSCodeObj && BGSCodeObj.EndSession is Function) BGSCodeObj.EndSession();
                render();
            } else if (BGSCodeObj && BGSCodeObj.Close is Function) BGSCodeObj.Close();
        }

        private function clampIndex(value:int, length:int):int
        {
            return length <= 0 ? 0 : Math.max(0, Math.min(value, length - 1));
        }

        private function captureMouseBaseline():void
        {
            if (!stage) return;
            lastMouseStageX = stage.mouseX;
            lastMouseStageY = stage.mouseY;
            hasMousePosition = true;
        }

        private function onMouseMove(event:MouseEvent):void
        {
            var moved:Boolean = !hasMousePosition ||
                Math.abs(event.stageX - lastMouseStageX) > 0.1 ||
                Math.abs(event.stageY - lastMouseStageY) > 0.1;
            if (!moved) return;
            hasMousePosition = true;
            lastMouseStageX = event.stageX;
            lastMouseStageY = event.stageY;
            if (searchMouseGuard) {
                searchMouseGuard = false;
                var target:DisplayObject = event.target as DisplayObject;
                while (target && target != this) {
                    if (target is Sprite && target.name.indexOf("itemRow_") == 0) {
                        var split:int = target.name.lastIndexOf("_");
                        selectItemRow(target.name.substring(8, split), indexFromName(target.name), target as Sprite);
                        break;
                    }
                    target = target.parent;
                }
            }
            mouseMovedSinceInput = true;
            focusSource = 3;
        }

        private function onMouseOut(event:MouseEvent):void
        {
            if (rendering || event.relatedObject != null || hoverTabName.length == 0) return;
            hoverTabName = "";
            updateTabAppearance();
        }

        private function onMouseWheel(event:MouseEvent):void
        {
            if (!event || event.delta == 0) return;
            var local:Point = globalToLocal(new Point(event.stageX, event.stageY));
            var delta:int = event.delta > 0 ? -1 : 1;
            var handled:Boolean = false;

            if (modalOpen) {
                var modalX:Number = (STAGE_W - 560) / 2 + 22;
                var modalY:Number = (STAGE_H - 184) / 2 + 78;
                if (inside(local, modalX, modalY, 516, 37) && modalValues.length > 0) {
                    focusSource = 3;
                    mouseMovedSinceInput = true;
                    selectModalOption(clampIndex(modalIndex + delta, modalValues.length));
                    handled = true;
                }
                if (handled) {
                    event.preventDefault();
                    event.stopImmediatePropagation();
                }
                return;
            }

            if (page == "nav") {
                var navPanelX:Number = (STAGE_W - NAV_PANEL_WIDTH) / 2;
                var navPanelY:Number = (STAGE_H - NAV_PANEL_HEIGHT) / 2;
                var navX:Number = navPanelX + NAV_CONTENT_INSET;
                var navY:Number = navPanelY + NAV_LIST_TOP;
                var navW:Number = NAV_PANEL_WIDTH - NAV_CONTENT_INSET * 2;
                if (inside(local, navX, navY, navW, NAV_LIST_HEIGHT)) {
                    var shown:Array = visiblePlugins();
                    focusSource = 3;
                    mouseMovedSinceInput = true;
                    if (shown.length > 0) {
                        var oldPluginStart:int = pluginScrollStart;
                        var nextPluginStart:int = clamp(pluginScrollStart + delta, 0, Math.max(0, shown.length - NAV_VISIBLE_ROWS));
                        pluginScrollStart = nextPluginStart;
                        if (pluginIndex < pluginScrollStart)
                            pluginIndex = pluginScrollStart;
                        else if (pluginIndex >= pluginScrollStart + NAV_VISIBLE_ROWS)
                            pluginIndex = Math.min(shown.length - 1, pluginScrollStart + NAV_VISIBLE_ROWS - 1);
                        if (pluginScrollStart != oldPluginStart)
                            rebuildPluginViewport();
                        else
                            selectPluginRow(pluginIndex);
                    }
                    handled = true;
                }
            } else {
                var bounds:Object = extractionBounds();
                var columnY:Number = Number(bounds.columnY);
                var listY:Number = columnY + EXTRACT_LIST_TOP;
                var listH:Number = EXTRACT_COLUMNS_HEIGHT - EXTRACT_LIST_HEIGHT_INSET;
                var leftListX:Number = Number(bounds.leftX) + 2;
                var rightListX:Number = Number(bounds.rightX) + 2;
                var leftListW:Number = Number(bounds.leftW) - 13;
                var rightListW:Number = Number(bounds.rightW) - 13;
                if (inside(local, leftListX, listY, leftListW, listH)) {
                    focusSource = 3;
                    mouseMovedSinceInput = true;
                    setActivePane("left");
                    scrollItemViewport("left", delta);
                    handled = true;
                } else if (inside(local, rightListX, listY, rightListW, listH)) {
                    focusSource = 3;
                    mouseMovedSinceInput = true;
                    setActivePane("right");
                    scrollItemViewport("right", delta);
                    handled = true;
                }
            }

            if (handled) {
                event.preventDefault();
                event.stopImmediatePropagation();
            }
        }

        private function rebuildPluginViewport():void
        {
            if (!pluginRowsLayer) return;
            var shown:Array = visiblePlugins();
            pluginIndex = clampIndex(pluginIndex, shown.length);
            pluginScrollStart = clamp(pluginScrollStart, 0, Math.max(0, shown.length - NAV_VISIBLE_ROWS));
            selectedPluginRow = null;
            clearLayer(pluginRowsLayer);
            var panelX:Number = (STAGE_W - NAV_PANEL_WIDTH) / 2;
            var panelY:Number = (STAGE_H - NAV_PANEL_HEIGHT) / 2;
            var listX:Number = panelX + NAV_CONTENT_INSET;
            var listY:Number = panelY + NAV_LIST_TOP;
            var listW:Number = NAV_PANEL_WIDTH - NAV_CONTENT_INSET * 2;
            drawRows(shown, pluginIndex, listX + 1, listY + 1, listW - 10,
                PLUGIN_ROW_HEIGHT, NAV_VISIBLE_ROWS, pluginScrollStart, "plugins",
                pluginRowsLayer, listX + listW - 5);
            if (pluginCounter)
                pluginCounter.text = shown.length ? (pluginIndex + 1) + " / " + shown.length : "0 / 0";
        }

        private function rebuildItemViewport(kind:String):void
        {
            var layer:Sprite = kind == "left" ? leftRowsLayer : rightRowsLayer;
            if (!layer) return;
            var bounds:Object = extractionBounds();
            var x:Number = Number(kind == "left" ? bounds.leftX : bounds.rightX);
            var width:Number = Number(kind == "left" ? bounds.leftW : bounds.rightW);
            var source:Array;
            var selected:int;
            var start:int;
            if (kind == "left") {
                source = visibleSessionItems(itemCategory);
                selected = leftIndex;
                start = leftScrollStart;
            } else {
                source = visibleItems(items, itemCategory);
                selected = rightIndex;
                start = rightScrollStart;
            }
            var y:Number = Number(bounds.columnY);
            var focused:Boolean = pane == kind;
            if (!source.length) {
                clearLayer(layer);
                return;
            }
            drawItemRows(layer, x, y, width, EXTRACT_COLUMNS_HEIGHT,
                source, selected, start, focused, kind);
            updateMascotTip();
        }

        private function scrollItemViewport(kind:String, delta:int):void
        {
            var source:Array = kind == "left" ? visibleSessionItems(itemCategory) : visibleItems(items, itemCategory);
            if (!source.length) return;
            var visibleCount:int = itemVisibleRows(EXTRACT_COLUMNS_HEIGHT);
            var selected:int = kind == "left" ? leftIndex : rightIndex;
            var oldStart:int = kind == "left" ? leftScrollStart : rightScrollStart;
            var maxStart:int = Math.max(0, source.length - visibleCount);
            var nextStart:int = clamp(oldStart + delta, 0, maxStart);
            if (selected < nextStart)
                selected = nextStart;
            else if (selected >= nextStart + visibleCount)
                selected = Math.min(source.length - 1, nextStart + visibleCount - 1);
            if (kind == "left") {
                leftScrollStart = nextStart;
                leftIndex = selected;
            } else {
                rightScrollStart = nextStart;
                rightIndex = selected;
            }
            if (nextStart != oldStart)
                rebuildItemViewport(kind);
            else if (kind == pane)
                selectItemRow(kind, selected);
            updateMascotTip();
        }

        private function setActivePane(targetPane:String):void
        {
            if (targetPane != "left" && targetPane != "right" || pane == targetPane) return;
            if (focusedItemRow)
                updateRowAppearance(focusedItemRow, false);
            pane = targetPane;
            updatePaneAppearance();
            var index:int = pane == "left" ? leftIndex : rightIndex;
            var layer:Sprite = pane == "left" ? leftRowsLayer : rightRowsLayer;
            focusedItemRow = layer ? layer.getChildByName("itemRow_" + pane + "_" + index) as Sprite : null;
            if (focusedItemRow)
                updateRowAppearance(focusedItemRow, true);
            updateMascotTip();
        }

        private function inside(point:Point, x:Number, y:Number, width:Number, height:Number):Boolean
        {
            return point.x >= x && point.x <= x + width && point.y >= y && point.y <= y + height;
        }

        private function clearTabHover():void
        {
            if (hoverTabName.length == 0) return;
            hoverTabName = "";
            updateTabAppearance();
        }

        private function indexFromName(name:String):int
        {
            return int(name.substring(name.lastIndexOf("_") + 1));
        }

        private function onPluginRowClick(event:MouseEvent):void
        {
            var row:Sprite = event.currentTarget as Sprite;
            if (!row) return;
            focusSource = 3;
            mouseMovedSinceInput = true;
            clearTabHover();
            var index:int = indexFromName(row.name);
            selectPluginRow(index);
            if (pluginIndex == index) activate();
        }

        private function onPluginRowOver(event:MouseEvent):void
        {
            var row:Sprite = event.currentTarget as Sprite;
            if (!row) return;
            focusSource = 3;
            mouseMovedSinceInput = true;
            clearTabHover();
            selectPluginRow(indexFromName(row.name));
        }

        private function selectPluginRow(index:int):void
        {
            var shown:Array = visiblePlugins();
            if (index < 0 || index >= shown.length) return;
            var nextRow:Sprite = pluginRowsLayer ? pluginRowsLayer.getChildByName("pluginRow_" + index) as Sprite : null;
            if (selectedPluginRow != nextRow && selectedPluginRow)
                updateRowAppearance(selectedPluginRow, false);
            pluginIndex = index;
            if (pluginCounter)
                pluginCounter.text = (pluginIndex + 1) + " / " + shown.length;
            if (nextRow) updateRowAppearance(nextRow, true);
            selectedPluginRow = nextRow;
        }

        private function onItemRowClick(event:MouseEvent):void
        {
            if (searchMouseGuard) return;
            var row:Sprite = event.currentTarget as Sprite;
            if (!row) return;
            focusSource = 3;
            mouseMovedSinceInput = true;
            clearTabHover();
            var separator:int = row.name.lastIndexOf("_");
            var targetPane:String = row.name.substring(8, separator);
            var index:int = indexFromName(row.name);
            selectItemRow(targetPane, index, row);
            if (pane == targetPane &&
                (targetPane == "left" ? leftIndex : rightIndex) == index)
                activate();
        }

        private function onItemRowOver(event:MouseEvent):void
        {
            if (searchMouseGuard) return;
            var row:Sprite = event.currentTarget as Sprite;
            if (!row) return;
            focusSource = 3;
            mouseMovedSinceInput = true;
            clearTabHover();
            var separator:int = row.name.lastIndexOf("_");
            selectItemRow(row.name.substring(8, separator), indexFromName(row.name), row);
        }

        private function onModalOptionOver(event:MouseEvent):void
        {
            var option:Sprite = event.currentTarget as Sprite;
            if (!option) return;
            focusSource = 3;
            mouseMovedSinceInput = true;
            selectModalOption(indexFromName(option.name));
        }

        private function onModalOptionClick(event:MouseEvent):void
        {
            var option:Sprite = event.currentTarget as Sprite;
            if (!option) return;
            focusSource = 3;
            mouseMovedSinceInput = true;
            var index:int = indexFromName(option.name);
            selectModalOption(index);
            if (modalIndex == index) confirmBatch();
        }

        private function selectItemRow(targetPane:String, index:int, sourceRow:Sprite = null):void
        {
            if (modalOpen || (targetPane != "left" && targetPane != "right")) return;
            var shown:Array = targetPane == "left" ? visibleSessionItems(itemCategory) : visibleItems(items, itemCategory);
            if (index < 0 || index >= shown.length) return;
            var paneChanged:Boolean = pane != targetPane;
            var oldFocusedRow:Sprite = focusedItemRow;
            var layer:Sprite = targetPane == "left" ? leftRowsLayer : rightRowsLayer;
            var nextRow:Sprite = sourceRow || (layer ? layer.getChildByName("itemRow_" + targetPane + "_" + index) as Sprite : null);
            if (oldFocusedRow != nextRow && oldFocusedRow)
                updateRowAppearance(oldFocusedRow, false);
            pane = targetPane;
            if (pane == "left") leftIndex = index;
            else rightIndex = index;
            if (paneChanged) updatePaneAppearance();
            if (nextRow) updateRowAppearance(nextRow, true);
            focusedItemRow = nextRow;
            updateMascotTip();
        }

        private function selectModalOption(index:int):void
        {
            if (index < 0 || index >= modalValues.length) return;
            var previous:Sprite = modalOptionRows.length > modalIndex ? modalOptionRows[modalIndex] as Sprite : null;
            modalIndex = index;
            var next:Sprite = modalOptionRows.length > modalIndex ? modalOptionRows[modalIndex] as Sprite : null;
            if (previous && previous != next) updateModalOptionAppearance(previous, false);
            if (next) updateModalOptionAppearance(next, true);
        }

        private function updateModalOptionAppearance(option:Sprite, selected:Boolean):void
        {
            var metrics:Object = componentMetrics[option];
            if (!metrics) return;
            drawModalOptionFrame(option, selected, Number(metrics.width), accent);
            var label:TextField = option.getChildByName("optionLabel") as TextField;
            if (label) {
                var format:TextFormat = label.defaultTextFormat;
                format.color = selected ? focusColor : themeColor(0.88);
                format.bold = selected;
                label.defaultTextFormat = format; label.setTextFormat(format);
            }
        }

        private function drawHeaderText(x:Number, y:Number, width:Number, value:String, size:Number,
            color:uint, family:String, bold:Boolean, tracking:Number):TextField
        {
            var field:TextField = makeText(value, x, y, size, color, bold);
            field.width = width; field.height = size + 10; field.autoSize = TextFieldAutoSize.NONE;
            visualTarget.addChild(field);
            // Unsupported actual characters retain the existing game-font path.
            var embedded:Boolean = HeaderFontFactory.supports(family, field.text);
            var format:TextFormat = embedded ? new TextFormat(family, size, color, bold) : makeFormat(size, color, 1, bold, "left");
            format.letterSpacing = tracking; field.embedFonts = embedded;
            field.defaultTextFormat = format; field.setTextFormat(format);
            if (!isLocalizedLabel(value)) {
                var probe:TextField = new TextField(); probe.embedFonts = embedded;
                probe.autoSize = TextFieldAutoSize.LEFT; probe.defaultTextFormat = format;
                var low:int = 0, high:int = value.length;
                probe.text = value;
                if (probe.textWidth > width - 7) {
                    while (low < high) {
                        var middle:int = int(Math.ceil((low + high) / 2));
                        probe.text = value.substr(0, middle) + "...";
                        if (probe.textWidth <= width - 7) low = middle; else high = middle - 1;
                    }
                    var prefix:String = value.substr(0, low);
                    if (prefix.length && prefix.charCodeAt(prefix.length - 1) >= 0xD800 && prefix.charCodeAt(prefix.length - 1) <= 0xDBFF)
                        prefix = prefix.substr(0, prefix.length - 1);
                    field.text = prefix + "..."; field.setTextFormat(format);
                }
            }
            return field;
        }

        private function drawText(x:Number, y:Number, value:String, size:Number, color:uint, alpha:Number = 1, bold:Boolean = false, tracking:Number = 0):TextField
        {
            var field:TextField = makeText(value, x, y, size, color, bold);
            field.autoSize = TextFieldAutoSize.LEFT;
            field.selectable = false; field.mouseEnabled = false;
            field.embedFonts = false; field.multiline = false; field.wordWrap = false;
            field.text = value;
            field.defaultTextFormat = makeFormat(size, color, alpha, bold, "left", tracking);
            field.alpha = alpha;
            field.setTextFormat(field.defaultTextFormat);
            visualTarget.addChild(field);
            return field;
        }

        private function drawFixedText(x:Number, y:Number, width:Number, value:String, size:Number,
            color:uint, alpha:Number = 1, bold:Boolean = false, align:String = "left"):TextField
        {
            return addTextTo(visualTarget, x, y, width, value, size, color, alpha, bold, align);
        }

        private function addTextTo(target:Sprite, x:Number, y:Number, width:Number, value:String, size:Number, color:uint, alpha:Number, bold:Boolean, align:String):TextField
        {
            var field:TextField = makeText(value, x, y, size, color, bold);
            field.x = x; field.y = y; field.width = width; field.height = size + 10;
            field.selectable = false; field.mouseEnabled = false; field.wordWrap = false;
            field.autoSize = TextFieldAutoSize.NONE;
            field.embedFonts = false; field.multiline = false;
            if (isLocalizedLabel(value)) {
                // Match Favorites: give Scaleform the complete key before styling.
                // A detached measuring field must never shorten a translation key.
                field.text = value;
                field.defaultTextFormat = makeFormat(size, color, alpha, bold, align);
            } else {
                field.text = fitText(value, width, size, color, alpha, bold, align);
                field.defaultTextFormat = makeFormat(size, color, alpha, bold, align);
            }
            field.alpha = alpha;
            field.setTextFormat(field.defaultTextFormat);
            target.addChild(field);
            return field;
        }

        private function isLocalizedLabel(value:String):Boolean
        {
            return value != null && /^\$AIE_[A-Z0-9_]+$/.test(value);
        }

        private function fitText(value:String, width:Number, size:Number, color:uint,
            alpha:Number, bold:Boolean, align:String):String
        {
            if (isLocalizedLabel(value)) return value;
            if (!value || width <= 4) return "";
            var probe:TextField = new TextField();
            probe.autoSize = TextFieldAutoSize.LEFT;
            probe.embedFonts = false;
            probe.defaultTextFormat = makeFormat(size, color, alpha, bold, align);
            probe.text = value;
            if (probe.textWidth <= width - 7) return value;

            var low:int = 0;
            var high:int = value.length;
            while (low < high) {
                var middle:int = int(Math.ceil((low + high) / 2));
                var prefix:String = value.substr(0, middle);
                if (prefix.length > 0) {
                    var lastCode:uint = prefix.charCodeAt(prefix.length - 1);
                    if (lastCode >= 0xD800 && lastCode <= 0xDBFF) prefix = prefix.substr(0, prefix.length - 1);
                }
                probe.text = prefix + "...";
                if (probe.textWidth <= width - 7) low = middle;
                else high = middle - 1;
            }
            var result:String = value.substr(0, low);
            if (result.length > 0) {
                var finalCode:uint = result.charCodeAt(result.length - 1);
                if (finalCode >= 0xD800 && finalCode <= 0xDBFF) result = result.substr(0, result.length - 1);
            }
            return result + "...";
        }

        private function makeFormat(size:Number, color:uint, alpha:Number, bold:Boolean, align:String, tracking:Number = 0):TextFormat
        {
            var fontName:String = bold ? "$MAIN_Font_Bold" : "$MAIN_Font";
            var format:TextFormat = new TextFormat(fontName, size, color, bold, false, false, null, null, align);
            format.letterSpacing = tracking;
            return format;
        }

        // Ported/adapted from Aozora Favorites SkyuiLikeMenuPanel.
        private function drawOriginalFrame(g:Graphics, width:Number, height:Number):void
        {
            var horizontalAlpha:Number = 0.88;
            var outerAlpha:Number = 0.45;

            // Vanilla-style rails: only the top and bottom bars are drawn.
            // Each end follows a small adjustable quarter-arc into the panel
            // edge; there are no square hooks and no connecting side edges.
            var innerInset:Number = 2.5;
            var radius:Number = 8.0;
            radius = Math.max(2.0, Math.min(radius, Math.min(width, height) * 0.5));
            var innerRadius:Number = Math.max(2.0, radius - innerInset);

            drawRoundedHorizontalRails(g, width, height, radius, 0.0, 1.25,
                themeColor(0.72), outerAlpha);
            drawRoundedHorizontalRails(g, width, height, innerRadius, innerInset, 2.25,
                themeColor(1.0), horizontalAlpha);
        }

        // Ported/adapted from Aozora Favorites SkyuiLikeMenuPanel.
        private function drawScanlines(width:Number, height:Number):void
        {
            scanlineLayer.graphics.clear();


            scanlineLayer.graphics.lineStyle(1, themeColor(1.0), 0.020);
            for (var yLine:Number = 3.0; yLine < height; yLine += 4.0) {
                scanlineLayer.graphics.moveTo(0, yLine);
                scanlineLayer.graphics.lineTo(width, yLine);
            }
        }

        // Ported/adapted from Aozora Favorites SkyuiLikeMenuPanel.
        private function makeText(value:String, xPos:Number, yPos:Number, size:Number, color:uint, bold:Boolean):TextField
        {
            var field:TextField = new TextField();
            field.x = xPos; field.y = yPos; field.text = value;
            field.defaultTextFormat = new TextFormat(bold ? "$MAIN_Font_Bold" : "$MAIN_Font", size, color, bold);
            field.setTextFormat(field.defaultTextFormat);
            field.selectable = false; field.mouseEnabled = false;
            field.multiline = false; field.wordWrap = false; field.embedFonts = false;
            return field;
        }

        // Ported/adapted from Aozora Favorites SkyuiLikeMenuPanel.
        private function setTextColor(field:TextField, color:uint):void
        {
            if (!field)
                return;
            var format:TextFormat = field.defaultTextFormat;
            format.color = color; field.defaultTextFormat = format; field.setTextFormat(format);
        }

        // Favorites footer key text uses regular weight with 0.2 tracking.
        private function setTextTracking(field:TextField, tracking:Number):void
        {
            var format:TextFormat = field.defaultTextFormat;
            format.letterSpacing = tracking;
            field.defaultTextFormat = format; field.setTextFormat(format);
        }

        // Ported/adapted from Aozora Favorites SkyuiLikeMenuPanel.
        private function setIconColor(icon:Sprite, color:uint):void
        {
            if (!icon)
                return;
            icon.transform.colorTransform = new ColorTransform(
                ((color >> 16) & 0xFF) / 255.0,
                ((color >> 8) & 0xFF) / 255.0,
                (color & 0xFF) / 255.0,
                1, 0, 0, 0, 0);
        }

        // Ported/adapted from Aozora Favorites SkyuiLikeMenuPanel.
        private function strokeRect(g:Graphics, xPos:Number, yPos:Number, width:Number, height:Number):void
        {
            g.moveTo(xPos, yPos);
            g.lineTo(xPos + width, yPos);
            g.lineTo(xPos + width, yPos + height);
            g.lineTo(xPos, yPos + height);
            g.lineTo(xPos, yPos);
        }

        // Ported/adapted from Aozora Favorites SkyuiLikeMenuPanel.
        private function strokeKeyCap(g:Graphics, xPos:Number, yPos:Number,
            width:Number, height:Number, cut:Number):void
        {
            // Continuous rectangular keycap; the key label remains a real
            // centered text field inside this fixed graphic.
            g.drawRect(xPos, yPos, width, height);
        }

        // Ported/adapted from Aozora Favorites SkyuiLikeMenuPanel.
        private function fillRect(g:Graphics, color:uint, alphaValue:Number,
            xPos:Number, yPos:Number, width:Number, height:Number):void
        {
            g.beginFill(color, alphaValue);
            strokeRect(g, xPos, yPos, width, height);
            g.endFill();
        }

        // Ported/adapted from Aozora Favorites SkyuiLikeMenuPanel.
        private function drawTriangle(g:Graphics, xPos:Number, yPos:Number, size:Number, up:Boolean, color:uint):void
        {
            g.beginFill(color, 0.66);
            if (up) {
                g.moveTo(xPos, yPos - size); g.lineTo(xPos - size, yPos + size); g.lineTo(xPos + size, yPos + size);
            } else {
                g.moveTo(xPos, yPos + size); g.lineTo(xPos - size, yPos - size); g.lineTo(xPos + size, yPos - size);
            }
            g.lineTo(xPos, up ? yPos - size : yPos + size); g.endFill();
        }

        // Adapted from Favorites layer separation; decoration never owns input.
        private function createVisualLayers():void
        {
            backgroundLayer = new Sprite(); silhouetteLayer = new Sprite();
            contentLayer = new Sprite(); themeLayer = new Sprite(); rowLayer = new Sprite();
            if (!mascotLayer) mascotLayer = new Sprite();
            scanlineLayer = new Sprite(); modalLayer = new Sprite();
            backgroundLayer.name = "backgroundLayer"; silhouetteLayer.name = "silhouetteLayer";
            contentLayer.name = "contentLayer"; themeLayer.name = "themeLayer";
            rowLayer.name = "rowLayer"; mascotLayer.name = "mascotLayer";
            scanlineLayer.name = "scanlineLayer"; modalLayer.name = "modalLayer";
            for each (var layer:Sprite in [backgroundLayer, silhouetteLayer, mascotLayer, scanlineLayer]) {
                layer.mouseEnabled = false; layer.mouseChildren = false;
            }
            contentLayer.mouseEnabled = themeLayer.mouseEnabled = rowLayer.mouseEnabled = false;
            modalLayer.mouseEnabled = false;
            addChild(backgroundLayer); addChild(silhouetteLayer); addChild(mascotLayer);
            addChild(contentLayer); contentLayer.addChild(themeLayer); contentLayer.addChild(rowLayer);
            addChild(scanlineLayer); addChild(modalLayer);
            // A4.1: quiet static texture only; no ENTER_FRAME listener.
            scanlineLayer.visible = true;
            visualTarget = themeLayer;
        }

        // Same F4SE texture bridge as Aozora Favorites; no native protocol change.
        public function OnF4SEObjCreated(codeObject:Object):void
        {
            if (!codeObject || !(codeObject.MountImage is Function)) return;
            imageBridge = codeObject;
            scheduleDecorationLoad();
        }

        private function scheduleDecorationLoad():void
        {
            if (!decorationInitialized || !imageBridge || decorationRequested) return;
            // Leave the movie/native initialization stack before requesting a texture.
            addEventListener(Event.ENTER_FRAME, mountHeaderDecoration);
        }

        private function mountHeaderDecoration(event:Event):void
        {
            removeEventListener(Event.ENTER_FRAME, mountHeaderDecoration);
            if (decorationRequested || !imageBridge || !stage) return;
            decorationRequested = true;
            mountWatermarks();
            mountMascots();
            var id:String = "AIE_HeaderMark_A417";
            try {
                if (!imageBridge.MountImage("AozoraItemExtractorMenu",
                    "Interface\\AozoraItemExtractor\\mark-a417.dds", id)) return;
                decorationLoader = new Loader();
                decorationLoader.contentLoaderInfo.addEventListener(Event.COMPLETE, onHeaderDecorationLoaded);
                decorationLoader.contentLoaderInfo.addEventListener(IOErrorEvent.IO_ERROR, onHeaderDecorationError);
                decorationLoader.load(new URLRequest("img://" + id));
            } catch (error:Error) { }
        }

        private function onHeaderDecorationLoaded(event:Event):void
        {
            var info:LoaderInfo = event.currentTarget as LoaderInfo;
            var loader:Loader = info ? info.loader : null;
            var bitmap:Bitmap = loader ? loader.content as Bitmap : null;
            if (!bitmap || !bitmap.bitmapData) return;
            externalImages["mark"] = bitmap;
            // Update only the visual header, not the whole page or random selection.
            if (headerMarkHolder && headerMarkHolder.parent)
                headerMarkHolder.parent.removeChild(headerMarkHolder);
            var width:Number = page == "extract" ? EXTRACT_PANEL_WIDTH : NAV_PANEL_WIDTH;
            var inset:Number = page == "extract" ? EXTRACT_CONTENT_INSET : NAV_CONTENT_INSET;
            drawNativeMark((STAGE_W + width) / 2 - inset - 55,
                (STAGE_H - NAV_PANEL_HEIGHT) / 2 + 38);
        }

        private function onHeaderDecorationError(event:IOErrorEvent):void
        {
            externalImages["mark"] = null;
        }

        private function mountWatermarks():void
        {
            for each (var key:String in ["watermark-nav", "watermark-left", "watermark-right"]) {
                var id:String = "AIE_Watermark_A418_" + key;
                try {
                    if (!imageBridge.MountImage("AozoraItemExtractorMenu",
                        "Interface\\AozoraItemExtractor\\" + key + "-a418.dds", id)) continue;
                    var loader:Loader = new Loader();
                    loader.name = key;
                    loader.contentLoaderInfo.addEventListener(Event.COMPLETE, onWatermarkLoaded);
                    loader.contentLoaderInfo.addEventListener(IOErrorEvent.IO_ERROR, onWatermarkError);
                    watermarkLoaders.push(loader);
                    loader.load(new URLRequest("img://" + id));
                } catch (error:Error) { }
            }
        }

        private function onWatermarkLoaded(event:Event):void
        {
            var info:LoaderInfo = event.currentTarget as LoaderInfo;
            var loader:Loader = info ? info.loader : null;
            var bitmap:Bitmap = loader ? loader.content as Bitmap : null;
            if (!bitmap || !bitmap.bitmapData) return;
            externalImages[loader.name] = bitmap;
            refreshWatermarks();
        }

        private function onWatermarkError(event:IOErrorEvent):void { }

        private function refreshWatermarks():void
        {
            if (!silhouetteLayer || !useDefaultArtwork) return;
            while (silhouetteLayer.numChildren) silhouetteLayer.removeChildAt(0);
            if (page == "nav") {
                prepareWatermarkSlot((STAGE_W - NAV_PANEL_WIDTH) / 2 + NAV_CONTENT_INSET +
                    (NAV_PANEL_WIDTH - NAV_CONTENT_INSET * 2) * 0.68,
                    (STAGE_H - NAV_PANEL_HEIGHT) / 2 + NAV_LIST_TOP + NAV_LIST_HEIGHT * 0.74);
            } else {
                var bounds:Object = extractionBounds();
                prepareWatermarkSlot(Number(bounds.leftX) + Number(bounds.leftW) / 2,
                    Number(bounds.columnY) + EXTRACT_COLUMNS_HEIGHT * 0.74, "left");
                prepareWatermarkSlot(Number(bounds.rightX) + Number(bounds.rightW) / 2,
                    Number(bounds.columnY) + EXTRACT_COLUMNS_HEIGHT * 0.74, "right");
            }
        }

        private function mountMascots():void
        {
            for each (var key:String in ["peek1", "peek2", "peek3", "corner1", "corner2", "corner3", "corner4"]) {
                var id:String = "AIE_Mascot_A419_" + key;
                try {
                    if (!imageBridge.MountImage("AozoraItemExtractorMenu",
                        "Interface\\AozoraItemExtractor\\" + key + "-a419.dds", id)) continue;
                    var loader:Loader = new Loader();
                    loader.name = key;
                    loader.contentLoaderInfo.addEventListener(Event.COMPLETE, onMascotTextureLoaded);
                    loader.contentLoaderInfo.addEventListener(IOErrorEvent.IO_ERROR, onMascotTextureError);
                    mascotLoaders.push(loader);
                    loader.load(new URLRequest("img://" + id));
                } catch (error:Error) { }
            }
        }

        private function onMascotTextureLoaded(event:Event):void
        {
            var info:LoaderInfo = event.currentTarget as LoaderInfo;
            var loader:Loader = info ? info.loader : null;
            var bitmap:Bitmap = loader ? loader.content as Bitmap : null;
            if (!bitmap || !bitmap.bitmapData) return;
            var holder:Sprite = new Sprite();
            holder.mouseEnabled = false; holder.mouseChildren = false;
            bitmap.smoothing = true;
            // Restore original aspect ratio after standardizing runtime DDS dimensions.
            bitmap.width = loader.name.indexOf("peek") == 0 ? 1024 : 1122;
            bitmap.height = loader.name.indexOf("peek") == 0 ? 1536 : 1402;
            holder.addChild(bitmap);
            mascotDisplays[loader.name] = holder;
            if (mascotKey == loader.name && mascotLayer) renderMascot();
        }

        private function onMascotTextureError(event:IOErrorEvent):void { }

        private function externalBitmap(key:String):DisplayObject
        {
            // Cached assets only. Drawing never starts a load.
            if (key.indexOf("peek") == 0 || key.indexOf("corner") == 0)
                return mascotDisplays[key] as DisplayObject;
            return key == "mark" || key.indexOf("watermark-") == 0 ? externalImages[key] as Bitmap : null;
        }

        private function onMascotAdded(event:Event):void
        {
            // These events bubble from descendants during visual-layer rebuilding.
            // Only the menu panel itself entering stage starts a new opening.
            if (event.target != this) return;
            if (stage) stage.addEventListener(Event.RESIZE, onMascotResize);
            mascotPage = "";
            if (mascotLayer) renderMascot();
        }

        private function onMascotRemoved(event:Event):void
        {
            if (event.target != this) return;
            pluginSearchTimer.stop();
            if (stage) stage.removeEventListener(Event.RESIZE, onMascotResize);
            mascotPage = "";
        }

        private function onMascotResize(event:Event):void
        {
            positionMascot();
        }

        // Selection persists through snapshot, row, category and theme redraws.
        private function renderMascot():void
        {
            mascotLayer.visible = mascotEnabled;
            if (!mascotEnabled) return;
            if (mascotPage != page || !mascotKey.length) {
                var count:int = page == "extract" ? 4 : 3;
                var previous:int = page == "extract" ? lastCornerIndex : lastPeekIndex;
                var choice:int = int(Math.random() * (previous < 0 ? count : count - 1));
                if (previous >= 0 && choice >= previous) ++choice;
                if (page == "extract") lastCornerIndex = choice;
                else lastPeekIndex = choice;
                mascotKey = (page == "extract" ? "corner" : "peek") + (choice + 1);
                mascotPage = page;
            }
            // Loading completion and page return always use the chosen cached asset.
            mascotArtwork = externalBitmap(mascotKey);
            if (!mascotArtwork) {
                while (mascotLayer.numChildren) mascotLayer.removeChildAt(0);
                return;
            }
            if (mascotArtwork.parent != mascotLayer) {
                while (mascotLayer.numChildren) mascotLayer.removeChildAt(0);
                mascotLayer.addChild(mascotArtwork);
            }
            positionMascot();
        }

        private function positionMascot():void
        {
            if (!mascotArtwork || !mascotLayer) return;
            // Native kShowAll scales the authored 1280x720 movie outside AS3.
            // Use resolution aspect only; do not mix physical pixels with UI units.
            var aspect:Number = stage && stage.stageHeight > 0 ?
                stage.stageWidth / stage.stageHeight : STAGE_W / STAGE_H;
            var viewportW:Number = Math.max(STAGE_W, STAGE_H * aspect);
            var viewportH:Number = Math.max(STAGE_H, STAGE_W / aspect);
            var lo:Point = new Point((STAGE_W - viewportW) / 2, (STAGE_H - viewportH) / 2);
            var hi:Point = new Point(lo.x + viewportW, lo.y + viewportH);
            // The DDS display holder already restores these source dimensions.
            // Avoid querying reparented GFx Bitmap bounds during a page transition.
            var bounds:Rectangle = mascotKey.indexOf("peek") == 0 ?
                new Rectangle(0, 0, 1024, 1536) : new Rectangle(0, 0, 1122, 1402);
            var panelWidth:Number = page == "extract" ? EXTRACT_PANEL_WIDTH : NAV_PANEL_WIDTH;
            var panelLeft:Number = (STAGE_W - panelWidth) / 2;
            var panelRight:Number = panelLeft + panelWidth;
            var gap:Number = Math.max(0, hi.x - panelRight - 2);
            var cap:Number = page == "extract" ? 360 : 315;
            // A little of the character continues behind the panel edge.
            var overlap:Number = page == "extract" ? 84 : 0;
            var scale:Number = Math.max(0, Math.min((gap + overlap) / bounds.width,
                Math.min(cap, (hi.y - lo.y) * 0.72) / bounds.height));
            mascotArtwork.scaleX = scale;
            mascotArtwork.scaleY = scale;
            mascotArtwork.visible = scale > 0;
            mascotArtwork.x = page == "extract" ? hi.x - bounds.right * scale :
                panelRight - 10 - bounds.left * scale;
            mascotArtwork.y = page == "extract" ? hi.y - bounds.bottom * scale :
                lo.y + (hi.y - lo.y - bounds.height * scale) * 0.52 - bounds.top * scale;
            // No scrollRect: its GFx rendering produced a red rectangular artifact.
            // Keep the artwork outside the panel through placement and fitting instead.
            mascotLayer.scrollRect = null;
            mascotLayer.x = mascotLayer.y = 0;

            updateMascotTip();
        }

        private function updateMascotTip():void
        {
            if (mascotTip && mascotTip.parent) mascotTip.parent.removeChild(mascotTip);
            mascotTip = null;
            if (!mascotEnabled || !mascotLayer || !mascotArtwork || mascotArtwork.parent != mascotLayer || !mascotArtwork.visible || modalOpen) return;
            var key:String = "$AIE_MASCOT_SEARCH_TIP";
            if (page == "extract") {
                var item:Object = currentItem();
                if (pane != "right" || !item) return;
                if (String(item.category) == "ammo") key = "$AIE_MASCOT_AMMO_GROUP_TIP";
                else if (uint(item.starterAmmoCount || 0) > 0) key = "$AIE_MASCOT_AMMO_TIP";
                else return;
            }
            var panelWidth:Number = page == "extract" ? EXTRACT_PANEL_WIDTH : NAV_PANEL_WIDTH;
            var panelRight:Number = (STAGE_W + panelWidth) / 2;
            var aspect:Number = stage && stage.stageHeight > 0 ? stage.stageWidth / stage.stageHeight : STAGE_W / STAGE_H;
            var viewportWidth:Number = Math.max(STAGE_W, STAGE_H * aspect);
            var screenRight:Number = (STAGE_W + viewportWidth) / 2;
            var available:Number = screenRight - panelRight - 18;
            if (available < 120) return;
            mascotTip = new Sprite();
            mascotTip.name = "mascotTip";
            mascotTip.mouseEnabled = false; mascotTip.mouseChildren = false;
            var field:TextField = makeText(key, 14, 10, 16, themeColor(0.98), false);
            if (key == "$AIE_MASCOT_AMMO_GROUP_TIP")
                field.text = field.text.replace("{count}", String(uint(item.group || 1)));
            // Localized game fonts retain Chinese glyph support. Chinese gets a
            // shorter measure; English needs more room for words and spaces.
            var chinese:Boolean = false;
            for (var i:int = 0; i < field.text.length; i++) {
                var code:uint = field.text.charCodeAt(i);
                if (code >= 0x3400 && code <= 0x9FFF) { chinese = true; break; }
            }
            var width:Number = Math.min(chinese ? 204 : 232, available);
            var size:Number = chinese ? 15 : 16;
            field.autoSize = TextFieldAutoSize.NONE;
            field.width = width - 28; field.height = 240;
            field.wordWrap = true; field.multiline = true;
            field.mouseEnabled = false; field.selectable = false;
            var format:TextFormat = makeFormat(size, themeColor(0.98), 1, false, "left");
            format.leading = chinese ? 5 : 3;
            field.defaultTextFormat = format; field.setTextFormat(format);
            field.height = Math.ceil(field.textHeight) + 8;
            var height:Number = Math.max(58, field.height + 20);
            // Source-space top-of-hair and head-center anchors for all seven poses.
            var heads:Object = {
                peek1: [440, 12], peek2: [450, 120], peek3: [435, 90],
                corner1: [810, 210], corner2: [740, 130],
                corner3: [780, 115], corner4: [780, 209]
            };
            var head:Array = heads[mascotKey] as Array;
            if (!head) head = [700, 150];
            var headX:Number = mascotArtwork.x + Number(head[0]) * mascotArtwork.scaleX;
            var headY:Number = mascotArtwork.y + Number(head[1]) * mascotArtwork.scaleY;
            mascotTip.x = clamp(headX - width * 0.55, panelRight + 8, screenRight - width - 10);
            mascotTip.y = Math.max(16, headY - height - 14);
            var tail:Number = clamp(headX - mascotTip.x, 20, width - 20);
            var g:Graphics = mascotTip.graphics;
            g.lineStyle(1, themeColor(0.76), 0.65);
            // One continuous fill keeps the translucent tail free of dark seams.
            g.beginFill(panelBackground, MENU_SURFACE_ALPHA);
            g.moveTo(10, 0); g.lineTo(width - 10, 0);
            g.curveTo(width, 0, width, 10); g.lineTo(width, height - 10);
            g.curveTo(width, height, width - 10, height);
            g.lineTo(tail + 7, height); g.lineTo(tail + 1, height + 9);
            g.lineTo(tail - 7, height); g.lineTo(10, height);
            g.curveTo(0, height, 0, height - 10); g.lineTo(0, 10);
            g.curveTo(0, 0, 10, 0); g.endFill();
            mascotTip.filters = [new DropShadowFilter(2, 90, 0x000000, 0.16, 3, 3, 1, 1)];
            mascotTip.addChild(field);
            mascotLayer.addChild(mascotTip);
        }

        // Compatible AS3 artwork hook only; no loader, native callback or pose cycling.
        public function SetDecorativeArtwork(value:DisplayObject):void
        {
            useDefaultArtwork = false;
            decorativeArtwork = value;
            render();
        }

        private function clamp(value:Number, low:Number, high:Number):Number
        {
            return Math.max(low, Math.min(value, high));
        }
    }
}
