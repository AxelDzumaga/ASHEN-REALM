# Telemetría local y privacidad

## Estado de ETAPA 57

Ashen Realm no envía telemetría a Internet. No contiene SDK de analytics o crash reporting, HTTP, sockets ni backend. Las ejecuciones desde el editor usan modo `development`, donde la telemetría local sirve para QA. Los exports usan `production` y quedan desactivados por defecto mientras no exista consentimiento y una política publicada. La preferencia interna `analytics_enabled` también tiene valor inicial `false` y todavía no se expone en la UI.

## Datos recogidos

Cada evento contiene `schema_version = 1`, nombre de evento, fecha UTC, un identificador aleatorio y efímero de sesión y únicamente las propiedades autorizadas por `data/telemetry/event_schema.json`.

Se registran de forma agregada:

- comienzo y cierre de sesión;
- inicio, final o abandono de una run;
- bioma y build equipada al inicio;
- nivel, progreso, resultado, Ceniza en bucket, rareza de loot, sinergias y usos agregados de las tres skills al finalizar;
- inicio y final de combate, template, hasta tres IDs internos de enemigos, cantidad de enemigos y turnos;
- Boss y fase máxima alcanzada;
- primera activación de cada sinergia por run;
- milestone completado;
- códigos controlados de errores no fatales o fatales.

## Datos que no se recogen

No se recogen nombre real, nombre del personaje, email, username, texto libre, IP, ubicación, rutas locales, contenido del perfil, inventario completo, identificadores de dispositivo, Android ID, advertising ID, IMEI, MAC, serial, credenciales, password, token, stack trace crudo ni fingerprint de hardware.

No se registra cada golpe, crítico, tick de estado, botón o pantalla.

## Almacenamiento y límites

- Eventos: `user://telemetry/`, JSONL, hasta 3 archivos de 512 KiB y 2 MiB totales.
- Errores fatales controlados: `user://logs/`, hasta 3 archivos de 64 KiB.
- Perfil y telemetría son archivos separados.
- El buffer se vacía al alcanzar 12 eventos, al finalizar/abandonar una run, al pausar y al cerrar limpiamente.
- Un fallo de escritura nunca bloquea gameplay ni SaveManager.

El marker `session_open.marker` existe solo durante una sesión. Si permanece al siguiente inicio se registra `unclean_exit_detected`; esto no confirma un crash.

## Limitación de crashes

GDScript puede registrar errores controlados mediante `report_error` y `report_fatal_error`, pero no intercepta todos los crashes nativos, aborts o fallos anteriores al arranque del motor. Una integración futura con Crashlytics, Sentry u otro servicio requerirá consentimiento, revisión legal y una etapa separada; este proyecto no incorpora ninguna de esas dependencias.

## Taxonomía

| Event | Trigger | Properties | Why | PII | Frequency |
|---|---|---|---|---|---|
| `app_started` | Inicio del autoload | environment | Contexto de QA | No | 1/sesión |
| `session_started` | Inicio del proceso | previous_session_unclean | Sesiones y cierre no limpio | No | 1/sesión |
| `session_ended` | Shutdown limpio | reason | Duración lógica/cierre | No | 1/sesión |
| `unclean_exit_detected` | Marker anterior presente | — | Señal de estabilidad, no crash confirmado | No | 0–1/sesión |
| `run_started` | Punto único de RunManager | biome, arma, armadura, Companion, skills | Builds y selección de bioma | No | 1/run |
| `run_finished` | Results después de save exitoso | resultado, nivel, progreso, Boss, sinergias, loot, duración, Ash y skill counts | Balance y funnel | No | 0–1/run |
| `run_abandoned` | RunManager descarta una run activa | bioma, posición, nivel, combates | Abandono | No | 0–1/run |
| `combat_started` | Combat construye el encuentro | tipo, hasta 3 IDs internos, cantidad, template, bioma, progreso | Dificultad por encounter/enemigo | No | 1/combate |
| `combat_finished` | Resolución idempotente | resultado, turnos, HP bucket, Companion, enemigos | Dificultad agregada | No | 1/combate |
| `boss_started` | Inicio del combate Boss | Boss y bioma | Funnel Boss | No | 0–1/run |
| `boss_finished` | Fin del combate Boss | Boss, resultado, fase | Muro de dificultad | No | 0–1/run |
| `boss_phase_reached` | Cambio de fase | Boss y fase máxima | Progreso de Boss | No | 0–2/run |
| `synergy_activated` | Primera activación por synergy/run | synergy ID | Valor de builds | No | 0–3/run esperado |
| `milestone_completed` | Persistencia exitosa | milestone ID | Progreso onboarding/meta | No | 0–pocas/lifetime |
| `error_reported` | Error controlado | códigos de error/sistema/contexto y fatal | Estabilidad | No | Excepcional |

Una run típica genera aproximadamente 14–30 eventos, según cantidad de combates, Boss y sinergias.
