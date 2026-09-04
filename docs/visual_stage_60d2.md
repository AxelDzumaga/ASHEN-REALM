# Etapa 60D.2 — Regeneración desde el Wanderer canónico

## Estado

**Técnico: APROBADO CON ADVERTENCIAS**  
**Etapa 60D.2: PARTIAL**  
**Artístico: PENDIENTE DE APROBACIÓN DEL USUARIO**

## Canonical asset

La referencia primaria fue `assets/art/player/player_ashen_wanderer_59b.png`, utilizada por `CharacterVisualData` para el idle aprobado de `60d_normal.png`.

- dimensiones: 1292×1218;
- formato: `Format32bppArgb`;
- alfa en las cuatro esquinas: 0;
- diseño: capucha grande, cabeza super-deformed, piernas cortas, espada exagerada, outline oscuro y cel shading simple.

La hoja 60D semi-realista anterior se conservó únicamente como referencia rechazada y no se normalizó ni se volvió a integrar.

## Generaciones y decisión

Se generó una hoja 2×2 de key poses usando el idle canónico como referencia primaria. La primera salida tenía checkerboard horneado (`Format24bppRgb`) y fue rechazada. La segunda corrección volvió a introducir un fondo pintado opaco y también fue rechazada.

No se integró ninguna de las dos salidas. Se evitó producir una secuencia de ocho frames inconsistente o inferior a 60C.

La generación utilizó la herramienta integrada de imágenes con prompts basados en `docs/art_prompts_stage60.md` y el estándar oficial. Los archivos permanecen fuera del proyecto; no hay nuevo spritesheet 60D.2 en `assets/`.

## Key poses

La prueba 2×2 alcanzó poses conceptuales de ready, anticipation, contact y follow-through, pero no superó transparencia técnica. Por lo tanto no se aprobó la comparación visual ni se procedió a wind-up, swing start, recovery y return.

## Integración y regresión

La integración 60C/60D permanece intacta:

- `AnimatedSprite2D`;
- `SpriteFrames` de 8 frames reales 60D;
- `CharacterVisualData`;
- contact ratio 0.50;
- choreography, VFX, daño, hitstop, knockback y fallback.

No se modificaron recursos de gameplay ni se reemplazó el asset rechazado.

## Validación

Pasaron `static_audit.py`, `ui_audit.py` y `android_readiness_audit.py`. No se ejecutó un nuevo runtime porque no hubo integración de código/asset; las capturas 60C/60D siguen siendo la evidencia válida del pipeline anterior.

No se generaron capturas `60d2_*` porque no existe un asset aprobado que probar. Esto es intencional y evita presentar evidencia de una animación no integrada.

## Invariantes

`SAVE_VERSION = 9` y `DEBUG_TOOLS_ENABLED = false` permanecen intactos. CombatMath, stats, balance, AI, turn order, encounters, save/load, telemetry, Android, safe area, Reduce Motion y responsive portrait no fueron modificados.

## Resultado honesto

La regeneración no alcanzó el estándar técnico mínimo de transparencia y canvas, por lo que 60D.2 queda **PARTIAL**. La integración real previa se conserva sin regresión.

Para cerrar esta etapa hace falta una herramienta que produzca una hoja RGBA real, 4×2, 2048×1024, con cada frame en 512×512 y consistencia comprobable contra el idle canónico. Hasta entonces no conviene avanzar con Crawler ni Warden.
