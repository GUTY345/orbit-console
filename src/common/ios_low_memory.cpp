// SPDX-FileCopyrightText: Copyright 2026 shadPS4 Emulator Project
// SPDX-License-Identifier: GPL-2.0-or-later

#include "common/ios_low_memory.h"

#include <atomic>
#include <chrono>
#include <cstdlib>
#include <mutex>
#include <thread>

#ifdef __APPLE__
#include <malloc/malloc.h>
#endif

#include "common/logging/log.h"
#include "common/thread.h"

namespace Common::IOSLowMemory {
namespace {

std::atomic_bool watchdog_running{false};
std::atomic_bool watchdog_stop{false};
std::thread watchdog_thread{};
std::atomic<u64> last_gc_tick{0};
std::mutex purge_mutex{};
std::atomic<u32> render_critical_depth{0};

u64 EnvU64(const char* name, u64 fallback) {
    const char* raw = std::getenv(name);
    if (raw == nullptr || raw[0] == '\0') {
        return fallback;
    }
    char* end = nullptr;
    const auto parsed = std::strtoull(raw, &end, 10);
    return end != raw ? parsed : fallback;
}

void SetEnvDefault(const char* name, const char* value) {
    if (std::getenv(name) == nullptr) {
        setenv(name, value, 1);
    }
}

} // namespace

bool IsEnabled() {
#if defined(__APPLE__)
    const char* enabled = std::getenv("SHADPS4_IOS_AGGRESSIVE_MEMORY_SAVING");
    return enabled != nullptr && enabled[0] != '\0' && enabled[0] != '0';
#else
    return false;
#endif
}

Budget GetBudget() {
    Budget budget{};
    budget.process_soft_limit =
        EnvU64("SHADPS4_IOS_PROCESS_SOFT_LIMIT_BYTES", budget.process_soft_limit);
    budget.backing_limit = EnvU64("SHADPS4_IOS_BACKING_LIMIT_BYTES", budget.backing_limit);
    budget.texture_trigger = EnvU64("SHADPS4_IOS_TEXTURE_GC_TRIGGER_BYTES", budget.texture_trigger);
    budget.texture_pressure =
        EnvU64("SHADPS4_IOS_TEXTURE_GC_PRESSURE_BYTES", budget.texture_pressure);
    budget.texture_critical =
        EnvU64("SHADPS4_IOS_TEXTURE_GC_CRITICAL_BYTES", budget.texture_critical);
    budget.max_cached_blob = EnvU64("SHADPS4_IOS_MAX_CACHE_BLOB_BYTES", budget.max_cached_blob);
    budget.chunk_size = EnvU64("SHADPS4_IOS_VM_CHUNK_BYTES", budget.chunk_size);
    return budget;
}

void ConfigureProcess() {
    SetEnvDefault("SHADPS4_IOS_AGGRESSIVE_MEMORY_SAVING", "1");
    SetEnvDefault("SHADPS4_IOS_PROCESS_SOFT_LIMIT_BYTES", "2936012800");
    // Free developer accounts on iPadOS can be killed well below the entitlement-backed ceiling.
    // Keep the initial direct-memory backing small enough to survive startup; later work can
    // stream/expand in smaller chunks once the core reaches the game loop.
    SetEnvDefault("SHADPS4_IOS_BACKING_LIMIT_BYTES", "805306368");
    SetEnvDefault("SHADPS4_IOS_TEXTURE_GC_TRIGGER_BYTES", "402653184");
    SetEnvDefault("SHADPS4_IOS_TEXTURE_GC_PRESSURE_BYTES", "805306368");
    SetEnvDefault("SHADPS4_IOS_TEXTURE_GC_CRITICAL_BYTES", "1073741824");
    SetEnvDefault("SHADPS4_IOS_MAX_CACHE_BLOB_BYTES", "16777216");
    SetEnvDefault("SHADPS4_IOS_VM_CHUNK_BYTES", "33554432");
    SetEnvDefault("SHADPS4_IOS_SKIP_PIPELINE_WARMUP", "1");
    SetEnvDefault("SHADPS4_IOS_DROP_LARGE_CACHE_BLOBS", "1");
    SetEnvDefault("SHADPS4_IOS_PREDICTIVE_STREAMING", "1");
    SetEnvDefault("SHADPS4_IOS_IMMEDIATE_GC_INTERVAL_MS", "1000");
}

void PurgeNow(const char* reason) {
    std::unique_lock lock{purge_mutex, std::try_to_lock};
    if (!lock.owns_lock()) {
        LOG_DEBUG(Core, "iOS low-memory purge skipped while another purge is active: {}",
                  reason != nullptr ? reason : "manual");
        return;
    }
    if (render_critical_depth.load(std::memory_order_acquire) != 0) {
        LOG_DEBUG(Core, "iOS low-memory purge deferred during render critical section: {}",
                  reason != nullptr ? reason : "manual");
        return;
    }
#ifdef __APPLE__
    malloc_zone_pressure_relief(nullptr, 0);
#endif
    LOG_INFO(Core, "iOS low-memory purge requested: {}", reason != nullptr ? reason : "manual");
}

ScopedRenderCriticalSection::ScopedRenderCriticalSection() {
    render_critical_depth.fetch_add(1, std::memory_order_acq_rel);
}

ScopedRenderCriticalSection::~ScopedRenderCriticalSection() {
    render_critical_depth.fetch_sub(1, std::memory_order_acq_rel);
}

void StartWatchdog() {
    ConfigureProcess();
    if (!IsEnabled()) {
        return;
    }
    bool expected = false;
    if (!watchdog_running.compare_exchange_strong(expected, true)) {
        return;
    }
    watchdog_stop = false;
    watchdog_thread = std::thread([] {
        Common::SetCurrentThreadName("shadPS4:iOSLowRAM");
        while (!watchdog_stop.load()) {
            std::this_thread::sleep_for(std::chrono::seconds(1));
            PurgeNow("1s watchdog");
        }
    });
    LOG_INFO(Core, "iOS low-memory watchdog started");
}

void StopWatchdog() {
    if (!watchdog_running.exchange(false)) {
        return;
    }
    watchdog_stop = true;
    if (watchdog_thread.joinable()) {
        watchdog_thread.join();
    }
    LOG_INFO(Core, "iOS low-memory watchdog stopped");
}

u64 ClampBackingSize(u64 requested) {
    if (!IsEnabled()) {
        return requested;
    }
    const auto budget = GetBudget();
    if (requested <= budget.backing_limit) {
        return requested;
    }
    LOG_WARNING(Kernel_Vmm,
                "iOS low-memory mode: clamping backing dmem from {} MiB to {} MiB",
                requested / 1_MB, budget.backing_limit / 1_MB);
    return budget.backing_limit;
}

bool ShouldSkipPipelineWarmup() {
    return IsEnabled() && std::getenv("SHADPS4_IOS_SKIP_PIPELINE_WARMUP") != nullptr;
}

bool ShouldDropCacheBlob(u64 bytes) {
    return IsEnabled() && std::getenv("SHADPS4_IOS_DROP_LARGE_CACHE_BLOBS") != nullptr &&
           bytes > GetBudget().max_cached_blob;
}

bool ShouldRunImmediateGC(u64 used_memory, u64 tick) {
    if (!IsEnabled()) {
        return false;
    }
    const auto budget = GetBudget();
    const auto previous = last_gc_tick.load();
    if (used_memory >= budget.texture_trigger || tick - previous >= 60) {
        last_gc_tick = tick;
        return true;
    }
    return false;
}

void LogLaunchProfile(const std::filesystem::path& executable) {
    if (!IsEnabled()) {
        return;
    }
    const auto budget = GetBudget();
    LOG_INFO(Core,
             "iOS low-memory launch profile active for {}: soft={} MiB backing={} MiB "
             "texture_gc={}/{}/{} MiB cache_blob={} MiB chunk={} MiB",
             executable.string(), budget.process_soft_limit / 1_MB, budget.backing_limit / 1_MB,
             budget.texture_trigger / 1_MB, budget.texture_pressure / 1_MB,
             budget.texture_critical / 1_MB, budget.max_cached_blob / 1_MB,
             budget.chunk_size / 1_MB);
}

} // namespace Common::IOSLowMemory
