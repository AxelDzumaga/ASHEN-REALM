# ASHEN REALM — DESIGN RULES

## NO YES-MAN

No aceptar automáticamente
las ideas del usuario.

Si una idea:

- rompe balance;
- genera grind;
- crea redundancia;
- provoca feature creep;
- complica mobile;
- aumenta deuda;
- no aporta decisiones;

explicarlo.

Proponer una alternativa.

---

## ANALIZAR IMPACTO GLOBAL

Toda feature debe evaluarse contra:

Combat
Map
Equipment
Inventory
Shop
Loot
Economy
Progression
Save
Events
Bosses
Affinities
UI
Mobile
3D
Performance
Art
Testing.

---

## DISEÑO ANTES DE CÓDIGO

Flujo:

IDEA
→ ANALYSIS
→ DESIGN PROPOSED
→ USER APPROVAL
→ IMPLEMENTATION.

No saltar etapas.

---

## ESTADOS

Usar:

IDEA
DESIGN PROPOSED
APPROVED
IMPLEMENTATION PENDING
IMPLEMENTED
TESTED
HUMAN PLAYTEST PENDING
FINAL ART PENDING
FINAL.

---

## PRIORIDAD

Clasificar:

NOW
NEXT
LATER
POST-LAUNCH
DEFER
REJECT.

---

## COMBAT

Profundidad debe surgir de:

- targeting;
- party composition;
- skills;
- status;
- affinities;
- resources;
- buffs;
- debuffs;
- enemy roles;
- boss mechanics.

No aumentar dificultad sólo con HP.

---

## EQUIPMENT

Un item debería aportar:

- poder;
- build;
- afinidad;
- resistencia;
- utility;
- set;
- efecto;
- apariencia.

Evitar items irrelevantes.

---

## ECONOMÍA

Dificultad no significa grind vacío.

Preferir:

RNG + pity + deterministic progression.

---

## BOSSES

Cada boss debe testear algo:

- sustain;
- targeting;
- status;
- preparation;
- resource management;
- damage;
- timing;
- party composition.

---

## MOBILE

READABILITY > CINEMATIC.

Touch targets grandes.

Evitar saturación.

---

## 3D

Priorizar:

silhouette
performance
materials
readability
animation clarity.

No hiperrealismo innecesario.

---

## NUMBERS

Todo número propuesto debe etiquetarse:

EXAMPLE
INITIAL TUNING
RECOMMENDED RANGE
VALIDATED.

---

## HUMAN PLAYTEST

Automated PASS
no reemplaza sensación real.

Si tests pasan
pero el usuario dice que se siente mal:

investigar.

---

## BUGS

Distinguir:

BUG
DESIGN ISSUE
CONTENT GAP
ART DEBT
PERFORMANCE ISSUE.

---

## FEATURE SIZE

Feature grande:

architecture
→ pilot
→ validation
→ content
→ balance
→ art
→ playtest.

---

## PRINCIPIO FINAL

La pregunta principal:

¿ESTO HACE QUE EL JUGADOR
TOME UNA DECISIÓN MÁS INTERESANTE?