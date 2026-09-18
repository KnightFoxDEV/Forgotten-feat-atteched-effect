-- ============================================================
-- WEAPON ENCHANT - EQUIP / DEEQUIP EVENT HANDLER
-- Aplica/remove conditions de enchant ao equipar/desequipar arma
-- Suporta: Ground, Backpack, Trade, Slots Left (6) e Right (5)
-- ============================================================

local function isEnchantableWeapon(item)
    if not item then return false end
    local it = item:getType()
    if not it then return false end
    local wt = it:getWeaponType()
    return wt == WEAPON_SWORD
        or wt == WEAPON_CLUB
        or wt == WEAPON_AXE
        or wt == WEAPON_DISTANCE
        or wt == WEAPON_WAND
end

-- Re-sincroniza os enchants baseado no que esta atualmente nas maos
function syncWeaponEnchants(player)
    if not player then return end

    local activeWeapon = nil
    for _, slot in ipairs({ CONST_SLOT_LEFT, CONST_SLOT_RIGHT }) do
        local eq = player:getSlotItem(slot)
        if eq and isEnchantableWeapon(eq) then
            activeWeapon = eq
            break
        end
    end

    if activeWeapon then
        if applyWeaponEnchants then
            applyWeaponEnchants(player, activeWeapon)
        end
    else
        if removeWeaponEnchants then
            removeWeaponEnchants(player)
        end
    end
end

-- ============================================================
-- 1. onUpdateInventory: Disparado pelo motor ao equipar/desequipar
-- Usa addEvent para garantir que a mudanca de slot foi concluida no C++
-- ============================================================
local ecInventory = Event()

function ecInventory.onUpdateInventory(player, item, slot, equip)
    if not player then return end

    if slot == CONST_SLOT_LEFT or slot == CONST_SLOT_RIGHT then
        local playerId = player:getId()
        addEvent(function()
            local p = Player(playerId)
            if p then
                syncWeaponEnchants(p)
            end
        end, 50)
    end
end

ecInventory:register(9)

-- ============================================================
-- 2. onMoveItem: Fallback em tempo real pos-movimentacao
-- Garante ativacao imediata ao puxar do chao para a mao ou vice-versa
-- ============================================================
local ecMove = Event()

function ecMove.onMoveItem(player, item, count, fromPosition, toPosition, fromCylinder, toCylinder)
    if not player or not item then return RETURNVALUE_NOERROR end

    local isFromHand = (fromPosition.x == CONTAINER_POSITION and (fromPosition.y == CONST_SLOT_LEFT or fromPosition.y == CONST_SLOT_RIGHT))
    local isToHand   = (toPosition.x == CONTAINER_POSITION and (toPosition.y == CONST_SLOT_LEFT or toPosition.y == CONST_SLOT_RIGHT))

    if isFromHand or isToHand then
        local playerId = player:getId()
        addEvent(function()
            local p = Player(playerId)
            if p then
                syncWeaponEnchants(p)
            end
        end, 70)
    end

    return RETURNVALUE_NOERROR
end

ecMove:register(9)

print(">> Weapon Enchant Equip Handler Loaded (Sync on Equip/Deequip/Ground)")