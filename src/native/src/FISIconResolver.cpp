#include "FISIconResolver.h"
#include "Performance.h"

#include <algorithm>
#include <array>
#include <cctype>
#include <filesystem>
#include <fstream>
#include <iterator>
#include <optional>
#include <regex>
#include <string_view>
#include <system_error>
#include <unordered_map>
#include <vector>

#include "RE/Fallout.h"
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <Windows.h>

namespace AIE
{
    namespace
    {
        struct TagIconRule
        {
            std::string tag;
            FISIcon icon;
        };

        struct AutoTagRule
        {
            std::string section;
            std::string tag;
            bool wildcard{ false };
            std::optional<std::regex> pattern;
        };

        std::vector<TagIconRule> g_tagRules;
        std::vector<AutoTagRule> g_autoTagRules;
        std::unordered_map<std::uint32_t, FISIcon> g_iconCache;
        bool g_rulesLoaded{ false };
        std::unordered_map<std::string, std::size_t> g_tagIndex;
        struct SectionStats
        {
            std::uint64_t calls{}, hits{}, misses{}, nameUs{}, autoUs{}, keywordUs{}, totalUs{}, regexTests{};
        };
        thread_local bool g_profiling = false;
        thread_local std::unordered_map<std::string, SectionStats> g_sections;
        thread_local std::uint64_t g_rulesUs = 0;
        thread_local std::uint64_t g_regexTests = 0;

        std::filesystem::path GameRoot()
        {
            wchar_t buffer[MAX_PATH]{};
            GetModuleFileNameW(nullptr, buffer, MAX_PATH);
            return std::filesystem::path(buffer).parent_path();
        }

        std::string Trim(std::string value)
        {
            const auto first = value.find_first_not_of(" \t\r\n");
            if (first == std::string::npos) return {};
            const auto last = value.find_last_not_of(" \t\r\n");
            return value.substr(first, last - first + 1);
        }

        std::string LowerAscii(std::string value)
        {
            for (auto& ch : value) {
                if (ch >= 'A' && ch <= 'Z') ch = static_cast<char>(ch - 'A' + 'a');
            }
            return value;
        }

        std::optional<std::string> Attribute(std::string_view element, std::string_view name)
        {
            std::size_t cursor = 0;
            while ((cursor = element.find(name, cursor)) != std::string_view::npos) {
                const auto before = cursor == 0 ? '\0' : element[cursor - 1];
                const auto endName = cursor + name.size();
                const auto after = endName < element.size() ? element[endName] : '\0';
                const auto identifier = [](char ch) {
                    return (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z') ||
                        (ch >= '0' && ch <= '9') || ch == '_' || ch == '-';
                };
                if (identifier(before) || identifier(after)) {
                    cursor = endName;
                    continue;
                }
                auto value = endName;
                while (value < element.size() && std::isspace(static_cast<unsigned char>(element[value]))) ++value;
                if (value >= element.size() || element[value++] != '=') {
                    cursor = endName;
                    continue;
                }
                while (value < element.size() && std::isspace(static_cast<unsigned char>(element[value]))) ++value;
                if (value >= element.size() || (element[value] != '\'' && element[value] != '"')) return std::nullopt;
                const auto quote = element[value++];
                const auto end = element.find(quote, value);
                return end == std::string_view::npos ? std::nullopt :
                    std::optional<std::string>(element.substr(value, end - value));
            }
            return std::nullopt;
        }

        bool TagBegins(std::string_view text, std::size_t cursor, std::string_view tag)
        {
            if (cursor == std::string_view::npos || text.compare(cursor, tag.size(), tag) != 0) return false;
            const auto next = cursor + tag.size();
            return next >= text.size() || std::isspace(static_cast<unsigned char>(text[next])) ||
                text[next] == '>' || text[next] == '/';
        }

        void ParseFISFile(const std::filesystem::path& path)
        {
            std::ifstream file(path, std::ios::binary);
            if (!file.is_open()) return;
            const std::string xml((std::istreambuf_iterator<char>(file)), std::istreambuf_iterator<char>());
            std::size_t cursor = 0;
            while ((cursor = xml.find("<tags", cursor)) != std::string::npos) {
                if (!TagBegins(xml, cursor, "<tags")) { cursor += 5; continue; }
                const auto startEnd = xml.find('>', cursor);
                if (startEnd == std::string::npos) break;
                const auto library = Attribute(std::string_view(xml).substr(cursor, startEnd - cursor + 1), "iconLibraryFile");
                if (!library || library->empty()) { cursor = startEnd + 1; continue; }
                const auto close = xml.find("</tags>", startEnd + 1);
                if (close == std::string::npos) break;
                std::size_t tagCursor = startEnd + 1;
                while ((tagCursor = xml.find("<tag", tagCursor)) != std::string::npos && tagCursor < close) {
                    if (!TagBegins(xml, tagCursor, "<tag")) { tagCursor += 4; continue; }
                    const auto tagEnd = xml.find('>', tagCursor);
                    if (tagEnd == std::string::npos || tagEnd >= close) break;
                    const auto element = std::string_view(xml).substr(tagCursor, tagEnd - tagCursor + 1);
                    const auto keyword = Attribute(element, "keyword");
                    const auto iconClass = Attribute(element, "icon");
                    if (keyword && iconClass && !keyword->empty() && !iconClass->empty()) {
                        g_tagRules.push_back({ Trim(*keyword), { Trim(*library), Trim(*iconClass) } });
                    }
                    tagCursor = tagEnd + 1;
                }
                cursor = close + 7;
            }
        }

        void ParseAutoTags(const std::filesystem::path& path)
        {
            std::ifstream file(path, std::ios::binary);
            if (!file.is_open()) return;
            std::string section;
            std::string line;
            while (std::getline(file, line)) {
                if (line.size() >= 3 && static_cast<unsigned char>(line[0]) == 0xEF &&
                    static_cast<unsigned char>(line[1]) == 0xBB && static_cast<unsigned char>(line[2]) == 0xBF) line.erase(0, 3);
                line = Trim(std::move(line));
                if (line.empty() || line.front() == ';' || line.front() == '#') continue;
                if (line.front() == '[' && line.back() == ']') {
                    section = LowerAscii(Trim(line.substr(1, line.size() - 2)));
                    continue;
                }
                const auto equals = line.find('=');
                if (section.empty() || equals == std::string::npos) continue;
                const auto patternText = Trim(line.substr(0, equals));
                const auto value = Trim(line.substr(equals + 1));
                const auto tagStart = value.find('[');
                const auto tagEnd = tagStart == std::string::npos ? std::string::npos : value.find(']', tagStart + 1);
                if (patternText.empty() || tagStart == std::string::npos || tagEnd <= tagStart + 1) continue;
                AutoTagRule rule;
                rule.section = section;
                rule.tag = Trim(value.substr(tagStart + 1, tagEnd - tagStart - 1));
                rule.wildcard = patternText == "*";
                if (!rule.wildcard) {
                    try {
                        rule.pattern.emplace(patternText, std::regex::icase);
                    } catch (const std::regex_error&) {
                        continue;
                    }
                }
                g_autoTagRules.push_back(std::move(rule));
            }
        }

        void LoadRules()
        {
            if (g_rulesLoaded) return;
            const auto rulesStart = Perf::NowUs();
            g_rulesLoaded = true;
            const auto data = GameRoot() / "Data" / "Interface" / "ItemSorter";
            const std::array baseCandidates{
                data / "FIS (FallUI Item Sorter).xml",
                data / "FIS" / "FIS (FallUI Item Sorter).xml"
            };
            for (const auto& candidate : baseCandidates) {
                std::error_code error;
                if (std::filesystem::is_regular_file(candidate, error)) {
                    ParseFISFile(candidate);
                    break;
                }
            }
            const auto addons = data / "FIS" / "TagConfiguration.Addons";
            std::error_code error;
            if (std::filesystem::is_directory(addons, error)) {
                std::vector<std::filesystem::path> files;
                for (const auto& entry : std::filesystem::directory_iterator(addons, error)) {
                    if (!error && entry.is_regular_file(error) && LowerAscii(entry.path().extension().string()) == ".xml") files.push_back(entry.path());
                }
                std::sort(files.begin(), files.end());
                for (const auto& file : files) ParseFISFile(file);
            }
            const auto autoTags = data / "FIS" / "AutoTags";
            const std::array autoTagCandidates{ autoTags / "AutoTags_en.ini", autoTags / "AutoTags_cn.ini" };
            for (const auto& candidate : autoTagCandidates) {
                std::error_code autoTagError;
                if (std::filesystem::is_regular_file(candidate, autoTagError)) ParseAutoTags(candidate);
            }
            // Preserve the existing later-rule-wins priority.
            for (std::size_t i = 0; i < g_tagRules.size(); ++i) g_tagIndex[g_tagRules[i].tag] = i;
            if (g_profiling) g_rulesUs += Perf::NowUs()-rulesStart;
        }

        FISIcon IconForTag(std::string_view tag)
        {
            LoadRules();
            const auto found = g_tagIndex.find(std::string(tag));
            return found != g_tagIndex.end() ? g_tagRules[found->second].icon : FISIcon{};
        }

        std::string SectionForObject(RE::TESBoundObject* object)
        {
            if (!object) return {};
            switch (object->GetFormType()) {
            case RE::ENUM_FORM_ID::kWEAP: return "weap";
            case RE::ENUM_FORM_ID::kARMO: return "armo";
            case RE::ENUM_FORM_ID::kALCH: return "alch";
            case RE::ENUM_FORM_ID::kAMMO: return "ammo";
            case RE::ENUM_FORM_ID::kMISC: return "misc";
            case RE::ENUM_FORM_ID::kNOTE: return "note";
            case RE::ENUM_FORM_ID::kBOOK: return "book";
            case RE::ENUM_FORM_ID::kOMOD: return "omod";
            case RE::ENUM_FORM_ID::kCMPO: return "cmpo";
            case RE::ENUM_FORM_ID::kINGR: return "ingr";
            case RE::ENUM_FORM_ID::kKEYM: return "keym";
            default: return {};
            }
        }

        FISIcon IconForAutoTag(std::string_view name, std::string_view section)
        {
            LoadRules();
            for (const auto& rule : g_autoTagRules) {
                if (g_profiling && rule.section == section && !rule.wildcard && rule.pattern) ++g_regexTests;
                if (rule.section == section && !rule.wildcard && rule.pattern &&
                    std::regex_search(name.begin(), name.end(), *rule.pattern)) {
                    auto icon = IconForTag(rule.tag);
                    if (!icon.className.empty()) return icon;
                }
            }
            for (const auto& rule : g_autoTagRules) {
                if (rule.section == section && rule.wildcard) {
                    auto icon = IconForTag(rule.tag);
                    if (!icon.className.empty()) return icon;
                }
            }
            return {};
        }

        FISIcon IconForName(std::string_view name)
        {
            LoadRules();
            std::size_t start = 0;
            while (start < name.size() && std::isspace(static_cast<unsigned char>(name[start]))) ++start;
            if (start >= name.size() || std::string_view("|{[(").find(name[start]) == std::string_view::npos) return {};
            const auto end = name.find_first_of("|}])", start + 1);
            if (end == std::string_view::npos || end <= start + 1) return {};
            return IconForTag(Trim(std::string(name.substr(start + 1, end - start - 1))));
        }

        FISIcon IconForKeywords(RE::TESBoundObject* object)
        {
            LoadRules();
            auto* keywordForm = object ? object->As<RE::BGSKeywordForm>() : nullptr;
            if (!keywordForm) return {};
            std::optional<std::size_t> best;
            keywordForm->ForEachKeyword([&](RE::BGSKeyword* keyword) {
                const auto found = g_tagIndex.find(keyword->formEditorID.c_str());
                if (found != g_tagIndex.end() && (!best || found->second > *best)) best = found->second;
                return RE::BSContainer::ForEachResult::kContinue;
            });
            return best ? g_tagRules[*best].icon : FISIcon{};
        }
    }

    FISIcon ResolveFISIcon(RE::TESBoundObject* object, const std::string& displayName)
    {
        if (!object) return {};
        const auto started = g_profiling ? Perf::NowUs() : 0;
        const auto section = SectionForObject(object);
        auto* stats = g_profiling ? &g_sections[section.empty() ? "unknown" : section] : nullptr;
        if (stats) ++stats->calls;
        const auto id = object->GetFormID();
        if (const auto cached = g_iconCache.find(id); cached != g_iconCache.end()) {
            if (stats) { ++stats->hits; stats->totalUs += Perf::NowUs()-started; }
            return cached->second;
        }
        if (stats) ++stats->misses;
        auto phase = stats ? Perf::NowUs() : 0;
        auto icon = IconForName(displayName);
        if (stats) stats->nameUs += Perf::NowUs()-phase;
        if (icon.className.empty()) {
            phase = stats ? Perf::NowUs() : 0;
            const auto tests = g_regexTests;
            icon = IconForAutoTag(displayName, section);
            if (stats) { stats->autoUs += Perf::NowUs()-phase; stats->regexTests += g_regexTests-tests; }
        }
        if (icon.className.empty()) {
            phase = stats ? Perf::NowUs() : 0; icon = IconForKeywords(object);
            if (stats) stats->keywordUs += Perf::NowUs()-phase;
        }
        g_iconCache.emplace(id, icon);
        if (stats) stats->totalUs += Perf::NowUs()-started;
        return icon;
    }

    void ResetFISCaches()
    {
        AIE_PERF_LOG("[AIE-P02] stage=FISReset icons={} tags={} auto-rules={}", g_iconCache.size(), g_tagRules.size(), g_autoTagRules.size());
        g_iconCache.clear(); g_tagRules.clear(); g_autoTagRules.clear(); g_tagIndex.clear(); g_rulesLoaded = false;
    }
    FISProfile::FISProfile()
    {
        g_sections.clear(); g_rulesUs = 0; g_regexTests = 0; g_profiling = Perf::enabled.load(std::memory_order_relaxed);
    }
    FISProfile::~FISProfile()
    {
        g_profiling = false;
        std::uint64_t total = 0, calls = 0;
        for (const auto& [section, stats] : g_sections) {
            total += stats.totalUs; calls += stats.calls;
            AIE_PERF_LOG("[AIE-P02] trace={} plugin=\"{}\" stage=FISSection section={} calls={} hit={} miss={} resolve-us={} name-us={} autotag-us={} keyword-us={} regex-tests={}",
                Perf::trace, Perf::plugin, section, stats.calls, stats.hits, stats.misses, stats.totalUs,
                stats.nameUs, stats.autoUs, stats.keywordUs, stats.regexTests);
        }
        AIE_PERF_LOG("[AIE-P02] trace={} plugin=\"{}\" stage=FISTotal calls={} resolve-us={} rules-load-us={} icon-cache={} tags={} auto-rules={}",
            Perf::trace, Perf::plugin, calls, total, g_rulesUs, g_iconCache.size(), g_tagRules.size(), g_autoTagRules.size());
    }
}
