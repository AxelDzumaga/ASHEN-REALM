# ASHEN REALM — MASTER PROJECT CONTEXT

## IDENTIDAD

Ashen Realm es un RPG / roguelite dark fantasy
orientado principalmente a mobile.

Debe combinar:

- exploración mediante runs;
- mapas/regiones 3D;
- combate RPG táctico por turnos;
- party building;
- equipment;
- loot;
- builds;
- afinidades;
- status effects;
- bosses;
- eventos;
- aliados;
- tienda;
- forja;
- refinamiento;
- progresión permanente.

El objetivo comercial es que el juego eventualmente
pueda publicarse como una experiencia 1.0 completa,
no quedarse como prototipo técnico.

---

## FILOSOFÍA

Ashen Realm debe generar decisiones.

El jugador debe preguntarse:

- qué región jugar;
- qué ruta tomar;
- qué enemigo atacar;
- qué build utilizar;
- qué afinidad preparar;
- qué item equipar;
- qué item mejorar;
- qué vender/salvagear;
- cuándo gastar moneda;
- qué boss perseguir;
- qué set intentar completar;
- qué aliado llevar.

La profundidad debe surgir
de la interacción entre sistemas.

No de agregar sistemas aislados.

---

## CORE LOOP

Refuge

→ preparar personaje / party

→ Equipment / Inventory

→ Shop / Forge

→ seleccionar región

→ comenzar run

→ recorrer Map3D

→ roll / routing

→ Combat / Event / Treasure / Heal / Elite

→ obtener loot

→ adaptar build

→ boss

→ boss reward / chest

→ Results

→ regreso al Refuge

→ metaprogresión

→ siguiente run.

---

## MAPAS

Dirección final:

Map3D.

El board lógico puede continuar
como estructura interna de run
si sigue siendo útil.

Cada región debe diferenciarse por:

- terreno;
- arquitectura;
- iluminación;
- enemigos;
- elites;
- boss;
- afinidades;
- hazards;
- eventos;
- loot;
- materiales;
- sets;
- secretos;
- narrativa;
- mecánicas.

No queremos regiones que sean
el mismo tablero con otro color.

---

## REGIONES ACTUALES

Actualmente existen:

- The Ashen Wastes
- Ember Marsh

Las futuras regiones
deben diseñarse y aprobarse gradualmente.

No asumir una lista enorme para 1.0.

---

## COMBAT

Target:

3D turn-based team combat.

Player Team:
izquierda.

Enemy Team:
derecha.

Cámara:
lateral / 3/4.

Personajes:
enfrentados.

Máximo futuro:
5v5.

No todos los combates deben usar 5 unidades.

La complejidad puede crecer:

1v1
→ 2v2
→ 3v3
→ composiciones mayores
→ 5v5.

El sistema exacto de iniciativa
todavía debe definirse.

---

## EQUIPMENT

Equipment es un pilar central.

Debe afectar:

- stats;
- builds;
- afinidades;
- resistencias;
- status;
- sets;
- refinement;
- apariencia.

El mejor item no debe reducirse
a “el número más alto”.

---

## EQUIPMENT VISUAL

Target final:

personaje 3D modular.

Slots objetivo:

WEAPON
HEAD
SHOULDERS
CHEST
HANDS
LEGS
FEET
CAPE
RING_1
RING_2
RELIC.

No asumir que todos existen actualmente.

Los principales slots visuales:

WEAPON
HEAD
SHOULDERS
CHEST
HANDS
LEGS
FEET
CAPE.

Rings/Relic pueden afectar
principalmente stats/VFX.

---

## ITEMS

Un item puede tener:

- ID;
- Name;
- Slot;
- Rarity;
- Required Level;
- Tier;
- Main Stats;
- Secondary Stats;
- Affinity;
- Resistance;
- Status modifiers;
- Set ID;
- Boss Source;
- Biome Source;
- Visual ID;
- Icon ID;
- Refinement;
- Salvage value;
- Lock/Favorite.

No agregar campos sin función real.

---

## ITEM PROGRESSION

Distinguir siempre:

PLAYER LEVEL

ITEM REQUIRED LEVEL

ITEM TIER

RARITY

REFINEMENT LEVEL.

Son conceptos distintos.

---

## AFFINITIES

Las afinidades deben crear estrategia.

No hard counters absolutos.

Objetivos posibles:

- elemental damage;
- weakness;
- resistance;
- status buildup;
- reactions;
- penetration;
- equipment builds;
- biome identity.

No llenar el juego de elementos
sin una función diferenciada.

---

## ECONOMÍA

Currencies principales:

ASH

GUARDIAN SIGILS

FORGE SHARDS.

Evitar crear monedas innecesarias.

El progreso debe combinar:

RNG
+
pity
+
currency
+
requirements
+
deterministic progress.

---

## SHOP / LOOT

Todo item debe poder integrarse
a un mismo Inventory.

Fuentes posibles:

COMBAT
ELITE
BOSS
CHEST
TREASURE
EVENT
SHOP.

No crear sistemas de items diferentes
según el origen.

---

## BOSSES

Un boss debe tener identidad.

Puede incluir:

- phases;
- mechanics;
- affinity;
- status interactions;
- minions;
- signature skills;
- unique loot;
- boss set;
- chest;
- Sigils;
- lore.

No hacer bosses como
“enemigo normal con muchísimo HP”.

---

## EVENTS

Los eventos deben aportar:

- decisiones;
- riesgo;
- recompensas;
- aliados;
- lore;
- combate;
- secretos;
- consecuencias.

Pueden existir chains.

Distinguir:

RUN FLAGS

de

PROFILE FLAGS.

---

## ALLIES

Puede haber:

- Ashen Wanderer;
- companion;
- temporary allies;
- permanent allies;
- summons.

Un aliado debe aportar decisiones,
no sólo daño gratis.

---

## PROGRESIÓN

Debe existir:

short-term progress

medium-term progress

long-term progress.

Ejemplos:

Short:
loot de una run.

Medium:
items/refinement/regiones.

Long:
boss sets/builds/endgame.

---

## MOBILE FIRST

Todo debe funcionar primero
como juego mobile.

Prioridades:

- legibilidad;
- touch;
- performance;
- claridad;
- duración razonable;
- navegación;
- safe areas;
- Android real.

---

## ARTE

Dirección:

dark fantasy stylized.

No hiperrealista.

Personajes legibles.

Siluetas claras.

Equipment visible.

El Ashen Wanderer debe mantener
identidad incluso al cambiar gear.

No producir en masa
antes de validar los pipelines.

---

## PRINCIPIO FINAL

Ashen Realm debe sentirse como
un RPG estratégico coherente.

No como una colección de features.