# ETAPA 59A — Visual proof of quality

Estado artístico: **pendiente de aprobación del usuario**.

## Alcance y clasificación

La vertical slice cubre Combat de The Ashen Wastes, Ashen Wanderer, Ember Hound, Ash Crawler, Ember Wretch, Ashbound Brute y Ashen Warden. No rediseña Lobby, Board, Equipment, Codex, Results ni otros biomas.

| Elemento | Estado 59A | Nota |
|---|---|---|
| Cutouts chibi 59A (6 personajes) | PROVISIONAL | Generados para probar dirección y legibilidad; no son arte final aprobado. |
| Combat backdrop 59A | PROVISIONAL | Composición opaca portrait; reemplazable desde `BiomeData`. |
| Ashen Wanderer previo y spritesheets previos | PROVISIONAL / DIRECCIÓN RECHAZADA | Semi-realistas, con microdetalle y proporción no chibi. Se conservan sin referencia activa. |
| `CombatStage`, emblemas, sombras, retícula y atmósfera | PROCEDURAL | Código liviano y reemplazable. |
| Ausencia de textura o animación | FALLBACK | Silueta procedural y label; no se presenta como arte. |
| Arte profesional definitivo | INEXISTENTE | No hay assets que puedan clasificarse como FINAL en esta slice. |

## Dirección aplicada

- 2D cartoon-chibi dark fantasy con outline, formas grandes y cel shading suave.
- Contraste frío violet-gray/teal contra brasa para evitar una pantalla sólo negra y naranja.
- Player y companion en el tercio inferior; enemigos/boss en la mitad superior; panel de acciones comprimido al borde inferior.
- Fondo portrait con cielo, montañas, ruinas, estructuras medias, arena y foreground implícitos; atmósfera y foreground procedural separados en runtime.
- Tres arquetipos con silueta, masa, postura y color secundario distintos: crawler rápido, wretch medio y brute tank.
- Ashen Warden con corona-horno, torso arquitectónico, espada-obelisco, núcleo y orbe; no deriva de escalar un enemigo normal.

## Pipeline reemplazable

Estructura vigente y extendida sin duplicar taxonomías:

```text
assets/art/
  player/
  companions/
  enemies/
  elites/
  bosses/
  biomes/ashen_wastes/59a/
data/visuals/
  player/
  companions/
  enemies/
  elites/
  bosses/
```

Convención propuesta para arte definitivo:

- Cutout estático: `<family>_<id>.png`; variante de prueba: sufijo `_59a`.
- Animación: `<family>_<id>_{idle|attack|hit|death}.png` y un `SpriteFrames` `<id>_animations.tres`.
- Canvas: 512×512 por frame normal, 768×768 sólo boss; PNG sRGB con alfa real.
- Pivot visual: centro inferior/pies constante en todos los estados; sombra de suelo fuera del PNG.
- Vista: tres cuartos; player/companion miran a la derecha, enemigos a la izquierda.
- Filtrado: linear para ilustración de alta resolución reducida; `fix_alpha_border=true`; sin mipmaps en UI 2D actual.
- Atlas: uno por personaje/estado durante producción; no atlas global que fuerce cargar todo el bestiario.
- `CharacterVisualData` conserva `combat_scale`, `combat_offset`, `flip_h`, `SpriteFrames` y fallback.
- `allow_equipment_overlays=false` permite arte con equipo integrado; puede volver a `true` cuando existan capas artísticas compatibles.

## Arquitectura y performance

- `BiomeEnvironmentLayer`: background bitmap, atmósfera procedural, foreground bitmap opcional y overlay.
- `CombatStage`: horizonte, arena y foreground procedural de respaldo.
- `CombatCharacterView`: `AnimatedSprite2D` opcional; si no hay frames usa Tween transform provisional para idle/attack/hit/death.
- `CombatTargetReticle`: retícula sobre el sprite; el pulso se congela con Reduce Motion.
- `CombatVFXController`: slash básico, doble trailing de Ember Slash, flash, ring, guard, heal, boss, muerte y números agrupados.
- Sin shaders nuevos, blur fullscreen ni luces 2D. Atmósfera: 5 masas de haze + 11 brasas, redibujadas a 20 Hz.
- Memoria fuente máxima simultánea estimada para el slice normal: ~36 MiB RGBA antes de compresión interna; boss reemplaza la formación triple.

## Acceso DEV controlado

Sólo funciona cuando `OS.is_debug_build()` es verdadero. `DEBUG_TOOLS_ENABLED` permanece `false`, no escribe el perfil y no completa tutoriales.

```powershell
& 'D:\Godot\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe' --path 'D:\Ashen Realm\ashen-realm' -- --visual-slice=normal
& 'D:\Godot\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe' --path 'D:\Ashen Realm\ashen-realm' -- --visual-slice=ember
& 'D:\Godot\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe' --path 'D:\Ashen Realm\ashen-realm' -- --visual-slice=boss
```

Agregar `--capture-visual-slice` guarda una captura técnica en `build/visual_slice/`.

## Capturas para aprobación

1. `normal`: esperar el estado de input; capturar player + companion frente a los tres arquetipos y comprobar retícula.
2. `ember`: el harness llena Brasa y dispara Ember Slash; capturar el arco doble/trailing, flash y número de daño.
3. `boss`: capturar tras la entrada con nombre, barra, aura y Warden completo; luego llevarlo a umbral de fase para comprobar transición.

Headless valida carga y lógica, no belleza. Dirección artística, proporciones finales, calidad de borde y composición real en Android quedan pendientes de revisión visual humana.

El residuo de una página descargada que estaba dentro de `assets/art/player/animations/` fue movido, no borrado, a `build/quarantine_59a/` (55 archivos auxiliares y el HTML). Puede recuperarse desde allí; no debe formar parte de un export.

## Prompt set usado (built-in image generation)

- Ashen Wanderer: cutout transparente, chibi 2.7 cabezas, capucha, ojos brasa, armadura quemada y espada ancha; outline y cel shading; sin realismo/3D/pixel art.
- Ember Hound: compañero pequeño adorable-peligroso, placas de carbón y lava, orejas grandes; no lobo real recoloreado.
- Ash Crawler: criatura baja rápida, cabeza cuña, garras de obsidiana y cintas de ceniza teal.
- Ember Wretch: humanoide compacto, máscara-horno cerámica, cleaver curvo y tela violeta.
- Ashbound Brute: masa rectangular de roca, brazo-escudo, puño martillo y bindings turquesa.
- Ashen Warden: boss arquitectónico con corona-horno, espada-obelisco, núcleo y orbe; escala y silueta propias.
- The Ashen Wastes: fondo portrait por profundidad, zona central tranquila y safe zones HUD; violet-gray contra brasa.
- Cinco pasadas `background-extraction`: eliminar checkerboard RGB y producir alfa genuino preservando cada diseño.
