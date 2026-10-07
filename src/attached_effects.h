// Copyright 2026 The Forgotten Server Authors. All rights reserved.
// Use of this source code is governed by the GPL-2.0 License that can be found in the LICENSE file.

#ifndef FS_ATTACHED_EFFECTS_H
#define FS_ATTACHED_EFFECTS_H

#include <map>
#include <string>
#include <string_view>
#include <cstdint>

struct AttachedEffectInfo {
	uint16_t id = 0;
	std::string name;
	uint16_t speed = 0;
	bool premium = false;
};

class AttachedEffects {
public:
	bool loadFromXml();
	bool reload();
	const std::map<uint16_t, AttachedEffectInfo>& getWings() const { return wings; }
	const std::map<uint16_t, AttachedEffectInfo>& getAuras() const { return auras; }
	const std::map<uint16_t, AttachedEffectInfo>& getEffects() const { return effects; }
	const std::map<uint16_t, AttachedEffectInfo>& getShaders() const { return shaders; }
	const AttachedEffectInfo* getWing(uint16_t id) const;
	const AttachedEffectInfo* getAura(uint16_t id) const;
	const AttachedEffectInfo* getEffect(uint16_t id) const;
	const AttachedEffectInfo* getShader(uint16_t id) const;
	const AttachedEffectInfo* getShaderByName(std::string_view name) const;

private:
	bool loadFile(const char* path, const char* root, std::map<uint16_t, AttachedEffectInfo>& destination);
	std::map<uint16_t, AttachedEffectInfo> wings;
	std::map<uint16_t, AttachedEffectInfo> auras;
	std::map<uint16_t, AttachedEffectInfo> effects;
	std::map<uint16_t, AttachedEffectInfo> shaders;
};

#endif
