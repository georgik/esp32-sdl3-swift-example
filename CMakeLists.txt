cmake_minimum_required(VERSION 3.29)

# Select board configuration based on -DBUILD_BOARD
if(NOT DEFINED BUILD_BOARD)
    message(WARNING "BUILD_BOARD CMake variable is not set, using esp32_p4_function_ev_board_noglib. Use idf.py @boards/BOARD.cfg reconfigure")
    set(ENV{BUILD_BOARD} "esp32_p4_function_ev_board_noglib")
else()
    set(ENV{BUILD_BOARD} ${BUILD_BOARD})
endif()

set(COMPONENTS
    main
    georgik__sdl
) # "Trim" the build. Include the minimal set of components; main and anything it depends on.

include($ENV{IDF_PATH}/tools/cmake/project.cmake)

project(esp32-sdl3-swift-example)

get_filename_component(configName "${CMAKE_BINARY_DIR}" NAME)
list(APPEND EXTRA_COMPONENT_DIRS "${CMAKE_SOURCE_DIR}/components/esp_littlefs")
littlefs_create_partition_image(assets assets FLASH_IN_PROJECT)
