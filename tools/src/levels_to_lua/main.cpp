#include <tileson.h>
#include <spdlog/logger.h>
#include <spdlog/sinks/stdout_color_sinks.h>
#include <spdlog/fmt/std.h>
#include <filesystem>
#include <gflags/gflags.h>

DEFINE_string(levels, "", "Folder where the levels reside");
DEFINE_string(lua, "", "Output file");

std::shared_ptr<spdlog::logger> toolLog;

static bool startsWith(const std::string& s, const std::string& prefix) {
	return s.size() >= prefix.size() && strncmp(s.c_str(), prefix.c_str(), prefix.size()) == 0;
}

int main(int argc, char* argv[]) {
	gflags::ParseCommandLineFlags(&argc, &argv, false);

	std::shared_ptr<spdlog::sinks::sink> console_sink(new spdlog::sinks::stderr_color_sink_st);
	toolLog.reset(new spdlog::logger("levels_to_lua", console_sink));

	std::filesystem::path levels_path = FLAGS_levels;
	toolLog->info("Levels folder: {}", levels_path);

	std::vector<std::filesystem::path> level_paths;
	for (const auto& entry : std::filesystem::directory_iterator(levels_path)) {
		if (entry.is_regular_file() && entry.path().extension() == ".tmj" && startsWith(entry.path().stem().string(), "level")) {
			toolLog->info("Found level {}", entry.path());
			level_paths.push_back(entry.path());
		}
	}

	std::sort(level_paths.begin(), level_paths.end());

	std::filesystem::path lua_path = FLAGS_lua;
	toolLog->info("Lua path: {}", lua_path);

	std::ofstream stream(lua_path);
	stream << "local levels = {" << std::endl;

	tson::Tileson tileson;
	for (const std::filesystem::path& path : level_paths) {
		toolLog->info("Parsing level {}", path);

		std::unique_ptr<tson::Map> map = tileson.parse(path);
		if (map->getStatus() != tson::ParseStatus::OK) {
			toolLog->error("Failed to parse file {}, reason {}", path, map->getStatusMessage());
			continue;
		}

		stream << "{ ";
		for (const tson::Layer& layer : map->getLayers()) {
			if (layer.getType() == tson::LayerType::TileLayer) {
				for (const auto& cell : layer.getTileData()) {
					stream << fmt::format("{{ {}, {}, {} }}, ", std::get<0>(cell.first), std::get<1>(cell.first), cell.second->getGid());
				}
			}
		}

		stream << " }," << std::endl;
	}

	stream << "}" << std::endl;

	return 0;
}
