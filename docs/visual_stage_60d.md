# Etapa 60D — Ashen Wanderer `basic_attack` cartoon-chibi

## Estado

**Técnico: APROBADO CON ADVERTENCIAS**  
**Etapa 60D: PARTIAL**  
**Artístico: PENDIENTE DE APROBACIÓN DEL USUARIO**

## Auditoría y asset anterior

El piloto 60C usaba `player_ashen_wanderer_attack.png`: 8 frames reales, transparentes, pero con acabado semi-realista y canvas de aproximadamente 1774×887. La captura demostraba animación, pero mezclaba visualmente con el idle cartoon-chibi 59B.

Se generó una corrección dirigida mediante la herramienta integrada de generación de imágenes, usando la hoja 60C como referencia de poses/layout y el estándar oficial como restricción. La primera salida fue rechazada porque el checkerboard estaba horneado; la segunda salida se verificó como `Format32bppArgb` con alfa 0 en las cuatro esquinas.

## Nuevo asset

`assets/art/player/animations/player_ashen_wanderer_basic_attack_60d.png`

- 8 poses diferentes;
- 4 columnas × 2 filas;
- poses de ready, anticipation, wind-up, swing, contacto, follow-through y recuperación;
- espada y silueta legibles;
- diseño mucho más cercano al cartoon-chibi 59B;
- fondo transparente real.

Limitación: la herramienta produjo 1774×887 y no 2048×1024. Las celdas son aproximadamente 444×444. Por ello el asset queda **PROVISIONAL**, no FINAL, aunque la consistencia entre poses es buena para un piloto.

## Integración

- `ashen_wanderer_basic_attack_pilot.tres` ahora referencia la hoja 60D.
- `AnimatedSprite2D` reproduce ocho frames distintos a 14 FPS.
- `CharacterVisualData` conserva el mapping y define `attack/basic_attack = 0.50`.
- `CombatCharacterView.play_attack()` usa `basic_attack` y mantiene fallback a `attack`/Tween.
- `CombatChoreographyController` conserva anticipation, approach, contacto, hitstop, VFX, daño, knockback, recovery y retorno.
- La escala por frame evita saltos de tamaño entre el canvas idle y las celdas de ataque.
- Al finalizar, el combatiente vuelve a idle sin modificar gameplay.

## Timing

- frame count: 8;
- FPS: 14;
- duración aproximada: 0,57 s;
- contact frame: aproximadamente 4 de 8;
- normalized contact ratio: 0,50;
- loop: false para ataque, true para idle;
- fallback: estático + Tween si falta SpriteFrames.

## VFX y hitstop

El arco completo no está integrado en el sprite. Se mantienen Basic Slash, hit flash, daño, hitstop, recoil y knockback como sistemas externos. No se modificó la lógica de combate ni el audio externo.

## Validación visual

Se generaron y revisaron capturas reales con Godot 4.7.1, renderer D3D12 Forward Mobile, 720×1280:

- [60d_normal.png](../build/visual_slice/60d_normal.png)
- [60d_attack_start.png](../build/visual_slice/60d_attack_start.png)
- [60d_attack_contact.png](../build/visual_slice/60d_attack_contact.png)
- [60d_attack_recovery.png](../build/visual_slice/60d_attack_recovery.png)

Las capturas muestran poses distintas y un ciclo visual real. No se generó GIF/APNG porque las capturas runtime fueron suficientes para comprobar el wiring y el momento de contacto.

## Validación técnica

Pasaron `static_audit.py`, `ui_audit.py`, `android_readiness_audit.py` e importación headless de Godot. Las ejecuciones normal, attack_start, attack_contact y attack_recovery terminaron con código 0 y `VISUAL_SLICE_CAPTURE error=0`.

`art_animation_audit.py` existe, pero no pudo ejecutarse en esta sesión porque el entorno bloqueó el lanzamiento directo de Python para esa herramienta. Las dimensiones y alfa del asset fueron comprobados mediante System.Drawing.

Warnings no bloqueantes de Godot: certificado raíz, shader cache del perfil aislado y carpeta temporal `user://telemetry` al cerrar. No hubo errores finales de parser, script, resource o escena.

## Invariantes

- `SAVE_VERSION = 9`.
- `DEBUG_TOOLS_ENABLED = false`.
- CombatMath, stats, balance, energy, costes, AI, turn order, encounters, companion, bosses, board, save/load, telemetry, Android, safe area, Reduce Motion y responsive portrait intactos.
- No se agregaron sistemas de gameplay.

## Archivos

Creado:

- `assets/art/player/animations/player_ashen_wanderer_basic_attack_60d.png`
- `data/visuals/player/ashen_wanderer_basic_attack_pilot.tres`
- `docs/visual_stage_60d.md`

Modificados:

- `data/visuals/player/ashen_wanderer.tres`
- `scripts/combat/combat_character_view.gd`
- `scripts/combat/combat_choreography_controller.gd`
- `scripts/combat/combat.gd`
- `scripts/core/game.gd`
- `scripts/core/debug_config.gd`

## Evaluación honesta

La consistencia frame-to-frame es suficientemente buena para un piloto técnico/artístico: el mismo Wanderer mantiene capucha, rostro, ojos, bufanda, espada, capa, proporciones, colores y dirección de luz. La diferencia frente a 60C es positiva y visible.

No es todavía arte FINAL por la resolución no normativa, el padding no normalizado a 512×512 y la necesidad de revisión humana de baseline/pivot. No recomiendo avanzar aún con Ash Crawler attack ni Ashen Warden attack_1 hasta aprobar manualmente esta secuencia y convertirla a una hoja normativa.
