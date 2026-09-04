# Reporte de estado — Ashen Realm (2026-09-02, actualizado 2026-09-03)

Auditoría de código real, no de documentos de diseño. Cada afirmación acá
abajo está verificada leyendo el archivo fuente correspondiente en esta
sesión — se cita el archivo cuando es relevante para que se pueda re-verificar.

**Nota 2026-09-03:** este documento se escribió el 2026-09-02 a las 16:18,
antes de que esa misma sesión implementara y wireara Afinidades Elementales
Fase 1 completo (ver sección 1, entrada "Afinidades elementales" actualizada
más abajo) y de que la sesión del 2026-09-03 cerrara reacciones cruzadas
(Wet+Frost, Wet+Storm) y los dos statuses que faltaban (Decay/Miasma,
Curse/Ceniza). La sección 2 ("Backlog pendiente") y la sección 3
("investigación") describen el punto de partida de esa investigación — ya
no el estado actual — se dejan sin editar como registro histórico de la
decisión, pero no reflejan lo que hay hoy en el código. Ver el cierre al
final del documento.

---

## 1. Inventario real, sistema por sistema

### Refinamiento (+20) — **completo y funcionando**
`scripts/economy/refinement_config.gd`, `scripts/save/save_manager.gd`,
`scripts/ui/refinement.gd`. `MAX_REFINEMENT=20`, 8 hitos (3/5/8/10/13/15/18/20),
costo de Material de Bioma y Sigilos interpolado para +11..+20, soporte para
ítems sin bioma de origen (stock combinado). `SAVE_VERSION=13`, migración
`<13` funcionando. Stage78: 38/38.
**Hueco real (CERRADO 2026-09-02, más tarde en la misma sesión):** el color
por hito ya está cableado — `item_card_view.gd` usa
`RefinementConfig.get_visual_tier_color()` para el accent del badge de
refinamiento. Ya no es puramente numérico.

### Drops de Eventos — **completo y funcionando**
`scripts/events/event_applier.gd`. 15% de probabilidad, determinista por
seed, acumula en `RunState` y deposita en Results junto con Ceniza/XP.
El texto de resultado en la pantalla de Evento sí muestra el drop
(`event_screen.gd:80` renderiza `resolution["text"]`, que incluye el material).
**Hueco real (CERRADO 2026-09-02, más tarde en la misma sesión):**
`run_result.gd` ya muestra el Material de Bioma ganado en la run cuando
`run.biome_material_earned > 0`, junto a Ceniza y Sigilos.

### Map3D — **layout y routing sólidos, legibilidad ya mejorada esta sesión**
- Routing determinista, D4, `BoardTurnController` compartido con Board2D:
  sin cambios, funcionando (`board_turn_contract_test`, `map3d_layout_test`,
  `map3d_complete_run_test` — todos PASS).
- Legibilidad: anillo de posición actual (nuevo), atenuado de casillas
  visitadas (corregido — el mecanismo original con `GeometryInstance3D.transparency`
  **nunca funcionó visualmente** bajo el renderer Mobile del proyecto; se
  reemplazó por oscurecido de material por instancia, verificado con captura).
- Equipamiento visible en el marcador del jugador: implementado esta sesión
  (hombreras + hoja, primitivas, color por rareza).
- Fix de derrota: confirmado por test automatizado y por captura visual.
  **Retest humano subjetivo (`build/map3d_playtest/HUMAN_PLAYTEST.md`) sigue
  sin hacerse** — sigue siendo el único pendiente CRITICAL real.

### Combat2D — **funcional, pero el layout NO es "player izquierda / enemigos derecha"**
Corrección importante a un supuesto que venía repitiéndose en los documentos
de diseño: revisé `scenes/combat/combat.tscn` directamente. El layout real es
**vertical**, no lateral:
- `EnemyCharacterView`: mitad superior, casi todo el ancho (anchors 0.11–0.89
  horiz, 0.035–0.525 vert).
- `PlayerCharacterView`: mitad inferior, lado izquierdo (anchors 0.04–0.68
  horiz, 0.485–0.925 vert).
- `CompanionCharacterView`: mitad inferior, lado derecho (0.63–0.97 horiz,
  0.575–0.92 vert).

Es decir: **enemigo arriba, jugador abajo-izquierda, compañero abajo-derecha**
— no una composición lateral. El punto 1 del backlog ("personajes en los
laterales, ya está así en 2D") **da por sentado algo que no es cierto hoy**.
Esto no es un problema en sí (la composición actual funciona), pero cambia
el punto de partida real para Combat3D: no hay que "extender" un layout
lateral existente, hay que decidirlo desde cero.

`scripts/combat/combat.gd` tiene **2109 líneas y ~136 funciones/variables**
en un solo controlador — mezcla orquestación de turnos, animación,
resolución de skills y HUD en un mismo archivo (a diferencia de Map3D, que
delega toda la lógica a `BoardTurnController` y solo se ocupa de presentación).
Esto es central para el punto 2 del reporte.

### Economía / Stage78 — **balanceada, ahora con un componente sin cerrar**
38/38 en la suite Stage78. El único elemento sin números finales es
Material de Bioma / Sigilos +11-20 (marcado explícitamente como placeholder
en `docs/refinement_extension_and_event_drops_spec.md`).

### Save / migraciones — **sólido**
`SAVE_VERSION=13`, cadena de migración `<9/<11/<12/<13` completa y
consistente, atomic write (TEMP→MAIN con BACKUP), sanitización de perfil
por sistema (`_sanitize_equipment`, `DiscoveryTracker`, `TutorialManager`,
`MilestoneResolverSource`, etc.). No hay deuda visible acá.

### Arquitectura de equipamiento visual — **CONFIRMACIÓN: ya estaba construida antes de esta sesión, con más alcance del que el backlog asumía**
Esto es lo que pediste confirmar puntualmente. Estado real, verificado
leyendo el código (no la documentación):
- `EquipmentVisualData` + `EquipmentVisualCatalog` (`scripts/data/`): las
  **16 piezas del catálogo** (8 armas + 8 armaduras) tienen su propia
  entrada visual procedural, con `ProceduralStyle` por ítem y color por
  rareza vía `VisualTheme.rarity_color()`.
- `EquipmentVisualLayer` (`scripts/ui/equipment_visual_layer.gd`): 3 capas
  (BACK/ARMOR/WEAPON), dibuja formas primitivas — el mismo lenguaje visual
  "primitivas provisionales" que Map3D, con gancho ya construido para
  reemplazar por arte real (`attachment_texture`, `DisplayMode.ATTACHMENT`).
- **Ya estaba conectado a Combat2D real** (`combat.gd:757`,
  `player_view.setup_equipment_visuals(...)`) y a Lobby (`lobby.gd:246`) —
  no solo a una pantalla de preview.
- **Esta sesión se extendió a Map3D**: el marcador del jugador ahora
  muestra hombreras (armadura) y una hoja (arma) coloreadas por rareza,
  leyendo del mismo `EquipmentData`/`EquipmentVisualCatalog`, sin duplicar
  lógica. Verificado con capturas (`build/map3d_playtest/visual_horizontal_spike/h04_equipment_closeup.png`).
- **Hueco real, no crítico:** `DisplayMode.FULL_VARIANT` y el campo
  `full_variant: CharacterVisualData` en `EquipmentVisualData` existen mero
  como gancho — ningún ítem del catálogo lo usa hoy (los 16 usan
  ATTACHMENT o ACCENT). Es infraestructura sin activar, no un bug.

---

## 2. Backlog pendiente — viabilidad real y prioridad reevaluada

Reordenado desde cero con lo que sé ahora del código, no con el orden que
venía en los documentos anteriores.

### 1. Afinidades elementales Fase 1 — **IMPLEMENTADO Y WIREADO (2026-09-02 tarde / 2026-09-03), ya no es "próximo paso"**
Lo que sigue abajo (investigación) describe el punto de partida antes de
implementar. Estado real hoy:
- `AffinityResolver` (PHYSICAL/EMBER/TIDE/ASH/MIASMA/FROST/STORM),
  `EquipmentData.element_type` (arma → tipo de daño real) y
  `EnemyData.resistance_tags/weakness_tags/immunity_tags` (poblados en los
  ~30 `.tres` de enemigos) wireados en `combat.gd` — las 4 rutas de cálculo
  de daño basadas en `CombatMath.calculate_damage()` pasan por
  `_resolve_elemental_damage()`. `CombatMath.gd` sigue sin tocarse: la
  resolución elemental vive en `combat.gd`, no en la fórmula de daño base.
- Statuses elementales: BURN (Brasa), WET (Marea), CHILLED (Escarcha), SHOCK
  (Tormenta) — mismo mecanismo DOT genérico en `CombatStatusController`.
- **2026-09-03:** cerrado el resto de Fase 1 — reacciones cruzadas
  (`CombatStatusController.apply_status()`): WET+FROST da buildup extra de
  CHILLED (+1 stack), WET+STORM hace que SHOCK salte una vez a otro objetivo
  (`_chain_shock`, un solo salto, determinista). Los dos elementos que solo
  tenían WEAK/RESIST sin status propio ahora lo tienen: DECAY (Miasma — DoT
  + reduce curación recibida vía `get_effective_healing`, estático) y CURSE
  (Ceniza — aumenta % de daño recibido de cualquier fuente vía
  `get_effective_incoming_damage`, wireado en los 7 sitios de `apply_damage`
  de `combat.gd` más el tick de DOT). Ninguno de los dos asignado a
  contenido de bioma todavía — mismo criterio que FROST/STORM: infraestructura
  lista, sin asignar. Regresión: ver `_test_elemental_reactions()` en
  `tools/tests/stage72_systems_runtime_test.gd`.

### 2. Rematar los dos huecos de refinamiento/eventos detectados en el inventario — **trivial, hacerlo ya**
Cablear color por hito en `item_card_view.gd` y agregar la línea de
Material de Bioma en `run_result.gd`. Es literalmente terminar lo que ya
está construido, no un feature nuevo. Esfuerzo: menos de una sesión corta.

### 3. Ampliar la tienda — **viable, bajo riesgo, esfuerzo bajo-medio**
`ShopCatalog` (`scripts/economy/shop_catalog.gd`) es una lista estática de
10 ofertas más un sistema de rotación por `total_runs` ya funcional.
Agregar una oferta de compra directa de Material de Bioma (o Fragmentos)
es extender ese mismo patrón `_make(...)`, no rediseñar nada. Lo único que
falta decidir es qué se vende (no un problema técnico).

### 4. Menús3D — **viable técnicamente, pero sin resolver primero horizontal/portrait es repetir el error que ya se vio en Map3D**
El spike horizontal ya mostró en la práctica (capturas reales, no teoría)
que reusar composición pensada para portrait en otro aspect ratio produce
HUD que invade la escena. Si Menús3D comparte `CameraRig`/convenciones con
Map3D como sugiere el backlog, hereda ese mismo riesgo. Bajo prioridad
real hasta decidir orientación — y de los tres candidatos (Lobby, Region
Select, Results), el Lobby es el de mayor impacto visual (ver sección 4).

### 5. Combat3D — **el más caro de los cuatro grandes, bajo esta evaluación más que antes**
Esto es lo que más cambió con la inspección real. Dos hallazgos concretos:
- El backlog asumía que Combat2D ya tiene composición lateral
  ("player izquierda, enemigos derecha") y que Combat3D solo tendría que
  "activarla". **Falso** — el layout real es vertical (enemigo arriba,
  jugador/compañero abajo). Combat3D no hereda una composición, la define
  de cero.
- `combat.gd` tiene 2109 líneas sin la separación lógica/presentación que
  sí tiene Map3D (`BoardTurnController` independiente). Portar esto a 3D
  no es "cambiar cómo se dibuja" de forma limpia como fue Map3D — primero
  hay que decidir si se extrae la orquestación de turnos a algo
  presentación-agnóstico (trabajo de arquitectura, no solo de arte) o si
  se acepta duplicar/mantener dos rutas de presentación dentro del mismo
  archivo gigante (riesgo de deuda técnica creciente).
- Además depende de resolver horizontal/portrait antes (mismo argumento
  que Menús3D, y el backlog original ya lo señalaba).

**Recomendación de orden:** 1 y 2 primero (bajo riesgo, cierran lo ya
empezado) → 3 (tienda, independiente y barato) → resolver horizontal/portrait
como spike de decisión (no implementación completa) → recién ahí evaluar
Combat3D con una fase previa de extracción de `combat.gd` → Menús3D al final,
reusando lo que salga de Combat3D.

---

## 3. Afinidades elementales — investigación (no la había hecho antes; no tengo registro de una sesión previa sobre esto)

### 3.1 ¿Existe un sistema de status effects?
**Sí, y es reusable.** `scripts/data/status_effect_data.gd` define un
framework genérico: `Category` (BUFF/DEBUFF/UTILITY/DOT/DEFENSE),
`DurationType` (TURNS/HITS/PERMANENT_COMBAT), `Trigger` (ON_APPLY/TURN_START/
TURN_END/ON_HIT_RECEIVED/ON_BASIC_ATTACK/ON_REMOVE), `StackMode`. Catálogo
actual (`status_effect_catalog.gd`): `BURN`, `WEAKEN`, `ARMOR_BREAK`,
`REGEN`, `GUARD` — 5 efectos, ninguno elemental salvo `BURN` (que
conceptualmente ya es "fuego"). `CombatStatusController` aplica/tiquea todo
esto con lógica genérica salvo un `match` especial para `burn` (daño) y
`regen` (cura) en `process_turn_start`.

Agregar Escarcha/Marea/Tormenta como nuevos `StatusEffectData` (.tres +
una entrada en el `match` de `process_turn_start` si necesitan lógica
especial, como un "shock" que salte a otro objetivo) sigue exactamente el
patrón ya usado para `burn`/`regen`. No hace falta un sistema nuevo.

**Hook ya existente y sin usar:** `can_apply_status()` en
`combat_status_controller.gd:61` — hoy siempre devuelve `true`, con el
comentario "Hook único para futuras inmunidades/resistencias". Es
literalmente el lugar donde iría "un enemigo de Ember Marsh resiste
Escarcha" o similar.

### 3.2 Roster real de enemigos (verificado en los `.tres` de bioma, no en documentos)

**The Ashen Wastes** (`data/biomes/ashen_wastes.tres`):
- Normales (8): ember_wretch, ash_crawler, hollow_guard, charred_hound,
  ember_acolyte, ash_stalker, cinder_ravager, pyre_skirmisher
- Élites (2): cinder_knight, ashbound_brute
- Boss: ashen_warden

**The Ember Marsh** (`data/biomes/ember_marsh.tres`):
- Normales (8): bog_emberling, drowned_husk, mire_stalker, cinder_leech,
  charroot_beast, ashen_mirecaller, mire_seer, rootbound_sentinel
- Élites (2): mire_knight, ember_maw
- Boss: sunken_pyre

Los nombres ya insinúan una identidad elemental orgánica (Ashen Wastes =
fuego/ceniza; Ember Marsh = fuego+pantano/podredumbre), pero **no hay
ningún campo de "elemento" en `EnemyData` hoy** — sería un campo nuevo, no
uno que ya exista sin usar.

### 3.3 ¿Dónde viviría el campo de probabilidad?

Ya existe un mecanismo de aplicar status por ataque, pero es
**determinista, no probabilístico:** `EnemyActionData`
(`scripts/data/enemy_action_data.gd`) tiene `status_id`, `status_stacks`,
`status_duration` — un movimiento especial del enemigo (elegido por
`weight` dentro del pool de acciones) aplica el status de forma
garantizada si se elige esa acción, no hay un "% de proc por golpe" sobre
el ataque básico.

Para "cada ataque tiene una chance de aplicar [elemento]" al estilo que
implica "afinidad elemental", el patrón más cercano ya existente es
`EquipmentData.crit_chance` (`float`, 0.0–0.5) — un roll de probabilidad ya
vive en el juego, solo que ligado a crítico, no a status. Agregar algo como
`elemental_proc_chance` a `EquipmentData` (para el jugador) y/o a
`EnemyActionData` (para enemigos) seguiría ese mismo patrón de campo +
roll contra RNG determinista por seed (mismo estilo que
`ChestResolver`/`EventApplier`, no `randf()` libre).

### 3.4 ¿Toca `combat_math.gd`?

Hoy, **no tiene por qué.** El archivo entero es:
```gdscript
static func calculate_damage(attack: int, defense: int) -> int:
    ...
```
12 líneas, sin ningún concepto de tipo/elemento. Si Fase 1 es "los ataques
pueden aplicar un status elemental" (como Quemadura ya hace), **no hace
falta tocarlo** — se resuelve enteramente en `CombatStatusController` y
`EnemyActionData`/equipment, en paralelo a `calculate_damage()`, no dentro
de él. Si en cambio se quiere una tabla de ventajas tipo "Escarcha hace
+30% a algo con Tormenta", **ahí sí** `calculate_damage()` necesitaría un
parámetro de elemento y una tabla de multiplicadores — es una decisión de
diseño que cambia el alcance real de "Fase 1", vale la pena confirmarla
antes de estimar esfuerzo con precisión.

### 3.5 Nota de naming

Ya existe `EquipmentData.Affinity` (`enum { NONE, ASH, EMBER, MIRE, WARDEN }`)
y `BiomeData.build_affinity_tag` — un sistema de "afinidad" **distinto**,
ligado a sinergias de build/loadout (`scripts/synergies/`), no a elementos
de combate. Llamar "afinidad elemental" al sistema nuevo (Brasa/Marea/
Escarcha/Tormenta) va a convivir con la palabra "afinidad" ya usada para
otra cosa en el código — no es un blocker, pero vale nombrarlo distinto en
el código (`elemental_type` o similar) para no generar ambigüedad con
`EquipmentData.affinity` ya existente.

---

## 4. Densidad visual — estimación de esfuerzo (sin arte final)

### Map3D — props procedurales
`scripts/board3d/ashen_wastes_map_3d.gd`: hoy hay 3 `MultiMeshInstance3D`
de ambientación — 48 rocas (`_build_rock_multimesh`), 12 ruinas/columnas
(`_build_ruin_multimesh`), 10 grietas de brasa (`_build_ember_crack_multimesh`),
todas con una sola forma geométrica por tipo (caja para rocas, cilindro
para ruinas) distribuidas con una fórmula determinista simple (`fmod`).
No hay skybox — el fondo es `Environment.background_color` sólido
(`Color(0.035, 0.025, 0.035)`) con niebla (`fog_density = 0.012`), sin
geometría de fondo ni horizonte.
**Esfuerzo real:** bajo-medio. Es agregar 2-3 formas más por multimesh
existente (variación de escala/rotación ya está, falta variedad de
silueta) y un cuarto/quinto multimesh de props nuevos (matorrales, huesos,
lo que corresponda al bioma) — mismo patrón, no una arquitectura nueva. Un
skybox mínimo (gradiente o una esfera con textura procedural simple) es
una tarde de trabajo, no un sistema nuevo.

### Player marker — silueta
Hoy es una `CapsuleMesh` + un cono de dirección + un toro decorativo
(`scenes/board3d/ashen_wastes_map_3d.tscn`), ya extendido esta sesión con
2 cajas de hombrera + 1 caja de arma (ver sección 1). Reemplazar la cápsula
por bloques low-poly (torso/cabeza diferenciados) es **extender el mismo
archivo de escena** que ya tiene el patrón establecido (mesh + material
por `_material()`), no tocar `EquipmentVisualLayer` en absoluto — son
sistemas separados por diseño (2D character sprite vs. marcador 3D).
**Esfuerzo real:** bajo. Es la tarea más contenida de las tres — mismo
patrón que ya se usó para agregar equipamiento al marcador.

### Lobby — ambientación
**CORRECCIÓN (2026-09-02, sesión posterior):** esta sección tenía un error
— no lo detecté al auditar solo los tipos de nodo en `lobby.tscn` la
primera vez. El nodo `Stage` tiene su propio script, `scripts/ui/refuge_stage.gd`,
que ya dibuja un fondo de santuario con columnas rotas, banners, un arco,
sconces con llama y un brasero con brasas — no es un `ColorRect` sólido.
Confirmado con captura real (`build/lobby_visual_check/lobby.png`).

El problema real no era ausencia de contenido — era **contraste**: la
mayoría de esos elementos usaban alpha muy bajo (0.045–0.17), casi
imperceptibles contra el arte 2D del personaje, que domina el encuadre.
Se corrigió subiendo el alpha/brillo del halo detrás del personaje, los
sconces y el brasero, y agregando más brasas dispersas — sin reconstruir
nada, extendiendo lo que ya estaba. Ver `refuge_stage.gd`.

---

## 5. Deuda técnica / cosas que valen la pena rematar (no pedidas, detectadas en la auditoría)

1. **Color por hito de refinamiento sin cablear** (sección 1) — trivial.
2. **Results no muestra Material de Bioma ganado** (sección 1) — trivial.
3. **`combat.gd` de 2109 líneas sin separación lógica/presentación** — no es
   un bug, pero es la razón concreta por la que Combat3D es caro. Vale la
   pena, cuando se decida avanzar con Combat3D, empezar con una fase de
   extracción (mover orquestación de turnos a algo tipo
   `CombatTurnController`, análogo a `BoardTurnController`) **antes** de
   tocar presentación — evita duplicar 2000 líneas.
4. **`DisplayMode.FULL_VARIANT` sin usar** en `EquipmentVisualData` — gancho
   construido, cero ítems lo usan. No es deuda urgente, pero si en algún
   momento se decide que un tier de refinamiento alto cambia la silueta del
   ítem (coordinación mencionada en el spec de refinamiento), este es el
   mecanismo que ya existe para eso.
5. **`BiomeData.future_final_boss_candidates`** — campo y getter construidos
   (`get_final_boss_candidates()`), pero ningún bioma lo puebla hoy (ambos
   solo tienen su `boss` único). Scaffolding para variedad de boss futura,
   inactivo.
6. **No hay ítems de compra de Material de Bioma en la tienda** — mencionado
   en la sección 2 como oportunidad barata, lo repito acá porque es
   literalmente "un sistema a medio conectar": la moneda existe, se gana
   jugando, pero no hay ninguna forma de comprarla ni gastarla salvo
   refinamiento.

---

## 6. Cierre — estado real al 2026-09-03

Los ítems 1 y 2 de la sección 5 (color de hito, Material de Bioma en
Results) y el ítem 1 de la sección 2 (Afinidades elementales Fase 1,
completo) están **implementados y en la suite de regresión** —
`stage72_systems_runtime_test.gd` corre `_test_affinities()` y
`_test_elemental_reactions()` en cada pasada de `build/stage72/`.

Pendiente real de Fase 1, no bloqueante:
- Ningún bioma asigna todavía FROST/STORM/MIASMA/CURSE a un enemigo o acción
  de jugador concreta — es una decisión de contenido/balance, no técnica.
  WET sigue siendo el único elemento con una acción de enemigo real
  (`soaking_strike.tres`, Ember Marsh).
- El resto del backlog de la sección 2 (tienda, horizontal/portrait,
  Combat3D, Menús3D) sigue sin tocar — la recomendación de orden de esa
  sección (afinidades → tienda → spike de orientación → Combat3D → Menús3D)
  sigue vigente, ahora con el primer paso cerrado.
