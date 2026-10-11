#pragma once
#include <algorithm>
#include <cstdint>
#include <string>
#include <string_view>
#include <vector>

namespace AIE::PluginSearch
{
    inline std::string Normalize(std::string_view value)
    {
        std::string result(value);
        for (auto& c : result) if (c >= 'A' && c <= 'Z') c = static_cast<char>(c + ('a' - 'A'));
        return result;
    }
    inline bool Space(char c) { return c == ' ' || c == '\t' || c == '\r' || c == '\n' || c == '\f' || c == '\v'; }
    inline std::string Trim(std::string_view value)
    {
        while (!value.empty() && Space(value.front())) value.remove_prefix(1);
        while (!value.empty() && Space(value.back())) value.remove_suffix(1);
        return std::string(value);
    }
    inline std::vector<std::string> Tokens(std::string_view query)
    {
        const auto normalized = Normalize(query);
        std::vector<std::string> tokens;
        std::size_t i = 0;
        while (i < normalized.size()) {
            while (i < normalized.size() && Space(normalized[i])) ++i;
            auto start = i;
            while (i < normalized.size() && !Space(normalized[i])) ++i;
            if (i > start) tokens.emplace_back(normalized.substr(start, i - start));
        }
        return tokens;
    }
    inline bool Matches(std::string_view normalizedName, const std::vector<std::string>& tokens)
    {
        return std::all_of(tokens.begin(), tokens.end(), [&](const auto& token) {
            return normalizedName.find(token) != std::string_view::npos;
        });
    }
    // Same threshold as AS3 UTF-16 length for valid UTF-8 names/queries.
    inline std::size_t QueryLength(std::string_view value)
    {
        std::size_t length = 0;
        for (unsigned char c : value) {
            if ((c & 0xC0) != 0x80) length += c >= 0xF0 ? 2 : 1;
        }
        return length;
    }
    template <class Items>
    inline std::uint32_t Count(const Items& items, const std::vector<std::string>& tokens)
    {
        std::uint32_t count = 0;
        for (const auto& item : items) if (Matches(item.normalizedName, tokens)) ++count;
        return count;
    }
}
