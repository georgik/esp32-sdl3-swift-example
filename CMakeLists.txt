CMakeLists.txtcmake_minimum_required(VERSION 3.29)

set(ENV{BUILD_BOARD} "esp32_p4_function_ev_board_noglib")
include($ENV{IDF_PATH}/tools/cmake/project.cmake)
project(esp32-sdl3-swift-example)


get_filename_component(configName "${CMAKE_BINARY_DIR}" NAME)
list(APPEND EXTRA_COMPONENT_DIRS "${CMAKE_SOURCE_DIR}/components/esp_littlefs")
littlefs_create_partition_image(assets assets FLASH_IN_PROJECT)
