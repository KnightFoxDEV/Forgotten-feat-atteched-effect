-- ============================================================
-- WEAPON ENCHANT - Dano Elemental da Arma
-- Arquivo: data/scripts/customs/weapon_enchant/weapon_enchant_element_damage.lua
-- Aplica dano elemental FIXO + efeito visual ao acertar o alvo.
--
-- Elementos:
-- Katon  = Fire   (COMBAT_FIREDAMAGE,   CONST_ME_HITBYFIRE)
-- Suiton = Water  (COMBAT_ICEDAMAGE,    CONST_ME_WATERSPLASH)
-- Raiton = Energy (COMBAT_ENERGYDAMAGE, CONST_ME_ENERGYHIT)
-- Poison = Earth  (COMBAT_EARTHDAMAGE,  CONST_ME_HITBYPOISON)
-- ============================================================

local ELEMENT_CONFIG = {
    fire   = { combat = COMBAT_FIREDAMAGE,   effect = CONST_ME_HITBYFIRE },
    ice    = { combat = COMBAT_ICEDAMAGE,    effect = CONST_ME_WATERSPLASH },
    energy = { combat = COMBAT_ENERGYDAMAGE, effect = CONST_ME_ENERGYHIT },
    poison = { combat = COMBAT_EARTHDAMAGE,  effect = CONST_ME_HITBYPOISON },
}

local creatureEvent = CreatureEvent("WeaponEnchantElementalDamage")

function creatureEvent.onHealthChange(target, source, primaryDamage, primaryType, secondaryDamage, secondaryType, origin)
    -- Apenas ataques originados de jogadores (melee, ranged ou wand)
    if not source or not source:isPlayer() then
        return primaryDamage, primaryType, secondaryDamage, secondaryType
    end

    if origin ~= ORIGIN_MELEE and origin ~= ORIGIN_RANGED and origin ~= ORIGIN_WAND then
        return primaryDamage, primaryType, secondaryDamage, secondaryType
    end

    -- Procura nos dois slots de mao (Right = 5, Left = 6) pelo item com elemento
    local weapon = nil
    local elemType = ""
    local elemValue = 0

    for _, slot in ipairs({ CONST_SLOT_LEFT, CONST_SLOT_RIGHT }) do
        local item = source:getSlotItem(slot)
        if item then
            local t = item:getCustomAttribute("weapon_element_type")
            local v = tonumber(item:getCustomAttribute("weapon_element_value")) or 0
            if t and t ~= "" and v > 0 then
                weapon = item
                elemType = tostring(t):lower()
                elemValue = v
                break
            end
        end
    end

    if not weapon or elemValue <= 0 then
        return primaryDamage, primaryType, secondaryDamage, secondaryType
    end

    local cfg = ELEMENT_CONFIG[elemType]
    if not cfg then
        return primaryDamage, primaryType, secondaryDamage, secondaryType
    end

    local targetCombatType = cfg.combat
    if not targetCombatType or targetCombatType == COMBAT_NONE then
        return primaryDamage, primaryType, secondaryDamage, secondaryType
    end

    -- Dano elemental FIXO = elemValue
    if secondaryDamage == 0 or secondaryType == COMBAT_NONE then
        secondaryType = targetCombatType
        secondaryDamage = elemValue
    elseif secondaryType == targetCombatType then
        secondaryDamage = secondaryDamage + elemValue
    else
        primaryDamage = primaryDamage + elemValue
    end

    -- Efeito visual do elemento no alvo
    if cfg.effect and target then
        target:getPosition():sendMagicEffect(cfg.effect)
    end

    return primaryDamage, primaryType, secondaryDamage, secondaryType
end

creatureEvent:type("healthchange")
creatureEvent:register()

-- Registra em todos os jogadores online
for _, player in ipairs(Game.getPlayers()) do
    player:registerEvent("WeaponEnchantElementalDamage")
end

print(">> Weapon Enchant Elemental Damage v2 Loaded (Katon, Suiton, Raiton, Poison)")