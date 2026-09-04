# Sistema de refinamiento

El refinamiento persiste por ID de la pieza canónica en `ProfileData.equipment_refinement`. Los duplicados siguen siendo cantidades y no absorben inversión.

- Cap: +10 (`RefinementConfig.MAX_REFINEMENT`).
- Éxito: garantizado.
- Destrucción/degradación: nunca.
- Coste: función única por rareza, tier y nivel actual.
- Materiales: Ceniza; desde niveles medios, Fragmentos; desde +8, Sigilos.
- Hitos: +3, +5, +8 y +10.
- Potencia activa inicial: +1 al stat principal por hito alcanzado (ATQ en arma, DEF en armadura).
- Hook visual: tier 0 normal, tier 1 desde +5, tier 2 en +10.

## Compatibilidad

La migración v11→v12 conserva inventario/equipado y asigna implícitamente +0. Un item legacy equipado permanece equipado.

## Salvage

Sólo se reciclan cantidades por encima de una copia. La copia canónica y su refinamiento permanecen intactos; por eso no existe bucle refine→salvage. Si en el futuro se habilita venta de la copia canónica, la recuperación recomendada es parcial y menor que el coste invertido.
