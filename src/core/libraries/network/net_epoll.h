// SPDX-FileCopyrightText: Copyright 2025 shadPS4 Emulator Project
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

#include "common/types.h"
#include "core/libraries/network/net.h"

#include <deque>
#include <mutex>
#include <vector>

#ifdef _WIN32
#include <wepoll.h>
#endif

#if defined(__APPLE__)
#include <TargetConditionals.h>
#endif

#if defined(__APPLE__) && TARGET_OS_IPHONE
constexpr int EPOLL_CTL_ADD = 1;
constexpr int EPOLL_CTL_MOD = 2;
constexpr int EPOLL_CTL_DEL = 3;
constexpr u32 EPOLLIN = 0x001;
constexpr u32 EPOLLOUT = 0x004;
constexpr u32 EPOLLERR = 0x008;
constexpr u32 EPOLLHUP = 0x010;

union epoll_data_t {
    void* ptr;
    int fd;
    u32 u32;
    u64 u64;
};

struct epoll_event {
    u32 events;
    epoll_data_t data;
};

inline int epoll_create1(int) {
    return -2;
}

inline int epoll_ctl(int, int, int, epoll_event*) {
    return 0;
}

inline int epoll_wait(int, epoll_event*, int, int) {
    return 0;
}
#endif

#if defined(__linux__) || defined(__APPLE__) || defined(__FreeBSD__)
// ADD libepoll-shim if using freebsd!
#if !defined(__APPLE__) || !TARGET_OS_IPHONE
#include <sys/epoll.h>
#endif
#include <unistd.h>
#endif

namespace Libraries::Net {

#ifdef _WIN32
using epoll_handle = HANDLE;
#else
using epoll_handle = int;
#endif

struct Epoll {
    std::vector<std::pair<u32 /*netId*/, OrbisNetEpollEvent>> events{};
    std::string name;
    epoll_handle epoll_fd;
    std::deque<u32> async_resolutions{};

    explicit Epoll(const char* name_) : name(name_), epoll_fd(epoll_create1(0)) {
#ifdef _WIN32
        ASSERT(epoll_fd != nullptr);
#else
        ASSERT(epoll_fd != -1);
#endif
        if (name_ == nullptr) {
            name = "anon";
        }
    }

    bool Destroyed() const noexcept {
        return destroyed;
    }

    void Destroy() noexcept {
        events.clear();
#ifdef _WIN32
        epoll_close(epoll_fd);
        epoll_fd = nullptr;
#elif defined(__APPLE__) && TARGET_OS_IPHONE
        epoll_fd = -1;
#else
        close(epoll_fd);
        epoll_fd = -1;
#endif
        name = "";
        destroyed = true;
    }

private:
    bool destroyed{};
};

u32 ConvertEpollEventsIn(u32 orbis_events);
u32 ConvertEpollEventsOut(u32 epoll_events);

class EpollTable {
public:
    EpollTable() = default;
    virtual ~EpollTable() = default;

    int CreateHandle(const char* name);
    void DeleteHandle(int d);
    Epoll* GetEpoll(int d);

private:
    std::vector<Epoll> epolls;
    std::mutex m_mutex;
};

} // namespace Libraries::Net
