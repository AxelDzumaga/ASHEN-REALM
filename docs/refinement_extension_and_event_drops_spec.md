# Especificación técnica — Refinamiento +20 y drops en Eventos

Estado: **implementado** (2026-09-02). Los tres bloqueantes de la v1 de este
documento están cerrados; ver sección 1. Los números de costo siguen siendo
una primera pasada de balance, ajustable después de una implementación de
prueba — no son cifras finales.

## 1. Decisiones cerradas

1. **Nombres de moneda de bioma** (`BiomeData.material_name`):
   - The Ashen Wastes → **Esquirla de Hueso**
   - The Ember Marsh → **Resina Corrupta**
   - Regla para futuras regiones: cada material se ancla a un objeto físico
     propio de esa región — no reciclar vocabulario de ceniza/brasa/podredumbre
     entre biomas.
2. **`SAVE_VERSION` 12→13**: autorizado y aplicado. `ProfileData.biome_materials`
   (`Dictionary`, clave `String` del biome id → cantidad), mismo patrón que
   `boss_defeat_counts`. Migración `<13` inicializa el diccionario vacío,
   mismo criterio que las migraciones `<12`.
3. **Drop de Evento**: acumula en `RunState.biome_material_earned` (entero,
   la run vive en un solo bioma) y se deposita en `SaveManager.deposit_run()`
   dentro de la misma transacción que XP/Ceniza/loot — nunca escribe al
   perfil a mitad de run.
4. **% de drop de Evento**: 15% (`EventApplier.MATERIAL_DROP_CHANCE`), 1–2
   unidades por drop, dentro del rango 10–20% aprobado.
5. **Costeo de hitos**, primera pasada:

   | Hito | Bonus | Material de Bioma | Fragmentos de Forja | Sigilos | Color |
   |---|---|---|---|---|---|
   | +13 | +1 | x3 | continúa fórmula existente | — | Rojo/Ámbar |
   | +15 | +1 | x5 | continúa fórmula existente | — | Carmesí |
   | +18 | +1 | x8 | continúa fórmula existente | x10 | Dorado |
   | +20 | +1 | x12 | continúa fórmula existente | x18 | Blanco-plateado/prismático |

   Total en +20: 8 hitos × +1 = +8 al stat primario (`RefinementConfig.get_primary_bonus`,
   sin cambios de lógica, solo de array `MILESTONES`).

## 2. Dos supuestos del spec que no coincidían con el código real

Encontrados y resueltos con el usuario antes de escribir código —
documentados acá para que no se pierdan:

### 2.1 "Sigilos del boss de origen" — no existe un sigilo por-boss

`ProfileData.guardian_sigils` es un **pool único y global**, alimentado por
`BossEncounterData.guardian_sigils_reward` sin distinguir de qué boss viene.
No hay (ni se agregó) un `Dictionary` per-boss. **Decisión del usuario:**
+18/+20 descuentan del pool global existente; "de origen" queda como
descripción de diseño, no como restricción mecánica. No se amplió el
esquema de guardado más allá de `biome_materials`.

### 2.2 Niveles intermedios sin costo especificado, y si Ceniza sigue aplicando

El spec original solo daba costos para los 4 hitos (+13/+15/+18/+20), pero
`RefinementConfig.get_cost()` se llama en cada nivel (+11, +12, +14, +16,
+17, +19 también refinan de a uno). **Decisión del usuario:**
- Ceniza sigue escalando con la fórmula continua existente
  (`18 + target² * 4 + tier * 6`, por rareza) en todo 1–20, sin cambios.
- Fragmentos de Forja: la fórmula existente ya es continua y no acotada
  (`ceili((target-2)/2) * rareza`) — se mantuvo sin cambios, se extiende
  naturalmente a 11–20.
- Material de Bioma: interpola linealmente entre los 4 puntos dados
  (10→0, 13→3, 15→5, 18→8, 20→12), redondeando hacia arriba entre hitos.
- Sigilos: 0 hasta +17; interpola entre 10 (+18) y 18 (+20) — en +19 da 14.

### 2.3 Ítems sin biome_tags — resuelto

`EquipmentData.biome_tags` es un `Array[StringName]`, no un único bioma —
en la práctica cada ítem tiene 0 o 1 tag (`data/equipment/**/*.tres`). Las
7 piezas "universales" del catálogo actual (sin tag) no tienen un bioma de
origen fijo. **Decisión final del usuario:** para esas piezas, el costo de
Material de Bioma en +11..+20 acepta el stock combinado de cualquier
Material de Bioma que tenga el jugador (Esquirla de Hueso o Resina
Corrupta, lo que haya), no un bioma por defecto.

Implementación: `RefinementConfig.get_biome_material_key(item)` devuelve
`""` para estas piezas (antes caía a Ashen Wastes por defecto). Dos
funciones nuevas centralizan la lógica de "cualquier material" para no
duplicarla entre `save_manager.gd` y la UI de refinamiento:
- `has_enough_biome_material(profile, item, amount)` — si el ítem tiene
  bioma propio, chequea esa moneda específica; si no, suma el stock de
  todas las monedas de bioma del perfil.
- `spend_biome_material(profile, item, amount)` — descuenta de la moneda
  específica, o (para piezas universales) recorre `BiomeCatalog.get_all()`
  en orden estable descontando de la primera con stock hasta cubrir el
  costo. El orden de qué moneda se gasta primero es un detalle interno —
  la UI no desglosa el gasto por bioma, solo muestra el total.

## 3. Qué se implementó

- `scripts/data/profile_data.gd` — campo `biome_materials`, serialización.
- `scripts/save/save_manager.gd` — `SAVE_VERSION = 13`, migración `<13`,
  depósito transaccional en `deposit_run()`, cobro/validación en
  `refine_equipment()`.
- `scripts/core/run_state.gd` — `biome_material_earned: int`.
- `scripts/economy/refinement_config.gd` — `MAX_REFINEMENT = 20`,
  `MILESTONES` extendido, `get_cost()` con la tercera rama +11..+20,
  `get_visual_tier()` con tiers 3–6 nuevos, `get_biome_material_key()`.
- `scripts/events/event_applier.gd` — `_roll_material_drop()`, determinista
  por seed (`BuildRewardResolver.make_seed`, mismo patrón que
  `ChestResolver`/las recompensas de boon/augment de evento).
- `scripts/data/biome_data.gd` + `data/biomes/*.tres` — campo `material_name`.
- `scripts/ui/refinement.gd` — muestra y valida el costo de material.

## 4. Pendiente / fuera de este alcance

- **Color por hito (CERRADO 2026-09-02, más tarde en la misma sesión):**
  `item_card_view.gd` ya usa `RefinementConfig.get_visual_tier_color()` como
  accent del badge de refinamiento (rojo/ámbar, carmesí, dorado,
  blanco-plateado). Ver `docs/project_status_report_2026-09-02.md`.
- **Coordinación con equipamiento visual (punto 4 del backlog original):**
  si un tier alto de refinamiento debe cambiar la silueta de las primitivas
  en `EquipmentVisualLayer`, no solo el brillo — no implementado, decisión
  de diseño aparte.
- Números de costo siguen siendo placeholder — ajustar después de probar.
