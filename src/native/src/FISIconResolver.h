#pragma once

#include <string>

namespace RE
{
    class TESBoundObject;
}

namespace AIE
{
    struct FISIcon
    {
        std::string library;
        std::string className;
    };

    FISIcon ResolveFISIcon(RE::TESBoundObject* object, const std::string& displayName);
}
