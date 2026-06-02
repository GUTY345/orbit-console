// SPDX-FileCopyrightText: Copyright 2026 shadPS4 Emulator Project
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

#include <cstddef>
#include <cstdint>
#include <filesystem>

#include "common/types.h"

namespace Common::IOSLowMemory {

struct Budget {
    u64 process_soft_limit = 2800_MB;
    u64 backing_limit = 2800_MB;
    u64 texture_trigger = 384_MB;
    u64 texture_pressure = 768_MB;
    u64 texture_critical = 1024_MB;
    u64 max_cached_blob = 16_MB;
    u64 chunk_size = 32_MB;
};

bool IsEnabled();
Budget GetBudget();
void ConfigureProcess();
void StartWatchdog();
void StopWatchdog();
void PurgeNow(const char* reason);
class ScopedRenderCriticalSection {
public:
    ScopedRenderCriticalSection();
    ~ScopedRenderCriticalSection();
};
u64 ClampBackingSize(u64 requested);
bool ShouldSkipPipelineWarmup();
bool ShouldDropCacheBlob(u64 bytes);
bool ShouldRunImmediateGC(u64 used_memory, u64 tick);
void LogLaunchProfile(const std::filesystem::path& executable);

} // namespace Common::IOSLowMemory
