cmake_minimum_required(VERSION 3.20)
set(CMAKE_CXX_STANDARD 14)
set(CMAKE_CXX_STANDARD_REQUIRED on)

project(permissions)

set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

if (UNIX AND APPLE)
    # Source
    set(SOURCE_FILES src/permissions.mm)

    # Add target
    add_library(${PROJECT_NAME} SHARED ${SOURCE_FILES} ${CMAKE_JS_SRC})

    set(LIBS)

    # External libs
    if (UNIX AND APPLE)
        set(LIBS ${LIBS} "-framework AppKit")
        set(LIBS ${LIBS} "-framework AVFoundation")
        set(LIBS ${LIBS} "-framework CoreBluetooth")
        set(LIBS ${LIBS} "-framework CoreFoundation")
        set(LIBS ${LIBS} "-framework CoreLocation")
        set(LIBS ${LIBS} "-framework CoreGraphics")
        set(LIBS ${LIBS} "-framework Contacts")
        set(LIBS ${LIBS} "-framework EventKit")
        set(LIBS ${LIBS} "-framework IOKit")
        set(LIBS ${LIBS} "-framework Photos")
        set(LIBS ${LIBS} "-framework Speech")
        set(LIBS ${LIBS} "-framework Storekit")
    endif ()

    set(CMAKE_OSX_DEPLOYMENT_TARGET 10.13)

    add_definitions(-DNAPI_DISABLE_CPP_EXCEPTIONS)
    add_definitions(-DNAPI_VERSION=4)

    # cmake-js
    include_directories(${CMAKE_JS_INC})

    # node-addon-api
    execute_process(COMMAND node -p "require('node-addon-api').include"
            WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
            OUTPUT_VARIABLE NODE_ADDON_API_DIR
            )
    string(REGEX REPLACE "[\r\n\"]" "" NODE_ADDON_API_DIR ${NODE_ADDON_API_DIR})

    target_include_directories(${PROJECT_NAME} PRIVATE ${NODE_ADDON_API_DIR})

    # Change suffix to *.node
    set_target_properties(${PROJECT_NAME} PROPERTIES PREFIX "" SUFFIX ".node")

    # BUILD
    target_link_libraries(${PROJECT_NAME} ${LIBS} ${CMAKE_JS_LIB})
endif ()
