# Economía de equipment

La economía de Etapa 78 combina azar limitado con progreso acumulativo:

- Ceniza: moneda general para cofres accesibles, equipo rotativo y refinamientos.
- Sigilos de Guardián: moneda de bosses para relicarios y piezas específicas.
- Fragmentos de Forja: único material inicial de refinamiento.
- Cofres: botín inmediato con piso de rareza y pity persistente.
- Duplicados: conservan utilidad mediante salvage; nunca consumen la copia canónica refinada.

## Flujo

`boss derrotado → cofre sin abrir + sigilos → apertura/tienda → equipo → refinamiento`

El depósito del boss forma parte de `SaveManager.deposit_run()`: una run no puede depositarse dos veces. Compra, apertura y refinamiento validan dominio, guardan de forma atómica y restauran el snapshot de memoria si falla el save.

## Precios provisionales

- Common directo: 95–135 Ceniza.
- Rare directo: 320–430 Ceniza.
- Epic directo: 840–1.060 Ceniza.
- Arcón de Ceniza: 55 Ceniza.
- Relicario Raro: 220 Ceniza.
- Cámara Épica: 620 Ceniza.
- Relicarios de boss: 8–10 Sigilos.
- Piezas del set del Guardián: 18–20 Sigilos.

Son anclas iniciales, no balance final. La rotación ocurre cada 3 runs y no depende de reloj.

## Agregar una oferta

Añadirla en `ShopCatalog.get_all()` con ID único, sección, reward, moneda, precio, requisito y stock. Nunca usar precio cero. Para equipment directo, `reward_id` debe existir en `EquipmentCatalog`.

## Seguridad

- No existe refinamiento con probabilidad ni destrucción.
- No se descuenta moneda si el reward es inválido.
- Stock por rotación se guarda con clave `offer_id:rotation`.
- Equipment directo ya poseído se rechaza; los cofres sí pueden producir duplicados útiles.

