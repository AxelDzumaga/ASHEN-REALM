# Etapa 60C — Piloto real Ashen Wanderer `basic_attack`

## Estado

**Técnico: APROBADO CON ADVERTENCIAS**  
**Etapa 60C: PARTIAL**  
**Artístico: PENDIENTE DE APROBACIÓN DEL USUARIO**

## Auditoría y decisión

Se revisaron los estándares y documentación 59B/59C/60/60B, `CharacterVisualData`, `CombatCharacterView`, `CombatChoreographyController`, recursos del player y flujo de basic attack. Se encontró `assets/art/player/animations/player_ashen_wanderer_attack.png`, una hoja transparente de 8 poses diferentes (4×2, celdas de aproximadamente 444×444) con preparación, swing, contacto y recuperación.

La hoja conserva identidad del Wanderer y arma legible, pero su acabado es más semi-realista que el estándar cartoon-chibi 59B. Se integró como piloto real, clasificada **PROVISIONAL**, sin presentarla como arte final.

## Integración

- Nuevo recurso `data/visuals/player/ashen_wanderer_basic_attack_pilot.tres`.
- `CharacterVisualData` del player referencia este SpriteFrames.
- `CombatCharacterView.play_attack()` prioriza `basic_attack` cuando existe y mantiene fallback a `attack`/Tween.
- `AnimatedSprite2D` reproduce ocho frames distintos a 14 FPS.
- Contact timing explícito: `animation_contact_times.attack = 0.5` y `basic_attack = 0.5`.
- La coreografía usa el contact ratio configurable para sincronizar approach, daño, VFX, hitstop, hit animation, knockback y retorno.
- Se corrigió la escala dinámica del AnimatedSprite2D por frame para que las celdas 444×444 no produzcan un personaje diminuto frente al idle.
- Filtering lineal y retorno a idle se conservan.

## Resultado visual

La captura de ataque demuestra animación frame-by-frame real y contacto claramente visible. El player cambia de pose, arma y silueta durante el swing; el daño, slash y recoil siguen conectados.

La diferencia de acabado respecto del idle 59B es visible: la hoja piloto tiene más detalle y un tratamiento semi-realista. Por eso el resultado es técnicamente válido pero no cumple todavía la consistencia artística final del estándar.

## Capturas runtime

Se ejecutó Godot 4.7.1 en modo gráfico, renderer D3D12 Forward Mobile, con perfiles aislados. Todas las ejecuciones finales terminaron con código 0:

- [60c_normal.png](../build/visual_slice/60c_normal.png)
- [60c_attack.png](../build/visual_slice/60c_attack.png)
- [60c_boss.png](../build/visual_slice/60c_boss.png)

`60c_attack.png` es la evidencia principal del cambio de frames. Las capturas normal y boss verifican que la integración no rompe la escena ni el boss existente.

## Validación

Pasaron `static_audit.py`, `ui_audit.py`, `android_readiness_audit.py` e importación headless del editor. No hubo errores finales de parser, script, resource o escena. Durante la iteración apareció un Parse Error de indentación al agregar el modo debug `attack`; fue corregido y revalidado. Persisten únicamente warnings ambientales de certificados, shader cache aislada y `user://telemetry` temporal.

## Invariantes

`SAVE_VERSION = 9` y `DEBUG_TOOLS_ENABLED = false` permanecen intactos. No se modificaron CombatMath, stats, balance, energía, costes, turn order, AI, encounters, companion, bosses, board, save/load, telemetry, safe area, Reduce Motion, responsive portrait ni Android config.

## Archivos

Creado:

- `data/visuals/player/ashen_wanderer_basic_attack_pilot.tres`
- `docs/visual_stage_60c.md`

Modificados:

- `data/visuals/player/ashen_wanderer.tres`
- `scripts/combat/combat_character_view.gd`
- `scripts/combat/combat_choreography_controller.gd`
- `scripts/combat/combat.gd`
- `scripts/core/game.gd`
- `scripts/core/debug_config.gd`

## Deuda restante

- El piloto no es arte final por inconsistencia de estilo con 59B.
- Idle/hit/death siguen usando frame estático provisional.
- No existe todavía una validación de baseline artística entre todos los frames.
- Ash Crawler `attack` y Warden `attack_1` necesitan hojas transparentes reales con el mismo lenguaje visual antes de migrarse.

La etapa no debe declararse PASS completo hasta reemplazar la hoja semi-realista por frames cartoon-chibi coherentes y revisar manualmente la secuencia.
