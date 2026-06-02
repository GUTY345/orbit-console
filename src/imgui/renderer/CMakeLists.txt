# SPDX-FileCopyrightText: Copyright 2024 shadPS4 Emulator Project
# SPDX-License-Identifier: GPL-2.0-or-later

project(ImGui_Resources)

set(FONT_EMBED_SOURCE "${CMAKE_SOURCE_DIR}/externals/dear_imgui/misc/fonts/binary_to_compressed_c.cpp")

if (IOS OR CMAKE_SYSTEM_NAME STREQUAL "iOS")
    set(FONT_EMBED_HOST_ARCH "${CMAKE_HOST_SYSTEM_PROCESSOR}")
    if (FONT_EMBED_HOST_ARCH STREQUAL "AMD64")
        set(FONT_EMBED_HOST_ARCH "x86_64")
    endif()

    set(FONT_EMBED_HOST_TOOL "${CMAKE_CURRENT_BINARY_DIR}/host_tools/Dear_ImGui_FontEmbed")
    add_custom_command(
        OUTPUT "${FONT_EMBED_HOST_TOOL}"
        COMMAND ${CMAKE_COMMAND} -E make_directory "${CMAKE_CURRENT_BINARY_DIR}/host_tools"
        COMMAND /usr/bin/env
            -u SDKROOT
            -u IPHONEOS_DEPLOYMENT_TARGET
            -u PLATFORM_NAME
            -u EFFECTIVE_PLATFORM_NAME
            MACOSX_DEPLOYMENT_TARGET=12.0
            xcrun -sdk macosx clang++ -std=c++17
            -target ${FONT_EMBED_HOST_ARCH}-apple-macosx12.0
            "${FONT_EMBED_SOURCE}" -o "${FONT_EMBED_HOST_TOOL}"
        DEPENDS "${FONT_EMBED_SOURCE}"
        USES_TERMINAL
    )
    add_custom_target(Dear_ImGui_FontEmbed_Host DEPENDS "${FONT_EMBED_HOST_TOOL}")
    set(FONT_EMBED_COMMAND "${FONT_EMBED_HOST_TOOL}")
    set(FONT_EMBED_DEPENDS Dear_ImGui_FontEmbed_Host)
else()
    add_executable(Dear_ImGui_FontEmbed "${FONT_EMBED_SOURCE}")
    set(FONT_EMBED_COMMAND "$<TARGET_FILE:Dear_ImGui_FontEmbed>")
    set(FONT_EMBED_DEPENDS Dear_ImGui_FontEmbed)
endif()

set(FONT_LIST
    NotoSansArabic-Regular.ttf
    NotoSansCJK-Regular.ttc
    NotoSans-Regular.ttf
    NotoSansSymbols2-Regular.ttf
    NotoSansThai-Regular.ttf
    ProggyVector-Regular.ttf
)

set(OutputList "")
FOREACH (FONT_FILE ${FONT_LIST})
    string(REGEX REPLACE "-" "_" fontname ${FONT_FILE})
    string(TOLOWER ${fontname} fontname)
    string(REGEX REPLACE "\\.(ttf|otf|ttc)$" "" fontname_cpp ${fontname})
    set(fontname_cpp "imgui_font_${fontname_cpp}")

    MESSAGE(STATUS "Embedding font ${FONT_FILE}")
    set(OUTPUT "generated_fonts/imgui_fonts/${fontname}")
    add_custom_command(
        OUTPUT "${OUTPUT}.g.cpp"
        COMMAND ${CMAKE_COMMAND} -E make_directory "generated_fonts/imgui_fonts"
        COMMAND "${FONT_EMBED_COMMAND}" -nostatic "${CMAKE_CURRENT_SOURCE_DIR}/fonts/${FONT_FILE}" ${fontname_cpp} > "${OUTPUT}.g.cpp"
        DEPENDS ${FONT_EMBED_DEPENDS} "fonts/${FONT_FILE}"
        USES_TERMINAL
    )
    list(APPEND OutputList "${OUTPUT}.g.cpp")
ENDFOREACH ()

add_library(ImGui_Resources STATIC ${OutputList})
set(IMGUI_RESOURCES_INCLUDE ${CMAKE_CURRENT_BINARY_DIR}/generated_fonts PARENT_SCOPE)
