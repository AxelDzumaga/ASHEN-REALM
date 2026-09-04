# Etapa 59B — Reorientación visual mobile cartoon-chibi

## Estado

**Técnico: APROBADO CON ADVERTENCIAS**  
**Artístico: PENDIENTE DE APROBACIÓN DEL USUARIO**  
**Etapa 59B: PARTIAL**

## Diagnóstico inicial

La slice 59A ya tenía mejor contraste y presencia que la base anterior, pero mantenía una mezcla de ilustración semi-seria y chibi, HUD sobredimensionado, tarjetas demasiado dominantes y una sensación de unidades colocadas sobre la arena. El boss era el elemento más sólido, aunque su encabezado invadía la silueta.

La hipótesis de que más detalle resolvería la percepción visual resultó falsa: el cuello de botella era la jerarquía, la escala, la separación de masas y la claridad de acción.

## Cambios aplicados

- Sustitución de la presentación de player, companion, crawler, wretch, brute y Ashen Warden por variantes 59B más simples y de silueta chibi. Todos son **PROVISIONALES**, generados como prueba de dirección; no son arte final.
- Fondo de combate 59B más calmo y legible, manteniendo capas/composición existentes.
- Layout portrait 720×1280: arena más alta, HUD inferior compacto, paneles superiores reducidos y companion separado del player.
- Paneles de enemigo/player/companion con menor opacidad, menos texto redundante y barras más compactas.
- Skill bar reducida: iconos y costes más claros, estados disabled/recarga legibles y targets táctiles conservados.
- Target seleccionado con puntero ámbar y anillo de suelo explícitos.
- Feedback central más contenido; el mensaje de turno prioriza el actor.
- Ember Slash con arco, trail, anillo e impacto diferenciados; se eliminó el badge duplicado del ataque básico.
- Choreography con anticipation/advance/contact/return, squash/recoil y hitstop más perceptible.
- Basic/skill feedback, números de daño y boss framing conservados dentro del sistema actual.
- Boss header compacto de dos líneas; nombre/fase visibles sin tapar la corona. Se conserva la fase existente.
- Overlay de arena atenuado para que el fondo y las siluetas respiren.
- Sin shaders nuevos ni nodos de partículas nuevos; se reutiliza el VFX procedural existente para rendimiento mobile.

## Assets y pipeline

Assets creados bajo `assets/art/.../*_59b.png` para player, companion, tres enemigos representativos, boss y backdrop. Clasificación: **PROVISIONAL**. No hay arte **FINAL** integrado en esta etapa. Se mantiene el pipeline `CharacterVisualData`/`Sprite2D`/`AnimatedSprite2D`/`AnimationPlayer` y los recursos pueden sustituirse sin rehacer el combate.

## Validación runtime

Se ejecutó Godot 4.7.1 en modo gráfico con renderer D3D12 Forward Mobile, perfil APPDATA aislado y argumentos `--visual-slice` + `--capture-visual-slice`. Las tres ejecuciones terminaron con código 0 y emitieron `VISUAL_SLICE_CAPTURE ... error=0`.

Capturas reales a 720×1280:

- [59b_normal.png](../build/visual_slice/59b_normal.png)
- [59b_ember.png](../build/visual_slice/59b_ember.png)
- [59b_boss.png](../build/visual_slice/59b_boss.png)

También se ejecutó importación de editor headless con código 0. El primer intento posterior a los cambios encontró un identificador de HUD obsoleto (`enemy_stats_label`) en `combat.gd`; se corrigió separando `enemy_attack_badge` y `enemy_defense_badge`, y las ejecuciones finales no presentan errores de parser/script/resource.

Auditorías: `static_audit.py`, `ui_audit.py`, `qa_balance_audit.py`, `content_simulation.py`, `tutorial_simulation.py`, `equipment_simulation.py`, `metaprogression_audit.py` y `android_readiness_audit.py` pasan. `audio_audit.py` conserva la advertencia preexistente de assets físicos ausentes/clave de settings; no se agregaron hooks ni se modificó el sistema de audio. No se exportó APK en esta etapa.

## Comparación honesta

La mejora frente a 59A es fuerte y verificable: la arena ocupa más pantalla, el HUD tapa menos, el player/companion/brute tienen lectura más directa, el target es obvio, Ember Slash se distingue y el Warden tiene presencia premium clara. La slice se acerca bastante más al estilo mobile comercial cartoon-chibi solicitado.

Todavía no es una aprobación artística final. Crawler y Wretch conservan algo de densidad/pintura de la dirección anterior, las animaciones siguen siendo transform/tween provisionales cuando no existen frames ilustrados, y algunos badges centrales pueden solaparse durante contacto. La mayor deuda es arte final consistente y animación dibujada; no hacen falta nuevos sistemas de gameplay para resolverla.

## Invariantes y rendimiento

- `SAVE_VERSION = 9` sin cambios.
- `DEBUG_TOOLS_ENABLED = false` en producción.
- CombatMath, stats, turnos manuales, AI, skills, energy, companion, bosses, board, save/load, telemetry y configuración Android preservados.
- No se agregaron monetización, backend, red, currencies, progresión, skills ni bosses nuevos.
- Sin blur fullscreen, iluminación dinámica compleja ni shaders; partículas y VFX siguen siendo acotados y compatibles con mobile.
- Safe area, responsive portrait y Reduce Motion existentes se mantienen.

## Próximo paso

Esperar aprobación visual del usuario. Si se aprueba la dirección, una eventual 59C/60 debería centrarse exclusivamente en reemplazar estos PNG provisionales por arte final coherente y producir animaciones dibujadas; no extender todavía el rediseño a lobby, board, equipment, codex o resultados.
