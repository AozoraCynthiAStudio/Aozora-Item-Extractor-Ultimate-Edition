#ifndef NOMINMAX
#define NOMINMAX
#endif

#include <algorithm>
#include <array>
#include <atomic>
#include <cctype>
#include <chrono>
#include <cstdint>
#include <cstdio>
#include <filesystem>
#include <fstream>
#include <functional>
#include <memory>
#include <mutex>
#include <optional>
#include <sstream>
#include <string>
#include <string_view>
#include <thread>
#include <type_traits>
#include <unordered_map>
#include <utility>
#include <vector>

#include "F4SE/F4SE.h"
#include "RE/Fallout.h"
#include "RE/H/HUDMenuUtils.h"
#include "RE/P/PlayerCamera.h"
#include "RE/P/PipboyManager.h"
#include "RE/B/BSInputDeviceManager.h"
#include "FISIconResolver.h"
#include "ScaleformMenu.h"
#include "PluginSearch.h"

#include <Windows.h>

#define AIE_EXPORT extern "C" __declspec(dllexport)

namespace fs = std::filesystem;

namespace
{
    constexpr const char* kPluginName = "AozoraItemExtractor";
    constexpr const char* kPluginFile = "AozoraItemExtractor.esp";
    constexpr std::uint32_t kLauncherLocalFormID = 0x800;
    constexpr std::uint32_t kSerializationID = 'AoIE';
    constexpr std::size_t kTakeAllBatchSize = 64;
    constexpr std::uint32_t kWeaponAmmoGrant = 1000;
    constexpr ULONGLONG kMenuOpenDebounceMs = 250;
    constexpr ULONGLONG kMenuReopenAfterCloseMs = 300;

    enum class ItemCategory
    {
        kWeapon,
        kArmor,
        kAid,
        kAmmo,
        kJunk,
        kMisc
    };

    struct CountConfig
    {
        std::uint32_t weapon = 1;
        std::uint32_t armor = 1;
        std::uint32_t ammo = 100;
        std::uint32_t aid = 1;
        std::uint32_t grenade = 1;
        std::uint32_t junk = 1;
        std::uint32_t misc = 1;
        bool addLauncherOnLoad = true;
    };

    struct PluginEntry
    {
        std::string name;
        bool light = false;
    };

    struct ItemEntry
    {
        std::uint32_t formID = 0;
        std::string name;
        std::string normalizedName;
        ItemCategory category = ItemCategory::kMisc;
        std::uint32_t groupCount = 1;
    };

    struct SessionEntry
    {
        std::uint32_t formID = 0;
        std::string name;
        ItemCategory category = ItemCategory::kMisc;
        std::uint32_t groupCount = 1;
        std::uint32_t baselineCount = 0;
        std::uint32_t totalTaken = 0;
        std::uint32_t totalReturned = 0;

        [[nodiscard]] std::uint32_t Net() const noexcept
        {
            return totalTaken > totalReturned ? totalTaken - totalReturned : 0;
        }
    };

    struct TakeAllJob
    {
        std::string plugin;
        std::vector<ItemEntry> items;
        std::size_t next = 0;
    };

    std::mutex g_mutex;
    bool g_menuOpen = false;
    bool g_hiddenForConsole = false;
    bool g_searchFocused = false;
    bool g_playerControlsBlocked = false;
    bool g_playerControlsWasBlocked = false;
    bool g_scanReady = false;
    ULONGLONG g_consoleRequestedAt = 0;
    std::string g_inputMode = "keyboard";
    std::string g_activePlugin;
    std::vector<PluginEntry> g_plugins;
    std::unordered_map<std::string, std::vector<ItemEntry>> g_itemsByPlugin;
    std::unordered_map<std::uint32_t, SessionEntry> g_session;
    CountConfig g_config;
    RE::BSTSmartPointer<RE::BSInputEnableLayer> g_inputLayer;
    std::atomic_bool g_transferQueued{ false };
    std::atomic_bool g_monitorStarted{ false };
    std::atomic<ULONGLONG> g_inputReleaseGeneration{ 0 };
    std::atomic_bool g_launcherPending{ false };
    std::atomic<ULONGLONG> g_launcherReadyAt{ 0 };
    std::atomic_bool g_scanQueued{ false };
    std::atomic<std::uint32_t> g_menuSerial{ 0 };
    std::atomic<ULONGLONG> g_lastMenuOpenAt{ 0 };
    std::atomic<ULONGLONG> g_lastMenuCloseAt{ 0 };

    fs::path GameRoot()
    {
        wchar_t buffer[MAX_PATH]{};
        GetModuleFileNameW(nullptr, buffer, MAX_PATH);
        return fs::path(buffer).parent_path();
    }

    fs::path ConfigPath()
    {
        return GameRoot() / "Data" / "F4SE" / "Plugins" / "AozoraItemExtractor.ini";
    }

    fs::path LogPath()
    {
        return GameRoot() / "Data" / "F4SE" / "Plugins" / "AozoraItemExtractor.log";
    }

    void Log(std::string_view message)
    {
        std::ofstream file(LogPath(), std::ios::app);
        if (file.is_open()) {
            file << message << '\n';
        }
    }

    std::string JsonEscape(std::string_view text)
    {
        std::string out;
        out.reserve(text.size() + 8);
        for (const char ch : text) {
            switch (ch) {
            case '\\': out += "\\\\"; break;
            case '"': out += "\\\""; break;
            case '\n': out += "\\n"; break;
            case '\r': out += "\\r"; break;
            case '\t': out += "\\t"; break;
            default:
                if (static_cast<unsigned char>(ch) < 0x20) {
                    char encoded[8]{};
                    std::snprintf(encoded, sizeof(encoded), "\\u%04x", static_cast<unsigned char>(ch));
                    out += encoded;
                } else {
                    out += ch;
                }
                break;
            }
        }
        return out;
    }

    std::string LowerAscii(std::string text)
    {
        std::transform(text.begin(), text.end(), text.begin(), [](unsigned char ch) {
            return static_cast<char>(std::tolower(ch));
        });
        return text;
    }

    const char* CategoryName(ItemCategory category)
    {
        switch (category) {
        case ItemCategory::kWeapon: return "weapon";
        case ItemCategory::kArmor: return "armor";
        case ItemCategory::kAid: return "aid";
        case ItemCategory::kAmmo: return "ammo";
        case ItemCategory::kJunk: return "junk";
        default: return "misc";
        }
    }

    std::uint32_t ReadIniUInt(const wchar_t* section, const wchar_t* key, std::uint32_t fallback)
    {
        const auto path = ConfigPath().wstring();
        return static_cast<std::uint32_t>(GetPrivateProfileIntW(section, key, static_cast<INT>(fallback), path.c_str()));
    }

    void ReadConfig()
    {
        g_config.weapon = std::max(1u, ReadIniUInt(L"ItemCount", L"Weapon", 1));
        g_config.armor = std::max(1u, ReadIniUInt(L"ItemCount", L"Armor", 1));
        g_config.ammo = std::max(1u, ReadIniUInt(L"ItemCount", L"Ammo", 100));
        g_config.aid = std::max(1u, ReadIniUInt(L"ItemCount", L"Aid", 1));
        g_config.grenade = std::max(1u, ReadIniUInt(L"ItemCount", L"Grenade", 1));
        g_config.junk = std::max(1u, ReadIniUInt(L"ItemCount", L"Junk", 1));
        g_config.misc = std::max(1u, ReadIniUInt(L"ItemCount", L"Misc", 1));
        g_config.addLauncherOnLoad = ReadIniUInt(L"General", L"AddLauncherOnLoad", 1) != 0;
    }

    AIE::ScaleformUI::Theme ReadTheme()
    {
        const auto settingsPath = (GameRoot() / "Data" / "MCM" / "Settings" / "AozoraItemExtractor.ini").wstring();
        AIE::ScaleformUI::Theme theme;
        theme.mode = std::clamp(static_cast<int>(GetPrivateProfileIntW(L"General", L"iThemeColorMode", 0, settingsPath.c_str())), 0, 1);
        theme.preset = std::clamp(static_cast<int>(GetPrivateProfileIntW(L"General", L"iThemeColorPreset", 0, settingsPath.c_str())), 0, 5);
        if (theme.mode == 0) {
            const auto hud = RE::HUDMenuUtils::GetGameplayHUDColor();
            theme.r = std::clamp(hud.r, 0.0F, 1.0F);
            theme.g = std::clamp(hud.g, 0.0F, 1.0F);
            theme.b = std::clamp(hud.b, 0.0F, 1.0F);
            if (theme.r + theme.g + theme.b < 0.05F) {
                theme.r = 0.40F;
                theme.g = 1.00F;
                theme.b = 0.70F;
            }
            return theme;
        }
        constexpr std::array<std::array<float, 3>, 6> presets{{
            { 0.40F, 1.00F, 0.70F },
            { 1.00F, 0.78F, 0.28F },
            { 0.38F, 0.88F, 1.00F },
            { 1.00F, 0.42F, 0.30F },
            { 0.82F, 0.58F, 1.00F },
            { 0.92F, 0.96F, 1.00F }
        }};
        const auto& color = presets[static_cast<std::size_t>(theme.preset)];
        theme.r = color[0];
        theme.g = color[1];
        theme.b = color[2];
        return theme;
    }

    RE::UserEvents::USER_EVENT_FLAG ModalBlockFlags()
    {
        using Flag = RE::UserEvents::USER_EVENT_FLAG;
        const auto value =
            static_cast<std::underlying_type_t<Flag>>(Flag::kMovement) |
            static_cast<std::underlying_type_t<Flag>>(Flag::kLooking) |
            static_cast<std::underlying_type_t<Flag>>(Flag::kActivate) |
            static_cast<std::underlying_type_t<Flag>>(Flag::kPOVSwitch) |
            static_cast<std::underlying_type_t<Flag>>(Flag::kFighting) |
            static_cast<std::underlying_type_t<Flag>>(Flag::kSneaking) |
            static_cast<std::underlying_type_t<Flag>>(Flag::kMainFour) |
            static_cast<std::underlying_type_t<Flag>>(Flag::kWheelZoom) |
            static_cast<std::underlying_type_t<Flag>>(Flag::kJumping) |
            static_cast<std::underlying_type_t<Flag>>(Flag::kVATS);
        return static_cast<Flag>(value);
    }

    void SetGameplayInputBlocked(bool blocked)
    {
        auto* manager = RE::BSInputEnableManager::GetSingleton();
        if (blocked) {
            if (manager && !g_inputLayer) {
                manager->AllocateNewLayer(g_inputLayer, "AozoraItemExtractorUI");
            }
            if (manager && g_inputLayer) {
                manager->EnableUserEvent(g_inputLayer->layerID, ModalBlockFlags(), false, RE::UserEvents::SENDER_ID::kMenu);
            }
            if (auto* controls = RE::PlayerControls::GetSingleton()) {
                if (!g_playerControlsBlocked) {
                    g_playerControlsWasBlocked = controls->blockPlayerInput;
                    g_playerControlsBlocked = true;
                }
                controls->blockPlayerInput = true;
                controls->data.moveInputVec = {};
                controls->data.lookInputVec = {};
                controls->data.lookInputVecNormalized = {};
                controls->data.prevMoveVec = {};
                controls->data.prevLookVec = {};
                controls->data.autoMove = false;
            }
            return;
        }

        if (manager && g_inputLayer) {
            manager->EnableUserEvent(g_inputLayer->layerID, ModalBlockFlags(), true, RE::UserEvents::SENDER_ID::kMenu);
            g_inputLayer.reset();
        }
        if (g_playerControlsBlocked) {
            if (auto* controls = RE::PlayerControls::GetSingleton()) {
                controls->blockPlayerInput = g_playerControlsWasBlocked;
                controls->data.moveInputVec = {};
                controls->data.lookInputVec = {};
                controls->data.lookInputVecNormalized = {};
                controls->data.prevMoveVec = {};
                controls->data.prevLookVec = {};
                controls->data.autoMove = false;
            }
            g_playerControlsBlocked = false;
            g_playerControlsWasBlocked = false;
        }
    }

    bool AnyNativeMenuOpen()
    {
        auto* ui = RE::UI::GetSingleton();
        if (!ui) {
            return true;
        }
        constexpr const char* names[] = {
            "BarberMenu", "BarterMenu", "BookMenu", "CharGenMenu", "Console",
            "ContainerMenu", "CookingMenu", "CraftingMenu", "DialogueMenu",
            "ExamineMenu", "FavoritesMenu", "LoadingMenu", "LockpickingMenu",
            "LooksMenu", "MainMenu", "MessageBoxMenu", "NameMenu", "PauseMenu",
            "PipboyMenu", "PowerArmorModMenu", "RobotModMenu", "SleepWaitMenu",
            "SPECIALMenu", "TerminalMenu", "VATSMenu", "WorkshopMenu"
        };
        for (const auto* name : names) {
            if (ui->GetMenuOpen(RE::BSFixedString(name))) {
                return true;
            }
        }
        return false;
    }

        bool IsPassiveHudMenu(const RE::IMenu& a_menu)
        {
            const auto menuName = std::string_view(a_menu.menuName.c_str());
            // CursorMenu renders the pointer; FaderMenu renders transitions.
            // Neither owns an independent interactive screen.
            if (menuName == "CursorMenu" || menuName == "FaderMenu") {
                return true;
            }
            const bool namedHud = menuName == "HUDMenu" || menuName == "PowerArmorHUDMenu";
            const bool buttonHints = menuName == "ButtonBarMenu";
            const bool takesInput =
                a_menu.menuFlags.all(RE::UI_MENU_FLAGS::kModal) ||
                a_menu.menuFlags.all(RE::UI_MENU_FLAGS::kUsesCursor) ||
                a_menu.menuFlags.all(RE::UI_MENU_FLAGS::kUsesMenuContext) ||
                a_menu.menuFlags.all(RE::UI_MENU_FLAGS::kPausesGame) ||
                a_menu.menuFlags.all(RE::UI_MENU_FLAGS::kUsesMovementToDirection);
            // Transient third-party display layers need not be HUD-named or
            // AlwaysOpen. Classify them by input ownership instead.
            // A gameplay context alone does not establish menu interaction.
            const bool hasInteractiveContext =
                a_menu.inputContext != RE::UserEvents::INPUT_CONTEXT_ID::kNone &&
                a_menu.inputContext != RE::UserEvents::INPUT_CONTEXT_ID::kMainGameplay;
            return !takesInput && (namedHud || buttonHints || !hasInteractiveContext);
        }

        bool OtherInteractiveMenuOpen(std::string* a_reason = nullptr)
        {
            auto* ui = RE::UI::GetSingleton();
            if (!ui) {
                return true;
            }
            for (const auto& menuHandle : ui->menuStack) {
                auto* menu = menuHandle.get();
                if (!menu || !menu->OnStack() || !menu->IsMenuDisplayEnabled()) {
                    continue;
                }
                if (IsPassiveHudMenu(*menu)) {
                    continue;
                }
                if (a_reason) {
                    *a_reason = "menu=" + std::string(menu->menuName.c_str()) +
                        " flags=" + std::to_string(menu->menuFlags.underlying()) +
                        " input-context=" + std::to_string(menu->inputContext.underlying());
                }
                return true;
            }
            return false;
        }

        std::string GameplayOpenBlockReason()
        {
            auto* ui = RE::UI::GetSingleton();
            if (!ui) {
                return "ui-missing";
            }
            // Dialogue can remain unpaused and expose passive-looking menu flags.
            // Never infer dialogue from a lingering speaker/target handle.
            if (ui->GetMenuOpen(RE::BSFixedString("DialogueMenu"))) {
                return "dialogue-menu";
            }
            // AE runtime log shows menuOpen can remain true in gameplay with
            // no DialogueMenu and only passive HUD layers. Do not use it as an
            // independent veto; actual menus and active input contexts follow.
            if (ui->menuMode != 0) {
                return "ui-menu-mode=" + std::to_string(ui->menuMode);
            }
            if (auto* main = RE::Main::GetSingleton(); main && main->inMenuMode) {
                return "main-menu-mode";
            }
            if (auto* controls = RE::PlayerControls::GetSingleton();
                controls && controls->blockPlayerInput) {
                return "player-input-blocked";
            }
            // HUD widgets can own input without registering another IMenu.
            // Observe the engine context stack, not only visible menu flags.
            if (auto* mappings = RE::ControlMap::GetSingleton()) {
                if (mappings->byTextEntryCount > 0) {
                    return "text-entry";
                }
                for (const auto context : mappings->contextPriorityStack) {
                    const auto id = context.underlying();
                    using Context = RE::UserEvents::INPUT_CONTEXT_ID;
                    switch (static_cast<Context>(id)) {
                    case Context::kBasicMenuNav:
                    case Context::kThumbNav:
                    case Context::kCursor:
                    case Context::kLThumbCursor:
                    case Context::kConsole:
                    case Context::kBook:
                    case Context::kTFC:
                    case Context::kLockpick:
                    case Context::kVATS:
                    case Context::kVATSPlayback:
                    case Context::kWorkshop:
                    case Context::kWorkshopAddendum:
                    case Context::kRobotModAddendum:
                    case Context::kSitWait:
                    case Context::kLooksMenu:
                    case Context::kPauseMenu:
                    case Context::kLevelUpMenu:
                    case Context::kLevelUpMenuPrevNext:
                    case Context::kMainMenu:
                    case Context::kQuickContainerMenu:
                    case Context::kQuickContainerMenuPerk:
                    case Context::kPlayBinkMenu:
                    case Context::kCreationClub:
                        return "active-input-context=" + std::to_string(id);
                    default:
                        // Gameplay, virtual controller and scope do not by
                        // themselves own an interactive selection interface.
                        break;
                    }
                }
            }
            // Photo modes/free-camera tools may keep their UI outside menuStack.
            if (auto* camera = RE::PlayerCamera::GetSingleton();
                camera && camera->QCameraEquals(RE::CameraState::kFree)) {
                return "free-camera";
            }
            std::string reason;
            OtherInteractiveMenuOpen(&reason);
            return reason;
        }


    void LogOpenBlock(const std::string& reason)
    {
        std::string detail = "OPEN_BLOCK reason=" + reason;
        if (auto* ui = RE::UI::GetSingleton()) {
            detail += " menuMode=" + std::to_string(ui->menuMode);
            for (const auto& handle : ui->menuStack) {
                const auto* menu = handle.get();
                if (!menu) continue;
                detail += " [" + std::string(menu->menuName.c_str()) +
                    " flags=" + std::to_string(menu->menuFlags.underlying()) +
                    " context=" + std::to_string(menu->inputContext.underlying()) +
                    " visible=" + std::to_string(menu->IsMenuDisplayEnabled()) +
                    " passive=" + std::to_string(IsPassiveHudMenu(*menu)) + "]";
            }
        }
        if (auto* map = RE::ControlMap::GetSingleton()) {
            detail += " text-entry=" + std::to_string(map->byTextEntryCount) + " contexts=";
            for (const auto context : map->contextPriorityStack) detail += std::to_string(context.underlying()) + ",";
        }
        Log(detail);
    }

    bool MenuCanOpen()
    {
        if (g_menuOpen) return false;
        const auto reason = GameplayOpenBlockReason();
        if (!reason.empty()) {
            LogOpenBlock(reason);
            return false;
        }
        AIE::ScaleformUI::RegisterMenu();
        return AIE::ScaleformUI::IsRegistered() && !AIE::ScaleformUI::IsOpen();
    }

    std::string DisplayName(RE::TESForm* form)
    {
        if (!form) {
            return {};
        }
        if (auto* full = form->As<RE::TESFullName>()) {
            if (const char* name = full->GetFullName(); name && name[0]) {
                return name;
            }
        }
        const auto sparse = RE::TESFullName::GetFullName(*form, false);
        return std::string(sparse);
    }

    const RE::TESFile* OwnerFile(std::uint32_t formID)
    {
        auto* data = RE::TESDataHandler::GetSingleton();
        if (!data) {
            return nullptr;
        }
        const auto fullIndex = static_cast<std::uint8_t>(formID >> 24);
        if (fullIndex == 0xFE) {
            const auto lightIndex = static_cast<std::uint16_t>((formID >> 12) & 0xFFF);
            return data->LookupLoadedLightModByIndex(lightIndex);
        }
        return data->LookupLoadedModByIndex(fullIndex);
    }

    bool HasFeaturedQuestKeyword(RE::TESForm* form)
    {
        auto* keywords = form ? form->As<RE::BGSKeywordForm>() : nullptr;
        return keywords && keywords->HasKeywordID(0x00183FAC);
    }

    bool BasicItemValid(RE::TESForm* form)
    {
        if (!form || form->GetDelete() || !form->GetPlayable(nullptr) || HasFeaturedQuestKeyword(form)) {
            return false;
        }
        if (!form->As<RE::TESBoundObject>() || !OwnerFile(form->GetFormID())) {
            return false;
        }
        return !DisplayName(form).empty();
    }

    std::uint32_t GroupCount(ItemCategory category, bool thrownWeapon)
    {
        if (thrownWeapon) {
            return g_config.grenade;
        }
        switch (category) {
        case ItemCategory::kWeapon: return g_config.weapon;
        case ItemCategory::kArmor: return g_config.armor;
        case ItemCategory::kAid: return g_config.aid;
        case ItemCategory::kAmmo: return g_config.ammo;
        case ItemCategory::kJunk: return g_config.junk;
        default: return g_config.misc;
        }
    }

    template <class T, class Classify>
    void ScanArray(RE::TESDataHandler* data, Classify classify)
    {
        for (auto* form : data->GetFormArray<T>()) {
            if (!BasicItemValid(form)) {
                continue;
            }
            const auto categoryAndThrown = classify(form);
            const auto category = categoryAndThrown.first;
            const auto thrown = categoryAndThrown.second;
            const auto* owner = OwnerFile(form->GetFormID());
            if (!owner) {
                continue;
            }
            ItemEntry entry;
            entry.formID = form->GetFormID();
            entry.name = DisplayName(form);
            entry.normalizedName = AIE::PluginSearch::Normalize(entry.name);
            entry.category = category;
            entry.groupCount = GroupCount(category, thrown);
            g_itemsByPlugin[std::string(owner->GetFilename())].push_back(std::move(entry));
        }
    }

    void ScanLoadedData()
    {
        ReadConfig();
        g_plugins.clear();
        g_itemsByPlugin.clear();
        g_scanReady = false;

        auto* data = RE::TESDataHandler::GetSingleton();
        if (!data) {
            Log("ScanLoadedData failed: TESDataHandler unavailable");
            return;
        }

        for (auto* file : data->compiledFileCollection.files) {
            if (file && file->IsActive() && file->filename[0]) {
                g_plugins.push_back({ std::string(file->GetFilename()), false });
            }
        }
        for (auto* file : data->compiledFileCollection.smallFiles) {
            if (file && file->IsActive() && file->filename[0]) {
                g_plugins.push_back({ std::string(file->GetFilename()), true });
            }
        }

        // DataHandler exposes regular plugins first and light plugins second,
        // each in load-order sequence. Reversing the combined list therefore
        // presents the player's effective load order from newest to oldest.
        std::reverse(g_plugins.begin(), g_plugins.end());

        ScanArray<RE::TESObjectWEAP>(data, [](RE::TESObjectWEAP* weapon) {
            return std::pair{ ItemCategory::kWeapon, weapon->IsThrownWeapon() };
        });
        ScanArray<RE::TESObjectARMO>(data, [](RE::TESObjectARMO*) {
            return std::pair{ ItemCategory::kArmor, false };
        });
        ScanArray<RE::TESAmmo>(data, [](RE::TESAmmo*) {
            return std::pair{ ItemCategory::kAmmo, false };
        });
        ScanArray<RE::AlchemyItem>(data, [](RE::AlchemyItem*) {
            return std::pair{ ItemCategory::kAid, false };
        });
        ScanArray<RE::TESObjectBOOK>(data, [](RE::TESObjectBOOK*) {
            return std::pair{ ItemCategory::kMisc, false };
        });
        ScanArray<RE::BGSNote>(data, [](RE::BGSNote*) {
            return std::pair{ ItemCategory::kMisc, false };
        });
        ScanArray<RE::TESKey>(data, [](RE::TESKey*) {
            return std::pair{ ItemCategory::kMisc, false };
        });
        ScanArray<RE::TESObjectMISC>(data, [](RE::TESObjectMISC* misc) {
            const bool junk = misc->componentData && !misc->componentData->empty();
            return std::pair{ junk ? ItemCategory::kJunk : ItemCategory::kMisc, false };
        });

        for (auto& [plugin, items] : g_itemsByPlugin) {
            std::sort(items.begin(), items.end(), [](const ItemEntry& left, const ItemEntry& right) {
                const int result = _stricmp(left.name.c_str(), right.name.c_str());
                return result == 0 ? left.formID < right.formID : result < 0;
            });
        }

        std::erase_if(g_plugins, [](const PluginEntry& plugin) {
            const auto found = g_itemsByPlugin.find(plugin.name);
            return found == g_itemsByPlugin.end() || found->second.empty();
        });

        g_scanReady = true;
        Log("ScanLoadedData complete: plugins=" + std::to_string(g_plugins.size()) +
            " itemPlugins=" + std::to_string(g_itemsByPlugin.size()));
    }

    std::vector<AIE::ScaleformUI::ItemRow> BuildInventoryRows()
    {
        std::vector<AIE::ScaleformUI::ItemRow> result;
        auto* player = RE::PlayerCharacter::GetSingleton();
        if (!player || !player->inventoryList) return result;
        result.reserve(player->inventoryList->data.size());
        for (const auto& inventoryItem : player->inventoryList->data) {
            auto* object = inventoryItem.object;
            if (!object || !BasicItemValid(object)) continue;
            std::uint64_t count = 0;
            for (auto stack = inventoryItem.stackData.get(); stack; stack = stack->nextStack.get()) {
                count += stack->GetCount();
            }
            if (count == 0 || count > UINT32_MAX) continue;
            const auto formID = object->GetFormID();
            auto category = ItemCategory::kMisc;
            bool thrown = false;
            if (auto* weapon = object->As<RE::TESObjectWEAP>()) {
                category = ItemCategory::kWeapon;
                thrown = weapon->IsThrownWeapon();
            } else if (object->As<RE::TESObjectARMO>()) {
                category = ItemCategory::kArmor;
            } else if (object->As<RE::TESAmmo>()) {
                category = ItemCategory::kAmmo;
            } else if (object->As<RE::AlchemyItem>()) {
                category = ItemCategory::kAid;
            } else if (auto* misc = object->As<RE::TESObjectMISC>(); misc && misc->componentData && !misc->componentData->empty()) {
                category = ItemCategory::kJunk;
            }
            const auto session = g_session.find(formID);
            std::uint32_t returnable = 0;
            std::uint32_t group = GroupCount(category, thrown);
            if (session != g_session.end()) {
                group = session->second.groupCount;
                const auto current = player->GetInventoryObjectCount(object);
                const auto aboveBaseline = current > session->second.baselineCount ? current - session->second.baselineCount : 0;
                returnable = std::min(session->second.Net(), aboveBaseline);
            }
            auto name = DisplayName(object);
            const auto icon = AIE::ResolveFISIcon(object, name);
            result.push_back({ formID, std::move(name), CategoryName(category), static_cast<std::uint32_t>(count), group,
                returnable, icon.library, icon.className });
        }
        std::sort(result.begin(), result.end(), [](const auto& left, const auto& right) {
            const int nameResult = _stricmp(left.name.c_str(), right.name.c_str());
            return nameResult == 0 ? left.formID < right.formID : nameResult < 0;
        });
        return result;
    }

    AIE::ScaleformUI::Snapshot BuildUISnapshot()
    {
        AIE::ScaleformUI::Snapshot snapshot;
        snapshot.inputMode = g_inputMode;
        snapshot.plugin = g_activePlugin;
        snapshot.page = g_activePlugin.empty() ? "nav" : "extract";
        snapshot.theme = ReadTheme();
        const auto settingsPath = (GameRoot() / "Data" / "MCM" / "Settings" / "AozoraItemExtractor.ini").wstring();
        snapshot.mascotEnabled = GetPrivateProfileIntW(L"General", L"bMascotEnabled", 1, settingsPath.c_str()) != 0;
        snapshot.plugins.reserve(g_plugins.size());
        for (const auto& plugin : g_plugins) snapshot.plugins.push_back({ plugin.name, plugin.light });
        if (!g_activePlugin.empty()) {
            const auto found = g_itemsByPlugin.find(g_activePlugin);
            if (found != g_itemsByPlugin.end()) {
                snapshot.items.reserve(found->second.size());
                for (const auto& item : found->second) {
                    auto* form = RE::TESForm::GetFormByID(item.formID);
                    auto* object = form ? form->As<RE::TESBoundObject>() : nullptr;
                    const auto icon = AIE::ResolveFISIcon(object, item.name);
                    const auto* weapon = object ? object->As<RE::TESObjectWEAP>() : nullptr;
                    const auto starterAmmo = item.category == ItemCategory::kWeapon && weapon && weapon->weaponData.ammo ? kWeaponAmmoGrant : 0u;
                    snapshot.items.push_back({ item.formID, item.name, CategoryName(item.category), 0,
                        item.groupCount, 0, icon.library, icon.className, starterAmmo });
                }
            }
        }
        snapshot.session = BuildInventoryRows();
        return snapshot;
    }

    void PushPluginsToUI()
    {
        AIE::ScaleformUI::SetSnapshot(BuildUISnapshot());
    }

    void PushItemsToUI()
    {
        AIE::ScaleformUI::SetSnapshot(BuildUISnapshot());
    }

    void PushSessionToUI()
    {
        AIE::ScaleformUI::UpdateSession(BuildInventoryRows());
    }

    void ClearSession()
    {
        g_session.clear();
        g_activePlugin.clear();
    }

    bool QueueGameTask(std::function<void()> task);

    void ScheduleGameplayInputRelease()
    {
        const auto generation = ++g_inputReleaseGeneration;
        std::thread([generation] {
            const auto deadline = GetTickCount64() + 2000;
            while (GetTickCount64() < deadline &&
                   ((GetAsyncKeyState(VK_TAB) & 0x8000) != 0 ||
                    (GetAsyncKeyState(VK_ESCAPE) & 0x8000) != 0)) {
                Sleep(10);
            }
            Sleep(120);
            QueueGameTask([generation] {
                std::lock_guard lock(g_mutex);
                if (!g_menuOpen && g_inputReleaseGeneration.load() == generation) {
                    SetGameplayInputBlocked(false);
                }
            });
        }).detach();
    }

    void CloseMenuInternal(bool deferInputRelease = false)
    {
        {
            std::lock_guard lock(g_mutex);
            g_lastMenuCloseAt = GetTickCount64();
            g_launcherPending = false;
            g_launcherReadyAt = 0;
            g_transferQueued = false;
            ClearSession();
            g_menuOpen = false;
            g_hiddenForConsole = false;
            g_searchFocused = false;
            g_consoleRequestedAt = 0;
        }
        AIE::ScaleformUI::SetHidden(false);
        AIE::ScaleformUI::Close();
        if (deferInputRelease) {
            ScheduleGameplayInputRelease();
        } else {
            ++g_inputReleaseGeneration;
            SetGameplayInputBlocked(false);
        }
    }

    void ScheduleScanForOpen(std::uint32_t serial)
    {
        if (g_scanReady || g_scanQueued.exchange(true)) {
            return;
        }
        std::thread([serial] {
            Sleep(60);
            if (!QueueGameTask([serial] {
                std::lock_guard lock(g_mutex);
                if (!g_menuOpen || g_menuSerial.load() != serial) {
                    g_scanQueued = false;
                    return;
                }
                if (!g_scanReady) {
                    ScanLoadedData();
                }
                g_scanQueued = false;
                if (g_menuOpen && g_menuSerial.load() == serial) {
                    PushPluginsToUI();
                }
            })) {
                g_scanQueued = false;
            }
        }).detach();
    }

    bool OpenMenuInternal(std::string inputMode)
    {
        const auto now = GetTickCount64();
        const auto lastOpen = g_lastMenuOpenAt.load();
        const auto lastClose = g_lastMenuCloseAt.load();
        if ((lastOpen != 0 && now - lastOpen < kMenuOpenDebounceMs) ||
            (lastClose != 0 && now - lastClose < kMenuReopenAfterCloseMs) ||
            !MenuCanOpen()) {
            return false;
        }
        ClearSession();
        g_inputMode = std::move(inputMode);
        ++g_inputReleaseGeneration;
        const auto serial = ++g_menuSerial;
        g_lastMenuOpenAt = now;
        g_menuOpen = true;
        g_hiddenForConsole = false;
        SetGameplayInputBlocked(true);
        AIE::ScaleformUI::SetSnapshot(BuildUISnapshot());
        if (!AIE::ScaleformUI::Open()) {
            g_menuOpen = false;
            SetGameplayInputBlocked(false);
            return false;
        }
        AIE::ScaleformUI::SetHidden(false);
        if (!g_scanReady) ScheduleScanForOpen(serial);
        return true;
    }

    void OpenPluginInternal(const std::string& pluginName)
    {
        const auto valid = std::find_if(g_plugins.begin(), g_plugins.end(), [&](const PluginEntry& entry) {
            return entry.name == pluginName;
        });
        if (valid == g_plugins.end()) return;
        g_activePlugin = pluginName;
        PushItemsToUI();
    }

    const ItemEntry* FindActiveItem(std::uint32_t formID)
    {
        const auto plugin = g_itemsByPlugin.find(g_activePlugin);
        if (plugin == g_itemsByPlugin.end()) return nullptr;
        const auto item = std::find_if(plugin->second.begin(), plugin->second.end(), [&](const ItemEntry& entry) {
            return entry.formID == formID;
        });
        return item == plugin->second.end() ? nullptr : &*item;
    }

    std::uint32_t InventoryCount(RE::Actor* player, RE::TESBoundObject* object)
    {
        if (!player || !object) return 0;
        return player->GetInventoryObjectCount(object);
    }

    bool TakeItemGroup(RE::PlayerCharacter* player, const ItemEntry& item, std::uint32_t requestedCount = 0)
    {
        auto* form = RE::TESForm::GetFormByID(item.formID);
        auto* object = form ? form->As<RE::TESBoundObject>() : nullptr;
        if (!player || !object || !BasicItemValid(form)) return false;

        const auto amount = requestedCount > 0 ? requestedCount : item.groupCount;
        auto [it, inserted] = g_session.try_emplace(item.formID);
        auto& session = it->second;
        if (inserted) {
            session.formID = item.formID;
            session.name = item.name;
            session.category = item.category;
            session.groupCount = item.groupCount;
            session.baselineCount = InventoryCount(player, object);
        }
        player->AddObjectToContainer(object, {}, static_cast<std::int32_t>(amount), nullptr, RE::ITEM_REMOVE_REASON::kNone);
        if (item.category == ItemCategory::kWeapon) {
            if (auto* weapon = form->As<RE::TESObjectWEAP>(); weapon && weapon->weaponData.ammo) {
                // Give one fixed starter stack per weapon extraction action.
                // Melee, grenade, and mine weapons simply have no base ammo
                // and therefore receive nothing here.
                player->AddObjectToContainer(
                    weapon->weaponData.ammo,
                    {},
                    static_cast<std::int32_t>(kWeaponAmmoGrant),
                    nullptr,
                    RE::ITEM_REMOVE_REASON::kNone);
            }
        }
        session.totalTaken += amount;
        return true;
    }

    void TransferItem(std::uint32_t formID, bool take, std::uint32_t requestedCount = 0)
    {
        if (!g_menuOpen || g_hiddenForConsole || g_activePlugin.empty()) return;
        auto* player = RE::PlayerCharacter::GetSingleton();
        auto* form = RE::TESForm::GetFormByID(formID);
        auto* object = form ? form->As<RE::TESBoundObject>() : nullptr;
        if (!player || !object || !BasicItemValid(form)) return;

        if (take) {
            const auto* item = FindActiveItem(formID);
            if (!item) return;
            if (TakeItemGroup(player, *item, requestedCount)) PushSessionToUI();
            return;
        }

        const auto found = g_session.find(formID);
        if (found == g_session.end() || found->second.Net() == 0) return;
        auto& session = found->second;
        const auto current = InventoryCount(player, object);
        const auto aboveBaseline = current > session.baselineCount ? current - session.baselineCount : 0;
        const auto desired = requestedCount > 0 ? requestedCount : session.groupCount;
        const auto removable = std::min({ desired, session.Net(), aboveBaseline });
        if (removable == 0) return;
        RE::TESObjectREFR::RemoveItemData removeData(object, static_cast<std::int32_t>(removable));
        player->RemoveItem(removeData);
        session.totalReturned += removable;
        if (session.Net() == 0) {
            g_session.erase(found);
        }
        PushSessionToUI();
    }

    bool QueueGameTask(std::function<void()> task)
    {
        if (auto* tasks = F4SE::GetTaskInterface()) {
            tasks->AddTask(std::move(task));
            return true;
        }
        return false;
    }

    void QueueTakeAllBatch(const std::shared_ptr<TakeAllJob>& job)
    {
        if (QueueGameTask([job] {
            bool queueNext = false;
            {
                std::lock_guard lock(g_mutex);
                if (!g_menuOpen || g_hiddenForConsole || g_activePlugin != job->plugin) {
                    g_transferQueued = false;
                    return;
                }

                auto* player = RE::PlayerCharacter::GetSingleton();
                if (!player) {
                    g_transferQueued = false;
                    return;
                }

                const auto end = std::min(job->next + kTakeAllBatchSize, job->items.size());
                bool changed = false;
                for (; job->next < end; ++job->next) {
                    changed = TakeItemGroup(player, job->items[job->next]) || changed;
                }
                if (changed) PushSessionToUI();
                queueNext = job->next < job->items.size();
                if (!queueNext) g_transferQueued = false;
            }
            if (queueNext) QueueTakeAllBatch(job);
        })) return;

        g_transferQueued = false;
    }

    void OnClose()
    {
        QueueGameTask([] { CloseMenuInternal(true); });
    }

    void OnEnterPlugin(std::string plugin)
    {
        QueueGameTask([plugin = std::move(plugin)] {
            std::lock_guard lock(g_mutex);
            OpenPluginInternal(plugin);
        });
    }

    void OnEndSession()
    {
        QueueGameTask([] {
            std::lock_guard lock(g_mutex);
            g_activePlugin.clear();
            PushPluginsToUI();
        });
    }

    void OnTransfer(std::uint32_t formID, bool take, std::uint32_t requestedCount)
    {
        if (!formID || g_transferQueued.exchange(true)) return;
        if (!QueueGameTask([formID, take, requestedCount] {
            std::lock_guard lock(g_mutex);
            TransferItem(formID, take, requestedCount);
            g_transferQueued = false;
        })) {
            g_transferQueued = false;
        }
    }

    void OnReturnAll()
    {
        if (g_transferQueued.exchange(true)) return;
        if (!QueueGameTask([] {
            std::lock_guard lock(g_mutex);
            auto* player = RE::PlayerCharacter::GetSingleton();
            if (player && g_menuOpen && !g_hiddenForConsole && !g_activePlugin.empty()) {
                for (auto it = g_session.begin(); it != g_session.end();) {
                    auto& entry = it->second;
                    auto* form = RE::TESForm::GetFormByID(it->first);
                    auto* object = form ? form->As<RE::TESBoundObject>() : nullptr;
                    if (!object || !BasicItemValid(form)) { ++it; continue; }
                    const auto current = InventoryCount(player, object);
                    const auto aboveBaseline = current > entry.baselineCount ? current - entry.baselineCount : 0;
                    const auto removable = std::min({ entry.Net(), aboveBaseline, static_cast<std::uint32_t>(INT32_MAX) });
                    if (removable) {
                        RE::TESObjectREFR::RemoveItemData data(object, static_cast<std::int32_t>(removable));
                        player->RemoveItem(data);
                        entry.totalReturned += removable;
                    }
                    if (entry.Net() == 0) it = g_session.erase(it);
                    else ++it;
                }
                PushSessionToUI();
            }
            g_transferQueued = false;
        })) g_transferQueued = false;
    }

    void OnTakeAll()
    {
        if (g_transferQueued.exchange(true)) return;
        std::shared_ptr<TakeAllJob> job;
        {
            std::lock_guard lock(g_mutex);
            if (!g_menuOpen || g_hiddenForConsole || g_activePlugin.empty()) {
                g_transferQueued = false;
                return;
            }
            const auto found = g_itemsByPlugin.find(g_activePlugin);
            if (found == g_itemsByPlugin.end() || found->second.empty()) {
                g_transferQueued = false;
                return;
            }
            job = std::make_shared<TakeAllJob>(TakeAllJob{ g_activePlugin, found->second, 0 });
        }
        QueueTakeAllBatch(job);
    }

    void OnSearchFocus(bool focused)
    {
        g_searchFocused = focused;
    }

    void OnScaleformMenuRemoved()
    {
        QueueGameTask([] {
            {
                std::lock_guard lock(g_mutex);
                if (!g_menuOpen) return;
                g_menuOpen = false;
                g_hiddenForConsole = false;
                g_searchFocused = false;
                g_transferQueued = false;
                ClearSession();
                g_lastMenuCloseAt = GetTickCount64();
            }
            ++g_inputReleaseGeneration;
            SetGameplayInputBlocked(false);
        });
    }

    AIE::ScaleformUI::PluginSearchResponse OnSearchPluginsAndItems(std::string query)
    {
        AIE::ScaleformUI::PluginSearchResponse response;
        response.query = query;
        const auto trimmed = AIE::PluginSearch::Trim(query);
        const auto tokens = AIE::PluginSearch::Tokens(trimmed);
        const bool itemSearch = AIE::PluginSearch::QueryLength(trimmed) >= 2;
        std::lock_guard lock(g_mutex);
        for (const auto& plugin : g_plugins) {
            const bool nameMatch = AIE::PluginSearch::Matches(AIE::PluginSearch::Normalize(plugin.name), tokens);
            std::uint32_t count = 0;
            if (itemSearch) {
                const auto found = g_itemsByPlugin.find(plugin.name);
                if (found != g_itemsByPlugin.end()) count = AIE::PluginSearch::Count(found->second, tokens);
            }
            if (nameMatch || count > 0) {
                response.results.push_back({plugin.name, plugin.light, count, nameMatch});
                response.totalItemMatches += count;
            }
        }
        return response;
    }

    void ConfigureScaleformCallbacks()
    {
        AIE::ScaleformUI::Callbacks callbacks;
        callbacks.close = OnClose;
        callbacks.enterPlugin = OnEnterPlugin;
        callbacks.endSession = OnEndSession;
        callbacks.transferItem = OnTransfer;
        callbacks.takeAll = OnTakeAll;
        callbacks.returnAll = OnReturnAll;
        callbacks.searchFocus = OnSearchFocus;
        callbacks.searchPluginsAndItems = [](std::string query) {
            // Do not acquire g_mutex or reenter GFx inside a GFx callback.
            QueueGameTask([query = std::move(query)] {
                if (!AIE::ScaleformUI::IsOpen()) return;
                const auto response = OnSearchPluginsAndItems(query);
                AIE::ScaleformUI::DeliverPluginSearchResults(response);
            });
        };
        callbacks.removedFromStack = OnScaleformMenuRemoved;
        AIE::ScaleformUI::SetCallbacks(std::move(callbacks));
    }

    void HideForConsole()
    {
        if (!g_menuOpen || g_hiddenForConsole) return;
        g_hiddenForConsole = true;
        g_consoleRequestedAt = GetTickCount64();
        AIE::ScaleformUI::SetHidden(true);
        SetGameplayInputBlocked(false);
    }

    void UpdateConsoleCoverState()
    {
        if (!g_menuOpen || !g_hiddenForConsole) return;
        auto* ui = RE::UI::GetSingleton();
        if (!ui) return;
        const bool consoleOpen = ui->GetMenuOpen(RE::BSFixedString("Console"));
        const bool requestPending = g_consoleRequestedAt && GetTickCount64() - g_consoleRequestedAt < 900;
        if (consoleOpen || requestPending) return;
        g_hiddenForConsole = false;
        g_consoleRequestedAt = 0;
        SetGameplayInputBlocked(true);
        AIE::ScaleformUI::SetHidden(false);
    }

    void StartMonitor()
    {
        if (g_monitorStarted.exchange(true)) return;
        std::thread([] {
            while (true) {
                Sleep(g_menuOpen ? 100 : 1000);
                if (!g_menuOpen) continue;
                QueueGameTask([] {
                    std::lock_guard lock(g_mutex);
                    UpdateConsoleCoverState();
                });
            }
        }).detach();
    }

    void RegisterInputHandler()
    {
        AIE::ScaleformUI::RegisterMenu();
    }
    void EnsureLauncher()
    {
        if (!g_config.addLauncherOnLoad) return;
        auto* data = RE::TESDataHandler::GetSingleton();
        auto* player = RE::PlayerCharacter::GetSingleton();
        auto* form = data ? data->LookupForm(kLauncherLocalFormID, kPluginFile) : nullptr;
        auto* object = form ? form->As<RE::TESBoundObject>() : nullptr;
        if (!player || !object) {
            Log("Launcher form unavailable; ESP may not be installed yet");
            return;
        }
        if (InventoryCount(player, object) == 0) {
            player->AddObjectToContainer(object, {}, 1, nullptr, RE::ITEM_REMOVE_REASON::kNone);
            Log("Launcher item added to player");
        }
    }

    void ResetRuntimeState()
    {
        CloseMenuInternal();
        std::lock_guard lock(g_mutex);
        g_plugins.clear();
        g_itemsByPlugin.clear();
        g_scanReady = false;
        g_transferQueued = false;
        g_scanQueued = false;
    }

    void F4SEAPI RevertCallback(const F4SE::SerializationInterface*)
    {
        ResetRuntimeState();
    }

    void PrewarmAndScan()
    {
        std::thread([] {
            Sleep(1200);
            QueueGameTask([] {
                std::lock_guard lock(g_mutex);
                AIE::ScaleformUI::RegisterMenu();
                if (!g_scanReady) {
                    ScanLoadedData();
                }
                g_scanQueued = false;
                EnsureLauncher();
                if (g_menuOpen) {
                    PushPluginsToUI();
                }
            });
        }).detach();
    }

    void F4SEMessageHandler(F4SE::MessagingInterface::Message* message)
    {
        if (!message) return;
        if (message->type == F4SE::MessagingInterface::kInputLoaded ||
            message->type == F4SE::MessagingInterface::kGameLoaded ||
            message->type == F4SE::MessagingInterface::kPostLoadGame) {
            RegisterInputHandler();
        }
        if (message->type == F4SE::MessagingInterface::kGameLoaded ||
            message->type == F4SE::MessagingInterface::kPostLoadGame) {
            ResetRuntimeState();
            PrewarmAndScan();
        }
    }
}

AIE_EXPORT F4SE::PluginVersionData F4SEPlugin_Version = []() noexcept {
    F4SE::PluginVersionData version{};
    version.PluginVersion({ 1, 0, 2, 0 });
    version.PluginName(kPluginName);
    version.AuthorName("Aozora");
    version.UsesAddressLibrary(true);
    version.UsesAddressLibraryNG(true);
    version.UsesSigScanning(false);
    version.IsLayoutDependent(true);
    version.IsLayoutDependentNG(true);
    version.HasNoStructUse(false);
    version.CompatibleVersions({
        F4SE::RUNTIME_1_10_162, F4SE::RUNTIME_1_10_163,
        F4SE::RUNTIME_1_10_980, F4SE::RUNTIME_1_10_984,
        F4SE::RUNTIME_1_11_137, F4SE::RUNTIME_1_11_159,
        F4SE::RUNTIME_1_11_169, F4SE::RUNTIME_1_11_191,
        F4SE::RUNTIME_1_11_221
    });
    return version;
}();

bool AIE_IsMenuAvailable(std::monostate)
{
    AIE::ScaleformUI::RegisterMenu();
    return AIE::ScaleformUI::IsRegistered();
}

bool AIE_OpenMenu(std::monostate)
{
    {
        std::lock_guard lock(g_mutex);
        if (!g_menuOpen) {
            g_launcherPending = false;
            g_launcherReadyAt = 0;
            return OpenMenuInternal("keyboard");
        }
    }
    if (g_menuOpen) {
        CloseMenuInternal();
        return true;
    }
    return false;
}

void AIE_CloseMenu(std::monostate)
{
    CloseMenuInternal();
}

bool AIE_IsMenuOpen(std::monostate)
{
    return g_menuOpen;
}

void AIE_OpenFromLauncher(std::monostate)
{
    bool expected = false;
    if (!g_launcherPending.compare_exchange_strong(expected, true)) {
        return;
    }
    g_launcherReadyAt = 0;

    if (auto* tasks = F4SE::GetTaskInterface()) {
        tasks->AddUITask([] {
            if (auto* queue = RE::UIMessageQueue::GetSingleton()) {
                queue->AddMessage("PipboyMenu", RE::UI_MESSAGE_TYPE::kHide);
            }
        });
    }

    std::thread([] {
        const auto deadline = GetTickCount64() + 3000;
        while (GetTickCount64() < deadline && g_launcherPending.load()) {
            if (!QueueGameTask([] {
                std::lock_guard lock(g_mutex);
                if (!g_launcherPending.load()) {
                    return;
                }
                if (g_menuOpen) {
                    g_launcherPending = false;
                    g_launcherReadyAt = 0;
                    return;
                }
                auto waitReason = GameplayOpenBlockReason();
                if (auto* pipboy = RE::PipboyManager::GetSingleton();
                    pipboy && (pipboy->pipboyOpening || pipboy->pipboyClosing || pipboy->pipboyRaising)) {
                    waitReason = "pipboy-animation";
                }
                if (!waitReason.empty()) {
                    static std::string lastWaitReason;
                    if (lastWaitReason != waitReason) {
                        Log("LAUNCHER_WAIT reason=" + waitReason);
                        lastWaitReason = waitReason;
                    }
                    g_launcherReadyAt = 0;
                    return;
                }

                const auto now = GetTickCount64();
                const auto readyAt = g_launcherReadyAt.load();
                if (readyAt == 0) {
                    g_launcherReadyAt = now;
                    return;
                }
                // Keep the menu closed for a short settle period after the
                // Pip-Boy flag drops, so its close animation cannot overlap
                // the custom menu opening.
                if (now - readyAt < 400) {
                    return;
                }

                const auto* devices = RE::BSInputDeviceManager::GetSingleton();
                const bool gamepad = devices && devices->IsGamepadConnected();
                if (OpenMenuInternal(gamepad ? "gamepad" : "keyboard")) {
                    g_launcherPending = false;
                    g_launcherReadyAt = 0;
                }
            })) {
                break;
            }
            Sleep(50);
        }
        g_launcherReadyAt = 0;
        g_launcherPending = false;
    }).detach();
}

bool RegisterPapyrus(RE::BSScript::IVirtualMachine* vm)
{
    if (!vm) return false;
    vm->BindNativeMethod("AozoraItemExtractorNative", "IsMenuAvailable", AIE_IsMenuAvailable);
    vm->BindNativeMethod("AozoraItemExtractorNative", "OpenMenu", AIE_OpenMenu);
    vm->BindNativeMethod("AozoraItemExtractorNative", "CloseMenu", AIE_CloseMenu);
    vm->BindNativeMethod("AozoraItemExtractorNative", "IsMenuOpen", AIE_IsMenuOpen);
    vm->BindNativeMethod("AozoraItemExtractorNative", "OpenFromLauncher", AIE_OpenFromLauncher);
    return true;
}

F4SE_PLUGIN_LOAD(const F4SE::LoadInterface* f4seInterface)
{
    F4SE::Init(f4seInterface, { .log = false });
    Log("Aozora Item Extractor load");
    ReadConfig();
    ConfigureScaleformCallbacks();
    if (auto* messaging = F4SE::GetMessagingInterface()) {
        messaging->RegisterListener(F4SEMessageHandler);
    }
    if (auto* papyrus = F4SE::GetPapyrusInterface()) {
        papyrus->Register(RegisterPapyrus);
    }
    if (auto* serialization = F4SE::GetSerializationInterface()) {
        serialization->SetUniqueID(kSerializationID);
        serialization->SetRevertCallback(RevertCallback);
    }
    RegisterInputHandler();
    StartMonitor();
    return true;
}

AIE_EXPORT bool F4SEPlugin_Query(const F4SE::QueryInterface* f4se, F4SE::PluginInfo* info)
{
    info->infoVersion = F4SE::PluginInfo::kVersion;
    info->name = kPluginName;
    info->version = 1;
    if (f4se->IsEditor()) return false;
    return f4se->RuntimeVersion() >= F4SE::RUNTIME_1_10_162;
}
