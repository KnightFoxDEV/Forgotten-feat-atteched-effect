-- ============================================================
-- WEAPON ENCHANT SYSTEM — SERVER SIDE (Mochila / Backpack)
-- ExtendedOpcode: 108
-- Arquivo: data/scripts/customs/weapon_enchant/weapon_enchant.lua
-- ============================================================

local OPCODE = 108

local config = {
    -- Slots de arma equipada nas mãos (Left = 6, Right = 5)
    weaponSlots = { CONST_SLOT_LEFT, CONST_SLOT_RIGHT },

    -- Custo em gold por 1 nível de cada atributo
    costPerLevel = {
        critChance = 50000,
        critAmount = 75000,
        lifeChance = 60000,
        lifeAmount = 60000,
    },

    -- Limites máximos de cada atributo
    limits = {
        critChance = 30,   -- 30% máximo de chance de crítico
        critAmount = 100,  -- 100% de dano crítico adicional
        lifeChance = 100,   -- 100% chance de life leech
        lifeAmount = 15,   -- 15% quantidade de life leech
    },

    -- Chaves compatíveis com o motor do servidor (look e combate)
    attrKeys = {
        critChance = "critical hit chance",
        critAmount = "critical hit damage",
        lifeChance = "life leech chance",
        lifeAmount = "life leech amount",
    },

    -- Chaves legadas (para migração transparente de armas já encantadas)
    legacyKeys = {
        critChance = "enchant_critChance",
        critAmount = "enchant_critAmount",
        lifeChance = "enchant_lifeChance",
        lifeAmount = "enchant_lifeAmount",
    },

    -- ConditionParam correspondentes para cada atributo
    condParams = {
        critChance = CONDITION_PARAM_SPECIALSKILL_CRITICALHITCHANCE,
        critAmount = CONDITION_PARAM_SPECIALSKILL_CRITICALHITAMOUNT,
        lifeChance = CONDITION_PARAM_SPECIALSKILL_LIFELEECHCHANCE,
        lifeAmount = CONDITION_PARAM_SPECIALSKILL_LIFELEECHAMOUNT,
    },

    -- SubId das conditions de enchant (únicos, não conflitam com rarity 1000-1020)
    condSubIds = {
        critChance = 2000,
        critAmount = 2001,
        lifeChance = 2002,
        lifeAmount = 2003,
    },

    -- Tipos de arma permitidos
    allowedWeaponTypes = {
        WEAPON_SWORD, WEAPON_CLUB, WEAPON_AXE,
        WEAPON_DISTANCE, WEAPON_WAND
    },

    -- Custo da transferência de enchants entre armas
    transferCost = 2000000,

    -- Itens consumíveis necessários para cada tentativa de enchant (+1)
    requiredItems = {
        critChance = { itemId = 3026, name = "Chance Critico Card" },
        critAmount = { itemId = 3032, name = "Dano Critico Card" },
        lifeChance = { itemId = 3030, name = "Chance Roubo De Vida Card" },
        lifeAmount = { itemId = 3029, name = "Roubo De Vida Card" },
    },

    -- Nomes de exibição dos atributos
    attrNames = {
        critChance = "Chance de Critico",
        critAmount = "Dano Critico",
        lifeChance = "Chance de Roubo de Vida",
        lifeAmount = "Roubo de Vida",
    },

    -- ============================================================
    -- Elemento da Arma (Fire / Ice / Energy / Poison)
    -- ============================================================
    elementConfig = {
        max    = 50,
        chance = 10,     -- 10% fixo de sucesso por tentativa
        cost   = 100000, -- gold por tentativa
        typeKey  = "weapon_element_type",   -- "fire"|"ice"|"energy"|"poison"
        valueKey = "weapon_element_value",  -- valor 1..50
        elements = {
            fire   = { name = "Katon",  itemId = 3028 },
            ice    = { name = "Suiton", itemId = 3027 },
            energy = { name = "Raiton", itemId = 3026 },
            poison = { name = "Poison", itemId = 3034 },
        },
    },

    -- ============================================================
    -- Catalisador de Sorte (Small Ruby: +30% de chance)
    -- ============================================================
    catalyst = {
        itemId      = 3023, -- Small Ruby
        name        = "Small Ruby",
        bonusChance = 30,   -- +30% de chance de sucesso
    },

    -- ============================================================
    -- Refinamento de Arma (+1 a +10, +1 Atk por nível)
    -- ============================================================
    refineConfig = {
        max          = 10,
        itemId       = 3042, -- Refinement Stone (configurável)
        name         = "Refinement Stone",
        cost         = 100000, -- 100k fixo por tentativa de refinamento
        chances      = { 40, 35, 30, 20, 15, 10, 10, 5, 5, 5 },
        key          = "weapon_refine_level",
    },
}

-- ============================================================
-- FUNÇÕES AUXILIARES DE ARMAS E ENCHANTS
-- ============================================================

-- Retorna true se o item é uma arma válida para encantar
local function isValidWeapon(item)
    if not item then return false end
    if #config.allowedWeaponTypes == 0 then return true end
    local weaponType = item:getType():getWeaponType()
    for _, wt in ipairs(config.allowedWeaponTypes) do
        if weaponType == wt then return true end
    end
    return false
end

-- Lê o valor de um enchant salvo no item (com migração de chaves legadas)
local function getEnchantValue(item, attr)
    if not item then return 0 end
    local key = config.attrKeys[attr]
    local oldKey = config.legacyKeys[attr]
    local val = (key and item:getCustomAttribute(key)) or (oldKey and item:getCustomAttribute(oldKey))
    return (val and tonumber(val)) or 0
end

-- Retorna a chance percentual de sucesso para a próxima tentativa de enchant (+1)
local function getEnchantSuccessChance(attr, currentVal)
    currentVal = currentVal or 0
    if attr == "critChance" or attr == "lifeAmount" then
        if currentVal < 5 then
            return 15
        elseif currentVal < 10 then
            return 10
        else
            return 5
        end
    elseif attr == "critAmount" or attr == "lifeChance" then
        return 20
    end
    return 100
end

-- Retorna as informações da arma para o cliente
local function getWeaponInfo(item)
    if not item then
        return { clientId = 0, name = "", weaponType = "" }
    end
    local it = item:getType()
    local wt = it:getWeaponType()
    local wtName = ""
    if wt == WEAPON_SWORD then wtName = "Sword"
    elseif wt == WEAPON_CLUB then wtName = "Club"
    elseif wt == WEAPON_AXE then wtName = "Axe"
    elseif wt == WEAPON_DISTANCE then wtName = "Distance"
    elseif wt == WEAPON_WAND then wtName = "Wand"
    else wtName = "Weapon" end
    return {
        clientId   = item:getId(),
        name       = item:getName(),
        weaponType = wtName,
    }
end

-- Busca todas as armas na mochila do jogador em ordem determinística
local function getBackpackWeapons(player)
    local weapons = {}
    if not player then return weapons end

    local backpack = player:getSlotItem(CONST_SLOT_BACKPACK)
    if backpack and backpack:isContainer() then
        local items = backpack:getItems(true)
        local idx = 0
        for _, it in ipairs(items) do
            if isValidWeapon(it) then
                idx = idx + 1
                -- Auto-migração para chaves padrão caso tenha sido encantado com a chave antiga
                for attr, standardKey in pairs(config.attrKeys) do
                    local curVal = getEnchantValue(it, attr)
                    if curVal > 0 and not it:getCustomAttribute(standardKey) then
                        it:setCustomAttribute(standardKey, curVal)
                    end
                end
                table.insert(weapons, { item = it, index = idx })
            end
        end
    end
    return weapons
end

-- Encontra uma arma na mochila pelo índice (1, 2, 3...)
local function findBackpackWeaponByIndex(player, index)
    if not player or not index then return nil end
    local idx = tonumber(index)
    if not idx or idx < 1 then return nil end
    local weapons = getBackpackWeapons(player)
    if weapons[idx] then
        return weapons[idx].item
    end
    return nil
end

-- ============================================================
-- CONDITIONS DE ENCHANT (APLICADAS QUANDO A ARMA É EQUIPADA)
-- ============================================================

local function removeAllLegacyConditions(player)
    if not player then return end
    for _, subId in pairs(config.condSubIds) do
        player:removeCondition(CONDITION_ATTRIBUTES, CONDITIONID_DEFAULT, subId, true)
    end
end

-- Reaplica enchants se alguma arma valida estiver equipada nas maos
function refreshEquippedEnchants(player)
    if not player then return end
    if syncWeaponEnchants then
        syncWeaponEnchants(player)
    else
        for _, slot in ipairs(config.weaponSlots) do
            local eq = player:getSlotItem(slot)
            if eq and isValidWeapon(eq) then
                applyWeaponEnchants(player, eq)
                return
            end
        end
        removeWeaponEnchants(player)
    end
end

-- Aplica todos os enchants salvos em um item ao jogador (chamado ao equipar)
function applyWeaponEnchants(player, item)
    if not player then return end
    removeAllLegacyConditions(player)
    if not item then return end

    for attr, param in pairs(config.condParams) do
        local val = getEnchantValue(item, attr)
        if val > 0 then
            local cond = Condition(CONDITION_ATTRIBUTES, CONDITIONID_DEFAULT)
            cond:setParameter(CONDITION_PARAM_SUBID, config.condSubIds[attr])
            cond:setParameter(CONDITION_PARAM_TICKS, -1)
            -- No TFS 1.x / 8.60 (combat.cpp), specialSkills usam basis points (1% = 100, 100% = 10000)
            cond:setParameter(param, val * 100)
            player:addCondition(cond)
        end
    end
end

-- Remove todos os enchants ativos (chamado ao desequipar)
function removeWeaponEnchants(player)
    if not player then return end
    removeAllLegacyConditions(player)
end

-- ============================================================
-- ENVIO DE DADOS PARA O CLIENTE
-- ============================================================

local function sendUpdate(player, selectedIndex, msg)
    if not player then return end

    local bpWeapons = getBackpackWeapons(player)
    local weaponsData = {}
    local selectedWeaponData = nil
    local selIdx = tonumber(selectedIndex) or 1

    for idx, entry in ipairs(bpWeapons) do
        local it = entry.item
        local info = getWeaponInfo(it)
        local enchants = {}
        for attr, _ in pairs(config.attrKeys) do
            enchants[attr] = getEnchantValue(it, attr)
        end
        local elementType  = it:getCustomAttribute(config.elementConfig.typeKey)  or ""
        local elementValue = tonumber(it:getCustomAttribute(config.elementConfig.valueKey)) or 0
        local refineLevel  = tonumber(it:getCustomAttribute(config.refineConfig.key)) or 0
        local currentAtk   = it:getAttribute(ITEM_ATTRIBUTE_ATTACK) or it:getType():getAttack()
        local baseAtk      = it:getType():getAttack()

        -- A lista atual vem da mochila; manter a propriedade no registro evita
        -- depender de uma variável global inexistente e permite suporte futuro
        -- a armas equipadas sem alterar o payload.
        local isEquipped = (entry.equipped == true)
        local displayName = isEquipped and ("[Equipada] " .. info.name) or info.name
        local wData = {
            index        = idx,
            clientId     = info.clientId,
            name         = displayName,
            weaponType   = info.weaponType,
            enchants     = enchants,
            elementType  = elementType,
            elementValue = elementValue,
            refineLevel  = refineLevel,
            currentAtk   = currentAtk,
            baseAtk      = baseAtk,
            equipped     = isEquipped,
        }
        table.insert(weaponsData, wData)

        if idx == selIdx then
            selectedWeaponData = wData
        end
    end

    if not selectedWeaponData and #weaponsData > 0 then
        selectedWeaponData = weaponsData[1]
        selIdx = 1
    end

    local balance = player:getMoney() + player:getBankBalance()

    local reqItemsData = {}
    for attr, req in pairs(config.requiredItems) do
        local count = (req.itemId and player:getItemCount(req.itemId)) or 0
        local itType = req.itemId and ItemType(req.itemId)
        local itName = req.name or (itType and itType:getName()) or ""
        local itClientId = req.itemId or 0
        reqItemsData[attr] = {
            itemId   = req.itemId,
            clientId = itClientId,
            name     = itName,
            count    = count,
        }
    end

    local elementItemsData = {}
    for elemKey, elem in pairs(config.elementConfig.elements) do
        local count = elem.itemId and player:getItemCount(elem.itemId) or 0
        local itType = elem.itemId and ItemType(elem.itemId)
        local itClientId = elem.itemId or 0
        elementItemsData[elemKey] = {
            itemId   = elem.itemId,
            clientId = itClientId,
            name     = elem.name,
            count    = count,
        }
    end

    local catalystCount = player:getItemCount(config.catalyst.itemId)
    local itTypeCat = ItemType(config.catalyst.itemId)
    local catalystClientId = config.catalyst.itemId
    local catalystData = {
        itemId   = config.catalyst.itemId,
        clientId = catalystClientId,
        name     = config.catalyst.name,
        bonus    = config.catalyst.bonusChance,
        count    = catalystCount,
    }

    local refineCount = player:getItemCount(config.refineConfig.itemId)
    local itTypeRef = ItemType(config.refineConfig.itemId)
    local refineClientId = config.refineConfig.itemId
    local refineData = {
        max          = config.refineConfig.max,
        itemId       = config.refineConfig.itemId,
        clientId     = refineClientId,
        name         = config.refineConfig.name,
        cost         = config.refineConfig.cost,
        chances      = config.refineConfig.chances,
        count        = refineCount,
    }

    local payload = {
        action           = "update",
        weapons          = weaponsData,
        selectedIndex    = selIdx,
        selected         = selectedWeaponData,
        costPerLevel     = config.costPerLevel,
        requiredItems    = reqItemsData,
        elementItemsData = elementItemsData,
        elementConfig    = { max = config.elementConfig.max, chance = config.elementConfig.chance, cost = config.elementConfig.cost },
        catalyst         = catalystData,
        refine           = refineData,
        balance          = balance,
        msg              = msg,
    }
    player:sendExtendedOpcode(OPCODE, json.encode(payload))
end

local function sendError(player, msg)
    player:sendExtendedOpcode(OPCODE, json.encode({ action = "error", msg = msg }))
end

local function sendSuccess(player, msg)
    player:sendExtendedOpcode(OPCODE, json.encode({ action = "success", msg = msg }))
end

-- ============================================================
-- HANDLER PRINCIPAL DO EXTENDED OPCODE
-- ============================================================

local enchantEvent = CreatureEvent("WeaponEnchantExtended")

function enchantEvent.onExtendedOpcode(player, opcode, buffer)
    if opcode ~= OPCODE then return end

    local ok, data = pcall(function() return json.decode(buffer) end)
    if not ok or not data then return end

    local action = data.action

    -- ---- OPEN / FETCH: jogador abre a janela ou atualiza lista ----
    if action == "open" or action == "fetch" then
        local requestedIndex = data.data and (data.data.index or data.data.selectedIndex)
        sendUpdate(player, requestedIndex)
        return
    end

    -- ---- SELECT: jogador selecionou uma arma da lista ----
    if action == "select" then
        local idx = data.data and (data.data.index or data.data.selectedIndex)
        sendUpdate(player, idx)
        return
    end

    -- ---- ENCHANT: adiciona (+1) ou remove (-1) enchant da arma na mochila ----
    if action == "enchant" then
        local payload = data.data
        if not payload then
            sendError(player, "Dados invalidos.")
            return
        end

        local idx   = tonumber(payload.index or payload.selectedIndex)
        local attr  = tostring(payload.attr or "")
        local delta = tonumber(payload.delta or 0)

        if not config.attrKeys[attr] then
            sendError(player, "Atributo desconhecido.")
            return
        end

        local weapon = findBackpackWeaponByIndex(player, idx)
        if not weapon then
            sendError(player, "Arma nao encontrada na mao ou mochila!")
            return
        end

        local currentVal = getEnchantValue(weapon, attr)
        local maxVal     = config.limits[attr]
        local cost       = config.costPerLevel[attr]
        local key        = config.attrKeys[attr]
        local oldKey     = config.legacyKeys[attr]

        if delta > 0 then
            if currentVal >= maxVal then
                sendError(player, "Atributo ja esta no maximo (" .. maxVal .. "%)!")
                return
            end

            -- Verifica se o jogador tem o item específico necessário
            local req = config.requiredItems[attr]
            local reqItemId = req and req.itemId
            local reqItemName = (req and req.name) or (reqItemId and ItemType(reqItemId):getName()) or "item especifico"

            if reqItemId and reqItemId > 0 then
                if player:getItemCount(reqItemId) < 1 then
                    sendError(player, "Voce precisa de 1x " .. reqItemName .. " para tentar encantar!")
                    return
                end
            end

            local balance = player:getMoney() + player:getBankBalance()
            if balance < cost then
                sendError(player, "Gold insuficiente! Necessario: " .. cost .. " gold.")
                return
            end

            -- Debita o gold
            if not player:removeTotalMoney(cost) then
                sendError(player, "Falha ao debitar o gold.")
                return
            end

            -- Consome 1x do item específico
            if reqItemId and reqItemId > 0 then
                if not player:removeItem(reqItemId, 1) then
                    player:setBankBalance(player:getBankBalance() + cost)
                    sendError(player, "Falha ao consumir o item " .. reqItemName .. ".")
                    return
                end
            end

            -- Consome catalisador (Small Ruby) se solicitado
            local useCatalyst = (payload.useCatalyst == true or payload.catalyst == true)
            local catalystBonus = 0
            if useCatalyst then
                if player:getItemCount(config.catalyst.itemId) < 1 then
                    sendError(player, "Voce precisa de 1x " .. config.catalyst.name .. " para usar como catalisador!")
                    return
                end
                if not player:removeItem(config.catalyst.itemId, 1) then
                    sendError(player, "Falha ao consumir " .. config.catalyst.name .. ".")
                    return
                end
                catalystBonus = config.catalyst.bonusChance
            end

            -- Rola a chance de sucesso
            local baseChance = getEnchantSuccessChance(attr, currentVal)
            local chance = math.min(100, baseChance + catalystBonus)
            local roll = math.random(1, 100)
            local attrName = config.attrNames[attr] or attr
            local catMsg = useCatalyst and (" [+" .. catalystBonus .. "% Ruby]") or ""

            if roll <= chance then
                local newVal = currentVal + 1
                weapon:setCustomAttribute(key, newVal)
                weapon:setCustomAttribute(oldKey, newVal)
                player:getPosition():sendMagicEffect(CONST_ME_MAGIC_BLUE)
                sendSuccess(player, "Sucesso (" .. chance .. "%" .. catMsg .. ")! " .. attrName .. " aumentado para " .. newVal .. "%!")
            else
                player:getPosition():sendMagicEffect(CONST_ME_POFF)
                local failItemMsg = useCatalyst and ("1x " .. reqItemName .. ", 1x " .. config.catalyst.name) or ("1x " .. reqItemName)
                sendError(player, "A tentativa falhou (" .. chance .. "% de chance)! " .. failItemMsg .. " e " .. cost .. " gold consumidos.")
            end
        else
            sendError(player, "Operacao invalida.")
            return
        end

        -- Se o item estiver equipado na mao, reaplica os bonus no jogador imediatamente
        refreshEquippedEnchants(player)

        sendUpdate(player, idx)
        return
    end

    -- ---- RESET: remove todos os enchants da arma selecionada ----
    if action == "reset" then
        local idx = data.data and (data.data.index or data.data.selectedIndex)
        local weapon = findBackpackWeaponByIndex(player, idx)
        if not weapon then
            sendError(player, "Arma nao encontrada na mao ou mochila!")
            return
        end

        local removed = false
        for attr, key in pairs(config.attrKeys) do
            local val = getEnchantValue(weapon, attr)
            if val > 0 then
                weapon:removeCustomAttribute(key)
                local oldKey = config.legacyKeys[attr]
                if oldKey then weapon:removeCustomAttribute(oldKey) end
                removed = true
            end
        end

        -- Limpa elemento da arma
        local elemType = weapon:getCustomAttribute(config.elementConfig.typeKey) or ""
        if elemType ~= "" then
            weapon:removeCustomAttribute(config.elementConfig.typeKey)
            weapon:removeCustomAttribute(config.elementConfig.valueKey)
            removed = true
        end

        -- Limpa refinamento da arma e restaura ataque original
        local refineLevel = tonumber(weapon:getCustomAttribute(config.refineConfig.key)) or 0
        if refineLevel > 0 then
            weapon:removeCustomAttribute(config.refineConfig.key)
            weapon:removeAttribute(ITEM_ATTRIBUTE_ATTACK)
            removed = true
        end

        if removed then
            player:getPosition():sendMagicEffect(CONST_ME_POFF)
            sendSuccess(player, "Todos os enchants foram resetados da arma!")
            -- Se estava equipada, remove os bonus
            refreshEquippedEnchants(player)
        else
            sendError(player, "Esta arma nao possui enchants.")
        end

        sendUpdate(player, idx)
        return
    end

    -- ---- TRANSFER: move os enchants de uma arma para outra sem enchants ----
    if action == "transfer" then
        local payload = data.data
        if not payload then
            sendError(player, "Dados invalidos.")
            return
        end

        local srcIdx = tonumber(payload.sourceIndex)
        local dstIdx = tonumber(payload.targetIndex)

        if not srcIdx or not dstIdx or srcIdx == dstIdx then
            sendError(player, "Indice de arma invalido.")
            return
        end

        local source = findBackpackWeaponByIndex(player, srcIdx)
        if not source then
            sendError(player, "Arma de origem nao encontrada na mochila!")
            return
        end

        local target = findBackpackWeaponByIndex(player, dstIdx)
        if not target then
            sendError(player, "Arma de destino nao encontrada na mochila!")
            return
        end

        -- Verifica se a origem tem pelo menos 1 enchant, elemento ou refinamento
        local hasEnchant = false
        for attr, _ in pairs(config.attrKeys) do
            if getEnchantValue(source, attr) > 0 then
                hasEnchant = true
                break
            end
        end
        local srcRefine = tonumber(source:getCustomAttribute(config.refineConfig.key)) or 0
        local srcElem   = source:getCustomAttribute(config.elementConfig.typeKey) or ""
        if srcRefine > 0 or srcElem ~= "" then
            hasEnchant = true
        end

        if not hasEnchant then
            sendError(player, "A arma de origem nao possui enchants para transferir!")
            return
        end

        -- Verifica se o destino está limpo (sem nenhum enchant, sem elemento e sem refinamento)
        for attr, _ in pairs(config.attrKeys) do
            if getEnchantValue(target, attr) > 0 then
                sendError(player, "A arma de destino ja possui enchants! Ela deve estar limpa.")
                return
            end
        end
        local targetElem = target:getCustomAttribute(config.elementConfig.typeKey) or ""
        if targetElem ~= "" then
            sendError(player, "A arma de destino ja possui um elemento! Ela deve estar limpa.")
            return
        end
        local targetRefine = tonumber(target:getCustomAttribute(config.refineConfig.key)) or 0
        if targetRefine > 0 then
            sendError(player, "A arma de destino ja possui refinamento! Ela deve estar limpa.")
            return
        end

        -- Verifica gold
        local balance = player:getMoney() + player:getBankBalance()
        if balance < config.transferCost then
            sendError(player, "Gold insuficiente! Necessario: " .. config.transferCost .. " gold.")
            return
        end
        if not player:removeTotalMoney(config.transferCost) then
            sendError(player, "Falha ao debitar o gold.")
            return
        end

        -- Executa a transferencia de enchants
        for attr, key in pairs(config.attrKeys) do
            local val = getEnchantValue(source, attr)
            local oldKey = config.legacyKeys[attr]
            if val > 0 then
                target:setCustomAttribute(key, val)
                if oldKey then target:setCustomAttribute(oldKey, val) end
                source:removeCustomAttribute(key)
                if oldKey then source:removeCustomAttribute(oldKey) end
            end
        end

        -- Transfere elemento da arma
        local srcElemType  = source:getCustomAttribute(config.elementConfig.typeKey)  or ""
        local srcElemValue = tonumber(source:getCustomAttribute(config.elementConfig.valueKey)) or 0
        if srcElemType ~= "" and srcElemValue > 0 then
            target:setCustomAttribute(config.elementConfig.typeKey,  srcElemType)
            target:setCustomAttribute(config.elementConfig.valueKey, srcElemValue)
            source:removeCustomAttribute(config.elementConfig.typeKey)
            source:removeCustomAttribute(config.elementConfig.valueKey)
        end

        -- Transfere refinamento da arma
        if srcRefine > 0 then
            target:setCustomAttribute(config.refineConfig.key, srcRefine)
            local baseAtk = target:getType():getAttack()
            target:setAttribute(ITEM_ATTRIBUTE_ATTACK, baseAtk + srcRefine)
            source:removeCustomAttribute(config.refineConfig.key)
            source:removeAttribute(ITEM_ATTRIBUTE_ATTACK)
        end

        -- Reaplica bonus caso alguma arma esteja equipada na mao
        refreshEquippedEnchants(player)

        player:getPosition():sendMagicEffect(CONST_ME_MAGIC_BLUE)
        sendSuccess(player, "Enchants transferidos com sucesso!")
        sendUpdate(player, dstIdx)
        return
    end

    -- ---- ENCHANT_ELEMENT: adiciona elemento (fire/ice/energy/poison) à arma ----
    if action == "enchant_element" then
        local payload = data.data
        if not payload then
            sendError(player, "Dados invalidos.")
            return
        end

        local idx     = tonumber(payload.index)
        local element = tostring(payload.element or ""):lower()

        local elemCfg = config.elementConfig.elements[element]
        if not elemCfg then
            sendError(player, "Elemento desconhecido: " .. element)
            return
        end

        local weapon = findBackpackWeaponByIndex(player, idx)
        if not weapon then
            sendError(player, "Arma nao encontrada na mochila!")
            return
        end

        -- Verifica se ja tem um elemento DIFERENTE
        local currentElemType  = weapon:getCustomAttribute(config.elementConfig.typeKey)  or ""
        local currentElemValue = tonumber(weapon:getCustomAttribute(config.elementConfig.valueKey)) or 0

        if currentElemType ~= "" and currentElemType ~= element then
            local displayCurrent = currentElemType:sub(1,1):upper() .. currentElemType:sub(2)
            sendError(player, "Esta arma ja tem o elemento " .. displayCurrent .. "! Resete para trocar.")
            return
        end

        if currentElemValue >= config.elementConfig.max then
            sendError(player, "Elemento ja esta no maximo +" .. config.elementConfig.max .. "!")
            return
        end

        -- Verifica item consumivel
        local reqItemId = elemCfg.itemId
        if reqItemId and reqItemId > 0 then
            if player:getItemCount(reqItemId) < 1 then
                local itType = ItemType(reqItemId)
                local itName = (itType and itType:getName()) or (elemCfg.name .. " Card")
                sendError(player, "Voce precisa de 1x " .. itName .. " para tentar!")
                return
            end
        end

        -- Verifica gold
        local cost = config.elementConfig.cost
        local balance = player:getMoney() + player:getBankBalance()
        if balance < cost then
            sendError(player, "Gold insuficiente! Necessario: " .. cost .. " gold.")
            return
        end

        -- Debita gold
        if not player:removeTotalMoney(cost) then
            sendError(player, "Falha ao debitar o gold.")
            return
        end

        -- Consome item
        if reqItemId and reqItemId > 0 then
            if not player:removeItem(reqItemId, 1) then
                player:setBankBalance(player:getBankBalance() + cost)
                sendError(player, "Falha ao consumir o item.")
                return
            end
        end

        -- Consome catalisador (Small Ruby) se solicitado
        local useCatalyst = (payload.useCatalyst == true or payload.catalyst == true)
        local catalystBonus = 0
        if useCatalyst then
            if player:getItemCount(config.catalyst.itemId) < 1 then
                sendError(player, "Voce precisa de 1x " .. config.catalyst.name .. " para usar como catalisador!")
                return
            end
            if not player:removeItem(config.catalyst.itemId, 1) then
                sendError(player, "Falha ao consumir " .. config.catalyst.name .. ".")
                return
            end
            catalystBonus = config.catalyst.bonusChance
        end

        -- Rola a chance (10% fixo + bonus de catalisador)
        local baseChance = config.elementConfig.chance
        local chance = math.min(100, baseChance + catalystBonus)
        local roll = math.random(1, 100)
        local catMsg = useCatalyst and (" [+" .. catalystBonus .. "% Ruby]") or ""

        if roll <= chance then
            local newVal = currentElemValue + 1
            weapon:setCustomAttribute(config.elementConfig.typeKey,  element)
            weapon:setCustomAttribute(config.elementConfig.valueKey, newVal)
            player:getPosition():sendMagicEffect(CONST_ME_MAGIC_BLUE)
            sendSuccess(player, "Sucesso (" .. chance .. "%" .. catMsg .. ")! " .. elemCfg.name .. " +" .. newVal .. " adicionado a arma!")
        else
            player:getPosition():sendMagicEffect(CONST_ME_POFF)
            local failItemMsg = useCatalyst and ("Item, 1x " .. config.catalyst.name) or "Item"
            sendError(player, "Falha! (" .. chance .. "% chance) " .. failItemMsg .. " e " .. cost .. " gold consumidos.")
        end

        sendUpdate(player, idx)
        return
    end

    -- ---- REFINE: aumenta o ataque físico da arma (+1 até +10) ----
    if action == "refine" then
        local payload = data.data
        if not payload then
            sendError(player, "Dados invalidos.")
            return
        end

        local idx = tonumber(payload.index)
        local weapon = findBackpackWeaponByIndex(player, idx)
        if not weapon then
            sendError(player, "Arma nao encontrada na mochila!")
            return
        end

        local currentRefine = tonumber(weapon:getCustomAttribute(config.refineConfig.key)) or 0
        if currentRefine >= config.refineConfig.max then
            sendError(player, "A arma ja atingiu o refinamento maximo (+" .. config.refineConfig.max .. ")!")
            return
        end

        local nextLevel = currentRefine + 1
        local cost = config.refineConfig.cost

        -- Verifica item de refinamento
        local reqItemId = config.refineConfig.itemId
        if reqItemId and reqItemId > 0 then
            if player:getItemCount(reqItemId) < 1 then
                sendError(player, "Voce precisa de 1x " .. config.refineConfig.name .. " para refinar!")
                return
            end
        end

        -- Verifica gold
        local balance = player:getMoney() + player:getBankBalance()
        if balance < cost then
            sendError(player, "Gold insuficiente! Necessario: " .. cost .. " gold.")
            return
        end

        -- Debita gold
        if not player:removeTotalMoney(cost) then
            sendError(player, "Falha ao debitar o gold.")
            return
        end

        -- Consome item de refino
        if reqItemId and reqItemId > 0 then
            if not player:removeItem(reqItemId, 1) then
                player:setBankBalance(player:getBankBalance() + cost)
                sendError(player, "Falha ao consumir o item de refino.")
                return
            end
        end

        -- Rola chance (apenas chance de refino, sem catalisador)
        local chance = config.refineConfig.chances[nextLevel] or 10
        local roll = math.random(1, 100)

        if roll <= chance then
            weapon:setCustomAttribute(config.refineConfig.key, nextLevel)
            local baseAtk = weapon:getType():getAttack()
            weapon:setAttribute(ITEM_ATTRIBUTE_ATTACK, baseAtk + nextLevel)
            player:getPosition():sendMagicEffect(CONST_ME_MAGIC_BLUE)
            sendSuccess(player, "Refinamento com Sucesso (" .. chance .. "%)! Arma refinada para +" .. nextLevel .. " (Atk: " .. (baseAtk + nextLevel) .. ")!")
        else
            player:getPosition():sendMagicEffect(CONST_ME_POFF)
            sendError(player, "O refinamento falhou (" .. chance .. "% de chance)! 1x " .. config.refineConfig.name .. " e " .. cost .. " gold consumidos. Arma intacta!")
        end

        sendUpdate(player, idx)
        return
    end
end

enchantEvent:type("extendedopcode")
enchantEvent:register()

-- ============================================================
-- EVENTO DE LOGIN
-- ============================================================

local enchantLogin = CreatureEvent("WeaponEnchantLogin")

function enchantLogin.onLogin(player)
    if not player then return true end
    player:registerEvent("WeaponEnchantExtended")
    player:registerEvent("WeaponEnchantElementalDamage")

    -- Remove conditions residuais e sincroniza bonus da arma na mao
    local playerId = player:getId()
    addEvent(function()
        local p = Player(playerId)
        if p then
            refreshEquippedEnchants(p)
        end
    end, 150)
    return true
end
enchantLogin:type("login")
enchantLogin:register()

-- ============================================================
-- TALKACTION: !enchant e /enchant
-- ============================================================

local talkEnchant = TalkAction("/enchant", "!enchant")
function talkEnchant.onSay(player, words, param)
    sendUpdate(player, 1)
    player:sendExtendedOpcode(OPCODE, json.encode({ action = "open" }))
    return false
end
talkEnchant:register()

print(">> Weapon Enchant System Loaded (Engine Combat & Look Integrated, Opcode " .. OPCODE .. ")")

-- ============================================================
-- ONLOOK: EXIBICAO DE ENCHANTS, ELEMENTO E REFINAMENTO NO ITEM
-- ============================================================
local ecLook = Event()

function ecLook.onLook(player, thing, position, distance, description)
    if not thing or not thing:isItem() then return description end

    local improvements = {}
    for attr, key in pairs(config.attrKeys) do
        local val = getEnchantValue(thing, attr)
        if val > 0 then
            table.insert(improvements, (config.attrNames[attr] or attr) .. ": +" .. val .. "%")
        end
    end

    if #improvements > 0 then
        description = description .. "\n\nMelhorias:"
        for _, stat in ipairs(improvements) do
            description = description .. "\n" .. stat
        end
    end

    local elemType  = thing:getCustomAttribute(config.elementConfig.typeKey) or ""
    local elemValue = tonumber(thing:getCustomAttribute(config.elementConfig.valueKey)) or 0
    if elemType ~= "" and elemValue > 0 then
        local elemCfg = config.elementConfig.elements[elemType]
        local elemName = (elemCfg and elemCfg.name) or (elemType:sub(1,1):upper() .. elemType:sub(2))
        description = description .. "\n\nElemento: " .. elemName .. " +" .. elemValue
    end

    local refineLevel = tonumber(thing:getCustomAttribute(config.refineConfig.key)) or 0
    if refineLevel > 0 then
        description = description .. "\n\nRefinamento: +" .. refineLevel .. " (Atk +" .. refineLevel .. ")"
    end

    return description
end

ecLook:register(10)
