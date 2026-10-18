#pragma once
#include <chrono>
#include <atomic>
#include <cstdint>
#include <string>
#include "F4SE/F4SE.h"

namespace AIE::Perf
{
    inline std::atomic_bool enabled{false};
    inline std::uint64_t NowUs()
    {
        return std::chrono::duration_cast<std::chrono::microseconds>(
            std::chrono::steady_clock::now().time_since_epoch()).count();
    }
    inline thread_local std::uint64_t trace = 0;
    inline thread_local std::uint64_t requestedUs = 0;
    inline thread_local std::string plugin;
    struct Context
    {
        std::uint64_t previousTrace = trace, previousRequest = requestedUs;
        std::string previousPlugin = plugin;
        Context(std::uint64_t id, std::uint64_t request, std::string name)
        { trace = id; requestedUs = request; plugin = std::move(name); }
        ~Context() { trace = previousTrace; requestedUs = previousRequest; plugin = std::move(previousPlugin); }
    };
    struct Stage
    {
        const char* name;
        std::uint64_t start = NowUs();
        explicit Stage(const char* value) : name(value) {}
        ~Stage() { if (enabled.load(std::memory_order_relaxed)) REX::INFO("[AIE-P02] trace={} plugin=\"{}\" stage={} us={}", trace, plugin, name, NowUs()-start); }
    };
}

#define AIE_PERF_LOG(...) do { if (AIE::Perf::enabled.load(std::memory_order_relaxed)) REX::INFO(__VA_ARGS__); } while (false)
