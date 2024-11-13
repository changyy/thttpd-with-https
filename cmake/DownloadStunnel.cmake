include(ExternalProject)

function(setup_stunnel)
    # 設置 Stunnel 版本和 URL
    set(STUNNEL_VERSION "5.73")
    set(STUNNEL_URL "https://www.stunnel.org/downloads/stunnel-${STUNNEL_VERSION}.tar.gz")
    set(STUNNEL_DOWNLOAD_DIR "${CMAKE_CURRENT_BINARY_DIR}/stunnel-download")
    set(STUNNEL_SOURCE_DIR "${CMAKE_CURRENT_BINARY_DIR}/stunnel-src")

    # 確保 OpenSSL 已經被找到
    if(NOT OPENSSL_FOUND)
        find_package(OpenSSL REQUIRED)
    endif()

    if(NOT EXISTS "${STUNNEL_SOURCE_DIR}")
        message(STATUS "Downloading and configuring Stunnel ${STUNNEL_VERSION}")
        message(STATUS "Using OpenSSL from: ${OPENSSL_ROOT_DIR}")
        
        # 下載 Stunnel
        file(DOWNLOAD
            ${STUNNEL_URL}
            "${STUNNEL_DOWNLOAD_DIR}/stunnel-${STUNNEL_VERSION}.tar.gz"
            SHOW_PROGRESS
            STATUS download_status
            TLS_VERIFY ON
        )
        
        list(GET download_status 0 status_code)
        if(NOT status_code EQUAL 0)
            message(FATAL_ERROR "Failed to download Stunnel")
        endif()
        
        # 創建臨時解壓目錄
        file(MAKE_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/stunnel-temp")
        
        # 解壓文件
        execute_process(
            COMMAND ${CMAKE_COMMAND} -E tar xzf "${STUNNEL_DOWNLOAD_DIR}/stunnel-${STUNNEL_VERSION}.tar.gz"
            WORKING_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/stunnel-temp"
            RESULT_VARIABLE extract_result
        )
        
        if(NOT extract_result EQUAL 0)
            message(FATAL_ERROR "Failed to extract Stunnel")
        endif()
        
        # 設置環境變數和 host type
        if(APPLE)
            execute_process(
                COMMAND uname -m
                OUTPUT_VARIABLE MACHINE_HARDWARE_NAME
                OUTPUT_STRIP_TRAILING_WHITESPACE
            )
            
            if(MACHINE_HARDWARE_NAME STREQUAL "arm64")
                set(HOST_TYPE "aarch64-apple-darwin")
                set(ENV{CC} "/usr/bin/clang")
                set(ENV{CFLAGS} "-arch arm64 -mmacosx-version-min=13.0")
                set(ENV{LDFLAGS} "-arch arm64")
                message(STATUS "Configuring Stunnel for Apple Silicon (ARM64)")
            else()
                set(HOST_TYPE "x86_64-apple-darwin")
                set(ENV{CC} "${CMAKE_C_COMPILER}")
                message(STATUS "Configuring Stunnel for non-ARM64 macOS")
            endif()
        else()
            execute_process(
                COMMAND uname -m
                OUTPUT_VARIABLE MACHINE_HARDWARE_NAME
                OUTPUT_STRIP_TRAILING_WHITESPACE
            )
            execute_process(
                COMMAND uname -s
                OUTPUT_VARIABLE OS_NAME
                OUTPUT_STRIP_TRAILING_WHITESPACE
            )
            string(TOLOWER ${OS_NAME} OS_NAME_LOWER)
            set(HOST_TYPE "${MACHINE_HARDWARE_NAME}-unknown-${OS_NAME_LOWER}")
        endif()
        
        # 根據系統找到 OpenSSL 安裝目錄
        if(APPLE)
            if(EXISTS "/usr/local/opt/openssl")
                set(SSL_DIR "/usr/local/opt/openssl")
            elseif(EXISTS "/opt/homebrew/opt/openssl@3")
                set(SSL_DIR "/opt/homebrew/opt/openssl@3")
            else()
                set(SSL_DIR ${OPENSSL_ROOT_DIR})
            endif()
        else()
            set(SSL_DIR ${OPENSSL_ROOT_DIR})
        endif()

        message(STATUS "Using SSL_DIR: ${SSL_DIR}")
        
        # 創建並運行配置腳本
        file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/stunnel-temp/configure.sh"
            "#!/bin/sh\n"
            "cd ${CMAKE_CURRENT_BINARY_DIR}/stunnel-temp/stunnel-${STUNNEL_VERSION}\n"
            "CC=\"$ENV{CC}\" CFLAGS=\"$ENV{CFLAGS}\" LDFLAGS=\"$ENV{LDFLAGS}\" ./configure --host=${HOST_TYPE} --prefix=${CMAKE_INSTALL_PREFIX} --with-ssl=${SSL_DIR}\n"
        )
        
        # 設置腳本權限
        execute_process(
            COMMAND chmod +x "${CMAKE_CURRENT_BINARY_DIR}/stunnel-temp/configure.sh"
            RESULT_VARIABLE chmod_result
        )
        
        if(NOT chmod_result EQUAL 0)
            message(FATAL_ERROR "Failed to set execute permission on configure script")
        endif()
        
        # 運行配置腳本
        execute_process(
            COMMAND sh "${CMAKE_CURRENT_BINARY_DIR}/stunnel-temp/configure.sh"
            WORKING_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/stunnel-temp"
            RESULT_VARIABLE configure_result
            OUTPUT_VARIABLE configure_output
            ERROR_VARIABLE configure_error
        )
        
        if(NOT configure_result EQUAL 0)
            message(STATUS "Configure output: ${configure_output}")
            message(STATUS "Configure error: ${configure_error}")
            message(FATAL_ERROR "Failed to configure Stunnel")
        endif()
        
        # 複製所有文件到源目錄
        file(COPY 
            "${CMAKE_CURRENT_BINARY_DIR}/stunnel-temp/stunnel-${STUNNEL_VERSION}/"
            DESTINATION "${STUNNEL_SOURCE_DIR}"
        )
        
        # 清理臨時目錄
        file(REMOVE_RECURSE "${CMAKE_CURRENT_BINARY_DIR}/stunnel-temp")
    endif()

    # 設置源碼目錄變量到父作用域
    set(STUNNEL_SOURCES_DIR "${STUNNEL_SOURCE_DIR}" PARENT_SCOPE)
endfunction()

# 調用函數並設置全局變量
setup_stunnel()
