cmake_minimum_required(VERSION 3.10)

project(whisper_flutter)

# Find required packages
find_package(PkgConfig REQUIRED)

# Set C++ standard
set(CMAKE_CXX_STANDARD 17)

# Add whisper.cpp as subdirectory (you'll need to add whisper.cpp source)
# add_subdirectory(${CMAKE_SOURCE_DIR}/src/main/cpp/whisper.cpp)

# Create the whisper library
add_library(whisper SHARED
    src/main/cpp/whisper_jni.cpp
    # Add whisper.cpp source files here
)

# Link libraries
target_link_libraries(whisper
    android
    log
)