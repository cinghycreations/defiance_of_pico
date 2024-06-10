add_executable( levels_to_lua main.cpp )
target_link_libraries( levels_to_lua PUBLIC spdlog nlohmann_json gflags::gflags tileson )
