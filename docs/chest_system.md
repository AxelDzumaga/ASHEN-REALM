# Sistema de cofres

`ChestData` define ID, tier, cantidad de rewards, piso/pesos de rareza, monedas/materiales, pity, set prioritario y `visual_id`.

Tiers iniciales:

| Tier | Uso | Piso |
|---|---|---|
| ASH | acceso frecuente | Common |
| RARE | objetivo de varias runs | Rare |
| EPIC | objetivo mediano | Rare, alta probabilidad Epic |
| ANCIENT | hook de largo plazo | Rare, dos rewards |
| BOSS | recompensa de boss | Rare |

`ChestResolver.resolve()` es puro y determinista por seed. `SaveManager.open_chest()` consume y deposita todo en una sola operación persistente.

## Pity y mala suerte

Cada cofre alto posee clave/límite configurable. Una apertura Epic reinicia el contador; al alcanzar el límite se fuerza Epic. El piso Rare de boss evita basura exclusiva y los Sigilos aportan progreso determinista independiente del pity.

## Boss sets

Un cofre puede declarar `boss_set_id`. Si se activa la prioridad de set, primero elige piezas faltantes; esto aumenta moderadamente la protección sin regalar el set. La compra directa con Sigilos es la garantía final.

## Agregar un cofre

Crear la definición en `ChestCatalog`, asignar un `visual_id`, pesos cuya longitud sea 3 y un piso válido. Los bosses deben referenciarlo explícitamente mediante `boss_chest_id`; nunca se infiere por nombre.

