# Visuais Astra 8.60

O servidor anuncia as extensões `WingsAndAura`, `OutfitShaders` e `AttachedEffectOutfit` somente ao Astra 8.60. As opções vêm de `data/XML/wings.xml`, `auras.xml`, `effects.xml` e `shaders.xml`; o editor de outfit envia a escolha e o servidor a salva no personagem.

## Banco de dados

Em uma base já existente, aplique uma vez `data/migrations/20261007_attached_effects.sql`. Instalações novas recebem as colunas pelo `schema.sql`.

## IDs e cliente

- Os IDs de `effects.xml` precisam estar registrados no cliente em `mods/game_attachedeffects/effects.lua`.
- Os IDs de asas e auras precisam corresponder aos visuais suportados pelo cliente.
- O valor `name` em `shaders.xml` precisa ser a chave exata registrada em `modules/game_shaders/shaders.lua`.
- Entradas com `premium="true"` aparecem e podem ser usadas somente por contas premium ou de acesso.

Os arquivos XML incluem IDs de exemplo alinhados ao cliente Astra deste workspace. Edite os catálogos para adicionar os visuais instalados no seu cliente. Para recarregá-los sem reiniciar, use `/reload effects` (também aceita `wings`, `auras` e `shaders`).
