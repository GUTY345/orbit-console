// SPDX-FileCopyrightText: Copyright 2024-2026 shadPS4 Emulator Project
// SPDX-License-Identifier: GPL-2.0-or-later

#include "core/libraries/ajm/ajm.h"
#include "core/libraries/app_content/app_content.h"
#include "core/libraries/audio/audioin.h"
#include "core/libraries/audio/audioout.h"
#include "core/libraries/audio3d/audio3d.h"
#include "core/libraries/audio3d/audio3d_openal.h"
#include "core/libraries/avplayer/avplayer.h"
#include "core/libraries/camera/camera.h"
#include "core/libraries/companion/companion_httpd.h"
#include "core/libraries/companion/companion_util.h"
#include "core/libraries/content_export/content_export.h"
#include "core/libraries/disc_map/disc_map.h"
#include "core/libraries/game_live_streaming/gamelivestreaming.h"
#include "core/libraries/gnmdriver/gnmdriver.h"
#include "core/libraries/hmd/hmd.h"
#include "core/libraries/hmd/hmd_setup_dialog.h"
#include "core/libraries/ime/error_dialog.h"
#include "core/libraries/ime/ime.h"
#include "core/libraries/ime/ime_dialog.h"
#include "core/libraries/kernel/kernel.h"
#include "core/libraries/libc_internal/libc_internal.h"
#include "core/libraries/libpng/pngdec.h"
#include "core/libraries/libs.h"
#include "core/libraries/mouse/mouse.h"
#include "core/libraries/move/move.h"
#include "core/libraries/network/http.h"
#include "core/libraries/network/http2.h"
#include "core/libraries/network/net.h"
#include "core/libraries/network/netctl.h"
#include "core/libraries/network/ssl.h"
#include "core/libraries/network/ssl2.h"
#include "core/libraries/np/np_auth.h"
#include "core/libraries/np/np_commerce.h"
#include "core/libraries/np/np_common.h"
#include "core/libraries/np/np_manager.h"
#include "core/libraries/np/np_matching2.h"
#include "core/libraries/np/np_partner.h"
#include "core/libraries/np/np_party.h"
#include "core/libraries/np/np_profile_dialog/np_profile_dialog.h"
#include "core/libraries/np/np_score/np_score.h"
#include "core/libraries/np/np_sns_facebook_dialog.h"
#include "core/libraries/np/np_trophy.h"
#include "core/libraries/np/np_tus.h"
#include "core/libraries/np/np_web_api/np_web_api.h"
#include "core/libraries/np/np_web_api2.h"
#include "core/libraries/pad/pad.h"
#include "core/libraries/playgo/playgo.h"
#include "core/libraries/playgo/playgo_dialog.h"
#include "core/libraries/random/random.h"
#include "core/libraries/razor_cpu/razor_cpu.h"
#include "core/libraries/remote_play/remoteplay.h"
#include "core/libraries/rudp/rudp.h"
#include "core/libraries/save_data/dialog/savedatadialog.h"
#include "core/libraries/save_data/savedata.h"
#include "core/libraries/screenshot/screenshot.h"
#include "core/libraries/share_play/shareplay.h"
#include "core/libraries/signin_dialog/signindialog.h"
#include "core/libraries/sysmodule/sysmodule.h"
#include "core/libraries/system/commondialog.h"
#include "core/libraries/system/msgdialog.h"
#include "core/libraries/system/posix.h"
#include "core/libraries/system/systemservice.h"
#include "core/libraries/system/userservice.h"
#include "core/libraries/ulobjmgr/ulobjmgr.h"
#include "core/libraries/usbd/usbd.h"
#include "core/libraries/video_recording/video_recording.h"
#include "core/libraries/videodec/videodec.h"
#include "core/libraries/videodec/videodec2.h"
#include "core/libraries/videoout/video_out.h"
#include "core/libraries/voice/voice.h"
#include "core/libraries/vr_tracker/vr_tracker.h"
#include "core/libraries/web_browser_dialog/webbrowserdialog.h"
#include "core/libraries/zlib/zlib_sce.h"
#include "fiber/fiber.h"

#if defined(__APPLE__)
#include <TargetConditionals.h>
#endif

#if defined(__APPLE__) && TARGET_OS_IOS
#include <string>
extern "C" void ShadIOSAppendDiagnosticLog(const char* message);
#endif

namespace Libraries {

#if defined(__APPLE__) && TARGET_OS_IOS
static void LogIOSHLERegister(const char* phase, const char* name) {
    std::string line = "HLE register ";
    line += phase;
    line += ": ";
    line += name;
    ShadIOSAppendDiagnosticLog(line.c_str());
}

#define IOS_HLE_REGISTER(name, expr)                                                              \
    do {                                                                                           \
        LogIOSHLERegister("begin", name);                                                          \
        expr;                                                                                      \
        LogIOSHLERegister("end", name);                                                            \
    } while (0)
#else
#define IOS_HLE_REGISTER(name, expr) expr
#endif

void InitHLELibs(Core::Loader::SymbolsResolver* sym) {
    LOG_INFO(Lib_Kernel, "Initializing HLE libraries");
    IOS_HLE_REGISTER("Kernel", Libraries::Kernel::RegisterLib(sym));
    IOS_HLE_REGISTER("LibcInternal", Libraries::LibcInternal::ForceRegisterLib(sym));
    IOS_HLE_REGISTER("GnmDriver", Libraries::GnmDriver::RegisterLib(sym));
    IOS_HLE_REGISTER("VideoOut", Libraries::VideoOut::RegisterLib(sym));
    IOS_HLE_REGISTER("UserService", Libraries::UserService::RegisterLib(sym));
    IOS_HLE_REGISTER("SystemService", Libraries::SystemService::RegisterLib(sym));
    IOS_HLE_REGISTER("CommonDialog", Libraries::CommonDialog::RegisterLib(sym));
    IOS_HLE_REGISTER("MsgDialog", Libraries::MsgDialog::RegisterLib(sym));
    IOS_HLE_REGISTER("AudioOut", Libraries::AudioOut::RegisterLib(sym));
    IOS_HLE_REGISTER("Http", Libraries::Http::RegisterLib(sym));
    IOS_HLE_REGISTER("Http2", Libraries::Http2::RegisterLib(sym));
    IOS_HLE_REGISTER("Net", Libraries::Net::RegisterLib(sym));
    IOS_HLE_REGISTER("NetCtl", Libraries::NetCtl::RegisterLib(sym));
    IOS_HLE_REGISTER("SaveData", Libraries::SaveData::RegisterLib(sym));
    IOS_HLE_REGISTER("SaveDataDialog", Libraries::SaveData::Dialog::RegisterLib(sym));
    IOS_HLE_REGISTER("Ssl2", Libraries::Ssl2::RegisterLib(sym));
    IOS_HLE_REGISTER("SysModule", Libraries::SysModule::RegisterLib(sym));
    IOS_HLE_REGISTER("Posix", Libraries::Posix::RegisterLib(sym));
    IOS_HLE_REGISTER("AudioIn", Libraries::AudioIn::RegisterLib(sym));
    IOS_HLE_REGISTER("NpCommerce", Libraries::Np::NpCommerce::RegisterLib(sym));
    IOS_HLE_REGISTER("NpCommon", Libraries::Np::NpCommon::RegisterLib(sym));
    IOS_HLE_REGISTER("NpManager", Libraries::Np::NpManager::RegisterLib(sym));
    IOS_HLE_REGISTER("NpMatching2", Libraries::Np::NpMatching2::RegisterLib(sym));
    IOS_HLE_REGISTER("NpScore", Libraries::Np::NpScore::RegisterLib(sym));
    IOS_HLE_REGISTER("NpTrophy", Libraries::Np::NpTrophy::RegisterLib(sym));
    IOS_HLE_REGISTER("NpWebApi", Libraries::Np::NpWebApi::RegisterLib(sym));
    IOS_HLE_REGISTER("NpWebApi2", Libraries::Np::NpWebApi2::RegisterLib(sym));
    IOS_HLE_REGISTER("NpProfileDialog", Libraries::Np::NpProfileDialog::RegisterLib(sym));
    IOS_HLE_REGISTER("NpSnsFacebookDialog", Libraries::Np::NpSnsFacebookDialog::RegisterLib(sym));
    IOS_HLE_REGISTER("NpAuth", Libraries::Np::NpAuth::RegisterLib(sym));
    IOS_HLE_REGISTER("NpParty", Libraries::Np::NpParty::RegisterLib(sym));
    IOS_HLE_REGISTER("NpPartner", Libraries::Np::NpPartner::RegisterLib(sym));
    IOS_HLE_REGISTER("NpTus", Libraries::Np::NpTus::RegisterLib(sym));
    IOS_HLE_REGISTER("ScreenShot", Libraries::ScreenShot::RegisterLib(sym));
    IOS_HLE_REGISTER("AppContent", Libraries::AppContent::RegisterLib(sym));
    IOS_HLE_REGISTER("PngDec", Libraries::PngDec::RegisterLib(sym));
    IOS_HLE_REGISTER("PlayGo", Libraries::PlayGo::RegisterLib(sym));
    IOS_HLE_REGISTER("PlayGoDialog", Libraries::PlayGo::Dialog::RegisterLib(sym));
    IOS_HLE_REGISTER("Random", Libraries::Random::RegisterLib(sym));
    IOS_HLE_REGISTER("Usbd", Libraries::Usbd::RegisterLib(sym));
    IOS_HLE_REGISTER("Pad", Libraries::Pad::RegisterLib(sym));
    IOS_HLE_REGISTER("Ajm", Libraries::Ajm::RegisterLib(sym));
    IOS_HLE_REGISTER("ErrorDialog", Libraries::ErrorDialog::RegisterLib(sym));
    IOS_HLE_REGISTER("ImeDialog", Libraries::ImeDialog::RegisterLib(sym));
    IOS_HLE_REGISTER("AvPlayer", Libraries::AvPlayer::RegisterLib(sym));
    IOS_HLE_REGISTER("Videodec", Libraries::Videodec::RegisterLib(sym));
    IOS_HLE_REGISTER("Videodec2", Libraries::Videodec2::RegisterLib(sym));
    if (EmulatorSettings.GetAudioBackend() == AudioBackend::OpenAL) {
        IOS_HLE_REGISTER("Audio3dOpenAL", Libraries::Audio3dOpenAL::RegisterLib(sym));
    } else {
        IOS_HLE_REGISTER("Audio3d", Libraries::Audio3d::RegisterLib(sym));
    }
    IOS_HLE_REGISTER("Ime", Libraries::Ime::RegisterLib(sym));
    IOS_HLE_REGISTER("GameLiveStreaming", Libraries::GameLiveStreaming::RegisterLib(sym));
    IOS_HLE_REGISTER("SharePlay", Libraries::SharePlay::RegisterLib(sym));
    IOS_HLE_REGISTER("Remoteplay", Libraries::Remoteplay::RegisterLib(sym));
    IOS_HLE_REGISTER("RazorCpu", Libraries::RazorCpu::RegisterLib(sym));
    IOS_HLE_REGISTER("Move", Libraries::Move::RegisterLib(sym));
    IOS_HLE_REGISTER("Fiber", Libraries::Fiber::RegisterLib(sym));
    IOS_HLE_REGISTER("Mouse", Libraries::Mouse::RegisterLib(sym));
    IOS_HLE_REGISTER("WebBrowserDialog", Libraries::WebBrowserDialog::RegisterLib(sym));
    IOS_HLE_REGISTER("Zlib", Libraries::Zlib::RegisterLib(sym));
    IOS_HLE_REGISTER("Hmd", Libraries::Hmd::RegisterLib(sym));
    IOS_HLE_REGISTER("HmdSetupDialog", Libraries::HmdSetupDialog::RegisterLib(sym));
    IOS_HLE_REGISTER("DiscMap", Libraries::DiscMap::RegisterLib(sym));
    IOS_HLE_REGISTER("Ulobjmgr", Libraries::Ulobjmgr::RegisterLib(sym));
    IOS_HLE_REGISTER("SigninDialog", Libraries::SigninDialog::RegisterLib(sym));
    IOS_HLE_REGISTER("Camera", Libraries::Camera::RegisterLib(sym));
    IOS_HLE_REGISTER("CompanionHttpd", Libraries::CompanionHttpd::RegisterLib(sym));
    IOS_HLE_REGISTER("CompanionUtil", Libraries::CompanionUtil::RegisterLib(sym));
    IOS_HLE_REGISTER("Voice", Libraries::Voice::RegisterLib(sym));
    IOS_HLE_REGISTER("Rudp", Libraries::Rudp::RegisterLib(sym));
    IOS_HLE_REGISTER("VrTracker", Libraries::VrTracker::RegisterLib(sym));
    IOS_HLE_REGISTER("ContentExport", Libraries::ContentExport::RegisterLib(sym));
    IOS_HLE_REGISTER("VideoRecording", Libraries::VideoRecording::RegisterLib(sym));

    // Loading libSceSsl is locked behind a title workaround that currently applies to nothing.
    // Libraries::Ssl::RegisterLib(sym);
}

} // namespace Libraries
