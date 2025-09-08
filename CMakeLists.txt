cmake_minimum_required(VERSION 3.29)

# Select board configuration based on -DBUILD_BOARD
if(NOT DEFINED BUILD_BOARD)
    message(WARNING "BUILD_BOARD CMake variable is not set, using esp32_p4_function_ev_board_noglib. Use idf.py @boards/BOARD.cfg reconfigure")
    set(ENV{BUILD_BOARD} "esp32_p4_function_ev_board_noglib")
else()
    set(ENV{BUILD_BOARD} ${BUILD_BOARD})
endif()

# Add BSP-specific configurations
if(BUILD_BOARD STREQUAL "m5stack_tab5")
    add_compile_definitions(BSP_CONFIG_NO_GRAPHIC_LIB=1)
endif()

include($ENV{IDF_PATH}/tools/cmake/project.cmake)
project(esp32-sdl3-swift-example)

get_filename_component(configName "${CMAKE_BINARY_DIR}" NAME)
list(APPEND EXTRA_COMPONENT_DIRS "${CMAKE_SOURCE_DIR}/components/esp_littlefs")
list(APPEND EXTRA_COMPONENT_DIRS "${CMAKE_SOURCE_DIR}/components")
littlefs_create_partition_image(assets assets FLASH_IN_PROJECT)
