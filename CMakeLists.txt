cmake_minimum_required( VERSION 3.21 )
set( CMAKE_CXX_STANDARD 17 )
project( defiance VERSION 0.1 )

add_subdirectory( ext/json EXCLUDE_FROM_ALL )
add_subdirectory( ext/spdlog EXCLUDE_FROM_ALL )
add_subdirectory( ext/gflags EXCLUDE_FROM_ALL )

add_library( tileson INTERFACE )
target_include_directories( tileson INTERFACE "${CMAKE_SOURCE_DIR}/ext/tileson/include" )

add_subdirectory( tools/src/levels_to_lua )

install( TARGETS levels_to_lua RUNTIME DESTINATION "${CMAKE_SOURCE_DIR}/tools" )
