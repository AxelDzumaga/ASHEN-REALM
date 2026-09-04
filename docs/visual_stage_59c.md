# Etapa 59C — Pulido visual del combate

## Estado

**Técnico: APROBADO CON ADVERTENCIAS**  
**Etapa 59C: PASS**  
**Aprobación artística: pendiente del usuario**

## Alcance

Se trabajó únicamente sobre la slice Combat y sus componentes visuales. No se modificaron Board, Lobby, Results, economía, progresión, AI, stats, turn order, Encounter System, saves, telemetry ni export Android.

## Cambios

- `combat_choreography_controller.gd`: ataques melee/aggressive más rápidos, anticipation más marcada, hitstop levemente ajustado y retorno más limpio.
- `combat_vfx_controller.gd`: pulso de impacto para ataques básicos, squash/recoil breve sobre el objetivo y badges VFX reubicados/acortados para no competir con el hit.
- `game.gd`: capturas de esta etapa guardadas como `59c_*.png`.
- No se generaron assets nuevos. Se conservaron los PNG 59B existentes, clasificados como **PROVISIONALES**.

## Resultado visual honesto

Frente a 59B, el contacto se percibe más claro: el atacante llega antes, el objetivo recibe un squash/recoil visible, el ataque básico tiene un pulso propio y Ember Slash conserva una lectura superior mediante arco/trail/anillo. La captura Ember ahora muestra daño y contacto con menos competencia central.

La composición general y el boss se mantienen estables. Persisten badges de turno durante ciertas fases, y los enemigos crawler/wretch todavía no tienen arte final completamente unificado. La dirección está más cerca de mobile cartoon-chibi comercial, pero no constituye aprobación artística final porque las ilustraciones y animaciones siguen siendo provisionales.

## Validación real

Se ejecutó Godot 4.7.1 gráfico, renderer D3D12 Forward Mobile, con `--visual-slice=normal|ember|boss --capture-visual-slice`. Las tres ejecuciones terminaron con código 0 y generaron:

- [59c_normal.png](../build/visual_slice/59c_normal.png)
- [59c_ember.png](../build/visual_slice/59c_ember.png)
- [59c_boss.png](../build/visual_slice/59c_boss.png)

Las capturas fueron revisadas visualmente a 720×1280. Importación headless, `static_audit.py`, `ui_audit.py` y `android_readiness_audit.py` pasan. Se observaron warnings de entorno no bloqueantes (certificados, shader cache aislada y carpeta `user://telemetry` al cerrar el perfil temporal); no hubo crash ni errores de parser/script/resource del proyecto durante las ejecuciones finales.

## Invariantes

- `SAVE_VERSION = 9` sin cambios.
- `DEBUG_TOOLS_ENABLED = false`.
- Gameplay, balance, skills, costes, turnos, AI, companion, bosses y sistemas externos preservados.
- Sin shaders nuevos, partículas masivas ni sistemas nuevos.
- Touch targets, safe area, responsive portrait y Reduce Motion preservados.

## Recomendación

59C puede considerarse una base técnica visual sólida. Para alcanzar aprobación artística final todavía conviene una futura etapa exclusiva de arte final y animaciones dibujadas, no una expansión de gameplay.
