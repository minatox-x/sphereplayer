cmake_minimum_required(VERSION 3.14)
project(sphere_player LANGUAGES CXX)

set(BINARY_NAME "sphere_player")

cmake_policy(SET CMP0063 NEW)

set(CMAKE_INSTALL_PREFIX "${CMAKE_BINARY_DIR}/install")
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Flutter REQUIRED)

set(FLUTTER_MANAGED_DIR "${CMAKE_CURRENT_SOURCE_DIR}/flutter")

# Application build; see runner/CMakeLists.txt
add_subdirectory("runner")

# ── Flutter library (managed) ──────────────────────────────────────────────
include(${FLUTTER_MANAGED_DIR}/generated_plugins.cmake)

# ── Installation ──────────────────────────────────────────────────────────
install(TARGETS ${BINARY_NAME} RUNTIME DESTINATION "${CMAKE_INSTALL_PREFIX}")
install(FILES "${FLUTTER_ICU_DATA_FILE}" DESTINATION "${CMAKE_INSTALL_PREFIX}" COMPONENT Runtime)
install(FILES "${FLUTTER_LIBRARY}" DESTINATION "${CMAKE_INSTALL_PREFIX}" COMPONENT Runtime)
if(PLUGIN_BUNDLED_LIBRARIES)
  install(FILES "${PLUGIN_BUNDLED_LIBRARIES}" DESTINATION "${CMAKE_INSTALL_PREFIX}" COMPONENT Runtime)
endif()
install(CODE "
  file(GLOB_RECURSE DLLS \"${CMAKE_BINARY_DIR}/flutter_assets/*\")
  foreach(DLL \${DLLS})
    file(COPY \${DLL} DESTINATION \"${CMAKE_INSTALL_PREFIX}/flutter_assets\")
  endforeach()
" COMPONENT Runtime)
install(DIRECTORY "${CMAKE_BINARY_DIR}/flutter_assets" DESTINATION "${CMAKE_INSTALL_PREFIX}" COMPONENT Runtime)
install(FILES "${AOT_LIBRARY}" DESTINATION "${CMAKE_INSTALL_PREFIX}" COMPONENT Runtime OPTIONAL)
