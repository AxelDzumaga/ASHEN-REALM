# Autoría de biomas y contenido extensible

Esta guía describe la arquitectura incorporada en ETAPA 72. Los ejemplos son de autoría; no habilitan contenido final por sí solos.

## Crear un bioma

1. Crear un `BiomeData` bajo `data/biomes/`.
2. Definir identidad (`id`, nombre, subtítulo y descripción), reglas del tablero y pools legacy de seguridad.
3. Definir progresión:
   - `progression_order`: orden de ruta.
   - `difficulty_tier`: dificultad comunicada.
   - `recommended_level`: orientación; **no bloquea**.
   - `required_milestone_id`: requisito real de desbloqueo, si existe.
   - `danger_rating`: comunicación de amenaza 1–5.
4. Definir metadata visual desacoplada:
   - `theme_family`: familia artística (por ejemplo `dark_wetland`, `frozen_coast`).
   - `environment_profile`: materiales/entorno.
   - `map_style`: lenguaje del tablero.
   - `ambient_profile`: ambiente sonoro/partículas.
   - `background_hook`: ID para arte futuro.
5. Añadirlo explícitamente a `BiomeCatalog` y verificar selección, desbloqueo y fallback.

No se deben reutilizar automáticamente fuego, ceniza o naranja. Cada bioma posee colores, overlays y hooks propios.

## Afinidad de enemigos y spawns

`normal_enemy_pool` sigue siendo el fallback exacto. Para pesos y cruce entre biomas se usan `EnemySpawnEntryData` en `normal_spawn_entries`:

- `NATIVE`: peso triplicado en bioma nativo.
- `COMMON_GLOBAL`: permitido en cualquier bioma.
- `ROAMING`: permitido sólo en `native_biomes`/`possible_biomes`.
- `RARE`: peso efectivo reducido.
- `BIOME_LOCKED`: exclusivamente nativo.

`blocked_biomes` siempre prevalece. Si las entradas quedan vacías o no producen candidatos, el resolver vuelve al pool legacy, evitando encuentros vacíos. Las elites y bosses mantienen pools separados.

## Bosses y amenazas futuras

`BossEncounterData.encounter_role` ya diferencia INTERMEDIATE/FINAL. ETAPA 72 agrega `native_biomes`, `possible_biomes` y `roaming_role` como metadata de autoría. Un mini-boss o roaming boss futuro debe reutilizar esa capa y jamás entrar accidentalmente en el pool de jefe final.

## Afinidades de combate

El conjunto inicial es deliberadamente pequeño: FÍSICO, BRASA, MAREA, CENIZA y MIASMA. `EnemyData` ofrece `primary_damage_type`, `resistance_tags`, `weakness_tags` e `immunity_tags`.

`AffinityResolver.resolve_damage_preview()` está probado, pero no conectado al cálculo de daño vivo. Esto evita modificar balance antes de una simulación dedicada. La única interacción de estado demostrada es MOJADO + QUEMADURA → un turno menos de duración; también permanece como preview en esta etapa.

## Agregar un item con requisito

1. Crear/editar `EquipmentData`.
2. Definir `required_level` (default seguro: 1) tras revisar rareza, tier y poder real.
3. Mantener `icon_id` para UI y `visual_id` para apariencia.
4. Añadir el item al `EquipmentCatalog` y validar `EquipmentVisualCatalog.validate_catalog()`.

La UI y `SaveManager.equip_item()` rechazan equipar si el nivel es insuficiente. Un item bloqueado sigue siendo propiedad del jugador. Un save legado conserva silenciosamente su equipo ya equipado; el requisito se aplica al próximo cambio de equipo.

## Agregar arte de item/equipment

`visual_id` resuelve a `EquipmentVisualData`, que soporta attachment, variante completa o fallback procedural. Armas y armaduras tienen layers independientes en `CombatCharacterView`. Si el ID es inválido o falta arte, se limpia sólo esa capa y el Wanderer base permanece visible.

No existe slot accesorio de dominio, por lo que no debe agregarse `AccessoryVisual` hasta que haya un slot real.
