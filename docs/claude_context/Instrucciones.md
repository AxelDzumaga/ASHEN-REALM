# ASHEN REALM — INSTRUCCIONES OPERATIVAS (Claude Code)

Guía compacta para cualquier sesión futura. No duplica el contenido
completo de los otros documentos de `docs/claude_context/` — solo fija
el protocolo de trabajo.

---

## 0. LECTURA OBLIGATORIA

Antes de trabajar, leer todos los `.md` de `docs/claude_context/`.

---

## 1. ORDEN DE FUENTE DE VERDAD

1. Código actual del repositorio.
2. Resultados de tests actuales (ejecutados, no asumidos).
3. `ASHEN_REALM_TECHNICAL_HANDOFF.md`.
4. `ASHEN_REALM_DECISIONS.md`.
5. `ASHEN_REALM_TARGET_ARCHITECTURE.md`.
6. `ASHEN_REALM_PRODUCTION_ROADMAP.md`.
7. Documentación histórica / resto de contexto.

Si un `.md` contradice el código actual, prevalece el código.

---

## 2. FLUJO OBLIGATORIO PARA FEATURES GRANDES

```
AUDIT
→ DESIGN/CONFIRM
→ IMPLEMENT
→ TEST
→ HUMAN PLAYTEST (cuando corresponda)
→ REPORT
→ UPDATE HANDOFF
```

No saltar etapas. No implementar antes de auditar el área correspondiente.

---

## 3. NO INVENTAR

Nunca asumir la existencia de:

- archivos / paths;
- funciones;
- clases;
- Resources;
- escenas;
- tests;
- SAVE_VERSION;
- estado de Git.

Si algo es desconocido: AUDITAR, no asumir.

---

## 4. NO REWRITE POR DEFECTO

Preferir extender/refactorizar incrementalmente sobre el código existente.

No crear sistemas paralelos (`CombatV2`, `SaveManager2`, `InventoryNew`,
`Board3DLogic`, etc.) sin evidencia técnica fuerte.

Reutilizar arquitectura existente.

---

## 5. SAVE / SAVE_VERSION

- No modificar `SAVE_VERSION` salvo que exista un cambio persistente real
  que requiera migración.
- Si es persistente, definir: campos, defaults, migración, compatibilidad
  hacia atrás, tests.
- Tests runtime que puedan guardar progreso deben usar el aislamiento
  centralizado (`SaveManager.use_isolated_test_profile()` o equivalente
  vigente en el repo).
- Nunca usar el perfil real del jugador para pruebas automatizadas.

---

## 6. REPOSITORIO PÚBLICO — SEGURIDAD

El repositorio oficial (`https://github.com/AxelDzumaga/ASHEN-REALM`) es
PÚBLICO. Nunca subir:

passwords, tokens, API keys, secrets, keystores privados, signing keys,
saves personales, test profiles, credenciales, información privada.

---

## 7. GIT

- No hacer commit ni push salvo que la tarea lo permita explícitamente
  o el usuario lo pida.
- Usar branches y commits pequeños cuando el control de versiones esté
  operativo.
- Nunca `--no-verify` ni bypass de firma sin pedido explícito.

---

## 8. ARQUITECTURA OBJETIVO

Toda implementación actual debe considerar
`ASHEN_REALM_TARGET_ARCHITECTURE.md`, sin intentar construir todo el
futuro hoy. Forward-compatible ≠ implementar sistemas futuros ahora.

---

## 9. MOBILE-FIRST

Toda decisión de UI/UX/performance prioriza mobile (legibilidad, touch,
performance, Android real) por sobre lo cinemático.

---

## 10. CONTENIDO / ARTE

No producir contenido final masivo (regiones, equipment, personajes 3D,
arte final) antes de validar el pipeline correspondiente.

---

## 11. REPORTES Y DOCUMENTACIÓN VIVA

- Toda etapa grande termina con un reporte técnico (ver estructura en
  `ASHEN_REALM_IMPLEMENTATION_PROMPT_RULES.md`).
- Tras una etapa que cambie el estado importante del proyecto, actualizar
  `ASHEN_REALM_TECHNICAL_HANDOFF.md`.
- Cuando una decisión de diseño quede aprobada, actualizar
  `ASHEN_REALM_DECISIONS.md`.

---

## 12. ROADMAP

Seguir `ASHEN_REALM_PRODUCTION_ROADMAP.md` salvo que una auditoría real
demuestre que necesita actualizarse.
