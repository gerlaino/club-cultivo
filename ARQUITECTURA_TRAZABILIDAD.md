# ARQUITECTURA DE TRAZABILIDAD — Cultivo Espacial
**Fecha:** 2026-05-10  
**Versión del schema analizado:** 2026_05_09_000001

---

## DIAGRAMA ER COMPLETO (estado actual)

```
╔══════════════════════════════════════════════════════════════════════════╗
║                         NÚCLEO DE CULTIVO                               ║
╚══════════════════════════════════════════════════════════════════════════╝

[clubs]
  │ id, slug, plan, numero_resolucion_reprocann, fecha_resolucion_reprocann
  │
  ├──N [sedes]
  │     │ club_id, nombre, tipo, declarada_reprocann, reprocann_domicilio_id
  │     │
  │     ├──N [salas]
  │     │     │ club_id, sede_id, nombre, tipo, plants_max, camera_stream_url
  │     │     │
  │     │     ├──N [lotes]
  │     │     │     │ club_id, sala_id, genetica_id*, codigo, estado, start_date
  │     │     │     │ grow_type, light_type, fotoperiodo, semanas_floracion
  │     │     │     │ * genetica_id es INTEGER sin FK constraint ⚠️
  │     │     │     │
  │     │     │     ├──N [plants]
  │     │     │     │     │ lote_id, codigo_qr, nombre, state, origen
  │     │     │     │     │ planta_madre_id (self-ref), es_seleccion, pasada_cosecha
  │     │     │     │     │ fecha_germinacion, fecha_vegetativo, fecha_floracion, fecha_cosecha
  │     │     │     │     │ altura_actual, num_colas, estado_salud, color_hojas
  │     │     │     │     │ ⚠️ SIN club_id | SIN deleted_at
  │     │     │     │     │
  │     │     │     │     ├──N [plant_activities]
  │     │     │     │     │     plant_id, user_id, activity_type, occurred_at, metadata (jsonb)
  │     │     │     │     │
  │     │     │     │     └──N [pesadas_plantas]
  │     │     │     │           pesada_id, plant_id, peso_humedo_g, peso_seco_g
  │     │     │     │
  │     │     │     ├──N [pesadas]
  │     │     │     │     lote_id, fase_origen, fase_destino
  │     │     │     │     peso_humedo_g, peso_seco_g, peso_curado_g
  │     │     │     │     manicurado, plantas_manicuradas, plantas_cosechadas
  │     │     │     │     aprobada_at, aprobada_por_id, motivo_rechazo
  │     │     │     │     ⚠️ SIN FK a stocks (relación implícita)
  │     │     │     │
  │     │     │     ├──N [lote_eventos] (bitácora)
  │     │     │     │     lote_id, user_id, tipo, estado_anterior, estado_nuevo
  │     │     │     │     sala_origen_id, sala_destino_id, registrado_en
  │     │     │     │
  │     │     │     ├──N [registros_ambientales] (manual)
  │     │     │     │     temp, humedad, vpd, co2, ph, ec, ppfd, horas_luz
  │     │     │     │     plagas_observadas, fertilizacion
  │     │     │     │
  │     │     │     ├──N [lecturas_ambientales] (IoT/sensores)
  │     │     │     │     dispositivo_id, tipo, valor, medido_at, fuente
  │     │     │     │     idempotencia: (dispositivo_id, tipo, medido_at) unique
  │     │     │     │
  │     │     │     ├──1 [costo_lotes]
  │     │     │     │     costo_insumos, costo_energia, costo_mano_obra
  │     │     │     │     costo_total, gramos_producidos, costo_por_gramo
  │     │     │     │
  │     │     │     └──N [tareas]
  │     │     │           sala_id, lote_id, plant_id (polimórfico)
  │     │     │           recurrente, frecuencia, horas_estimadas, horas_reales
  │     │     │
  │     │     ├──N [dispositivos]
  │     │     │     sala_id, tipo, webhook_token_digest
  │     │     │
  │     │     └──N [sala_cultivadores]
  │     │           sala_id, user_id (join table)
  │     │
  │     └──N [stocks]
  │           sede_id, lote_id, origen, forma_producto
  │           cantidad, costo_unitario_ars, lote_origen_consumido_g, estado
  │           ⚠️ SIN plant_id | SIN pesada_id | SIN numero_lote_producto
  │           │
  │           ├──N [stock_movimientos]
  │           │     tipo, gramos, sede_origen_id, sede_destino_id
  │           │
  │           └──N [dispensaciones]
  │                 paciente_id, user_id, stock_id, indicacion_medica_id
  │                 cantidad, aporte_socio_ars, medio_pago
  │                 con_envio, estado_envio, delivery_id, codigo_paquete
  │
  ├──N [geneticas]
  │     nombre, tipo, thc, cbd, terpenos, tiempo_floracion
  │     rendimiento, criador, registrada_inase, slug, global
  │     │
  │     └──N [setpoints_fase]
  │           fase, tipo_lectura, valor_min, valor_max, valor_ideal
  │
  ├──N [pacientes]
  │     nombre, apellido, dni, reprocann_numero, reprocann_vencimiento
  │     reprocann_estado, con_seguimiento_medico, limite_dispensacion_mensual_g
  │     deleted_at (soft delete)
  │     │
  │     ├──N [indicacion_medicas]
  │     │     patologia, dosificacion, via_administracion
  │     │     fecha_emision, fecha_vencimiento, activa
  │     │
  │     ├──N [dispensaciones] (ver arriba)
  │     │
  │     ├──1 [cuenta_corrientes]
  │     │     limite_credito, saldo_disponible (en $ y en gramos)
  │     │     │
  │     │     └──N [cuenta_corriente_movimientos]
  │     │
  │     ├──N [paciente_notas]
  │     │
  │     ├──N [patient_documents]
  │     │     template_id, datos (jsonb), hash_documento
  │     │     firma_paciente_data, firmado_paciente_at
  │     │     firma_medico_data, firmado_medico_at
  │     │
  │     └──N [documentos]
  │
  ├──N [movimientos_contables]
  │     sede_id, lote_id, dispensacion_id, paciente_id
  │     tipo, categoria, monto_ars, fecha, pagado
  │
  ├──N [reglas_ambientales]
  │     sala_id, tipo_lectura, condicion, umbral_a, umbral_b
  │     │
  │     └──N [alertas]
  │           estado, reconocida_at, resuelta_at
  │
  ├──N [alertas_internas]
  │     tipo, severidad, destinada_a_role, contexto (jsonb)
  │
  └──N [users]
        role (11 roles), club_id, observer_club_id, observer_token
```

---

## BRECHAS DE TRAZABILIDAD — DIAGNÓSTICO

### Brecha 1: Planta → Stock (CRÍTICA 🔴)
**Problema:** Cuando se aprueba una pesada y se crea un stock, no queda FK de qué planta específica generó ese producto.  
**Impacto:** No es posible responder "¿este gramo de flor vino de qué planta específica?"  
**Solución:** Agregar `pesada_id` a `stocks` para formalizar el vínculo.

### Brecha 2: Stock sin número de lote de producto (CRÍTICA 🔴)
**Problema:** `stocks` no tiene un código de lote de producto (ej: "FL-2026-0042") para etiquetas.  
**Impacto:** Sin este código, no se puede implementar trazabilidad de etiqueta retail ni ARICCAME.  
**Solución:** Agregar `numero_lote_producto` autogenerado + `fecha_elaboracion` + `fecha_vencimiento_estimada`.

### Brecha 3: lotes.genetica_id sin FK (IMPORTANTE 🟡)
**Problema:** `lotes.genetica_id` es INTEGER sin constraint de FK en el schema.  
**Impacto:** Posible corrupción silenciosa de datos si se elimina una genética.  
**Solución:** Agregar FK constraint + convertir a bigint.

### Brecha 4: plants sin club_id ni deleted_at (IMPORTANTE 🟡)
**Problema:** Consultas de plantas por club requieren JOIN a través de lote. Sin deleted_at, no hay soft delete.  
**Impacto:** Queries costosas; imposible "dar de baja" una planta sin eliminarla.  
**Solución:** Agregar `club_id` desnormalizado + `deleted_at`.

### Brecha 5: ARICCAME (CRÍTICA REGULATORIA 🔴)
**Problema:** ARICCAME es el sistema de trazabilidad obligatorio del ANMAT para cannabis medicinal en Argentina.  
**Impacto:** Sin integración, los clubes con pacientes REPROCANN no pueden cumplir el marco regulatorio completo.  
**Solución:** Nuevo modelo `AriccameRegistro` + campos en `stocks` y `dispensaciones`.

---

## MIGRACIONES SUGERIDAS

### MIGRACIÓN 1 — Número de lote de producto en stocks
**Brecha que cierra:** Trazabilidad de etiqueta retail, base para ARICCAME  
**Destructiva:** No (solo agrega columnas)  
**Prioridad:** 🔴 Crítica

```ruby
class AddNumeroLoteProductoToStocks < ActiveRecord::Migration[7.2]
  def change
    add_column :stocks, :numero_lote_producto, :string
    add_column :stocks, :fecha_elaboracion,     :date
    add_column :stocks, :fecha_vencimiento_est, :date
    add_column :stocks, :pesada_id,             :bigint
    add_column :stocks, :club_id,               :bigint, null: true

    add_index :stocks, :numero_lote_producto, unique: true, where: "numero_lote_producto IS NOT NULL"
    add_index :stocks, :pesada_id
    add_index :stocks, :club_id

    add_foreign_key :stocks, :pesadas
    add_foreign_key :stocks, :clubs
  end
end
```

### MIGRACIÓN 2 — QR en stocks (productos)
**Brecha que cierra:** Escaneo QR en producto final para trazabilidad retail  
**Destructiva:** No  
**Prioridad:** 🔴 Crítica

```ruby
class AddCodigoQrToStocks < ActiveRecord::Migration[7.2]
  def change
    add_column :stocks, :codigo_qr, :string
    add_index  :stocks, :codigo_qr, unique: true, where: "codigo_qr IS NOT NULL"
  end
end
```

### MIGRACIÓN 3 — FK correcta para lotes.genetica_id
**Brecha que cierra:** Integridad referencial, previene orphaned records  
**Destructiva:** No (agrega constraint, puede fallar si hay datos huérfanos)  
**Prioridad:** 🟡 Importante

```ruby
class FixLotesGeneticaIdFk < ActiveRecord::Migration[7.2]
  def up
    # Limpiar referencias huérfanas primero
    execute <<~SQL
      UPDATE lotes SET genetica_id = NULL
      WHERE genetica_id IS NOT NULL
        AND genetica_id NOT IN (SELECT id FROM geneticas)
    SQL

    change_column :lotes, :genetica_id, :bigint
    add_foreign_key :lotes, :geneticas, on_delete: :nullify
    add_index :lotes, :genetica_id, if_not_exists: true
  end

  def down
    remove_foreign_key :lotes, :geneticas
    change_column :lotes, :genetica_id, :integer
  end
end
```

### MIGRACIÓN 4 — Soft delete y club_id en plants
**Brecha que cierra:** Trazabilidad de plantas dadas de baja; performance en queries  
**Destructiva:** No  
**Prioridad:** 🟡 Importante

```ruby
class AddClubIdAndDeletedAtToPlants < ActiveRecord::Migration[7.2]
  def up
    add_column :plants, :club_id,    :bigint
    add_column :plants, :deleted_at, :datetime

    # Backfill club_id desde lote
    execute <<~SQL
      UPDATE plants
      SET club_id = lotes.club_id
      FROM lotes
      WHERE plants.lote_id = lotes.id
    SQL

    change_column_null :plants, :club_id, false
    add_index :plants, :club_id
    add_index :plants, :deleted_at
    add_foreign_key :plants, :clubs
  end

  def down
    remove_column :plants, :club_id
    remove_column :plants, :deleted_at
  end
end
```

### MIGRACIÓN 5 — Modelo ARICCAME (registro regulatorio ANMAT)
**Brecha que cierra:** Cumplimiento legal ARICCAME; exportación a sistema ANMAT  
**Destructiva:** No (nueva tabla)  
**Prioridad:** 🔴 Crítica (para clubes con resolución REPROCANN)

```ruby
class CreateAriccameRegistros < ActiveRecord::Migration[7.2]
  def change
    create_table :ariccame_registros do |t|
      t.bigint  :club_id,         null: false
      t.bigint  :stock_id
      t.bigint  :dispensacion_id
      t.bigint  :paciente_id
      t.string  :tipo,            null: false  # stock_entrada | dispensacion | destruccion
      t.string  :estado,          default: 'pendiente', null: false  # pendiente | enviado | confirmado | error
      t.string  :numero_ariccame  # ID asignado por el sistema ANMAT al confirmar
      t.jsonb   :payload_enviado, default: {}
      t.jsonb   :respuesta_anmat, default: {}
      t.datetime :enviado_at
      t.datetime :confirmado_at
      t.text    :error_mensaje
      t.timestamps
    end

    add_index :ariccame_registros, :club_id
    add_index :ariccame_registros, [:tipo, :estado]
    add_index :ariccame_registros, :numero_ariccame, unique: true, where: "numero_ariccame IS NOT NULL"
    add_index :ariccame_registros, :stock_id
    add_index :ariccame_registros, :dispensacion_id

    add_foreign_key :ariccame_registros, :clubs
    add_foreign_key :ariccame_registros, :stocks
    add_foreign_key :ariccame_registros, :dispensaciones
    add_foreign_key :ariccame_registros, :pacientes

    # Campos en dispensaciones para estado ARICCAME
    add_column :dispensaciones, :ariccame_reportada, :boolean, default: false, null: false
    add_index  :dispensaciones, :ariccame_reportada
  end
end
```

### MIGRACIÓN 6 — Plan vs Real en lotes
**Brecha que cierra:** Comparación planificado vs ejecutado  
**Destructiva:** No  
**Prioridad:** 🟡 Importante

```ruby
class AddPlanVsRealToLotes < ActiveRecord::Migration[7.2]
  def change
    # Plants
    add_column :lotes, :plants_count_objetivo,     :integer  # lo que se planeó
    add_column :lotes, :plants_count_cosechadas,   :integer  # lo que se cosechó
    # Rendimiento
    add_column :lotes, :rendimiento_objetivo_g,    :decimal, precision: 10, scale: 2
    add_column :lotes, :rendimiento_real_g,        :decimal, precision: 10, scale: 2
    # Fechas objetivo vs real
    add_column :lotes, :fecha_cosecha_objetivo,    :date
    add_column :lotes, :fecha_cosecha_real,        :date
    add_column :lotes, :fecha_fin_objetivo,        :date
    add_column :lotes, :fecha_fin_real,            :date
  end
end
```

### MIGRACIÓN 7 — Renovación de REPROCANN (workflow)
**Brecha que cierra:** Gestión del ciclo de vida de la habilitación REPROCANN  
**Destructiva:** No  
**Prioridad:** 🟡 Importante

```ruby
class CreateReprocannRenovaciones < ActiveRecord::Migration[7.2]
  def change
    create_table :reprocann_renovaciones do |t|
      t.bigint  :paciente_id,  null: false
      t.bigint  :club_id,      null: false
      t.bigint  :gestionada_por_id
      t.string  :estado,       null: false, default: 'en_tramite'
      # estados: en_tramite | presentada | aprobada | rechazada
      t.string  :numero_nuevo
      t.date    :vencimiento_nuevo
      t.date    :fecha_presentacion
      t.date    :fecha_resolucion
      t.text    :notas
      t.timestamps
    end

    add_index :reprocann_renovaciones, :paciente_id
    add_index :reprocann_renovaciones, [:club_id, :estado]
    add_foreign_key :reprocann_renovaciones, :pacientes
    add_foreign_key :reprocann_renovaciones, :clubs
  end
end
```

### MIGRACIÓN 8 — INASE número de registro en genéticas
**Brecha que cierra:** Registro formal de variedad ante INASE (obligatorio para variedades comercializadas)  
**Destructiva:** No  
**Prioridad:** 🟡 Importante

```ruby
class AddInaseFieldsToGeneticas < ActiveRecord::Migration[7.2]
  def change
    add_column :geneticas, :numero_registro_inase, :string
    add_column :geneticas, :fecha_registro_inase,  :date
    add_column :geneticas, :categoria_inase,       :string
    # categorias: semilla | material_vegetativo | mixto
    add_index :geneticas, :numero_registro_inase, unique: true, where: "numero_registro_inase IS NOT NULL"
  end
end
```

### MIGRACIÓN 9 — Alerta por vencimiento de indicaciones médicas
**Brecha que cierra:** Alertas automáticas cuando vence una indicación médica  
**Destructiva:** No  
**Prioridad:** 🟢 Deseable

```ruby
class AddAlertaVencimientoToIndicacionMedicas < ActiveRecord::Migration[7.2]
  def change
    add_column :indicacion_medicas, :alerta_30_dias_enviada, :boolean, default: false
    add_column :indicacion_medicas, :alerta_vencida_enviada, :boolean, default: false
    add_index  :indicacion_medicas, [:activa, :fecha_vencimiento]
  end
end
```

### MIGRACIÓN 10 — reprocann_adjunto como ActiveStorage
**Brecha que cierra:** Consistencia: el adjunto REPROCANN debe ser un attachment, no una URL string  
**Destructiva:** Requiere migración de datos (mover strings a ActiveStorage)  
**Prioridad:** 🟡 Importante

```ruby
class MigrateReprocannAdjuntoToActiveStorage < ActiveRecord::Migration[7.2]
  def change
    # El adjunto se maneja vía has_one_attached :reprocann_adjunto en el modelo
    # Este migration solo documenta la intención — la columna se elimina
    # DESPUÉS de migrar los archivos existentes via script
    remove_column :pacientes, :reprocann_adjunto, :string
    # Correr primero: rake reprocann:migrate_attachments
  end
end
```

---

## ARQUITECTURA SUGERIDA — CADENA COMPLETA POST-MIGRACIONES

```
SEMILLA / GENÉTICA
  └─► geneticas (registrada_inase ✅, numero_registro_inase 🆕)
        └─► lotes (genetica_id con FK ✅ post-migración 3)
              └─► salas
              └─► plants (club_id 🆕, deleted_at 🆕)
                    └─► plant_activities (bitácora por planta ✅)
                    └─► pesadas_plantas (peso individual ✅)
              └─► pesadas
                    │ (aprobada → crea stock, ahora con FK 🆕)
                    └─► stocks (pesada_id 🆕, numero_lote_producto 🆕, codigo_qr 🆕)
                              └─► dispensaciones (indicacion_medica_id ✅, ariccame_reportada 🆕)
                                        └─► pacientes (reprocann_numero ✅)
                                                └─► indicacion_medicas (vencimiento alert 🆕)
                              └─► ariccame_registros 🆕 (ANMAT reporting)
```

**Leyenda:** ✅ ya existe | 🆕 agregado con estas migraciones
