# Roadmap

## Bloque H — Contabilidad completa

Objetivo: P&L real por lote, por cepa, por sala.

- [x] Pantalla de costos por lote (insumos, mano de obra, energía, prorrateado) — `LoteDetailView` aside
- [x] Cálculo de costo por gramo cosechado — automático en `CostoLote` backend
- [x] Tab "P&L por lote" en `ContabilidadView` — ranking de eficiencia por lote
- [x] Dashboard contable: ingresos, egresos, balance por mes/año/sede — `ContabilidadView` Dashboard tab
- [x] Exportación a CSV del libro diario
- [x] PDF del estado de resultados (P&L mensual completo) — botón "Exportar PDF" en tab P&L de ContabilidadView
- [x] P&L por **cepa** — sub-tab en ContabilidadView con promedio/mín/máx de costo/g
- [x] `CuentaCorriente` de socios: tab en SocioDetailView con saldo, historial, carga y ajuste
- [x] Integración automatizada: dispensación → descuento automático de `CuentaCorriente` — `after_create :debitar_cuenta_corriente` en `Dispensacion`

---

## Bloque I — IoT y sensórica

Objetivo: datos ambientales en tiempo real por sala.

- [ ] Modelo `LecturaSensor` (sala, timestamp, tipo: temperatura/humedad/CO₂/PPFD/EC/pH, valor)
- [ ] Ingesta vía MQTT (broker externo) o HTTP polling
- [ ] Histórico ambiental por sala — gráfico de serie temporal
- [ ] Alertas cuando parámetros salen de rango configurado (VPD, temperatura mínima/máxima)
- [ ] Correlación automática condiciones ambientales ↔ rendimiento del lote

---

## Bloque J — Reportes y analytics avanzados

Objetivo: dashboards completos con datos históricos.

- [ ] Rendimiento por cepa a lo largo del tiempo (gramos/m², THC% estimado)
- [ ] Comparativa de lotes: mismo genotipo en distintas condiciones
- [ ] Tasa de pérdida (plantas descartadas, causas)
- [ ] Tiempo promedio por estadío por cepa
- [ ] Exportación de reportes completos (PDF, Excel)
- [ ] Vista legal / auditor: trazabilidad planta → dispensación para compliance REPROCANN

---

## Bloque K — IA y predicción

Objetivo: inteligencia sobre los datos acumulados.

- [ ] Modelo predictivo de rendimiento (gramos secos esperados) por cepa + condiciones ambientales
- [ ] Detección de anomalías: alerta temprana de deficiencias o plagas vía serie temporal de sensores
- [ ] Visión artificial: foto de planta → clasificación de estadío / detección de deficiencia (modelo externo o propio)
- [ ] Recomendaciones automáticas al cultivador ("EC demasiado alta para este estadío")
- [ ] Benchmarking anónimo entre clubes suscriptos (data agregada)
- [ ] API pública para investigación (endpoints de datos anonimizados)

---

## Backlog sin bloque asignado

- PWA: notificaciones push para alertas ambientales y tareas pendientes
- Onboarding wizard: flujo guiado para nuevos clubes (primer socio, primera sala, primer lote)
- App móvil nativa (React Native o Capacitor) para dispensador en punto de entrega
- Multi-idioma (i18n) — castellano rioplatense como base, inglés para expansión
- Webhook system: notificar sistemas externos en eventos clave (cosecha, dispensación, alta de socio)
