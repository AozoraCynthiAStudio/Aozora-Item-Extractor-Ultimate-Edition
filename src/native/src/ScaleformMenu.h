#pragma once

#include <cstdint>
#include <functional>
#include <string>
#include <vector>

namespace AIE::ScaleformUI
{
    struct PluginRow
    {
        std::string name;
        bool light{ false };
    };

    struct ItemRow
    {
        std::uint32_t formID{ 0 };
        std::string name;
        std::string category;
        std::uint32_t count{ 0 };
        std::uint32_t group{ 1 };
        std::uint32_t returnable{ 0 };
        std::string iconLibrary;
        std::string iconClass;
        std::uint32_t starterAmmoCount{ 0 };
    };

    struct Theme
    {
        int mode{ 0 };
        int preset{ 0 };
        float r{ 0.40F };
        float g{ 1.00F };
        float b{ 0.70F };
    };

    struct Snapshot
    {
        std::vector<PluginRow> plugins;
        std::vector<ItemRow> items;
        std::vector<ItemRow> session;
        std::string inputMode{ "keyboard" };
        std::string plugin;
        std::string page{ "nav" };
        Theme theme;
        bool mascotEnabled{ true };
    };

    struct PluginSearchRow
    {
        std::string name;
        bool light{ false };
        std::uint32_t matchCount{ 0 };
        bool pluginNameMatch{ false };
    };
    struct PluginSearchResponse
    {
        std::string query;
        std::vector<PluginSearchRow> results;
        std::uint32_t totalItemMatches{ 0 };
    };

    struct Callbacks
    {
        std::function<void()> initialize;
        std::function<void()> close;
        std::function<void()> endSession;
        std::function<void()> takeAll;
        std::function<void()> returnAll;
        std::function<void(std::string)> enterPlugin;
        std::function<void(std::uint32_t, bool, std::uint32_t)> transferItem;
        std::function<void(bool)> searchFocus;
        std::function<void(std::string)> searchPluginsAndItems;
        std::function<void()> removedFromStack;
    };

    void SetCallbacks(Callbacks callbacks);
    void DeliverPluginSearchResults(const PluginSearchResponse& response);
    void SetSnapshot(Snapshot snapshot);
    void UpdateSession(std::vector<ItemRow> session);
    void SetInputMode(std::string inputMode);

    void RegisterMenu();
    [[nodiscard]] bool IsRegistered();
    [[nodiscard]] bool IsOpen();
    bool Open();
    void Close();
    void SetHidden(bool hidden);
    void SendKey(const char* key, std::int32_t focusSource = 1);
}
