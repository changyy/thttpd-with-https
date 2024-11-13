cmake_minimum_required(VERSION 3.10)
project(thttpd-with-https C)

# 設置專案版本
set(PROJECT_VERSION "1.0.0")

set(THTTPD_PORT "8080" CACHE STRING "Port for THTTPD to listen on")
set(STUNNEL_PORT "8443" CACHE STRING "Port for Stunnel to listen on")

# 設置 CMake 模組路徑
set(CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH} "${CMAKE_SOURCE_DIR}/cmake")

# 設置編譯選項
option(ENABLE_SSL "Enable HTTPS support via stunnel" ON)
option(ENABLE_DEBUG "Enable debug build" OFF)
option(ENABLE_TESTS "Enable testing" OFF)

# 設置默認端口
set(THTTPD_PORT 80 CACHE STRING "Port for THTTPD to listen on")
set(STUNNEL_PORT 443 CACHE STRING "Port for Stunnel to listen on")

# 設置安裝目錄
set(INSTALL_BIN_DIR "${CMAKE_INSTALL_PREFIX}/bin" CACHE PATH "Installation directory for executables")
set(INSTALL_CONF_DIR "${CMAKE_INSTALL_PREFIX}/etc" CACHE PATH "Installation directory for config files")

# 檢查必要的依賴
find_package(OpenSSL REQUIRED)

# 包含下載模組
include(DownloadTHTTPD)
if(ENABLE_SSL)
    include(DownloadStunnel)
endif()

# 確保源碼目錄已設置
if(NOT DEFINED THTTPD_SOURCES_DIR)
    message(FATAL_ERROR "THTTPD_SOURCES_DIR not set")
endif()

if(ENABLE_SSL AND NOT DEFINED STUNNEL_SOURCES_DIR)
    message(FATAL_ERROR "STUNNEL_SOURCES_DIR not set")
endif()

# 設置編譯標誌
if(ENABLE_DEBUG)
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -g -O0 -DDEBUG")
else()
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -O2")
endif()

# 應用補丁
if(EXISTS "${CMAKE_SOURCE_DIR}/patches/thttpd-ssl.patch")
    message(STATUS "Applying THTTPD SSL patch")
    execute_process(
        COMMAND patch -p1 -i "${CMAKE_SOURCE_DIR}/patches/thttpd-ssl.patch"
        WORKING_DIRECTORY ${THTTPD_SOURCES_DIR}
        RESULT_VARIABLE PATCH_RESULT
    )
    if(NOT PATCH_RESULT EQUAL 0)
        message(FATAL_ERROR "Failed to apply THTTPD patch")
    endif()
endif()

# 添加 THTTPD 編譯目標
add_custom_target(thttpd ALL
    COMMAND ${CMAKE_MAKE_PROGRAM}
    WORKING_DIRECTORY ${THTTPD_SOURCES_DIR}
    COMMENT "Building THTTPD"
)

# 添加 Stunnel 編譯目標
if(ENABLE_SSL)
    add_custom_target(stunnel ALL
        COMMAND ${CMAKE_MAKE_PROGRAM}
        WORKING_DIRECTORY ${STUNNEL_SOURCES_DIR}
        COMMENT "Building Stunnel"
    )
    
    # 設置依賴關係
    add_dependencies(stunnel thttpd)
endif()

# 添加一個用於檢查檔案存在的函數
function(check_file_exists file_path error_message)
    if(NOT EXISTS "${file_path}")
        message(FATAL_ERROR "${error_message}")
    endif()
endfunction()

# 添加收集目標
add_custom_target(collect
    # 首先建立 bin 目錄
    COMMAND ${CMAKE_COMMAND} -E make_directory "${CMAKE_BINARY_DIR}/bin"
    
    # 確認並複製 thttpd
    COMMAND ${CMAKE_COMMAND} -E echo "Checking and copying thttpd..."
    COMMAND ${CMAKE_COMMAND} -E copy 
        "${THTTPD_SOURCES_DIR}/thttpd"
        "${CMAKE_BINARY_DIR}/bin/"
    
    # 確認並複製 stunnel
    COMMAND ${CMAKE_COMMAND} -E echo "Checking and copying stunnel..."
    COMMAND ${CMAKE_COMMAND} -E copy 
        "${STUNNEL_SOURCES_DIR}/src/stunnel"
        "${CMAKE_BINARY_DIR}/bin/"
    
    COMMENT "Collecting executables to bin directory"
)

# 設置收集目標的依賴
add_dependencies(collect thttpd stunnel)

# 安裝規則
install(
    FILES "${THTTPD_SOURCES_DIR}/thttpd"
    DESTINATION ${INSTALL_BIN_DIR}
    PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE
)

if(ENABLE_SSL)
    install(
        FILES "${STUNNEL_SOURCES_DIR}/src/.libs/stunnel"
        DESTINATION ${INSTALL_BIN_DIR}
        PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE
    )
endif()

# 同樣更新安裝規則
install(
    PROGRAMS    # 使用 PROGRAMS 而不是 FILES 來保留執行權限
        "${THTTPD_SOURCES_DIR}/thttpd"
        "${STUNNEL_SOURCES_DIR}/src/stunnel"
    DESTINATION ${INSTALL_BIN_DIR}
)

# 安裝配置文件
install(
    FILES 
        "${CMAKE_BINARY_DIR}/thttpd.conf"
        "${CMAKE_BINARY_DIR}/stunnel.conf"
    DESTINATION ${INSTALL_CONF_DIR}
)

# 配置文件
configure_file(
    "${CMAKE_SOURCE_DIR}/src/config/thttpd.conf.in"
    "${CMAKE_BINARY_DIR}/bin/thttpd.conf"
    @ONLY
)

if(ENABLE_SSL)
    configure_file(
        "${CMAKE_SOURCE_DIR}/src/config/stunnel.conf.in"
        "${CMAKE_BINARY_DIR}/bin/stunnel.conf"
        @ONLY
    )
endif()

# 配置腳本文件
configure_file(
    "${CMAKE_SOURCE_DIR}/src/scripts/generate-cert.sh.in"
    "${CMAKE_BINARY_DIR}/bin/generate-cert.sh"
    @ONLY
)

configure_file(
    "${CMAKE_SOURCE_DIR}/src/scripts/start-servers.sh.in"
    "${CMAKE_BINARY_DIR}/bin/start-servers.sh"
    @ONLY
)

configure_file(
    "${CMAKE_SOURCE_DIR}/src/scripts/stop-servers.sh.in"
    "${CMAKE_BINARY_DIR}/bin/stop-servers.sh"
    @ONLY
)

# 添加設置腳本權限的命令
add_custom_target(prepare-scripts
    COMMAND chmod +x "${CMAKE_BINARY_DIR}/bin/generate-cert.sh"
    COMMAND chmod +x "${CMAKE_BINARY_DIR}/bin/start-servers.sh"
    COMMAND chmod +x "${CMAKE_BINARY_DIR}/bin/stop-servers.sh"
    COMMENT "Setting script permissions"
)

# 更新 collect 目標以包含腳本準備
add_dependencies(collect prepare-scripts)

# 添加測試
if(ENABLE_TESTS)
    enable_testing()
    add_subdirectory(tests)
endif()

# 顯示配置摘要
message(STATUS "")
message(STATUS "THTTPD with HTTPS Configuration Summary")
message(STATUS "=====================================")
message(STATUS "Version:                 ${PROJECT_VERSION}")
message(STATUS "SSL support:             ${ENABLE_SSL}")
message(STATUS "Debug build:             ${ENABLE_DEBUG}")
message(STATUS "THTTPD port:             ${THTTPD_PORT}")
message(STATUS "Stunnel port:            ${STUNNEL_PORT}")
message(STATUS "Install prefix:          ${CMAKE_INSTALL_PREFIX}")
message(STATUS "THTTPD sources:          ${THTTPD_SOURCES_DIR}")
if(ENABLE_SSL)
    message(STATUS "Stunnel sources:         ${STUNNEL_SOURCES_DIR}")
endif()
message(STATUS "OpenSSL root:            ${OPENSSL_ROOT_DIR}")
message(STATUS "")
