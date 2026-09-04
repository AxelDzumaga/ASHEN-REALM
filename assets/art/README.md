# Ashen Realm — manifiesto de arte jugable

Esta carpeta contiene arte reemplazable. Los recursos de `res://data/visuals/` son la única capa que enlaza imágenes con datos; gameplay y guardado no dependen de estos archivos.

## Especificación común

- Formato recomendado: PNG con transparencia alfa.
- Espacio de color: sRGB.
- Combat: 768×768 máximo, personaje completo o tres cuartos, vista 3/4, centrado y con aire alrededor de la silueta.
- Portrait: puede reutilizar la misma imagen, recortada por `TextureRect` en Archivo y Results.
- No crear `.import` manualmente. Godot generará sus metadatos cuando el usuario importe los PNG.
- Si una textura no está asignada, la interfaz muestra el emblema procedural de ETAPA 28.

## Player — 1

| Recurso | Archivo esperado | Uso |
|---|---|---|
| Ashen Wanderer | `player/player_ashen_wanderer.png` | Combat, Results |

## Normales — 12

| Recurso | Archivo esperado | Región |
|---|---|---|
| Ember Wretch | `enemies/enemy_ember_wretch.png` | The Ashen Wastes |
| Ash Crawler | `enemies/enemy_ash_crawler.png` | The Ashen Wastes |
| Charred Hound | `enemies/enemy_charred_hound.png` | The Ashen Wastes |
| Ember Acolyte | `enemies/enemy_ember_acolyte.png` | The Ashen Wastes |
| Hollow Guard | `enemies/enemy_hollow_guard.png` | The Ashen Wastes |
| Ash Stalker | `enemies/enemy_ash_stalker.png` | The Ashen Wastes |
| Bog Emberling | `enemies/enemy_bog_emberling.png` | The Ember Marsh |
| Drowned Husk | `enemies/enemy_drowned_husk.png` | The Ember Marsh |
| Mire Stalker | `enemies/enemy_mire_stalker.png` | The Ember Marsh |
| Cinder Leech | `enemies/enemy_cinder_leech.png` | The Ember Marsh |
| Charroot Beast | `enemies/enemy_charroot_beast.png` | The Ember Marsh |
| Ashen Mirecaller | `enemies/enemy_ashen_mirecaller.png` | The Ember Marsh |

## Élites — 4

| Recurso | Archivo esperado | Región |
|---|---|---|
| Cinder Knight | `elites/elite_cinder_knight.png` | The Ashen Wastes |
| Ashbound Brute | `elites/elite_ashbound_brute.png` | The Ashen Wastes |
| Mire Knight | `elites/elite_mire_knight.png` | The Ember Marsh |
| Ember Maw | `elites/elite_ember_maw.png` | The Ember Marsh |

## Jefes — 2

| Recurso | Archivo esperado | Región |
|---|---|---|
| Ashen Warden | `bosses/boss_ashen_warden.png` | The Ashen Wastes |
| The Sunken Pyre | `bosses/boss_sunken_pyre.png` | The Ember Marsh |

Total: 19 personajes. Todos los PNG son opcionales. Cada recurso `.tres` dentro de `res://data/visuals/` ya contiene su ruta esperada y los carga bajo demanda; alcanza con colocar el archivo en esa ruta. Los campos `Texture2D` siguen disponibles como override explícito.

## Biomas

Los fondos se cargan bajo demanda desde `BiomeData`. Todos son opcionales: si faltan, `AshenBackdrop` y los colores procedurales permanecen visibles.

| Región | Archivo | Dimensiones | Alpha | Uso |
|---|---|---:|---|---|
| The Ashen Wastes | `biomes/ashen_wastes/background.png` | 1280×960 | No necesario | Board, Combat, Eventos, Tesoro y Results |
| The Ashen Wastes | `biomes/ashen_wastes/thumbnail.png` | 512×288 | No necesario | Selección, Refugio, anuncio y Archivo |
| The Ashen Wastes | `biomes/ashen_wastes/foreground.png` | 1280×960 | Sí | Rocas/ceniza solo en bordes; opcional |
| The Ember Marsh | `biomes/ember_marsh/background.png` | 1280×960 | No necesario | Board, Combat, Eventos, Tesoro y Results |
| The Ember Marsh | `biomes/ember_marsh/thumbnail.png` | 512×288 | No necesario | Selección, Refugio, anuncio y Archivo |
| The Ember Marsh | `biomes/ember_marsh/foreground.png` | 1280×960 | Sí | Raíces/niebla solo en bordes; opcional |

El mismo `background.png` se utiliza inicialmente en Board y Combat. `BiomeData.combat_background_path` permite asignar más adelante un `combat_background.png` independiente sin modificar scripts.

### Composición y zonas seguras

- Mantener el 45% central con contraste y detalle reducidos para personajes, Vida y feedback.
- Reservar aproximadamente el 12% superior y el 22% inferior sin elementos narrativos esenciales; la UI puede cubrir esas áreas.
- Concentrar ruinas, raíces, rocas y siluetas en bordes y horizonte.
- Diseñar para recorte `keep aspect covered`: ningún elemento indispensable debe quedar en los 15% laterales.
- Background opaco en PNG sRGB. Foreground con transparencia alfa real.
- No incluir personajes, texto, logos, marcos ni UI.
- No crear `.import` manualmente ni forzar ajustes de compresión desde código.

La carpeta `ui/` permanece reservada para una etapa posterior y no contiene referencias obligatorias.

## Animación por frames

Combat acepta `SpriteFrames` opcionales mediante `CharacterVisualData`. El orden de resolución es: `SpriteFrames` con una animación `idle` usable, PNG estático y, finalmente, emblema abstracto. Archivo y Results continúan usando el retrato estático; no reproducen animaciones.

Cada personaje utiliza como máximo un recurso `SpriteFrames` con cuatro animaciones estándar:

- `idle`: loop, 4–8 frames, 6–8 FPS.
- `attack`: sin loop, 6–10 frames, 10–14 FPS.
- `hit`: sin loop, 3–5 frames, 10–14 FPS.
- `death`: sin loop, 6–10 frames, 8–12 FPS; el último frame debe poder permanecer visible.

El canvas, pivot visual, escala, orientación y posición de base deben ser idénticos en todas las animaciones de un personaje. Recomendación móvil: 512×512 por frame, PNG sRGB con alfa, sin fondo ni sombra de suelo pintada. 768×768 queda reservado para Jefes cuya silueta realmente lo necesite. El centro inferior debe actuar como referencia visual de los pies.

### Carpetas y nombres

- Player: `player/animations/player_ashen_wanderer_{idle|attack|hit|death}.png`.
- Normales: `enemies/animations/enemy_<id>_{idle|attack|hit|death}.png`.
- Élites: `elites/animations/elite_<id>_{idle|attack|hit|death}.png`.
- Jefes: `bosses/animations/boss_<id>_{idle|attack|hit|death}.png`.
- Recurso por personaje: `res://data/visuals/<familia>/<id>_animations.tres`.

No se necesitan cuatro `.tres`: un único `SpriteFrames` contiene las cuatro animaciones. Los archivos pueden ser una lámina por animación o una lámina única bien documentada. No crear `.import` manualmente.

### Primeras pruebas

Los 19 recursos visuales ya declaran una ruta opcional `<id>_animations.tres` junto a su `CharacterVisualData`. Para probar uno más adelante, crear el recurso `SpriteFrames` en esa ruta, agregar las cuatro animaciones con los nombres exactos y asignar sus frames. Combat lo detectará sin cambios de código. También se puede asignar un recurso directamente al campo `sprite_frames` como override explícito.

`combat_scale` ajusta la presencia dentro de Combat sin alterar el PNG ni el spritesheet; `combat_offset` corrige su posición dentro del marco; `flip_h` cambia orientación de forma explícita. Estos campos no afectan Archivo ni Results.

### Memoria orientativa

Un frame RGBA 512×512 ocupa aproximadamente 1 MiB descomprimido. Un set de 26 frames ronda 26 MiB antes de optimizaciones internas; cuatro animaciones de 8 frames rondan 32 MiB. A 768×768, cada frame se acerca a 2,25 MiB. Por eso 512×512 es el objetivo y Combat solo debe retener Player + enemigo actual; no hace falta un caché personalizado de los 19 sets.
