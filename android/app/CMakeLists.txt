# CMakeLists.txt - Cross-Platform Whisper.cpp Integration
cmake_minimum_required(VERSION 3.22.1)

project(whisper_flutter)

# Set C++ standard
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Platform detection
if(ANDROID)
    message(STATUS "Building for Android")
    set(PLATFORM_ANDROID TRUE)
elseif(CMAKE_SYSTEM_NAME STREQUAL "iOS")
    message(STATUS "Building for iOS")
    set(PLATFORM_IOS TRUE)
elseif(CMAKE_SYSTEM_NAME STREQUAL "Darwin")
    message(STATUS "Building for macOS")
    set(PLATFORM_MACOS TRUE)
elseif(CMAKE_SYSTEM_NAME STREQUAL "Linux")
    message(STATUS "Building for Linux")
    set(PLATFORM_LINUX TRUE)
elseif(CMAKE_SYSTEM_NAME STREQUAL "Windows")
    message(STATUS "Building for Windows")
    set(PLATFORM_WINDOWS TRUE)
endif()

# Compiler optimizations
if(CMAKE_BUILD_TYPE STREQUAL "Release")
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -O3 -DNDEBUG")
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -O3 -DNDEBUG")
else()
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -O2 -g")
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -O2 -g")
endif()

# Source directories
set(JNI_DIR ${CMAKE_SOURCE_DIR}/src/main/cpp)
set(WHISPER_CPP_DIR ${JNI_DIR}/whisper.cpp)

# Check if whisper.cpp source is available
if(EXISTS ${WHISPER_CPP_DIR}/whisper.cpp)
    set(WHISPER_AVAILABLE TRUE)
    message(STATUS "Found whisper.cpp source at ${WHISPER_CPP_DIR}")
else()
    set(WHISPER_AVAILABLE FALSE)
    message(WARNING "whisper.cpp source not found at ${WHISPER_CPP_DIR}")
    message(WARNING "Building without native whisper.cpp support")
endif()

# Platform-specific configurations
if(PLATFORM_ANDROID)
    # Android NDK specific settings
    find_library(log-lib log)
    
    # Android API level and architecture settings
    if(ANDROID_ABI STREQUAL "arm64-v8a")
        set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -march=armv8-a")
        set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -march=armv8-a")
    elseif(ANDROID_ABI STREQUAL "armeabi-v7a")
        set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -march=armv7-a -mfpu=neon")
        set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -march=armv7-a -mfpu=neon")
    endif()
    
    # Android-specific compile definitions
    add_definitions(-DANDROID -D__ANDROID__)
    
elseif(PLATFORM_IOS)
    # iOS specific settings
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fobjc-arc")
    add_definitions(-DIOS -D__IOS__)
    
    # iOS deployment target
    set(CMAKE_OSX_DEPLOYMENT_TARGET "13.0")
    
elseif(PLATFORM_MACOS)
    # macOS specific settings
    add_definitions(-DMACOS -D__MACOS__)
    set(CMAKE_OSX_DEPLOYMENT_TARGET "10.15")
    
elseif(PLATFORM_LINUX)
    # Linux specific settings
    add_definitions(-DLINUX -D__LINUX__)
    
elseif(PLATFORM_WINDOWS)
    # Windows specific settings
    add_definitions(-DWINDOWS -D_WIN32)
    
    if(MSVC)
        set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} /bigobj")
    endif()
endif()

# Common compile definitions
add_definitions(-DGGML_USE_ACCELERATE)
if(WHISPER_AVAILABLE)
    add_definitions(-DWHISPER_AVAILABLE=1)
else()
    add_definitions(-DWHISPER_AVAILABLE=0)
endif()

# Whisper.cpp configuration
if(WHISPER_AVAILABLE)
    # Whisper.cpp source files
    set(WHISPER_SOURCES
        ${WHISPER_CPP_DIR}/whisper.cpp
        ${WHISPER_CPP_DIR}/ggml.c
        ${WHISPER_CPP_DIR}/ggml-alloc.c
        ${WHISPER_CPP_DIR}/ggml-backend.c
        ${WHISPER_CPP_DIR}/ggml-quants.c
    )

    # Check for optional ggml files
    if(EXISTS ${WHISPER_CPP_DIR}/ggml-metal.m)
        list(APPEND WHISPER_SOURCES ${WHISPER_CPP_DIR}/ggml-metal.m)
        if(PLATFORM_IOS OR PLATFORM_MACOS)
            add_definitions(-DGGML_USE_METAL)
        endif()
    endif()

    if(EXISTS ${WHISPER_CPP_DIR}/ggml-cuda.cu)
        # CUDA support (mainly for desktop platforms)
        if(PLATFORM_LINUX OR PLATFORM_WINDOWS)
            find_package(CUDA QUIET)
            if(CUDA_FOUND)
                enable_language(CUDA)
                list(APPEND WHISPER_SOURCES ${WHISPER_CPP_DIR}/ggml-cuda.cu)
                add_definitions(-DGGML_USE_CUDA)
                message(STATUS "CUDA support enabled")
            endif()
        endif()
    endif()

    # Create whisper.cpp static library
    add_library(whisper_cpp_static STATIC ${WHISPER_SOURCES})

    # Whisper.cpp compile options
    target_compile_options(whisper_cpp_static PRIVATE
        $<$<COMPILE_LANGUAGE:C>:-std=c11>
        $<$<COMPILE_LANGUAGE:CXX>:-std=c++17>
        -fPIC
        -Wall
        -Wextra
        -Wpedantic
        -Wcast-qual
        -Wno-unused-function
    )

    # Platform-specific optimizations for whisper.cpp
    if(PLATFORM_ANDROID OR PLATFORM_IOS)
        # Mobile optimizations
        target_compile_options(whisper_cpp_static PRIVATE
            -ffast-math
            -funroll-loops
        )
        
        # ARM NEON optimizations
        if(ANDROID_ABI STREQUAL "arm64-v8a" OR ANDROID_ABI STREQUAL "armeabi-v7a")
            target_compile_definitions(whisper_cpp_static PRIVATE GGML_USE_ARM_NEON)
        endif()
        
    else()
        # Desktop optimizations
        target_compile_options(whisper_cpp_static PRIVATE
            -march=native
            -mtune=native
            -ffast-math
            -funroll-loops
        )
    endif()

    # Include directories for whisper.cpp
    target_include_directories(whisper_cpp_static PUBLIC ${WHISPER_CPP_DIR})

    # Platform-specific whisper.cpp linking
    if(PLATFORM_MACOS OR PLATFORM_IOS)
        find_library(ACCELERATE_FRAMEWORK Accelerate)
        find_library(METAL_FRAMEWORK Metal)
        find_library(FOUNDATION_FRAMEWORK Foundation)
        
        target_link_libraries(whisper_cpp_static 
            ${ACCELERATE_FRAMEWORK}
            ${FOUNDATION_FRAMEWORK}
        )
        
        if(METAL_FRAMEWORK AND (EXISTS ${WHISPER_CPP_DIR}/ggml-metal.m))
            target_link_libraries(whisper_cpp_static ${METAL_FRAMEWORK})
        endif()
        
    elseif(PLATFORM_ANDROID)
        # Android specific libraries for whisper.cpp
        target_link_libraries(whisper_cpp_static 
            android
            ${log-lib}
        )
        
    elseif(PLATFORM_LINUX)
        # Linux threading and math libraries
        find_package(Threads REQUIRED)
        target_link_libraries(whisper_cpp_static 
            Threads::Threads
            m
        )
        
    elseif(PLATFORM_WINDOWS)
        # Windows specific libraries
        target_link_libraries(whisper_cpp_static
            kernel32
            user32
        )
    endif()

endif() # WHISPER_AVAILABLE

# Main JNI library configuration
if(PLATFORM_ANDROID)
    # Android JNI library
    add_library(whisper SHARED
        ${JNI_DIR}/whisper_jni.cpp
    )
    
    # Android linking
    target_link_libraries(whisper
        android
        ${log-lib}
    )
    
    if(WHISPER_AVAILABLE)
        target_link_libraries(whisper whisper_cpp_static)
    endif()
    
elseif(PLATFORM_IOS OR PLATFORM_MACOS)
    # iOS/macOS static library (for Flutter integration)
    add_library(whisper STATIC
        ${JNI_DIR}/whisper_ios.cpp  # iOS-specific implementation
    )
    
    if(WHISPER_AVAILABLE)
        target_link_libraries(whisper whisper_cpp_static)
    endif()
    
else()
    # Desktop shared library
    add_library(whisper SHARED
        ${JNI_DIR}/whisper_desktop.cpp  # Desktop-specific implementation
    )
    
    if(WHISPER_AVAILABLE)
        target_link_libraries(whisper whisper_cpp_static)
    endif()
endif()

# Common whisper library settings
target_compile_options(whisper PRIVATE
    $<$<COMPILE_LANGUAGE:CXX>:-std=c++17>
    -fPIC
    -Wall
    -Wextra
)

# Include directories for main library
target_include_directories(whisper PRIVATE
    ${JNI_DIR}
)

if(WHISPER_AVAILABLE)
    target_include_directories(whisper PRIVATE ${WHISPER_CPP_DIR})
endif()

# Platform-specific compile definitions for main library
if(WHISPER_AVAILABLE)
    target_compile_definitions(whisper PRIVATE WHISPER_AVAILABLE=1)
else()
    target_compile_definitions(whisper PRIVATE WHISPER_AVAILABLE=0)
endif()

# Android specific settings
if(PLATFORM_ANDROID)
    # NDK API level compatibility
    target_compile_definitions(whisper PRIVATE
        ANDROID_NDK_VERSION=${ANDROID_NDK_REVISION}
    )
    
    # Strip symbols in release builds
    if(CMAKE_BUILD_TYPE STREQUAL "Release")
        set_target_properties(whisper PROPERTIES LINK_FLAGS "-s")
    endif()
    
    # ABI-specific optimizations
    if(ANDROID_ABI STREQUAL "arm64-v8a")
        target_compile_definitions(whisper PRIVATE ARM64_V8A)
    elseif(ANDROID_ABI STREQUAL "armeabi-v7a")
        target_compile_definitions(whisper PRIVATE ARMEABI_V7A)
    elseif(ANDROID_ABI STREQUAL "x86_64")
        target_compile_definitions(whisper PRIVATE X86_64)
    elseif(ANDROID_ABI STREQUAL "x86")
        target_compile_definitions(whisper PRIVATE X86)
    endif()
endif()

# Installation settings
if(PLATFORM_ANDROID)
    # Android: libraries are automatically packaged into APK
    install(TARGETS whisper
        LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    )
    
    if(WHISPER_AVAILABLE)
        install(TARGETS whisper_cpp_static
            ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
        )
    endif()
    
elseif(PLATFORM_IOS)
    # iOS: static libraries are linked into the app
    install(TARGETS whisper
        ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
    )
    
    if(WHISPER_AVAILABLE)
        install(TARGETS whisper_cpp_static
            ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
        )
    endif()
    
else()
    # Desktop platforms
    install(TARGETS whisper
        LIBRARY DESTINATION lib
        ARCHIVE DESTINATION lib
        RUNTIME DESTINATION bin
    )
    
    if(WHISPER_AVAILABLE)
        install(TARGETS whisper_cpp_static
            ARCHIVE DESTINATION lib
        )
    endif()
endif()

# Debug information
message(STATUS "=== Build Configuration ===")
message(STATUS "Platform: ${CMAKE_SYSTEM_NAME}")
message(STATUS "Build Type: ${CMAKE_BUILD_TYPE}")
message(STATUS "C++ Standard: ${CMAKE_CXX_STANDARD}")
message(STATUS "Whisper.cpp Available: ${WHISPER_AVAILABLE}")

if(PLATFORM_ANDROID)
    message(STATUS "Android ABI: ${ANDROID_ABI}")
    message(STATUS "Android API Level: ${ANDROID_PLATFORM}")
    message(STATUS "NDK Version: ${ANDROID_NDK_REVISION}")
endif()

if(WHISPER_AVAILABLE)
    message(STATUS "Whisper.cpp Directory: ${WHISPER_CPP_DIR}")
    message(STATUS "Whisper Sources: ${WHISPER_SOURCES}")
endif()

message(STATUS "C++ Flags: ${CMAKE_CXX_FLAGS}")
message(STATUS "C Flags: ${CMAKE_C_FLAGS}")
message(STATUS "=== End Configuration ===")

# Add custom target for downloading whisper.cpp if not present
if(NOT WHISPER_AVAILABLE)
    add_custom_target(download_whisper_cpp
        COMMAND ${CMAKE_COMMAND} -E echo "Downloading whisper.cpp..."
        COMMAND git clone https://github.com/ggerganov/whisper.cpp.git ${WHISPER_CPP_DIR}
        WORKING_DIRECTORY ${JNI_DIR}
        COMMENT "Downloading whisper.cpp source code"
    )
    
    message(STATUS "To download whisper.cpp, run: cmake --build . --target download_whisper_cpp")
endif()

# Add custom target for cleaning whisper.cpp
add_custom_target(clean_whisper_cpp
    COMMAND ${CMAKE_COMMAND} -E remove_directory ${WHISPER_CPP_DIR}
    COMMENT "Removing whisper.cpp source code"
)

# Testing configuration
if(CMAKE_PROJECT_NAME STREQUAL PROJECT_NAME)
    include(CTest)
    
    if(BUILD_TESTING)
        # Add basic library loading test
        add_subdirectory(tests OPTIONAL)
    endif()
endif()