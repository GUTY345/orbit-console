// SPDX-FileCopyrightText: Copyright 2026 shadPS4 Emulator Project
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

#include <array>
#include <cstddef>
#include <string>
#include "common/types.h"

namespace Core::CPU::CustomBridge {

struct GuestRegisterContext {
    enum Register : std::size_t {
        Rax,
        Rcx,
        Rdx,
        Rbx,
        Rsp,
        Rbp,
        Rsi,
        Rdi,
        R8,
        R9,
        R10,
        R11,
        R12,
        R13,
        R14,
        R15,
        Count,
    };

    std::array<u64, Count> gpr{};
    u64 rip{};
    u64 rflags{0x202};
    u64 fs_base{};
    u64 gs_base{};
    u64 instruction_counter{};
    bool halted{};
    bool suspended{};

    // XMM state is required very early by real PS4 titles. This interpreter keeps a
    // conservative 128-bit SIMD view first; a future dynarec can widen this to YMM.
    std::array<std::array<u8, 16>, 16> xmm{};
    u32 mxcsr{0x1f80};
};

class CustomCPUTranslator {
public:
    using ExitFunc = void(PS4_SYSV_ABI*)();

    bool Initialize(const u8* guest_code_base);
    void TranslateBlock(u64 guest_pc);
    void ExecuteRegistersContext(void* context);

    bool ExecuteEntry(u64 entry_pc, void* entry_params, ExitFunc exit_func);
    const char* LastStatus() const;

private:
    enum class StepResult {
        Continue,
        Halt,
        Unsupported,
        Fault,
    };

    StepResult Step(GuestRegisterContext& context);
    StepResult DecodeOneByte(GuestRegisterContext& context, u8 op);
    StepResult DecodeRex(GuestRegisterContext& context, u8 rex);
    StepResult DecodePrefixed(GuestRegisterContext& context, u8 prefix);
    StepResult DecodeTwoByte(GuestRegisterContext& context, u64 opcode_rip, u8 prefix,
                             u8 rex_byte);
    StepResult DecodeGroup1(GuestRegisterContext& context, u8 rex, u8 op);
    StepResult DecodeJccShort(GuestRegisterContext& context, u8 op);
    StepResult DecodeJccNear(GuestRegisterContext& context, u64 opcode_rip);
    bool CheckCondition(GuestRegisterContext& context, u8 condition) const;
    void UpdateArithmeticFlags(GuestRegisterContext& context, u64 lhs, u64 rhs, u64 result,
                               u8 width, bool subtract);
    void UpdateLogicFlags(GuestRegisterContext& context, u64 result, u8 width);
    u64 ReadGpr(const GuestRegisterContext& context, std::size_t reg, u8 width) const;
    void WriteGpr(GuestRegisterContext& context, std::size_t reg, u8 width, u64 value);
    bool Push64(GuestRegisterContext& context, u64 value);
    bool Pop64(GuestRegisterContext& context, u64& value);
    bool ReadMemory(u64 address, void* out, std::size_t size) const;
    bool WriteMemory(u64 address, const void* in, std::size_t size) const;
    bool ReadXmmOperand(const GuestRegisterContext& context, std::size_t reg, u64 address,
                        bool from_memory, void* out, std::size_t size) const;
    bool WriteXmmOperand(GuestRegisterContext& context, std::size_t reg, u64 address,
                         bool to_memory, const void* in, std::size_t size);
    u8 Read8(u64 address, bool& ok) const;
    u32 Read32(u64 address, bool& ok) const;
    u64 Read64(u64 address, bool& ok) const;
    bool Write64(u64 address, u64 value);
    void LogUnsupported(const GuestRegisterContext& context, u64 rip, u8 opcode);
    void AppendFileLog(const std::string& line) const;
    std::string FormatRegisterDump(const GuestRegisterContext& context) const;
    std::string FormatBytes(u64 rip, std::size_t count) const;
    std::string Disassemble(u64 rip) const;
    void SetStatus(const char* status);
    void SetStatus(std::string status);

    const u8* guest_code_base{};
    const char* last_status{"not initialized"};
    std::string owned_status{};
    u64 unsupported_rip{};
    u8 unsupported_opcode{};
};

} // namespace Core::CPU::CustomBridge
