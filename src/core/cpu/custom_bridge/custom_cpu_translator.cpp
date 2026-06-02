// SPDX-FileCopyrightText: Copyright 2026 shadPS4 Emulator Project
// SPDX-License-Identifier: GPL-2.0-or-later

#include "core/cpu/custom_bridge/custom_cpu_translator.h"

#include <array>
#include <chrono>
#include <cstring>
#include <filesystem>
#include <fstream>
#include <iterator>
#include <mutex>
#include <sstream>
#include <cstdlib>
#include <fmt/format.h>
#include <Zydis/Zydis.h>
#include <Zycore/Status.h>
#include "common/arch.h"
#include "common/logging/log.h"
#include "core/tls.h"

#if defined(__APPLE__) && defined(ARCH_ARM64)
extern "C" void ShadIOSSetCoreStage(int stage, const char* description);
extern "C" void ShadIOSAppendDiagnosticLog(const char* message);
#endif

namespace Core::CPU::CustomBridge {
namespace {

constexpr u64 MaxInterpreterSteps = 500000;
constexpr u64 FlagCf = 1ull << 0;
constexpr u64 FlagPf = 1ull << 2;
constexpr u64 FlagZf = 1ull << 6;
constexpr u64 FlagSf = 1ull << 7;
constexpr u64 FlagOf = 1ull << 11;
constexpr u8 PrefixNone = 0;
constexpr u8 Prefix66 = 0x66;
constexpr u8 PrefixF2 = 0xf2;
constexpr u8 PrefixF3 = 0xf3;

struct RexPrefix {
    bool w{};
    bool r{};
    bool x{};
    bool b{};
};

struct ModRm {
    u8 raw{};
    u8 mod{};
    u8 reg{};
    u8 rm{};
    u8 sib{};
    s32 disp{};
    std::size_t length{1};
    bool has_sib{};
    bool has_memory{};
    bool rip_relative{};
    u64 address{};
};

constexpr u64 WidthMask(u8 width) {
    return width >= 64 ? ~0ull : ((1ull << width) - 1);
}

constexpr u64 SignBit(u8 width) {
    return 1ull << (width - 1);
}

constexpr const char* RegisterName(std::size_t index) {
    constexpr const char* names[] = {"rax", "rcx", "rdx", "rbx", "rsp", "rbp", "rsi", "rdi",
                                     "r8",  "r9",  "r10", "r11", "r12", "r13", "r14", "r15"};
    return index < std::size(names) ? names[index] : "unknown";
}

RexPrefix DecodeRexPrefix(u8 rex) {
    return RexPrefix{
        .w = (rex & 0x08) != 0,
        .r = (rex & 0x04) != 0,
        .x = (rex & 0x02) != 0,
        .b = (rex & 0x01) != 0,
    };
}

bool DecodeModRm(const GuestRegisterContext& context, u64 rip_after_modrm, RexPrefix rex, ModRm& out,
                 const CustomCPUTranslator&) {
    const auto read8 = [](u64 address, bool& ok) {
        u8 value = 0;
        ok = address != 0;
        if (ok) {
            std::memcpy(&value, reinterpret_cast<const void*>(address), sizeof(value));
        }
        return value;
    };
    const auto read32 = [](u64 address, bool& ok) {
        u32 value = 0;
        ok = address != 0;
        if (ok) {
            std::memcpy(&value, reinterpret_cast<const void*>(address), sizeof(value));
        }
        return value;
    };
    bool ok = false;
    out.raw = read8(rip_after_modrm - 1, ok);
    if (!ok) {
        return false;
    }
    out.mod = (out.raw >> 6) & 0x3;
    out.reg = ((out.raw >> 3) & 0x7) | (rex.r ? 8 : 0);
    out.rm = (out.raw & 0x7) | (rex.b ? 8 : 0);
    out.has_memory = out.mod != 0x3;

    u64 cursor = rip_after_modrm;
    if (!out.has_memory) {
        out.length = 1;
        return true;
    }

    u64 base = 0;
    u64 index = 0;
    u8 scale = 1;
    const u8 low_rm = out.raw & 0x7;

    if (low_rm == 4) {
        out.has_sib = true;
        out.sib = read8(cursor++, ok);
        if (!ok) {
            return false;
        }
        scale = static_cast<u8>(1u << ((out.sib >> 6) & 0x3));
        const u8 index_reg = ((out.sib >> 3) & 0x7) | (rex.x ? 8 : 0);
        const u8 base_reg = (out.sib & 0x7) | (rex.b ? 8 : 0);
        if (index_reg != 4) {
            index = context.gpr[index_reg] * scale;
        }
        if ((out.sib & 0x7) == 5 && out.mod == 0) {
            out.disp = static_cast<s32>(read32(cursor, ok));
            cursor += 4;
            if (!ok) {
                return false;
            }
            base = 0;
        } else {
            base = context.gpr[base_reg];
        }
    } else if (low_rm == 5 && out.mod == 0) {
        out.rip_relative = true;
        out.disp = static_cast<s32>(read32(cursor, ok));
        cursor += 4;
        if (!ok) {
            return false;
        }
        base = cursor;
    } else {
        base = context.gpr[out.rm];
    }

    if (out.mod == 1) {
        out.disp = static_cast<s8>(read8(cursor++, ok));
        if (!ok) {
            return false;
        }
    } else if (out.mod == 2) {
        out.disp = static_cast<s32>(read32(cursor, ok));
        cursor += 4;
        if (!ok) {
            return false;
        }
    }

    out.address = base + index + static_cast<s64>(out.disp);
    out.length = static_cast<std::size_t>(cursor - (rip_after_modrm - 1));
    return true;
}

} // namespace

bool CustomCPUTranslator::Initialize(const u8* guest_code_base_) {
    guest_code_base = guest_code_base_;
    SetStatus("custom cpu translator initialized");
    LOG_INFO(Core_Linker, "CustomCPUTranslator initialized: guest_code_base={}",
             static_cast<const void*>(guest_code_base));
    AppendFileLog(fmt::format("CustomCPUTranslator initialized guest_code_base={:#x}",
                              reinterpret_cast<u64>(guest_code_base)));
    return guest_code_base != nullptr;
}

void CustomCPUTranslator::TranslateBlock(u64 guest_pc) {
    LOG_INFO(Core_Linker, "CustomCPUTranslator TranslateBlock requested at {:#x}", guest_pc);
    AppendFileLog(fmt::format("TranslateBlock requested guest_pc={:#x}", guest_pc));
    SetStatus("decode block requested");
}

void CustomCPUTranslator::ExecuteRegistersContext(void* raw_context) {
    auto* context = static_cast<GuestRegisterContext*>(raw_context);
    if (context == nullptr) {
        SetStatus("null register context");
        LOG_ERROR(Core_Linker, "CustomCPUTranslator ExecuteRegistersContext received null context");
        AppendFileLog("ExecuteRegistersContext received null context");
        return;
    }

    SetStatus("interpreter loop entered");
    AppendFileLog(fmt::format("interpreter loop entered rip={:#x} rsp={:#x}", context->rip,
                              context->gpr[GuestRegisterContext::Rsp]));
    for (; context->instruction_counter < MaxInterpreterSteps && !context->halted &&
           !context->suspended;
         ++context->instruction_counter) {
        const StepResult result = Step(*context);
        if (result == StepResult::Continue) {
            continue;
        }
        if (result == StepResult::Halt) {
            SetStatus("guest halted");
            break;
        }
        if (result == StepResult::Fault) {
            SetStatus("guest memory read/write fault");
            AppendFileLog(fmt::format("guest fault rip={:#x} steps={} {}",
                                      context->rip, context->instruction_counter,
                                      FormatRegisterDump(*context)));
            context->suspended = true;
            break;
        }
        SetStatus("unsupported x86-64 opcode");
        context->suspended = true;
        break;
    }

    if (context->instruction_counter >= MaxInterpreterSteps) {
        SetStatus("step budget exhausted; guest thread suspended");
        AppendFileLog(fmt::format("step budget exhausted rip={:#x} steps={} bytes=[{}] {}",
                                  context->rip, context->instruction_counter,
                                  FormatBytes(context->rip, 16), FormatRegisterDump(*context)));
        context->suspended = true;
    }
}

bool CustomCPUTranslator::ExecuteEntry(u64 entry_pc, void* entry_params, ExitFunc exit_func) {
    EnsureThreadInitialized();
    if (!Initialize(reinterpret_cast<const u8*>(entry_pc))) {
        SetStatus("invalid guest entry");
        AppendFileLog(fmt::format("invalid guest entry entry={:#x}", entry_pc));
        return false;
    }

    GuestRegisterContext context{};
    context.rip = entry_pc;
    context.gpr[GuestRegisterContext::Rdi] = reinterpret_cast<u64>(entry_params);
    context.gpr[GuestRegisterContext::Rsi] = reinterpret_cast<u64>(exit_func);

    alignas(16) std::array<u8, 64 * 1024> bootstrap_stack{};
    context.gpr[GuestRegisterContext::Rsp] =
        reinterpret_cast<u64>(bootstrap_stack.data() + bootstrap_stack.size() - 8);

#if defined(__APPLE__) && defined(ARCH_ARM64)
    ShadIOSSetCoreStage(920, "custom ARM64 CPU interpreter entered");
#endif
    LOG_WARNING(Core_Linker,
                "Starting experimental ARM64 fallback interpreter at entry={:#x}. Unsupported "
                "opcodes suspend the guest thread and log RIP/opcode bytes instead of crashing.",
                entry_pc);
    AppendFileLog(fmt::format(
        "=== Orbit CPU translator session entry={:#x} params={:#x} exit={:#x} ===", entry_pc,
        reinterpret_cast<u64>(entry_params), reinterpret_cast<u64>(exit_func)));

    ExecuteRegistersContext(&context);

#if defined(__APPLE__) && defined(ARCH_ARM64)
    ShadIOSSetCoreStage(929, LastStatus());
#endif
    LOG_ERROR(Core_Linker,
              "CustomCPUTranslator stopped at rip={:#x} steps={} status={} unsupported={:#x}/{:#04x}",
              context.rip, context.instruction_counter, LastStatus(), unsupported_rip,
              unsupported_opcode);
    AppendFileLog(fmt::format(
        "CustomCPUTranslator stopped rip={:#x} steps={} status={} unsupported={:#x}/{:#04x}",
        context.rip, context.instruction_counter, LastStatus(), unsupported_rip,
        unsupported_opcode));
    return context.halted;
}

const char* CustomCPUTranslator::LastStatus() const {
    return last_status;
}

CustomCPUTranslator::StepResult CustomCPUTranslator::Step(GuestRegisterContext& context) {
    bool ok = false;
    const u64 rip = context.rip;
    const u8 op = Read8(rip, ok);
    if (!ok) {
        LOG_ERROR(Core_Linker, "CustomCPUTranslator failed to read opcode at {:#x}", rip);
        return StepResult::Fault;
    }

    if (op >= 0x70 && op <= 0x7f) {
        return DecodeJccShort(context, op);
    }
    if (op >= 0x40 && op <= 0x4f) {
        return DecodeRex(context, op);
    }
    if (op == Prefix66 || op == PrefixF2 || op == PrefixF3) {
        return DecodePrefixed(context, op);
    }
    return DecodeOneByte(context, op);
}

CustomCPUTranslator::StepResult CustomCPUTranslator::DecodeOneByte(GuestRegisterContext& context,
                                                                   u8 op) {
    bool ok = false;
    const u64 rip = context.rip;
    switch (op) {
    case 0x0f:
        return DecodeTwoByte(context, rip, PrefixNone, 0);
    case 0x01: // add r/m32, r32
    case 0x03: // add r32, r/m32
    case 0x29: // sub r/m32, r32
    case 0x2b: // sub r32, r/m32
    case 0x31: { // xor r/m32, r32
        RexPrefix rex{};
        ModRm modrm{};
        if (!DecodeModRm(context, rip + 2, rex, modrm, *this)) {
            return StepResult::Fault;
        }
        u32 mem = 0;
        u64 rm = 0;
        if (modrm.has_memory) {
            if (!ReadMemory(modrm.address, &mem, sizeof(mem))) {
                return StepResult::Fault;
            }
            rm = mem;
        } else {
            rm = ReadGpr(context, modrm.rm, 32);
        }
        const u64 reg = ReadGpr(context, modrm.reg, 32);
        const auto write_rm = [&](u64 value) -> bool {
            const u32 narrowed = static_cast<u32>(value);
            if (!modrm.has_memory) {
                WriteGpr(context, modrm.rm, 32, narrowed);
                return true;
            }
            return WriteMemory(modrm.address, &narrowed, sizeof(narrowed));
        };
        switch (op) {
        case 0x01: {
            const u64 result = (rm + reg) & WidthMask(32);
            if (!write_rm(result)) {
                return StepResult::Fault;
            }
            UpdateArithmeticFlags(context, rm, reg, result, 32, false);
            break;
        }
        case 0x03: {
            const u64 result = (reg + rm) & WidthMask(32);
            WriteGpr(context, modrm.reg, 32, result);
            UpdateArithmeticFlags(context, reg, rm, result, 32, false);
            break;
        }
        case 0x29: {
            const u64 result = (rm - reg) & WidthMask(32);
            if (!write_rm(result)) {
                return StepResult::Fault;
            }
            UpdateArithmeticFlags(context, rm, reg, result, 32, true);
            break;
        }
        case 0x2b: {
            const u64 result = (reg - rm) & WidthMask(32);
            WriteGpr(context, modrm.reg, 32, result);
            UpdateArithmeticFlags(context, reg, rm, result, 32, true);
            break;
        }
        case 0x31: {
            const u64 result = (rm ^ reg) & WidthMask(32);
            if (!write_rm(result)) {
                return StepResult::Fault;
            }
            UpdateLogicFlags(context, result, 32);
            break;
        }
        default:
            break;
        }
        context.rip += 1 + modrm.length;
        return StepResult::Continue;
    }
    case 0x39: // cmp r/m32, r32
    case 0x3b: { // cmp r32, r/m32
        RexPrefix rex{};
        ModRm modrm{};
        if (!DecodeModRm(context, rip + 2, rex, modrm, *this)) {
            return StepResult::Fault;
        }
        u32 mem = 0;
        const bool reverse = op == 0x3b;
        u64 rm = 0;
        if (modrm.has_memory) {
            if (!ReadMemory(modrm.address, &mem, sizeof(mem))) {
                return StepResult::Fault;
            }
            rm = mem;
        } else {
            rm = ReadGpr(context, modrm.rm, 32);
        }
        const u64 reg = ReadGpr(context, modrm.reg, 32);
        const u64 lhs = reverse ? reg : rm;
        const u64 rhs = reverse ? rm : reg;
        UpdateArithmeticFlags(context, lhs, rhs, (lhs - rhs) & WidthMask(32), 32, true);
        context.rip += 1 + modrm.length;
        return StepResult::Continue;
    }
    case 0x50 ... 0x57: { // push low registers
        const std::size_t reg = op - 0x50;
        if (!Push64(context, context.gpr[reg])) {
            return StepResult::Fault;
        }
        context.rip += 1;
        return StepResult::Continue;
    }
    case 0x58 ... 0x5f: { // pop low registers
        const std::size_t reg = op - 0x58;
        if (!Pop64(context, context.gpr[reg])) {
            return StepResult::Fault;
        }
        context.rip += 1;
        return StepResult::Continue;
    }
    case 0x68: { // push imm32
        const u64 imm = static_cast<u64>(static_cast<s64>(static_cast<s32>(Read32(rip + 1, ok))));
        if (!ok || !Push64(context, imm)) {
            return StepResult::Fault;
        }
        context.rip += 5;
        return StepResult::Continue;
    }
    case 0x6a: { // push imm8
        const u64 imm = static_cast<u64>(static_cast<s64>(static_cast<s8>(Read8(rip + 1, ok))));
        if (!ok || !Push64(context, imm)) {
            return StepResult::Fault;
        }
        context.rip += 2;
        return StepResult::Continue;
    }
    case 0x89: // mov r/m32, r32
    case 0x8b: { // mov r32, r/m32
        RexPrefix rex{};
        ModRm modrm{};
        if (!DecodeModRm(context, rip + 2, rex, modrm, *this)) {
            return StepResult::Fault;
        }
        u32 mem = 0;
        if (op == 0x89) {
            const u32 value = static_cast<u32>(ReadGpr(context, modrm.reg, 32));
            if (modrm.has_memory) {
                if (!WriteMemory(modrm.address, &value, sizeof(value))) {
                    return StepResult::Fault;
                }
            } else {
                WriteGpr(context, modrm.rm, 32, value);
            }
        } else {
            u32 value = 0;
            if (modrm.has_memory) {
                if (!ReadMemory(modrm.address, &mem, sizeof(mem))) {
                    return StepResult::Fault;
                }
                value = mem;
            } else {
                value = static_cast<u32>(ReadGpr(context, modrm.rm, 32));
            }
            WriteGpr(context, modrm.reg, 32, value);
        }
        context.rip += 1 + modrm.length;
        return StepResult::Continue;
    }
    case 0x8d: { // lea r32, m
        RexPrefix rex{};
        ModRm modrm{};
        if (!DecodeModRm(context, rip + 2, rex, modrm, *this) || !modrm.has_memory) {
            return StepResult::Fault;
        }
        WriteGpr(context, modrm.reg, 32, modrm.address);
        context.rip += 1 + modrm.length;
        return StepResult::Continue;
    }
    case 0x90:
        context.rip += 1;
        return StepResult::Continue;
    case 0xb8 ... 0xbf: { // mov r32, imm32
        const std::size_t reg = op - 0xb8;
        const u32 imm = Read32(rip + 1, ok);
        if (!ok) {
            return StepResult::Fault;
        }
        WriteGpr(context, reg, 32, imm);
        context.rip += 5;
        return StepResult::Continue;
    }
    case 0xc3: { // ret
        u64 target = 0;
        if (!Pop64(context, target)) {
            return StepResult::Fault;
        }
        context.rip = target;
        return target == 0 ? StepResult::Halt : StepResult::Continue;
    }
    case 0xc7: { // mov r/m32, imm32
        RexPrefix rex{};
        ModRm modrm{};
        if (!DecodeModRm(context, rip + 2, rex, modrm, *this) || modrm.reg != 0) {
            return StepResult::Fault;
        }
        const u32 imm = Read32(rip + 1 + modrm.length, ok);
        if (!ok) {
            return StepResult::Fault;
        }
        if (modrm.has_memory) {
            if (!WriteMemory(modrm.address, &imm, sizeof(imm))) {
                return StepResult::Fault;
            }
        } else {
            WriteGpr(context, modrm.rm, 32, imm);
        }
        context.rip += 5 + modrm.length;
        return StepResult::Continue;
    }
    case 0xc2: { // ret imm16
        u16 stack_pop = 0;
        if (!ReadMemory(rip + 1, &stack_pop, sizeof(stack_pop))) {
            return StepResult::Fault;
        }
        u64 target = 0;
        if (!Pop64(context, target)) {
            return StepResult::Fault;
        }
        context.gpr[GuestRegisterContext::Rsp] += stack_pop;
        context.rip = target;
        return target == 0 ? StepResult::Halt : StepResult::Continue;
    }
    case 0xc9: { // leave
        context.gpr[GuestRegisterContext::Rsp] = context.gpr[GuestRegisterContext::Rbp];
        u64 rbp = 0;
        if (!Pop64(context, rbp)) {
            return StepResult::Fault;
        }
        context.gpr[GuestRegisterContext::Rbp] = rbp;
        context.rip += 1;
        return StepResult::Continue;
    }
    case 0xcc:
    case 0xf4:
        context.halted = true;
        context.rip += 1;
        return StepResult::Halt;
    case 0xe8: { // call rel32
        const s32 rel = static_cast<s32>(Read32(rip + 1, ok));
        if (!ok || !Push64(context, rip + 5)) {
            return StepResult::Fault;
        }
        context.rip = rip + 5 + rel;
        return StepResult::Continue;
    }
    case 0xe9: { // jmp rel32
        const s32 rel = static_cast<s32>(Read32(rip + 1, ok));
        if (!ok) {
            return StepResult::Fault;
        }
        context.rip = rip + 5 + rel;
        return StepResult::Continue;
    }
    case 0xeb: { // jmp rel8
        const s8 rel = static_cast<s8>(Read8(rip + 1, ok));
        if (!ok) {
            return StepResult::Fault;
        }
        context.rip = rip + 2 + rel;
        return StepResult::Continue;
    }
    case 0x81:
    case 0x83:
        return DecodeGroup1(context, 0, op);
    case 0x84:
    case 0x85: { // test r/m8|r/m32, r8|r32
        RexPrefix rex{};
        ModRm modrm{};
        if (!DecodeModRm(context, rip + 2, rex, modrm, *this)) {
            return StepResult::Fault;
        }
        const u8 width = op == 0x84 ? 8 : 32;
        u64 rm = 0;
        if (modrm.has_memory) {
            if (!ReadMemory(modrm.address, &rm, width / 8)) {
                return StepResult::Fault;
            }
        } else {
            rm = ReadGpr(context, modrm.rm, width);
        }
        UpdateLogicFlags(context, rm & ReadGpr(context, modrm.reg, width), width);
        context.rip += 1 + modrm.length;
        return StepResult::Continue;
    }
    default:
        LogUnsupported(context, rip, op);
        return StepResult::Unsupported;
    }
}

CustomCPUTranslator::StepResult CustomCPUTranslator::DecodeRex(GuestRegisterContext& context,
                                                               u8 rex_byte) {
    const RexPrefix rex = DecodeRexPrefix(rex_byte);
    bool ok = false;
    const u64 rip = context.rip;
    const u8 op = Read8(rip + 1, ok);
    if (!ok) {
        return StepResult::Fault;
    }

    const u8 width = rex.w ? 64 : 32;
    if (op == 0x0f) {
        return DecodeTwoByte(context, rip + 1, PrefixNone, rex_byte);
    }
    if (op >= 0xb8 && op <= 0xbf) { // mov r64/r32, imm
        const std::size_t reg = (op - 0xb8) + (rex.b ? 8 : 0);
        if (rex.w) {
            const u64 imm = Read64(rip + 2, ok);
            if (!ok) {
                return StepResult::Fault;
            }
            WriteGpr(context, reg, 64, imm);
            context.rip += 10;
        } else {
            const u32 imm = Read32(rip + 2, ok);
            if (!ok) {
                return StepResult::Fault;
            }
            WriteGpr(context, reg, 32, imm);
            context.rip += 6;
        }
        return StepResult::Continue;
    }

    if (op == 0x01 || op == 0x03 || op == 0x29 || op == 0x2b || op == 0x31 || op == 0x39 ||
        op == 0x3b || op == 0x85 || op == 0x89 || op == 0x8b || op == 0x8d) {
        ModRm modrm{};
        if (!DecodeModRm(context, rip + 3, rex, modrm, *this)) {
            return StepResult::Fault;
        }
        if (op == 0x8d) {
            if (!modrm.has_memory) {
                return StepResult::Fault;
            }
            WriteGpr(context, modrm.reg, width, modrm.address);
            context.rip += 2 + modrm.length;
            return StepResult::Continue;
        }
        u64 mem = 0;
        const auto read_rm = [&]() -> u64 {
            if (!modrm.has_memory) {
                return ReadGpr(context, modrm.rm, width);
            }
            if (!ReadMemory(modrm.address, &mem, width / 8)) {
                ok = false;
            }
            return mem & WidthMask(width);
        };
        const auto write_rm = [&](u64 value) -> bool {
            value &= WidthMask(width);
            if (!modrm.has_memory) {
                WriteGpr(context, modrm.rm, width, value);
                return true;
            }
            return WriteMemory(modrm.address, &value, width / 8);
        };

        const u64 rm = read_rm();
        if (!ok) {
            return StepResult::Fault;
        }
        const u64 reg = ReadGpr(context, modrm.reg, width);
        switch (op) {
        case 0x01: { // add r/m, reg
            const u64 result = (rm + reg) & WidthMask(width);
            if (!write_rm(result)) {
                return StepResult::Fault;
            }
            UpdateArithmeticFlags(context, rm, reg, result, width, false);
            break;
        }
        case 0x03: { // add reg, r/m
            const u64 result = (reg + rm) & WidthMask(width);
            WriteGpr(context, modrm.reg, width, result);
            UpdateArithmeticFlags(context, reg, rm, result, width, false);
            break;
        }
        case 0x29: { // sub r/m, reg
            const u64 result = (rm - reg) & WidthMask(width);
            if (!write_rm(result)) {
                return StepResult::Fault;
            }
            UpdateArithmeticFlags(context, rm, reg, result, width, true);
            break;
        }
        case 0x2b: { // sub reg, r/m
            const u64 result = (reg - rm) & WidthMask(width);
            WriteGpr(context, modrm.reg, width, result);
            UpdateArithmeticFlags(context, reg, rm, result, width, true);
            break;
        }
        case 0x31: { // xor r/m, reg
            const u64 result = (rm ^ reg) & WidthMask(width);
            if (!write_rm(result)) {
                return StepResult::Fault;
            }
            UpdateLogicFlags(context, result, width);
            break;
        }
        case 0x39: { // cmp r/m, reg
            UpdateArithmeticFlags(context, rm, reg, (rm - reg) & WidthMask(width), width, true);
            break;
        }
        case 0x3b: { // cmp reg, r/m
            UpdateArithmeticFlags(context, reg, rm, (reg - rm) & WidthMask(width), width, true);
            break;
        }
        case 0x85: { // test r/m, reg
            UpdateLogicFlags(context, rm & reg, width);
            break;
        }
        case 0x89: { // mov r/m, reg
            if (!write_rm(reg)) {
                return StepResult::Fault;
            }
            break;
        }
        case 0x8b: { // mov reg, r/m
            WriteGpr(context, modrm.reg, width, rm);
            break;
        }
        default:
            break;
        }
        context.rip += 2 + modrm.length;
        return StepResult::Continue;
    }

    if (op == 0x81 || op == 0x83) {
        return DecodeGroup1(context, rex_byte, op);
    }

    // REX + push/pop extended registers.
    if (op >= 0x50 && op <= 0x5f) {
        const std::size_t reg = (op & 0x7) + (rex.b ? 8 : 0);
        if (op < 0x58) {
            if (!Push64(context, context.gpr[reg])) {
                return StepResult::Fault;
            }
        } else if (!Pop64(context, context.gpr[reg])) {
            return StepResult::Fault;
        }
        context.rip += 2;
        return StepResult::Continue;
    }

    LogUnsupported(context, rip, rex_byte);
    return StepResult::Unsupported;
}

CustomCPUTranslator::StepResult CustomCPUTranslator::DecodePrefixed(GuestRegisterContext& context,
                                                                    u8 prefix) {
    bool ok = false;
    const u64 rip = context.rip;
    u64 cursor = rip + 1;
    u8 rex_byte = 0;
    u8 op = Read8(cursor, ok);
    if (!ok) {
        return StepResult::Fault;
    }
    if (op >= 0x40 && op <= 0x4f) {
        rex_byte = op;
        op = Read8(++cursor, ok);
        if (!ok) {
            return StepResult::Fault;
        }
    }

    if (op == 0x0f) {
        return DecodeTwoByte(context, cursor, prefix, rex_byte);
    }

    // REP NOP is frequently emitted as pause in spin loops.
    if (prefix == PrefixF3 && op == 0x90) {
        context.rip = cursor + 1;
        return StepResult::Continue;
    }

    LogUnsupported(context, rip, prefix);
    return StepResult::Unsupported;
}

CustomCPUTranslator::StepResult CustomCPUTranslator::DecodeTwoByte(GuestRegisterContext& context,
                                                                   u64 opcode_rip, u8 prefix,
                                                                   u8 rex_byte) {
    bool ok = false;
    const RexPrefix rex = rex_byte != 0 ? DecodeRexPrefix(rex_byte) : RexPrefix{};
    const u8 op2 = Read8(opcode_rip + 1, ok);
    if (!ok) {
        return StepResult::Fault;
    }

    if (op2 >= 0x80 && op2 <= 0x8f) {
        return DecodeJccNear(context, opcode_rip);
    }

    if (op2 == 0x05) { // syscall
        AppendFileLog(fmt::format("CustomCPUTranslator syscall trap rip={:#x} rax={:#x} {}",
                                  context.rip, context.gpr[GuestRegisterContext::Rax],
                                  FormatRegisterDump(context)));
        SetStatus(fmt::format("guest syscall trap at rip={:#x}", context.rip));
        context.suspended = true;
        return StepResult::Unsupported;
    }

    if (op2 == 0x0b) { // ud2
        AppendFileLog(fmt::format("CustomCPUTranslator UD2 trap rip={:#x} disasm=\"{}\"",
                                  context.rip, Disassemble(context.rip)));
        SetStatus(fmt::format("guest UD2 trap at rip={:#x}", context.rip));
        context.suspended = true;
        return StepResult::Unsupported;
    }

    if (op2 == 0x1f) { // multi-byte nop
        ModRm modrm{};
        if (!DecodeModRm(context, opcode_rip + 3, rex, modrm, *this)) {
            return StepResult::Fault;
        }
        context.rip = opcode_rip + 2 + modrm.length;
        return StepResult::Continue;
    }

    const bool is_xmm_move =
        op2 == 0x10 || op2 == 0x11 || op2 == 0x28 || op2 == 0x29 || op2 == 0x6f ||
        op2 == 0x7f || op2 == 0x57 || op2 == 0xef;
    if (is_xmm_move) {
        ModRm modrm{};
        if (!DecodeModRm(context, opcode_rip + 3, rex, modrm, *this)) {
            return StepResult::Fault;
        }

        const std::size_t vector_size =
            (prefix == PrefixF3) ? 4 : ((prefix == PrefixF2) ? 8 : 16);
        std::array<u8, 16> tmp{};

        switch (op2) {
        case 0x57: // xorps xmm, xmm/m128
        case 0xef: { // pxor xmm, xmm/m128
            if (op2 == 0xef && prefix != Prefix66) {
                break;
            }
            if (!ReadXmmOperand(context, modrm.rm, modrm.address, modrm.has_memory, tmp.data(),
                                16)) {
                return StepResult::Fault;
            }
            for (std::size_t i = 0; i < 16; ++i) {
                context.xmm[modrm.reg][i] ^= tmp[i];
            }
            context.rip = opcode_rip + 2 + modrm.length;
            return StepResult::Continue;
        }
        case 0x10: // movss/movsd xmm, xmm/m
        case 0x28: // movaps xmm, xmm/m128
        case 0x6f: { // movdqa xmm, xmm/m128
            if (op2 == 0x6f && prefix != Prefix66) {
                break;
            }
            const std::size_t size = op2 == 0x28 || op2 == 0x6f ? 16 : vector_size;
            if (!ReadXmmOperand(context, modrm.rm, modrm.address, modrm.has_memory, tmp.data(),
                                size)) {
                return StepResult::Fault;
            }
            std::memcpy(context.xmm[modrm.reg].data(), tmp.data(), size);
            context.rip = opcode_rip + 2 + modrm.length;
            return StepResult::Continue;
        }
        case 0x11: // movss/movsd xmm/m, xmm
        case 0x29: // movaps xmm/m128, xmm
        case 0x7f: { // movdqa xmm/m128, xmm
            if (op2 == 0x7f && prefix != Prefix66) {
                break;
            }
            const std::size_t size = op2 == 0x29 || op2 == 0x7f ? 16 : vector_size;
            if (!WriteXmmOperand(context, modrm.rm, modrm.address, modrm.has_memory,
                                 context.xmm[modrm.reg].data(), size)) {
                return StepResult::Fault;
            }
            context.rip = opcode_rip + 2 + modrm.length;
            return StepResult::Continue;
        }
        default:
            break;
        }
    }

    LogUnsupported(context, context.rip, Read8(context.rip, ok));
    return StepResult::Unsupported;
}

CustomCPUTranslator::StepResult CustomCPUTranslator::DecodeGroup1(GuestRegisterContext& context,
                                                                  u8 rex_byte, u8 op) {
    bool ok = true;
    const u64 rip = context.rip;
    const bool has_rex = rex_byte >= 0x40 && rex_byte <= 0x4f;
    const RexPrefix rex = has_rex ? DecodeRexPrefix(rex_byte) : RexPrefix{};
    const u64 opcode_rip = rip + (has_rex ? 1 : 0);
    const u8 width = rex.w ? 64 : 32;
    ModRm modrm{};
    if (!DecodeModRm(context, opcode_rip + 2, rex, modrm, *this)) {
        return StepResult::Fault;
    }
    const u64 imm_offset = opcode_rip + 1 + modrm.length;
    s64 imm = 0;
    std::size_t imm_size = 1;
    if (op == 0x81) {
        imm = static_cast<s32>(Read32(imm_offset, ok));
        imm_size = 4;
    } else {
        imm = static_cast<s8>(Read8(imm_offset, ok));
    }
    if (!ok) {
        return StepResult::Fault;
    }

    u64 lhs = 0;
    if (modrm.has_memory) {
        if (!ReadMemory(modrm.address, &lhs, width / 8)) {
            return StepResult::Fault;
        }
    } else {
        lhs = ReadGpr(context, modrm.rm, width);
    }

    const u8 group = modrm.reg & 0x7;
    const u64 rhs = static_cast<u64>(imm) & WidthMask(width);
    u64 result = lhs;
    bool write_result = true;
    if (group == 0) { // add
        result = (lhs + rhs) & WidthMask(width);
        UpdateArithmeticFlags(context, lhs, rhs, result, width, false);
    } else if (group == 1) { // or
        result = (lhs | rhs) & WidthMask(width);
        UpdateLogicFlags(context, result, width);
    } else if (group == 4) { // and
        result = (lhs & rhs) & WidthMask(width);
        UpdateLogicFlags(context, result, width);
    } else if (group == 5) { // sub
        result = (lhs - rhs) & WidthMask(width);
        UpdateArithmeticFlags(context, lhs, rhs, result, width, true);
    } else if (group == 6) { // xor
        result = (lhs ^ rhs) & WidthMask(width);
        UpdateLogicFlags(context, result, width);
    } else if (group == 7) { // cmp
        result = (lhs - rhs) & WidthMask(width);
        UpdateArithmeticFlags(context, lhs, rhs, result, width, true);
        write_result = false;
    } else {
        LogUnsupported(context, rip, Read8(opcode_rip, ok));
        return StepResult::Unsupported;
    }

    if (write_result) {
        if (modrm.has_memory) {
            if (!WriteMemory(modrm.address, &result, width / 8)) {
                return StepResult::Fault;
            }
        } else {
            WriteGpr(context, modrm.rm, width, result);
        }
    }
    context.rip = opcode_rip + 1 + modrm.length + imm_size;
    return StepResult::Continue;
}

CustomCPUTranslator::StepResult CustomCPUTranslator::DecodeJccShort(GuestRegisterContext& context,
                                                                    u8 op) {
    bool ok = false;
    const s8 rel = static_cast<s8>(Read8(context.rip + 1, ok));
    if (!ok) {
        return StepResult::Fault;
    }
    const u64 next = context.rip + 2;
    context.rip = CheckCondition(context, op & 0xf) ? next + rel : next;
    return StepResult::Continue;
}

CustomCPUTranslator::StepResult CustomCPUTranslator::DecodeJccNear(GuestRegisterContext& context,
                                                                   u64 opcode_rip) {
    bool ok = false;
    const u8 op2 = Read8(opcode_rip + 1, ok);
    if (!ok) {
        return StepResult::Fault;
    }
    if (op2 < 0x80 || op2 > 0x8f) {
        LogUnsupported(context, context.rip, 0x0f);
        return StepResult::Unsupported;
    }
    const s32 rel = static_cast<s32>(Read32(opcode_rip + 2, ok));
    if (!ok) {
        return StepResult::Fault;
    }
    const u64 next = opcode_rip + 6;
    context.rip = CheckCondition(context, op2 & 0xf) ? next + rel : next;
    return StepResult::Continue;
}

bool CustomCPUTranslator::CheckCondition(GuestRegisterContext& context, u8 condition) const {
    const bool cf = (context.rflags & FlagCf) != 0;
    const bool zf = (context.rflags & FlagZf) != 0;
    const bool sf = (context.rflags & FlagSf) != 0;
    const bool of = (context.rflags & FlagOf) != 0;
    switch (condition) {
    case 0x0:
        return of;
    case 0x1:
        return !of;
    case 0x2:
        return cf;
    case 0x3:
        return !cf;
    case 0x4:
        return zf;
    case 0x5:
        return !zf;
    case 0x6:
        return cf || zf;
    case 0x7:
        return !cf && !zf;
    case 0x8:
        return sf;
    case 0x9:
        return !sf;
    case 0xc:
        return sf != of;
    case 0xd:
        return sf == of;
    case 0xe:
        return zf || (sf != of);
    case 0xf:
        return !zf && (sf == of);
    default:
        return false;
    }
}

void CustomCPUTranslator::UpdateArithmeticFlags(GuestRegisterContext& context, u64 lhs, u64 rhs,
                                                u64 result, u8 width, bool subtract) {
    const u64 mask = WidthMask(width);
    lhs &= mask;
    rhs &= mask;
    result &= mask;
    context.rflags &= ~(FlagCf | FlagPf | FlagZf | FlagSf | FlagOf);
    if (result == 0) {
        context.rflags |= FlagZf;
    }
    if ((__builtin_popcountll(result & 0xff) & 1) == 0) {
        context.rflags |= FlagPf;
    }
    if ((result & SignBit(width)) != 0) {
        context.rflags |= FlagSf;
    }
    if (subtract) {
        if (lhs < rhs) {
            context.rflags |= FlagCf;
        }
        if (((lhs ^ rhs) & (lhs ^ result) & SignBit(width)) != 0) {
            context.rflags |= FlagOf;
        }
    } else {
        if (result < lhs) {
            context.rflags |= FlagCf;
        }
        if (((~(lhs ^ rhs)) & (lhs ^ result) & SignBit(width)) != 0) {
            context.rflags |= FlagOf;
        }
    }
}

void CustomCPUTranslator::UpdateLogicFlags(GuestRegisterContext& context, u64 result, u8 width) {
    result &= WidthMask(width);
    context.rflags &= ~(FlagCf | FlagPf | FlagZf | FlagSf | FlagOf);
    if (result == 0) {
        context.rflags |= FlagZf;
    }
    if ((__builtin_popcountll(result & 0xff) & 1) == 0) {
        context.rflags |= FlagPf;
    }
    if ((result & SignBit(width)) != 0) {
        context.rflags |= FlagSf;
    }
}

u64 CustomCPUTranslator::ReadGpr(const GuestRegisterContext& context, std::size_t reg,
                                 u8 width) const {
    if (reg >= GuestRegisterContext::Count) {
        return 0;
    }
    return context.gpr[reg] & WidthMask(width);
}

void CustomCPUTranslator::WriteGpr(GuestRegisterContext& context, std::size_t reg, u8 width,
                                   u64 value) {
    if (reg >= GuestRegisterContext::Count) {
        return;
    }
    if (width == 32) {
        context.gpr[reg] = static_cast<u32>(value);
    } else {
        context.gpr[reg] = value & WidthMask(width);
    }
}

bool CustomCPUTranslator::Push64(GuestRegisterContext& context, u64 value) {
    context.gpr[GuestRegisterContext::Rsp] -= sizeof(u64);
    return WriteMemory(context.gpr[GuestRegisterContext::Rsp], &value, sizeof(value));
}

bool CustomCPUTranslator::Pop64(GuestRegisterContext& context, u64& value) {
    if (!ReadMemory(context.gpr[GuestRegisterContext::Rsp], &value, sizeof(value))) {
        return false;
    }
    context.gpr[GuestRegisterContext::Rsp] += sizeof(u64);
    return true;
}

bool CustomCPUTranslator::ReadMemory(u64 address, void* out, std::size_t size) const {
    if (address == 0 || out == nullptr || size == 0) {
        return false;
    }
    std::memcpy(out, reinterpret_cast<const void*>(address), size);
    return true;
}

bool CustomCPUTranslator::WriteMemory(u64 address, const void* in, std::size_t size) const {
    if (address == 0 || in == nullptr || size == 0) {
        return false;
    }
    std::memcpy(reinterpret_cast<void*>(address), in, size);
    return true;
}

bool CustomCPUTranslator::ReadXmmOperand(const GuestRegisterContext& context, std::size_t reg,
                                         u64 address, bool from_memory, void* out,
                                         std::size_t size) const {
    if (out == nullptr || size == 0 || size > 16) {
        return false;
    }
    if (from_memory) {
        return ReadMemory(address, out, size);
    }
    if (reg >= context.xmm.size()) {
        return false;
    }
    std::memcpy(out, context.xmm[reg].data(), size);
    return true;
}

bool CustomCPUTranslator::WriteXmmOperand(GuestRegisterContext& context, std::size_t reg,
                                          u64 address, bool to_memory, const void* in,
                                          std::size_t size) {
    if (in == nullptr || size == 0 || size > 16) {
        return false;
    }
    if (to_memory) {
        return WriteMemory(address, in, size);
    }
    if (reg >= context.xmm.size()) {
        return false;
    }
    std::memcpy(context.xmm[reg].data(), in, size);
    return true;
}

u8 CustomCPUTranslator::Read8(u64 address, bool& ok) const {
    u8 value = 0;
    ok = ReadMemory(address, &value, sizeof(value));
    return value;
}

u32 CustomCPUTranslator::Read32(u64 address, bool& ok) const {
    u32 value = 0;
    ok = ReadMemory(address, &value, sizeof(value));
    return value;
}

u64 CustomCPUTranslator::Read64(u64 address, bool& ok) const {
    u64 value = 0;
    ok = ReadMemory(address, &value, sizeof(value));
    return value;
}

bool CustomCPUTranslator::Write64(u64 address, u64 value) {
    return WriteMemory(address, &value, sizeof(value));
}

void CustomCPUTranslator::LogUnsupported(const GuestRegisterContext& context, u64 rip, u8 opcode) {
    unsupported_rip = rip;
    unsupported_opcode = opcode;
    const std::string bytes = FormatBytes(rip, 16);
    LOG_ERROR(Core_Linker,
              "CustomCPUTranslator unsupported opcode {:#04x} at rip={:#x}; bytes=[{}]; "
              "rax={:#x} rbx={:#x} rcx={:#x} rdx={:#x} rsi={:#x} rdi={:#x} rsp={:#x} rbp={:#x}",
              opcode, rip, bytes, context.gpr[GuestRegisterContext::Rax],
              context.gpr[GuestRegisterContext::Rbx], context.gpr[GuestRegisterContext::Rcx],
              context.gpr[GuestRegisterContext::Rdx], context.gpr[GuestRegisterContext::Rsi],
              context.gpr[GuestRegisterContext::Rdi], context.gpr[GuestRegisterContext::Rsp],
              context.gpr[GuestRegisterContext::Rbp]);
    AppendFileLog(fmt::format(
        "CustomCPUTranslator unsupported opcode {:#04x} rip={:#x} disasm=\"{}\" bytes=[{}] {}",
        opcode, rip, Disassemble(rip), bytes, FormatRegisterDump(context)));
    SetStatus(fmt::format("suspended at rip={:#x} opcode={:#04x}", rip, opcode));
}

void CustomCPUTranslator::AppendFileLog(const std::string& line) const {
#if defined(__APPLE__) && defined(ARCH_ARM64)
    ShadIOSAppendDiagnosticLog(line.c_str());
#endif
    try {
        static std::mutex log_mutex;
        std::lock_guard lock{log_mutex};

        const char* home = std::getenv("HOME");
        if (home == nullptr || home[0] == '\0') {
            return;
        }

        const auto documents = std::filesystem::path(home) / "Documents";
        std::filesystem::create_directories(documents);
        std::ofstream out(documents / "orbit_console_cpu.log", std::ios::app);
        if (!out) {
            return;
        }

        const auto now = std::chrono::system_clock::now().time_since_epoch();
        const auto ms = std::chrono::duration_cast<std::chrono::milliseconds>(now).count();
        out << ms << " " << line << '\n';
    } catch (...) {
    }
}

std::string CustomCPUTranslator::FormatRegisterDump(const GuestRegisterContext& context) const {
    return fmt::format(
        "rax={:#x} rbx={:#x} rcx={:#x} rdx={:#x} rsi={:#x} rdi={:#x} rsp={:#x} rbp={:#x} "
        "r8={:#x} r9={:#x} r10={:#x} r11={:#x} r12={:#x} r13={:#x} r14={:#x} r15={:#x} "
        "rflags={:#x}",
        context.gpr[GuestRegisterContext::Rax], context.gpr[GuestRegisterContext::Rbx],
        context.gpr[GuestRegisterContext::Rcx], context.gpr[GuestRegisterContext::Rdx],
        context.gpr[GuestRegisterContext::Rsi], context.gpr[GuestRegisterContext::Rdi],
        context.gpr[GuestRegisterContext::Rsp], context.gpr[GuestRegisterContext::Rbp],
        context.gpr[GuestRegisterContext::R8], context.gpr[GuestRegisterContext::R9],
        context.gpr[GuestRegisterContext::R10], context.gpr[GuestRegisterContext::R11],
        context.gpr[GuestRegisterContext::R12], context.gpr[GuestRegisterContext::R13],
        context.gpr[GuestRegisterContext::R14], context.gpr[GuestRegisterContext::R15],
        context.rflags);
}

std::string CustomCPUTranslator::FormatBytes(u64 rip, std::size_t count) const {
    bool ok = false;
    std::ostringstream bytes;
    for (std::size_t i = 0; i < count; ++i) {
        const u8 b = Read8(rip + i, ok);
        if (!ok) {
            break;
        }
        bytes << fmt::format("{:02x} ", b);
    }
    return bytes.str();
}

std::string CustomCPUTranslator::Disassemble(u64 rip) const {
    if (rip == 0) {
        return "<null>";
    }

    ZydisDecoder decoder;
    ZydisDecoderInit(&decoder, ZYDIS_MACHINE_MODE_LONG_64, ZYDIS_STACK_WIDTH_64);
    ZydisDecodedInstruction instruction;
    ZydisDecodedOperand operands[ZYDIS_MAX_OPERAND_COUNT_VISIBLE];
    const auto status = ZydisDecoderDecodeFull(
        &decoder, reinterpret_cast<const void*>(rip), 16, &instruction, operands);
    if (!ZYAN_SUCCESS(status)) {
        return "<decode failed>";
    }

    ZydisFormatter formatter;
    ZydisFormatterInit(&formatter, ZYDIS_FORMATTER_STYLE_INTEL);
    char buffer[256] = {};
    ZydisFormatterFormatInstruction(&formatter, &instruction, operands,
                                    instruction.operand_count_visible, buffer, sizeof(buffer),
                                    rip, ZYAN_NULL);
    return buffer;
}

void CustomCPUTranslator::SetStatus(const char* status) {
    owned_status.clear();
    last_status = status != nullptr ? status : "unknown";
}

void CustomCPUTranslator::SetStatus(std::string status) {
    owned_status = std::move(status);
    last_status = owned_status.c_str();
}

} // namespace Core::CPU::CustomBridge
