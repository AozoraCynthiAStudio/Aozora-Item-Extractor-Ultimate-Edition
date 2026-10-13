#ifndef NOMINMAX
#define NOMINMAX
#endif
#include "ScaleformMenu.h"
#include "PreviewSpike.h"

#include <algorithm>
#include <array>
#include <charconv>
#include <cstdint>
#include <memory>
#include <mutex>
#include <string>
#include <string_view>
#include <utility>

#include "F4SE/F4SE.h"
#include "RE/B/BSScaleformManager.h"
#include "RE/B/BS_BUTTON_CODE.h"
#include "RE/B/ButtonEvent.h"
#include "RE/C/ControlMap.h"
#include "RE/Fallout.h"
#include "RE/G/GameMenuBase.h"
#include "RE/I/INPUT_EVENT_TYPE.h"
#include "RE/M/MenuOpenCloseEvent.h"
#include "RE/M/MenuControls.h"
#include "RE/S/SWFToCodeFunctionHandler.h"
#include "RE/T/ThumbstickEvent.h"
#include "RE/U/UI.h"
#include "RE/U/UIMessageQueue.h"
#include "RE/U/UI_MENU_FLAGS.h"
#include "RE/U/UI_MESSAGE_TYPE.h"
#include "Scaleform/G/GFx_ASMovieRootBase.h"
#include <Windows.h>

namespace AIE::ScaleformUI
{
    namespace
    {
        constexpr std::string_view kMenuName = "AozoraItemExtractorMenu";
        constexpr std::string_view kMoviePath = "Interface/AozoraItemExtractorMenu.swf";
        constexpr std::int32_t kConsoleKey = 0xC0;

        void EnsureItemExtractorTranslations(RE::BSScaleformManager* scaleform)
        {
            static bool loaded = false;
            if (loaded || !scaleform || !scaleform->loader) return;
            auto* translator = scaleform->GetTranslator();
            if (!translator) return;
            translator->AddTranslationsMod("AozoraItemExtractor");
            translator->Release();
            loaded = true;
        }

        enum class NativeFunction : std::intptr_t
        {
            kInitialize,
            kClose,
            kEnterPlugin,
            kEndSession,
            kTransferItem,
            kTakeAll,
            kReturnAll,
            kSearchFocus,
            kSearchPluginsAndItems
        };

        using FunctionParams = Scaleform::GFx::FunctionHandler::Params;

        std::mutex g_stateMutex;
        Snapshot g_snapshot;
        Callbacks g_callbacks;
        class ItemExtractorMenu;
        ItemExtractorMenu* g_menu{ nullptr };
        bool g_registered{ false };
        bool g_searchFocused{ false };
        bool g_hidden{ false };
        bool g_textEntryOwned{ false };

        const char* g_textEntryBridgePath{ nullptr };
        void SetSearchTextEntryMode(bool enabled);

        void ClearSearchTextEntry()
        {
            SetSearchTextEntryMode(false);
            g_searchFocused = false;
            if (g_callbacks.searchFocus) g_callbacks.searchFocus(false);
        }

        std::uint32_t ParamUInt32(const FunctionParams& params, std::uint32_t index)
        {
            if (!params.args || index >= params.argCount) return 0;
            const auto& value = params.args[index];
            if (value.IsUInt()) return value.GetUInt();
            if (value.IsInt()) return value.GetInt() >= 0 ? static_cast<std::uint32_t>(value.GetInt()) : 0;
            if (value.IsNumber()) return value.GetNumber() >= 0.0 ? static_cast<std::uint32_t>(value.GetNumber()) : 0;
            if (value.IsString() && value.GetString()) {
                std::uint32_t parsed = 0;
                const auto* first = value.GetString();
                const auto* last = first + std::char_traits<char>::length(first);
                std::from_chars(first, last, parsed, 10);
                return parsed;
            }
            return 0;
        }

        std::string ParamString(const FunctionParams& params, std::uint32_t index)
        {
            if (!params.args || index >= params.argCount || !params.args[index].IsString() ||
                !params.args[index].GetString()) return {};
            return params.args[index].GetString();
        }

        bool ParamBool(const FunctionParams& params, std::uint32_t index)
        {
            if (!params.args || index >= params.argCount) return false;
            const auto& value = params.args[index];
            if (value.IsBoolean()) return value.GetBoolean();
            if (value.IsNumber()) return value.GetNumber() != 0.0;
            return false;
        }

        class DirectFunctionHandler final : public Scaleform::GFx::FunctionHandler
        {
        public:
            void Call(const Params& params) override;
        };

        class ItemExtractorMenu final : public RE::GameMenuBase
        {
        public:
            static constexpr std::string_view MENU_NAME = kMenuName;
            static constexpr std::string_view MOVIE_PATH = kMoviePath;

            ItemExtractorMenu()
            {
                menuFlags.set(RE::UI_MENU_FLAGS::kModal);
                menuFlags.set(RE::UI_MENU_FLAGS::kPausesGame);
                menuFlags.set(RE::UI_MENU_FLAGS::kUsesBlurredBackground);
                menuFlags.set(RE::UI_MENU_FLAGS::kUsesMenuContext);
                menuFlags.set(RE::UI_MENU_FLAGS::kUsesCursor);
                menuFlags.set(RE::UI_MENU_FLAGS::kUpdateUsesCursor);
                menuFlags.set(RE::UI_MENU_FLAGS::kUsesMovementToDirection);
                menuFlags.set(RE::UI_MENU_FLAGS::kAllowSaving);
                depthPriority = RE::UI_DEPTH_PRIORITY::kStandard;
                inputContext = RE::UserEvents::INPUT_CONTEXT_ID::kQuickContainerMenu;

                MapCodeObjectFunctions();
                auto* scaleform = RE::BSScaleformManager::GetSingleton();
                EnsureItemExtractorTranslations(scaleform);
                bool loaded = scaleform && scaleform->LoadMovie(
                    *this, uiMovie, MENU_NAME.data(), "root1.BGSCodeObj",
                    Scaleform::GFx::Movie::ScaleModeType::kShowAll, 0.0F);
                if (!loaded && scaleform) {
                    loaded = scaleform->LoadMovieEx(
                        *this, MOVIE_PATH.data(), "root1.BGSCodeObj",
                        Scaleform::GFx::Movie::ScaleModeType::kShowAll, 0.0F);
                }
                if (loaded) {
                    g_menu = this;
                    InstallDirectCodeObjectFunctions();
                }
            }

            ~ItemExtractorMenu() override
            {
                ClearSearchTextEntry();
                EndHUDIsolation();
                if (g_menu == this) g_menu = nullptr;
            }

#ifdef AIE_PREVIEW_SPIKE
            AIE::PreviewSpike::Probe previewProbe_;
            void AdvanceMovie(float delta, std::uint64_t time) override
            {
                RE::GameMenuBase::AdvanceMovie(delta, time);
                bool extraction = false;
                {
                    std::lock_guard lock(g_stateMutex);
                    extraction = g_snapshot.page != "nav" && !g_hidden;
                }
                previewProbe_.Tick(uiMovie.get(), extraction);
            }
#endif

            void MapCodeObjectFunctions() override
            {
                MapCodeMethodToASFunction("Initialize", static_cast<std::int32_t>(NativeFunction::kInitialize));
                MapCodeMethodToASFunction("Close", static_cast<std::int32_t>(NativeFunction::kClose));
                MapCodeMethodToASFunction("EnterPlugin", static_cast<std::int32_t>(NativeFunction::kEnterPlugin));
                MapCodeMethodToASFunction("EndSession", static_cast<std::int32_t>(NativeFunction::kEndSession));
                MapCodeMethodToASFunction("TransferItem", static_cast<std::int32_t>(NativeFunction::kTransferItem));
                MapCodeMethodToASFunction("TakeAll", static_cast<std::int32_t>(NativeFunction::kTakeAll));
                MapCodeMethodToASFunction("ReturnAll", static_cast<std::int32_t>(NativeFunction::kReturnAll));
                MapCodeMethodToASFunction("SearchFocus", static_cast<std::int32_t>(NativeFunction::kSearchFocus));
                MapCodeMethodToASFunction("SearchPluginsAndItems", static_cast<std::int32_t>(NativeFunction::kSearchPluginsAndItems));
            }

            void InstallDirectCodeObjectFunctions()
            {
                if (!uiMovie) return;
                Scaleform::GFx::Value codeObject;
                if (!uiMovie->GetVariable(std::addressof(codeObject), "root1.BGSCodeObj") || !codeObject.IsObject()) return;
                constexpr std::array functions{
                    std::pair{ "Initialize", NativeFunction::kInitialize },
                    std::pair{ "Close", NativeFunction::kClose },
                    std::pair{ "EnterPlugin", NativeFunction::kEnterPlugin },
                    std::pair{ "EndSession", NativeFunction::kEndSession },
                    std::pair{ "TransferItem", NativeFunction::kTransferItem },
                    std::pair{ "TakeAll", NativeFunction::kTakeAll },
                    std::pair{ "ReturnAll", NativeFunction::kReturnAll },
                    std::pair{ "SearchFocus", NativeFunction::kSearchFocus },
                    std::pair{ "SearchPluginsAndItems", NativeFunction::kSearchPluginsAndItems }
                };
                for (const auto& [name, function] : functions) {
                    auto* handler = new DirectFunctionHandler();
                    Scaleform::GFx::Value callback;
                    uiMovie->CreateFunction(std::addressof(callback), handler,
                        reinterpret_cast<void*>(static_cast<std::intptr_t>(function)));
                    codeObject.SetMember(name, callback);
                    handler->Release();
                }
            }

            void Call(const Params& params) override
            {
                const auto function = static_cast<NativeFunction>(reinterpret_cast<std::intptr_t>(params.userData));
                Callbacks callbacks;
                {
                    std::lock_guard lock(g_stateMutex);
                    callbacks = g_callbacks;
                }
                switch (function) {
                case NativeFunction::kInitialize:
                    if (callbacks.initialize) callbacks.initialize();
                    PushSnapshot();
                    break;
                case NativeFunction::kClose:
                    if (callbacks.close) callbacks.close();
                    break;
                case NativeFunction::kEnterPlugin:
                    if (callbacks.enterPlugin) callbacks.enterPlugin(ParamString(params, 0));
                    break;
                case NativeFunction::kEndSession:
                    if (callbacks.endSession) callbacks.endSession();
                    break;
                case NativeFunction::kTransferItem:
                    if (callbacks.transferItem) callbacks.transferItem(
                        ParamUInt32(params, 0), ParamBool(params, 1), ParamUInt32(params, 2));
                    break;
                case NativeFunction::kTakeAll:
                    if (callbacks.takeAll) callbacks.takeAll();
                    break;
                case NativeFunction::kReturnAll:
                    if (callbacks.returnAll) callbacks.returnAll();
                    break;
                case NativeFunction::kSearchPluginsAndItems:
                    if (callbacks.searchPluginsAndItems) callbacks.searchPluginsAndItems(ParamString(params, 0));
                    break;
                case NativeFunction::kSearchFocus:
                    g_searchFocused = ParamBool(params, 0);
                    SetSearchTextEntryMode(g_searchFocused && !g_hidden);
                    if (callbacks.searchFocus) callbacks.searchFocus(g_searchFocused);
                    break;
                default:
                    break;
                }
            }

            void OnAddedToMenuStack() override
            {
                RE::GameMenuBase::OnAddedToMenuStack();
                g_menu = this;
                PushSnapshot();
                // Acquire only after stack entry and a usable extractor movie.
                if (uiMovie && uiMovie->asMovieRoot) BeginHUDIsolation();
            }

            void OnRemovedFromMenuStack() override
            {
                ClearSearchTextEntry();
#ifdef AIE_PREVIEW_SPIKE
                previewProbe_.Clear();
#endif
                EndHUDIsolation();
                Callbacks callbacks;
                {
                    std::lock_guard lock(g_stateMutex);
                    callbacks = g_callbacks;
                }
                if (callbacks.removedFromStack) callbacks.removedFromStack();
                RE::GameMenuBase::OnRemovedFromMenuStack();
            }

            bool ShouldHandleEvent(const RE::InputEvent* event) override
            {
                if (!event || !OnStack() || g_hidden) return false;
                if (event->eventType == RE::INPUT_EVENT_TYPE::kChar) {
                    return g_searchFocused && event->device == RE::INPUT_DEVICE::kKeyboard;
                }
                if (event->eventType != RE::INPUT_EVENT_TYPE::kButton &&
                    event->eventType != RE::INPUT_EVENT_TYPE::kThumbstick) return false;
                if (event->device == RE::INPUT_DEVICE::kKeyboard &&
                    event->eventType == RE::INPUT_EVENT_TYPE::kButton) {
                    const auto* button = static_cast<const RE::ButtonEvent*>(event);
                    if (static_cast<std::int32_t>(button->GetBSButtonCode()) == kConsoleKey) return false;
                }
                return true;
            }

            void OnButtonEvent(const RE::ButtonEvent* event) override
            {
                if (!event) return;
                if (event->device == RE::INPUT_DEVICE::kMouse) {
                    RE::IMenu::OnButtonEvent(event);
                    return;
                }
                if (!event->QJustPressed()) {
                    const_cast<RE::ButtonEvent*>(event)->handled = RE::InputEvent::HANDLED_RESULT::kStop;
                    return;
                }

                const auto code = static_cast<std::int32_t>(event->GetBSButtonCode());
                if (event->device == RE::INPUT_DEVICE::kKeyboard && g_searchFocused) {
                    auto* handledEvent = const_cast<RE::ButtonEvent*>(event);
                    handledEvent->handled = RE::InputEvent::HANDLED_RESULT::kStop;
                    const auto button = static_cast<RE::BS_BUTTON_CODE>(code);
                    // Pass standard Ctrl editing commands to the focused input
                    // field (and optional Scaleform copy/paste plugins).
                    if ((GetAsyncKeyState(0x11) & 0x8000) != 0 &&
                        (button == RE::BS_BUTTON_CODE::kA || button == RE::BS_BUTTON_CODE::kC ||
                         button == RE::BS_BUTTON_CODE::kV || button == RE::BS_BUTTON_CODE::kX)) {
                        handledEvent->handled = RE::InputEvent::HANDLED_RESULT::kUnhandled;
                        RE::IMenu::OnButtonEvent(event);
                        return;
                    }
                    if (button == RE::BS_BUTTON_CODE::kEscape || button == RE::BS_BUTTON_CODE::kTab) {
                        SendKey("back");
                        return;
                    }
                    if (button == RE::BS_BUTTON_CODE::kEnter) {
                        InvokePanel("root1.Menu_mc.FinishSearch");
                    } else if (button == RE::BS_BUTTON_CODE::kBackspace) {
                        InvokePanel("root1.Menu_mc.HandleSearchBackspace");
                    } else if (button == RE::BS_BUTTON_CODE::kDelete) {
                        InvokePanel("root1.Menu_mc.HandleSearchDelete");
                    } else if (button == RE::BS_BUTTON_CODE::kLeft || button == RE::BS_BUTTON_CODE::kRight) {
                        Scaleform::GFx::Value delta(button == RE::BS_BUTTON_CODE::kLeft ? -1 : 1);
                        InvokePanel("root1.Menu_mc.MoveSearchCaret", std::addressof(delta), 1);
                    }
                    return;
                }

                std::string_view key;
                if (event->device == RE::INPUT_DEVICE::kKeyboard) {
                    if (code >= static_cast<std::int32_t>(RE::BS_BUTTON_CODE::kA) &&
                        code <= static_cast<std::int32_t>(RE::BS_BUTTON_CODE::kZ)) {
                        switch (static_cast<RE::BS_BUTTON_CODE>(code)) {
                        case RE::BS_BUTTON_CODE::kE: key = "confirm"; break;
                        case RE::BS_BUTTON_CODE::kF: key = "search"; break;
                        case RE::BS_BUTTON_CODE::kQ: key = "batch"; break;
                        case RE::BS_BUTTON_CODE::kR: key = "take-all"; break;
                        case RE::BS_BUTTON_CODE::kZ: key = "category-prev"; break;
                        case RE::BS_BUTTON_CODE::kC: key = "category-next"; break;
                        default:
                            keyBuffer_[0] = static_cast<char>('a' + code - static_cast<std::int32_t>(RE::BS_BUTTON_CODE::kA));
                            key = std::string_view(keyBuffer_, 1);
                            break;
                        }
                    } else {
                        switch (static_cast<RE::BS_BUTTON_CODE>(code)) {
                        case RE::BS_BUTTON_CODE::kUp: key = "up"; break;
                        case RE::BS_BUTTON_CODE::kDown: key = "down"; break;
                        case RE::BS_BUTTON_CODE::kLeft: key = "left"; break;
                        case RE::BS_BUTTON_CODE::kRight: key = "right"; break;
                        case RE::BS_BUTTON_CODE::kEnter: key = "confirm"; break;
                        case RE::BS_BUTTON_CODE::kEscape: key = "back"; break;
                        case RE::BS_BUTTON_CODE::kTab: key = "back"; break;
                        case RE::BS_BUTTON_CODE::kF: key = "search"; break;
                        case RE::BS_BUTTON_CODE::kQ: key = "batch"; break;
                        case RE::BS_BUTTON_CODE::kR: key = "take-all"; break;
                        case RE::BS_BUTTON_CODE::kZ: key = "category-prev"; break;
                        case RE::BS_BUTTON_CODE::kC: key = "category-next"; break;
                        default: break;
                        }
                    }
                } else if (event->device == RE::INPUT_DEVICE::kGamepad) {
                    switch (static_cast<RE::BS_BUTTON_CODE>(code)) {
                    case RE::BS_BUTTON_CODE::kAButton: key = "confirm"; break;
                    case RE::BS_BUTTON_CODE::kBButton:
                    case RE::BS_BUTTON_CODE::kBack: key = "back"; break;
                    case RE::BS_BUTTON_CODE::kYButton: key = "search"; break;
                    case RE::BS_BUTTON_CODE::kXButton: key = "take-all"; break;
                    case RE::BS_BUTTON_CODE::kDPAD_Up: key = "up"; break;
                    case RE::BS_BUTTON_CODE::kDPAD_Down: key = "down"; break;
                    case RE::BS_BUTTON_CODE::kDPAD_Left: key = "left"; break;
                    case RE::BS_BUTTON_CODE::kDPAD_Right: key = "right"; break;
                    case RE::BS_BUTTON_CODE::kLTrigger: key = "category-prev"; break;
                    case RE::BS_BUTTON_CODE::kRTrigger: key = "category-next"; break;
                    default: break;
                    }
                }
                const_cast<RE::ButtonEvent*>(event)->handled = RE::InputEvent::HANDLED_RESULT::kStop;
                if (!key.empty()) SendKey(std::string(key).c_str(),
                    event->device == RE::INPUT_DEVICE::kGamepad ? 2 : 1);
            }

            void OnCharacterEvent(const RE::CharacterEvent* event) override
            {
                if (!event || !g_searchFocused || event->charCode < 0x20 || event->charCode == 0x7F) return;
                const_cast<RE::CharacterEvent*>(event)->handled = RE::InputEvent::HANDLED_RESULT::kStop;
                if (event->charCode >= 0x80)
                    REX::INFO("[AIE] SEARCH_UNICODE code={}", event->charCode);
                Scaleform::GFx::Value character(event->charCode);
                InvokePanel("root1.Menu_mc.HandleSearchCharacter", std::addressof(character), 1);
            }

            void OnThumbstickEvent(const RE::ThumbstickEvent* event) override
            {
                if (!event) return;
                if (event->QIDCode() == RE::ThumbstickEvent::kRight) {
                    const_cast<RE::ThumbstickEvent*>(event)->handled = RE::InputEvent::HANDLED_RESULT::kStop;
                    Scaleform::GFx::Value axis(static_cast<double>(event->yValue));
                    InvokePanel("root1.Menu_mc.HandleRightStickAxis", std::addressof(axis), 1);
                    return;
                }
                if (event->QIDCode() != RE::ThumbstickEvent::kLeft ||
                    event->prevDir == event->currDir || event->currDir == RE::DIRECTION_VAL::kNone) return;
                const_cast<RE::ThumbstickEvent*>(event)->handled = RE::InputEvent::HANDLED_RESULT::kStop;
                switch (event->currDir) {
                case RE::DIRECTION_VAL::kUp: SendKey("up", 2); break;
                case RE::DIRECTION_VAL::kDown: SendKey("down", 2); break;
                case RE::DIRECTION_VAL::kLeft: SendKey("left", 2); break;
                case RE::DIRECTION_VAL::kRight: SendKey("right", 2); break;
                default: break;
                }
            }

            void PushPluginSearchResults(const PluginSearchResponse& response)
            {
                if (!uiMovie || !uiMovie->asMovieRoot) return;
                Scaleform::GFx::Value results;
                uiMovie->CreateArray(std::addressof(results));
                for (const auto& row : response.results) {
                    Scaleform::GFx::Value item;
                    uiMovie->CreateObject(std::addressof(item));
                    SetString(item, "name", row.name);
                    SetString(item, "kind", row.light ? "ESL" : "ESP");
                    item.SetMember("matchCount", Scaleform::GFx::Value(row.matchCount));
                    item.SetMember("pluginNameMatch", Scaleform::GFx::Value(row.pluginNameMatch));
                    results.PushBack(item);
                }
                Scaleform::GFx::Value args[3];
                args[0] = Scaleform::GFx::Value(response.query.c_str());
                args[1] = results;
                args[2] = Scaleform::GFx::Value(response.totalItemMatches);
                InvokePanel("root1.Menu_mc.ApplyPluginSearchResults", args, 3);
            }

            void PushSnapshot()
            {
                if (!uiMovie || !uiMovie->asMovieRoot) return;
                Snapshot snapshotData;
                {
                    std::lock_guard lock(g_stateMutex);
                    snapshotData = g_snapshot;
                }
                Scaleform::GFx::Value snapshot;
                Scaleform::GFx::Value plugins;
                uiMovie->CreateArray(std::addressof(plugins));
                for (const auto& row : snapshotData.plugins) {
                    Scaleform::GFx::Value item;
                    uiMovie->CreateObject(std::addressof(item));
                    SetString(item, "name", row.name);
                    SetString(item, "kind", row.light ? "ESL" : "ESP");
                    plugins.PushBack(item);
                }
                Scaleform::GFx::Value items;
                CreateItems(items, snapshotData.items);
                Scaleform::GFx::Value session;
                CreateItems(session, snapshotData.session);
                uiMovie->CreateObject(std::addressof(snapshot));
                snapshot.SetMember("plugins", plugins);
                snapshot.SetMember("items", items);
                snapshot.SetMember("session", session);
                snapshot.SetMember("page", Scaleform::GFx::Value(snapshotData.page.c_str()));
                snapshot.SetMember("plugin", Scaleform::GFx::Value(snapshotData.plugin.c_str()));
                snapshot.SetMember("inputMode", Scaleform::GFx::Value(snapshotData.inputMode.c_str()));
                Scaleform::GFx::Value theme;
                uiMovie->CreateObject(std::addressof(theme));
                theme.SetMember("mode", Scaleform::GFx::Value(snapshotData.theme.mode));
                theme.SetMember("preset", Scaleform::GFx::Value(snapshotData.theme.preset));
                theme.SetMember("r", Scaleform::GFx::Value(snapshotData.theme.r));
                theme.SetMember("g", Scaleform::GFx::Value(snapshotData.theme.g));
                theme.SetMember("b", Scaleform::GFx::Value(snapshotData.theme.b));
                snapshot.SetMember("theme", theme);
                snapshot.SetMember("mascotEnabled", Scaleform::GFx::Value(snapshotData.mascotEnabled));
                uiMovie->Invoke("root1.Menu_mc.ApplySnapshot", nullptr, std::addressof(snapshot), 1);
            }

        private:
            void InvokePanel(const char* function, const Scaleform::GFx::Value* args = nullptr, std::uint32_t argCount = 0)
            {
                if (uiMovie && uiMovie->asMovieRoot) {
                    uiMovie->Invoke(function, nullptr, args, argCount);
                }
            }

            void SetString(Scaleform::GFx::Value& target, const char* key, const std::string& value)
            {
                Scaleform::GFx::Value stringValue;
                uiMovie->asMovieRoot->CreateString(std::addressof(stringValue), value.c_str());
                target.SetMember(key, stringValue);
            }

            void SetString(Scaleform::GFx::Value& target, const char* key, const char* value)
            {
                Scaleform::GFx::Value stringValue;
                uiMovie->asMovieRoot->CreateString(std::addressof(stringValue), value);
                target.SetMember(key, stringValue);
            }

            void CreateItems(Scaleform::GFx::Value& array, const std::vector<ItemRow>& source)
            {
                uiMovie->CreateArray(std::addressof(array));
                for (const auto& row : source) {
                    Scaleform::GFx::Value item;
                    uiMovie->CreateObject(std::addressof(item));
                    item.SetMember("formID", Scaleform::GFx::Value(row.formID));
                    item.SetMember("count", Scaleform::GFx::Value(row.count));
                    item.SetMember("group", Scaleform::GFx::Value(row.group));
                    item.SetMember("returnable", Scaleform::GFx::Value(row.returnable));
                    SetString(item, "name", row.name);
                    SetString(item, "category", row.category);
                    SetString(item, "iconLibrary", row.iconLibrary);
                    SetString(item, "iconClass", row.iconClass);
                    item.SetMember("starterAmmoCount", Scaleform::GFx::Value(row.starterAmmoCount));
                    array.PushBack(item);
                }
            }

        public:
            void PushSession()
            {
                if (!uiMovie || !uiMovie->asMovieRoot) return;
                std::vector<ItemRow> session;
                {
                    std::lock_guard lock(g_stateMutex);
                    session = g_snapshot.session;
                }
                Scaleform::GFx::Value sessionValue;
                CreateItems(sessionValue, session);
                uiMovie->Invoke("root1.Menu_mc.UpdateSession", nullptr, std::addressof(sessionValue), 1);
            }

        private:
            void BeginHUDIsolation()
            {
                if (isolatedHUDMovie_) return;
                auto* ui = RE::UI::GetSingleton();
                const auto hud = ui ? ui->GetMenu(RE::BSFixedString("HUDMenu")) : nullptr;
                if (!hud || !hud->uiMovie || !hud->uiMovie->asMovieRoot) return;

                // Retain this exact movie; never apply saved state to a replacement HUD.
                isolatedHUDMovie_ = hud->uiMovie;
                hudWasVisible_ = isolatedHUDMovie_->GetVisible();
                hudVisibilityChanged_ = hudWasVisible_;
                if (hudVisibilityChanged_) isolatedHUDMovie_->SetVisible(false);
            }

            void EndHUDIsolation()
            {
                if (!isolatedHUDMovie_) return;
                // Release ownership before restoration so removal + destruction is idempotent.
                auto movie = isolatedHUDMovie_;
                isolatedHUDMovie_ = nullptr;
                const bool changed = std::exchange(hudVisibilityChanged_, false);
                if (changed) movie->SetVisible(hudWasVisible_);
            }

            Scaleform::Ptr<Scaleform::GFx::Movie> isolatedHUDMovie_;
            bool hudWasVisible_{ false };
            bool hudVisibilityChanged_{ false };

            char keyBuffer_[2]{ 0, 0 };
        };

        void SetSearchTextEntryMode(bool enabled)
        {
            if (g_textEntryOwned == enabled) return;
            auto* controls = RE::ControlMap::GetSingleton();
            if (!controls) return;
            Scaleform::GFx::Value flag(enabled);
            bool bridged = false;
            if (g_menu && g_menu->uiMovie && g_menu->uiMovie->asMovieRoot) {
                if (enabled) {
                    // Prefer the official F4SE callback: legacy IME plugins hook
                    // this callback as well as the engine text-entry function.
                    for (const auto* path : { "root.f4se.AllowTextInput", "root1.f4se.AllowTextInput" }) {
                        if (g_menu->uiMovie->Invoke(path, nullptr, std::addressof(flag), 1)) {
                            g_textEntryBridgePath = path; bridged = true; break;
                        }
                    }
                } else if (g_textEntryBridgePath) {
                    bridged = g_menu->uiMovie->Invoke(g_textEntryBridgePath, nullptr, std::addressof(flag), 1);
                }
            }
            if (!bridged) controls->SetTextEntryMode(enabled);
            g_textEntryOwned = enabled;
            REX::INFO("[AIE] SEARCH_TEXT_ENTRY enabled={} bridge={} engine-count={}",
                enabled, bridged ? "f4se" : "engine", static_cast<int>(controls->byTextEntryCount));
            if (!enabled) g_textEntryBridgePath = nullptr;
        }

        void DirectFunctionHandler::Call(const Params& params)
        {
            if (g_menu) g_menu->Call(params);
        }

        RE::IMenu* CreateMenu(const RE::UIMessage&)
        {
            return new ItemExtractorMenu();
        }
    }

    void SetCallbacks(Callbacks callbacks)
    {
        std::lock_guard lock(g_stateMutex);
        g_callbacks = std::move(callbacks);
    }

    void DeliverPluginSearchResults(const PluginSearchResponse& response)
    {
        if (g_menu && IsOpen()) g_menu->PushPluginSearchResults(response);
    }

    void SetSnapshot(Snapshot snapshot)
    {
        {
            std::lock_guard lock(g_stateMutex);
            g_snapshot = std::move(snapshot);
        }
        if (g_menu && IsOpen()) g_menu->PushSnapshot();
    }

    void UpdateSession(std::vector<ItemRow> session)
    {
        {
            std::lock_guard lock(g_stateMutex);
            g_snapshot.session = std::move(session);
        }
        if (g_menu && IsOpen()) g_menu->PushSession();
    }

    void SetInputMode(std::string inputMode)
    {
        std::lock_guard lock(g_stateMutex);
        g_snapshot.inputMode = std::move(inputMode);
    }

    void RegisterMenu()
    {
        if (g_registered) return;
        auto* ui = RE::UI::GetSingleton();
        if (!ui || ui->GetMenu(RE::BSFixedString(kMenuName.data()))) return;
        ui->RegisterMenu(kMenuName.data(), CreateMenu);
        g_registered = true;
    }

    bool IsRegistered()
    {
        return g_registered;
    }

    bool IsOpen()
    {
        auto* ui = RE::UI::GetSingleton();
        return ui && ui->GetMenuOpen(RE::BSFixedString(kMenuName.data()));
    }

    bool Open()
    {
        RegisterMenu();
        if (!g_registered || IsOpen()) return g_registered;
        auto* queue = RE::UIMessageQueue::GetSingleton();
        if (!queue) return false;
        queue->AddMessage(RE::BSFixedString(kMenuName.data()), RE::UI_MESSAGE_TYPE::kShow);
        return true;
    }

    void Close()
    {
        ClearSearchTextEntry();
        if (!IsOpen()) return;
        if (auto* queue = RE::UIMessageQueue::GetSingleton()) {
            queue->AddMessage(RE::BSFixedString(kMenuName.data()), RE::UI_MESSAGE_TYPE::kHide);
        }
    }

    void SetHidden(bool hidden)
    {
        g_hidden = hidden;
        SetSearchTextEntryMode(g_searchFocused && !hidden);
        if (g_menu && g_menu->uiMovie && g_menu->uiMovie->asMovieRoot) {
            Scaleform::GFx::Value value(hidden);
            g_menu->uiMovie->Invoke("root1.Menu_mc.SetHidden", nullptr, std::addressof(value), 1);
        }
    }

    void SendKey(const char* key, std::int32_t focusSource)
    {
        if (!g_menu || !g_menu->uiMovie || !key) return;
        std::array<Scaleform::GFx::Value, 2> args;
        g_menu->uiMovie->asMovieRoot->CreateString(std::addressof(args[0]), key);
        args[1] = Scaleform::GFx::Value(focusSource);
        g_menu->uiMovie->Invoke("root1.Menu_mc.HandleKey", nullptr, args.data(), 2);
    }
}
