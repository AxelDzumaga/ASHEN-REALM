# Etapa 60 — Arte final y animación 2D del combate

## Estado

**Técnico: APROBADO CON ADVERTENCIAS**  
**Etapa 60: PARTIAL**  
**Artístico: PENDIENTE DE APROBACIÓN DEL USUARIO**

## Auditoría inicial

La arquitectura ya incluía `CharacterVisualData`, `SpriteFrames` opcionales, `AnimatedSprite2D` creado por `CombatCharacterView`, Tween/choreography y fallback estático. En la slice 59C los seis combatientes usaban principalmente PNG estáticos 59B más Tween. Existían algunas hojas previas de animación del player/crawler/wretch, pero su tratamiento era semi-realista, con fondos no transparentes y no cumplía el estándar; se clasifican como **PROVISIONALES** y no se activaron.

Los PNG 59B actuales tampoco cumplen todavía las resoluciones normativas 512×512/768×768: por ejemplo player 1292×1218, crawler 1536×1024 y boss 1448×1086. Se mantienen como **PROVISIONALES**.

## Arquitectura final preparada

- `CharacterVisualData` ahora permite declarar `animation_contact_times` por nombre de animación.
- `CombatCharacterView` soporta `idle`, `attack`, `basic_attack`, `ember_slash`, `hit`, `guard`, `second_wind`, `death` y fallback por nombre.
- `CombatChoreographyController` consulta el contact ratio configurable en lugar de depender exclusivamente de la mitad de la duración.
- Ember Slash solicita su animación específica y retrocede a `attack`/Tween si no existe.
- Se agregaron recursos `SpriteFrames` reemplazables para Wanderer, Ash Crawler y Ashen Warden.
- Los recursos contienen actualmente un frame de la ilustración 59B por estado para demostrar carga, selección y reproducción segura; esto es una **preparación técnica**, no animación dibujada final.
- Tween continúa controlando approach, knockback, squash y recoil complementario.

## Recursos preparados

- `data/visuals/player/ashen_wanderer_59b_spriteframes.tres`
- `data/visuals/enemies/ash_crawler_59b_spriteframes.tres`
- `data/visuals/bosses/ashen_warden_59b_spriteframes.tres`

Los tres se referencian desde sus `CharacterVisualData` y funcionan mediante `AnimatedSprite2D`. Companion, Wretch y Brute conservan fallback estático hasta disponer de hojas coherentes.

## Contact frame y timings

Contact ratios configurados para player, crawler y Warden. Los SpriteFrames de prueba usan velocidades diferenciadas por rol (idle lento, ataque más rápido, boss deliberado), pero al tener un solo frame no producen todavía cambio de pose visible. La sincronización VFX/SFX existente sigue entrando desde los puntos de impacto del combate; no se modificó audio externo.

## Validación

Pasaron `static_audit.py`, `ui_audit.py` e importación headless de Godot 4.7.1. Se ejecutó Godot gráfico con renderer D3D12 Forward Mobile para normal, Ember y boss; las tres ejecuciones terminaron con código 0 y generaron capturas reales:

- [60_normal.png](../build/visual_slice/60_normal.png)
- [60_ember.png](../build/visual_slice/60_ember.png)
- [60_boss.png](../build/visual_slice/60_boss.png)

Las capturas confirman que el pipeline no rompe Combat, aunque visualmente todavía se comportan como ilustraciones estáticas porque no existe arte frame-by-frame aprobado.

Warnings no bloqueantes: certificados raíz, shader cache del perfil aislado y carpeta temporal `user://telemetry` al cerrar. No hubo crash ni errores finales de parser, script, resource o escena. No se exportó APK.

## Invariantes

`SAVE_VERSION = 9` y `DEBUG_TOOLS_ENABLED = false` permanecen intactos. No se tocaron CombatMath, stats, balance, energy, costes, AI, turn order, encounters, loot, economía, board, save/load, telemetry, tutorial, monetización ni configuración Android.

## Clasificación y deuda artística

- **FINAL:** ninguno.
- **PROVISIONAL:** todos los PNG 59B, hojas previas y SpriteFrames de esta etapa.
- **PLACEHOLDER/FALLBACK:** fallback procedural/estático existente cuando falta una animación.

La etapa demuestra pipeline reemplazable y fallback seguro, pero no puede declararse arte final ni animación final. Para completar la intención artística se necesita producir hojas transparentes consistentes con el estándar oficial, con frames reales para Wanderer, Crawler y Warden primero, y luego migrar Companion, Wretch y Brute progresivamente.
