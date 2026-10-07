#include "otpch.h"

#include "attached_effects.h"

#include "logger.h"
#include "pugicast.h"
#include "tools.h"

#include <fmt/format.h>
#include <algorithm>
#include <cctype>
#include <limits>

bool AttachedEffects::loadFile(const char* path, const char* root, std::map<uint16_t, AttachedEffectInfo>& destination)
{
	pugi::xml_document doc;
	const auto result = doc.load_file(path);
	if (!result) {
		printXMLError("AttachedEffects::loadFile", path, result);
		return false;
	}

	const auto rootNode = doc.child(root);
	if (!rootNode) {
		LOG_ERROR(fmt::format("[AttachedEffects] Missing <{}> root in {}", root, path));
		return false;
	}

	std::map<uint16_t, AttachedEffectInfo> loaded;
	for (const auto node : rootNode.children()) {
		if (std::string_view(node.name()).empty()) {
			continue;
		}
		const uint32_t rawId = node.attribute("id").as_uint();
		const std::string name = node.attribute("name").as_string();
		if (rawId == 0 || rawId > std::numeric_limits<uint16_t>::max() || name.empty()) {
			LOG_WARN(fmt::format("[AttachedEffects] Ignoring invalid entry in {} (id={}, name='{}')", path, rawId, name));
			continue;
		}
		const auto id = static_cast<uint16_t>(rawId);
		if (!loaded.emplace(id, AttachedEffectInfo{id, name, static_cast<uint16_t>(node.attribute("speed").as_uint()),
		                                                   node.attribute("premium").as_bool()}).second) {
			LOG_WARN(fmt::format("[AttachedEffects] Duplicate id {} in {}", id, path));
		}
	}
	destination = std::move(loaded);
	return true;
}

bool AttachedEffects::loadFromXml()
{
	std::map<uint16_t, AttachedEffectInfo> loadedWings;
	std::map<uint16_t, AttachedEffectInfo> loadedAuras;
	std::map<uint16_t, AttachedEffectInfo> loadedEffects;
	std::map<uint16_t, AttachedEffectInfo> loadedShaders;
	if (!loadFile("data/XML/wings.xml", "wings", loadedWings) ||
	    !loadFile("data/XML/auras.xml", "auras", loadedAuras) ||
	    !loadFile("data/XML/effects.xml", "effects", loadedEffects) ||
	    !loadFile("data/XML/shaders.xml", "shaders", loadedShaders)) {
		return false;
	}

	wings = std::move(loadedWings);
	auras = std::move(loadedAuras);
	effects = std::move(loadedEffects);
	shaders = std::move(loadedShaders);
	return true;
}

bool AttachedEffects::reload()
{
	return loadFromXml();
}

const AttachedEffectInfo* AttachedEffects::getWing(uint16_t id) const
{
	const auto it = wings.find(id);
	return it == wings.end() ? nullptr : &it->second;
}

const AttachedEffectInfo* AttachedEffects::getAura(uint16_t id) const
{
	const auto it = auras.find(id);
	return it == auras.end() ? nullptr : &it->second;
}

const AttachedEffectInfo* AttachedEffects::getEffect(uint16_t id) const
{
	const auto it = effects.find(id);
	return it == effects.end() ? nullptr : &it->second;
}

const AttachedEffectInfo* AttachedEffects::getShader(uint16_t id) const
{
	const auto it = shaders.find(id);
	return it == shaders.end() ? nullptr : &it->second;
}

const AttachedEffectInfo* AttachedEffects::getShaderByName(std::string_view name) const
{
	for (const auto& entry : shaders) {
		const std::string& shaderName = entry.second.name;
		if (shaderName.size() == name.size() &&
		    std::equal(shaderName.begin(), shaderName.end(), name.begin(), [](unsigned char left, unsigned char right) {
			    return std::tolower(left) == std::tolower(right);
		    })) {
			return &entry.second;
		}
	}
	return nullptr;
}
