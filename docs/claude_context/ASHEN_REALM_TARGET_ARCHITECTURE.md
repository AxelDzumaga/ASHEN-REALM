# ASHEN REALM — TARGET ARCHITECTURE

Este documento describe
a dónde queremos llegar.

NO describe necesariamente
lo que existe hoy.

---

## TARGET GAME

Ashen Realm final:

3D REGION EXPLORATION

+

TURN-BASED TEAM COMBAT

+

UP TO 5v5

+

MODULAR 3D CHARACTER

+

VISUAL EQUIPMENT

+

LOOT / SHOP / INVENTORY

+

AFFINITIES / STATUS / BUILDS

+

MULTIPLE REGIONS

+

EVENTS / ALLIES

+

BOSSES

+

LONG-TERM PROGRESSION.

---

## DOMAIN / PRESENTATION

La lógica crítica debe sobrevivir
a cambios de presentación.

Ejemplo:

Combat Domain
        ↓
Combat2D
Combat3D.

Board Domain
        ↓
Board2D
Map3D.

Equipment Domain
        ↓
Inventory
Stats
Character3D Visuals.

---

## COMBAT TARGET

Crear una capa
presentation-independent.

Target conceptual:

CombatTurnController
+
CombatState
+
Actors
+
Skills
+
Status
+
AI
+
Targeting
+
Resolution.

Presentation:

Combat2D
o
Combat3D.

---

## EQUIPMENT TARGET

Common item domain:

ItemData
→ Inventory
→ Equip
→ Stats
→ Builds
→ VisualDefinition.

Separar:

GAMEPLAY DATA

de:

VISUAL DATA.

---

## CHARACTER 3D

Target:

BaseBody
+
Skeleton
+
Head
+
Shoulders
+
Chest
+
Hands
+
Legs
+
Feet
+
Cape
+
Weapon.

Potential sockets:

hand_r
hand_l
head
spine/chest
shoulders.

Gameplay must not depend
on mesh objects.

---

## VISUAL DEFINITION

Conceptual:

visual_id

→ mesh
→ material
→ attachment point
→ visibility rules
→ VFX
→ fallback.

---

## SHOP / LOOT PIPELINE

All acquisition sources:

Combat
Elite
Boss
Chest
Treasure
Event
Shop

must converge into:

Item
→ Inventory.

No separate shop-item architecture.

---

## REGIONS

BiomeData / RegionData
should drive:

- board length;
- encounters;
- affinity;
- enemy weights;
- environment;
- loot;
- events;
- boss;
- visual profile.

Do not duplicate full systems per region.

---

## CONTENT SCALE

First:

framework.

Then:

pilot.

Then:

validation.

Only then:

batch production.

---

## ART PIPELINE

Character:

Concept
→ turnaround
→ model
→ retopo
→ UV
→ texture
→ rig
→ animation
→ optimization
→ Godot.

Equipment:

Concept
→ slot-compatible model
→ skeleton/attachment
→ material
→ visual ID
→ Godot.

Enemy:

Concept
→ model
→ rig
→ animation set
→ EnemyData/VisualDefinition.

---

## FORWARD COMPATIBILITY

Every implementation should ask:

1. Does it work now?
2. Does it respect current architecture?
3. Can it evolve toward the target?
4. Is it creating avoidable rewrite debt?
5. Can it be validated incrementally?

Forward-compatible
does NOT mean
implement all future systems today.