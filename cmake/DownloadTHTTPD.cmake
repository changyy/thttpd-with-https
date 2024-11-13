include(ExternalProject)

function(setup_thttpd)
    # 設置 THTTPD 版本和 URL
    set(THTTPD_VERSION "2.29")
    set(THTTPD_URL "http://www.acme.com/software/thttpd/thttpd-${THTTPD_VERSION}.tar.gz")
    set(THTTPD_DOWNLOAD_DIR "${CMAKE_CURRENT_BINARY_DIR}/thttpd-download")
    set(THTTPD_SOURCE_DIR "${CMAKE_CURRENT_BINARY_DIR}/thttpd-src")

    if(NOT EXISTS "${THTTPD_SOURCE_DIR}")
        message(STATUS "Downloading and configuring THTTPD ${THTTPD_VERSION}")
        
        # 下載 THTTPD
        file(DOWNLOAD
            ${THTTPD_URL}
            "${THTTPD_DOWNLOAD_DIR}/thttpd-${THTTPD_VERSION}.tar.gz"
            SHOW_PROGRESS
            STATUS download_status
        )
        
        list(GET download_status 0 status_code)
        if(NOT status_code EQUAL 0)
            message(FATAL_ERROR "Failed to download THTTPD")
        endif()
        
        # 創建臨時解壓目錄
        file(MAKE_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/thttpd-temp")
        
        # 解壓文件
        execute_process(
            COMMAND ${CMAKE_COMMAND} -E tar xzf "${THTTPD_DOWNLOAD_DIR}/thttpd-${THTTPD_VERSION}.tar.gz"
            WORKING_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/thttpd-temp"
            RESULT_VARIABLE extract_result
        )
        
        if(NOT extract_result EQUAL 0)
            message(FATAL_ERROR "Failed to extract THTTPD")
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
                set(ENV{CFLAGS} "-arch arm64 -mmacosx-version-min=13.0 -Wno-implicit-int -Wno-return-type")
                set(ENV{LDFLAGS} "-arch arm64")
                message(STATUS "Configuring for Apple Silicon (ARM64)")
            else()
                set(HOST_TYPE "x86_64-apple-darwin")
                set(ENV{CC} "${CMAKE_C_COMPILER}")
                message(STATUS "Configuring for non-ARM64 macOS")
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
        
        # 創建並運行配置腳本
        file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/thttpd-temp/configure.sh"
            "#!/bin/sh\n"
            "cd ${CMAKE_CURRENT_BINARY_DIR}/thttpd-temp/thttpd-${THTTPD_VERSION}\n"
            "CC=\"$ENV{CC}\" CFLAGS=\"$ENV{CFLAGS}\" LDFLAGS=\"$ENV{LDFLAGS}\" ./configure --host=${HOST_TYPE}\n"
        )
        
        # 設置腳本權限
        execute_process(
            COMMAND chmod +x "${CMAKE_CURRENT_BINARY_DIR}/thttpd-temp/configure.sh"
            RESULT_VARIABLE chmod_result
        )
        
        if(NOT chmod_result EQUAL 0)
            message(FATAL_ERROR "Failed to set execute permission on configure script")
        endif()
        
        # 運行配置腳本
        execute_process(
            COMMAND sh "${CMAKE_CURRENT_BINARY_DIR}/thttpd-temp/configure.sh"
            WORKING_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/thttpd-temp"
            RESULT_VARIABLE configure_result
            OUTPUT_VARIABLE configure_output
            ERROR_VARIABLE configure_error
        )
        
        if(NOT configure_result EQUAL 0)
            message(STATUS "Configure output: ${configure_output}")
            message(STATUS "Configure error: ${configure_error}")
            message(FATAL_ERROR "Failed to configure THTTPD")
        endif()
        
        # 複製所有文件到源目錄
        file(COPY 
            "${CMAKE_CURRENT_BINARY_DIR}/thttpd-temp/thttpd-${THTTPD_VERSION}/"
            DESTINATION "${THTTPD_SOURCE_DIR}"
        )
        
        # 清理臨時目錄
        file(REMOVE_RECURSE "${CMAKE_CURRENT_BINARY_DIR}/thttpd-temp")
    endif()

    # 設置源碼目錄變量到父作用域
    set(THTTPD_SOURCES_DIR "${THTTPD_SOURCE_DIR}" PARENT_SCOPE)
endfunction()

# 調用函數並設置全局變量
setup_thttpd()
