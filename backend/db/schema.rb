# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.2].define(version: 2026_06_16_000001) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "alertas", force: :cascade do |t|
    t.bigint "club_id", null: false
    t.bigint "regla_id", null: false
    t.bigint "sala_id", null: false
    t.bigint "lectura_id"
    t.string "estado", default: "activa", null: false
    t.text "mensaje", null: false
    t.datetime "reconocida_at"
    t.bigint "reconocida_por_id"
    t.datetime "resuelta_at"
    t.bigint "resuelta_por_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["club_id", "estado"], name: "idx_alertas_club_estado"
    t.index ["lectura_id"], name: "index_alertas_on_lectura_id"
    t.index ["reconocida_por_id"], name: "index_alertas_on_reconocida_por_id"
    t.index ["regla_id"], name: "index_alertas_on_regla_id"
    t.index ["resuelta_por_id"], name: "index_alertas_on_resuelta_por_id"
    t.index ["sala_id", "estado"], name: "idx_alertas_sala_estado"
    t.index ["sala_id"], name: "index_alertas_on_sala_id"
  end

  create_table "alertas_internas", force: :cascade do |t|
    t.bigint "club_id", null: false
    t.string "tipo", null: false
    t.text "mensaje", null: false
    t.string "severidad", default: "info", null: false
    t.datetime "leida_at"
    t.bigint "creada_por_id"
    t.string "destinada_a_role"
    t.jsonb "contexto", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "lote_id"
    t.index ["club_id", "leida_at"], name: "index_alertas_internas_on_club_id_and_leida_at"
    t.index ["club_id"], name: "index_alertas_internas_on_club_id"
    t.index ["lote_id"], name: "index_alertas_internas_on_lote_id"
  end

  create_table "analisis_ia", force: :cascade do |t|
    t.bigint "club_id", null: false
    t.bigint "lote_id"
    t.bigint "user_id", null: false
    t.string "tipo", null: false
    t.text "contenido", null: false
    t.integer "tokens_usados"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["club_id"], name: "index_analisis_ia_on_club_id"
    t.index ["lote_id", "created_at"], name: "index_analisis_ia_on_lote_id_and_created_at"
    t.index ["lote_id"], name: "index_analisis_ia_on_lote_id"
    t.index ["user_id"], name: "index_analisis_ia_on_user_id"
  end

  create_table "analisis_laboratorio", force: :cascade do |t|
    t.bigint "lote_id", null: false
    t.bigint "genetica_id"
    t.bigint "club_id", null: false
    t.bigint "user_id", null: false
    t.date "fecha_analisis"
    t.string "laboratorio"
    t.decimal "thc_pct", precision: 5, scale: 2
    t.decimal "cbd_pct", precision: 5, scale: 2
    t.decimal "cbg_pct", precision: 5, scale: 2
    t.string "terpenos_principales"
    t.text "notas"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["club_id"], name: "index_analisis_laboratorio_on_club_id"
    t.index ["genetica_id"], name: "index_analisis_laboratorio_on_genetica_id"
    t.index ["lote_id"], name: "index_analisis_laboratorio_on_lote_id"
  end

  create_table "aplicacion_planes", force: :cascade do |t|
    t.bigint "plan_trabajo_id", null: false
    t.bigint "club_id", null: false
    t.bigint "aplicado_por_id", null: false
    t.string "objetivo_tipo"
    t.integer "objetivo_id"
    t.date "fecha_inicio", null: false
    t.string "estado", default: "activo", null: false
    t.integer "tareas_creadas", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["aplicado_por_id"], name: "index_aplicacion_planes_on_aplicado_por_id"
    t.index ["club_id", "estado"], name: "index_aplicacion_planes_on_club_id_and_estado"
    t.index ["club_id"], name: "index_aplicacion_planes_on_club_id"
    t.index ["objetivo_tipo", "objetivo_id"], name: "index_aplicacion_planes_on_objetivo_tipo_and_objetivo_id"
    t.index ["plan_trabajo_id"], name: "index_aplicacion_planes_on_plan_trabajo_id"
  end

  create_table "ariccame_registros", force: :cascade do |t|
    t.bigint "club_id", null: false
    t.string "tipo", null: false
    t.string "estado", default: "pendiente", null: false
    t.jsonb "payload", default: {}, null: false
    t.jsonb "respuesta", default: {}
    t.string "codigo_ariccame"
    t.string "error_mensaje"
    t.integer "intentos", default: 0
    t.datetime "enviado_at"
    t.datetime "confirmado_at"
    t.bigint "stock_id"
    t.bigint "dispensacion_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["club_id", "estado"], name: "index_ariccame_registros_on_club_id_and_estado"
    t.index ["club_id", "tipo"], name: "index_ariccame_registros_on_club_id_and_tipo"
    t.index ["club_id"], name: "index_ariccame_registros_on_club_id"
    t.index ["codigo_ariccame"], name: "index_ariccame_registros_on_codigo_ariccame", where: "(codigo_ariccame IS NOT NULL)"
    t.index ["dispensacion_id"], name: "index_ariccame_registros_on_dispensacion_id"
    t.index ["estado"], name: "index_ariccame_registros_on_estado"
    t.index ["stock_id"], name: "index_ariccame_registros_on_stock_id"
  end

  create_table "auditorias", force: :cascade do |t|
    t.string "auditable_type", null: false
    t.bigint "auditable_id", null: false
    t.bigint "club_id", null: false
    t.bigint "user_id"
    t.string "accion", null: false
    t.jsonb "cambios", default: {}
    t.datetime "created_at", null: false
    t.index ["auditable_type", "auditable_id"], name: "index_auditorias_on_auditable"
    t.index ["club_id", "created_at"], name: "index_auditorias_on_club_id_and_created_at"
    t.index ["club_id"], name: "index_auditorias_on_club_id"
    t.index ["user_id"], name: "index_auditorias_on_user_id"
  end

  create_table "check_ins", force: :cascade do |t|
    t.bigint "paciente_id", null: false
    t.bigint "dispensacion_id"
    t.bigint "club_id", null: false
    t.integer "escala_bienestar"
    t.jsonb "sintomas", default: {}, null: false
    t.text "notas"
    t.string "via_registro", default: "dispensacion", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["club_id"], name: "index_check_ins_on_club_id"
    t.index ["dispensacion_id"], name: "index_check_ins_on_dispensacion_id", unique: true
    t.index ["paciente_id", "created_at"], name: "index_check_ins_on_paciente_id_and_created_at"
    t.index ["paciente_id"], name: "index_check_ins_on_paciente_id"
  end

  create_table "clubs", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "legal_name"
    t.string "phone"
    t.string "email"
    t.string "website"
    t.string "address"
    t.string "city"
    t.string "state"
    t.string "country"
    t.string "timezone"
    t.string "theme_primary"
    t.string "plan", default: "semilla", null: false
    t.date "plan_activo_hasta"
    t.boolean "plan_trial", default: true, null: false
    t.jsonb "limites_custom", default: {}
    t.string "slug", null: false
    t.string "cuit"
    t.string "numero_igj"
    t.string "numero_resolucion_reprocann"
    t.date "fecha_resolucion_reprocann"
    t.string "tipo_organizacion"
    t.boolean "web_activa", default: false, null: false
    t.text "descripcion_web"
    t.string "instagram_url"
    t.string "facebook_url"
    t.string "whatsapp"
    t.text "horarios_atencion"
    t.boolean "activo", default: true, null: false
    t.datetime "deleted_at"
    t.boolean "benchmark_opt_in", default: false, null: false
    t.string "smtp_host"
    t.integer "smtp_port", default: 587
    t.string "smtp_user"
    t.string "smtp_pass"
    t.string "smtp_from"
    t.string "smtp_from_name"
    t.string "ia_tier", default: "basico", null: false
    t.integer "ia_limite_hora", default: 20, null: false
    t.jsonb "features", default: {}, null: false
    t.string "twilio_account_sid"
    t.string "twilio_auth_token_enc"
    t.string "twilio_whatsapp_from"
    t.integer "umbral_stock_g", default: 50, null: false
    t.jsonb "alertas_config", default: {}, null: false
    t.integer "lote_numero_seq", default: 0, null: false
    t.date "contabilidad_cerrada_hasta"
    t.index ["benchmark_opt_in"], name: "index_clubs_on_benchmark_opt_in"
    t.index ["deleted_at"], name: "index_clubs_on_deleted_at"
    t.index ["features"], name: "index_clubs_on_features", using: :gin
    t.index ["plan"], name: "index_clubs_on_plan"
    t.index ["slug"], name: "index_clubs_on_slug", unique: true
  end

  create_table "conversaciones_asistente", force: :cascade do |t|
    t.bigint "club_id", null: false
    t.bigint "user_id", null: false
    t.date "fecha", null: false
    t.jsonb "mensajes", default: [], null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["club_id"], name: "index_conversaciones_asistente_on_club_id"
    t.index ["user_id", "fecha"], name: "index_conversaciones_asistente_on_user_id_and_fecha", unique: true
    t.index ["user_id"], name: "index_conversaciones_asistente_on_user_id"
  end

  create_table "costo_lotes", force: :cascade do |t|
    t.bigint "lote_id", null: false
    t.bigint "club_id", null: false
    t.decimal "costo_insumos", precision: 12, scale: 2, default: "0.0", null: false
    t.decimal "costo_energia", precision: 12, scale: 2, default: "0.0", null: false
    t.decimal "costo_mano_obra", precision: 12, scale: 2, default: "0.0", null: false
    t.decimal "costo_prorrateado", precision: 12, scale: 2, default: "0.0", null: false
    t.decimal "costo_total", precision: 12, scale: 2, default: "0.0", null: false
    t.decimal "gramos_producidos", precision: 10, scale: 2
    t.decimal "costo_por_gramo", precision: 10, scale: 2
    t.text "notas"
    t.bigint "calculado_por_id"
    t.datetime "calculado_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["club_id"], name: "index_costo_lotes_on_club_id"
    t.index ["lote_id"], name: "index_costo_lotes_on_lote_id", unique: true
  end

  create_table "cuenta_corriente_movimientos", force: :cascade do |t|
    t.bigint "cuenta_corriente_id", null: false
    t.bigint "dispensacion_id"
    t.bigint "created_by_id", null: false
    t.string "tipo", null: false
    t.decimal "monto", precision: 12, scale: 2, null: false
    t.decimal "saldo_anterior", precision: 12, scale: 2, null: false
    t.decimal "saldo_nuevo", precision: 12, scale: 2, null: false
    t.string "descripcion"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "unidad", default: "ars", null: false
    t.index ["created_by_id"], name: "index_cuenta_corriente_movimientos_on_created_by_id"
    t.index ["cuenta_corriente_id"], name: "index_cuenta_corriente_movimientos_on_cuenta_corriente_id"
    t.index ["dispensacion_id"], name: "index_cuenta_corriente_movimientos_on_dispensacion_id"
  end

  create_table "cuenta_corrientes", force: :cascade do |t|
    t.bigint "paciente_id", null: false
    t.bigint "club_id", null: false
    t.decimal "limite_credito", precision: 12, scale: 2, default: "0.0", null: false
    t.decimal "saldo_disponible", precision: 12, scale: 2, default: "0.0", null: false
    t.text "notas"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "credito_gramos_activo", default: false, null: false
    t.decimal "limite_credito_g", precision: 10, scale: 3
    t.decimal "saldo_disponible_g", precision: 10, scale: 3, default: "0.0"
    t.index ["club_id"], name: "index_cuenta_corrientes_on_club_id"
    t.index ["paciente_id"], name: "index_cuenta_corrientes_on_paciente_id"
  end

  create_table "dispensaciones", force: :cascade do |t|
    t.bigint "paciente_id", null: false
    t.bigint "user_id", null: false
    t.bigint "indicacion_medica_id"
    t.text "observaciones"
    t.date "fecha_dispensacion", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "sede_id"
    t.decimal "aporte_socio_ars", precision: 10, scale: 2
    t.string "medio_pago", default: "efectivo", null: false
    t.bigint "stock_id"
    t.decimal "cantidad", precision: 10, scale: 3, default: "0.0", null: false
    t.decimal "precio_unitario_ars", precision: 10, scale: 2
    t.boolean "con_envio", default: false, null: false
    t.string "estado_envio"
    t.bigint "delivery_id"
    t.string "direccion_envio"
    t.string "contacto_nombre"
    t.string "contacto_telefono"
    t.text "notas_envio"
    t.string "codigo_paquete"
    t.text "notas_entrega"
    t.text "motivo_fallo"
    t.datetime "entregado_at"
    t.boolean "ariccame_reportada", default: false, null: false
    t.text "firma_entrega_data"
    t.index ["ariccame_reportada"], name: "index_dispensaciones_on_ariccame_reportada", where: "(ariccame_reportada = false)"
    t.index ["codigo_paquete"], name: "index_dispensaciones_on_codigo_paquete", unique: true
    t.index ["delivery_id"], name: "index_dispensaciones_on_delivery_id"
    t.index ["estado_envio"], name: "index_dispensaciones_on_estado_envio"
    t.index ["fecha_dispensacion"], name: "index_dispensaciones_on_fecha_dispensacion"
    t.index ["indicacion_medica_id"], name: "index_dispensaciones_on_indicacion_medica_id"
    t.index ["medio_pago"], name: "index_dispensaciones_on_medio_pago"
    t.index ["paciente_id", "fecha_dispensacion"], name: "index_dispensaciones_on_paciente_id_and_fecha_dispensacion"
    t.index ["paciente_id"], name: "index_dispensaciones_on_paciente_id"
    t.index ["sede_id"], name: "index_dispensaciones_on_sede_id"
    t.index ["stock_id"], name: "index_dispensaciones_on_stock_id"
    t.index ["user_id"], name: "index_dispensaciones_on_user_id"
  end

  create_table "disponibilidad_medicos", force: :cascade do |t|
    t.bigint "medico_id", null: false
    t.bigint "club_id", null: false
    t.integer "dia_semana", null: false
    t.integer "hora_inicio", null: false
    t.integer "hora_fin", null: false
    t.boolean "activa", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["club_id", "medico_id"], name: "index_disponibilidad_medicos_on_club_id_and_medico_id"
    t.index ["club_id"], name: "index_disponibilidad_medicos_on_club_id"
    t.index ["medico_id", "dia_semana"], name: "index_disponibilidad_medicos_on_medico_id_and_dia_semana"
    t.index ["medico_id"], name: "index_disponibilidad_medicos_on_medico_id"
  end

  create_table "dispositivos", force: :cascade do |t|
    t.bigint "club_id", null: false
    t.bigint "sala_id", null: false
    t.string "tipo", null: false
    t.string "marca"
    t.string "modelo"
    t.string "serial"
    t.string "nombre_amigable", null: false
    t.string "estado", default: "activo", null: false
    t.datetime "ultima_lectura_at"
    t.string "webhook_token_digest"
    t.datetime "last_token_rotated_at"
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["club_id", "serial"], name: "idx_dispositivos_serial", unique: true, where: "(serial IS NOT NULL)"
    t.index ["club_id"], name: "index_dispositivos_on_club_id"
    t.index ["sala_id"], name: "index_dispositivos_on_sala_id"
  end

  create_table "document_templates", force: :cascade do |t|
    t.bigint "club_id", null: false
    t.bigint "created_by_id", null: false
    t.string "nombre", null: false
    t.string "tipo", null: false
    t.text "descripcion"
    t.text "contenido_html"
    t.jsonb "campos", default: []
    t.boolean "activo", default: true, null: false
    t.boolean "requiere_firma_paciente", default: false, null: false
    t.boolean "requiere_firma_medico", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["club_id", "activo"], name: "index_document_templates_on_club_id_and_activo"
    t.index ["club_id", "tipo"], name: "index_document_templates_on_club_id_and_tipo"
    t.index ["club_id"], name: "index_document_templates_on_club_id"
    t.index ["created_by_id"], name: "index_document_templates_on_created_by_id"
  end

  create_table "documentos", force: :cascade do |t|
    t.bigint "club_id", null: false
    t.bigint "user_id", null: false
    t.string "tipo", null: false
    t.string "titulo", null: false
    t.text "descripcion"
    t.date "fecha_vencimiento"
    t.string "estado", default: "vigente"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "subido_por_id"
    t.bigint "paciente_id"
    t.index ["club_id"], name: "index_documentos_on_club_id"
    t.index ["estado"], name: "index_documentos_on_estado"
    t.index ["fecha_vencimiento"], name: "index_documentos_on_fecha_vencimiento"
    t.index ["paciente_id"], name: "index_documentos_on_paciente_id"
    t.index ["subido_por_id"], name: "index_documentos_on_subido_por_id"
    t.index ["tipo"], name: "index_documentos_on_tipo"
    t.index ["user_id"], name: "index_documentos_on_user_id"
  end

  create_table "eventos", force: :cascade do |t|
    t.bigint "club_id", null: false
    t.string "titulo", null: false
    t.text "descripcion"
    t.datetime "fecha_inicio", null: false
    t.datetime "fecha_fin"
    t.string "lugar"
    t.boolean "activo", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["activo"], name: "index_eventos_on_activo"
    t.index ["club_id", "activo", "fecha_inicio"], name: "index_eventos_on_club_id_and_activo_and_fecha_inicio"
    t.index ["club_id"], name: "index_eventos_on_club_id"
  end

  create_table "geneticas", force: :cascade do |t|
    t.bigint "club_id"
    t.string "nombre", null: false
    t.text "descripcion"
    t.decimal "thc", precision: 5, scale: 2
    t.decimal "cbd", precision: 5, scale: 2
    t.boolean "disponible", default: true, null: false
    t.boolean "activa", default: true, null: false
    t.string "tipo"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "origen"
    t.integer "tiempo_floracion"
    t.integer "rendimiento"
    t.integer "altura"
    t.string "dificultad"
    t.boolean "registrada_inase"
    t.string "criador"
    t.string "terpenos"
    t.boolean "visible_web", default: false, null: false
    t.string "slug", null: false
    t.boolean "global", default: false, null: false
    t.string "numero_registro_inase"
    t.date "fecha_registro_inase"
    t.string "categoria_inase"
    t.index ["activa"], name: "index_geneticas_on_activa"
    t.index ["club_id", "activa"], name: "index_geneticas_on_club_id_and_activa"
    t.index ["club_id", "slug"], name: "index_geneticas_on_club_id_and_slug", unique: true
    t.index ["club_id"], name: "index_geneticas_on_club_id"
    t.index ["numero_registro_inase"], name: "idx_geneticas_numero_inase", unique: true, where: "(numero_registro_inase IS NOT NULL)"
  end

  create_table "indicacion_medicas", force: :cascade do |t|
    t.bigint "paciente_id", null: false
    t.bigint "user_id", null: false, comment: "Médico que emite"
    t.string "patologia", null: false
    t.text "dosificacion", null: false
    t.string "via_administracion", null: false
    t.integer "duracion_dias"
    t.date "fecha_emision", null: false
    t.date "fecha_vencimiento"
    t.boolean "activa", default: true, null: false
    t.text "observaciones"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["activa"], name: "index_indicacion_medicas_on_activa"
    t.index ["fecha_vencimiento"], name: "index_indicacion_medicas_on_fecha_vencimiento"
    t.index ["paciente_id"], name: "index_indicacion_medicas_on_paciente_id"
    t.index ["user_id"], name: "index_indicacion_medicas_on_user_id"
  end

  create_table "jwt_denylists", force: :cascade do |t|
    t.string "jti"
    t.datetime "exp"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["jti"], name: "index_jwt_denylists_on_jti"
  end

  create_table "lecturas_ambientales", force: :cascade do |t|
    t.bigint "club_id", null: false
    t.bigint "sala_id", null: false
    t.bigint "dispositivo_id"
    t.bigint "lote_id"
    t.string "tipo", null: false
    t.decimal "valor", precision: 10, scale: 4, null: false
    t.string "unidad", limit: 20, null: false
    t.datetime "medido_at", null: false
    t.string "fuente", default: "manual", null: false
    t.string "origen_record_type"
    t.bigint "origen_record_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["club_id", "medido_at"], name: "idx_la_club_medido"
    t.index ["dispositivo_id", "tipo", "medido_at"], name: "idx_la_idempotencia", unique: true, where: "(dispositivo_id IS NOT NULL)"
    t.index ["dispositivo_id"], name: "index_lecturas_ambientales_on_dispositivo_id"
    t.index ["lote_id"], name: "index_lecturas_ambientales_on_lote_id"
    t.index ["origen_record_type", "origen_record_id"], name: "idx_la_origen", where: "(origen_record_id IS NOT NULL)"
    t.index ["sala_id", "tipo", "medido_at"], name: "idx_la_sala_tipo_medido"
    t.index ["sala_id"], name: "index_lecturas_ambientales_on_sala_id"
  end

  create_table "lecturas_ambientales_diarias", force: :cascade do |t|
    t.bigint "club_id", null: false
    t.bigint "sala_id", null: false
    t.string "tipo", null: false
    t.date "fecha", null: false
    t.decimal "valor_min", precision: 10, scale: 4, null: false
    t.decimal "valor_max", precision: 10, scale: 4, null: false
    t.decimal "valor_avg", precision: 10, scale: 4, null: false
    t.decimal "valor_p5", precision: 10, scale: 4
    t.decimal "valor_p95", precision: 10, scale: 4
    t.integer "n_lecturas", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["club_id", "fecha"], name: "idx_lad_club_fecha"
    t.index ["sala_id", "tipo", "fecha"], name: "idx_lad_unique", unique: true
    t.index ["sala_id"], name: "index_lecturas_ambientales_diarias_on_sala_id"
  end

  create_table "lote_eventos", force: :cascade do |t|
    t.bigint "lote_id", null: false
    t.bigint "user_id", null: false
    t.bigint "club_id", null: false
    t.string "tipo", null: false
    t.string "estado_anterior"
    t.string "estado_nuevo"
    t.text "descripcion"
    t.datetime "registrado_en", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "sala_origen_id"
    t.bigint "sala_destino_id"
    t.index ["club_id"], name: "index_lote_eventos_on_club_id"
    t.index ["lote_id"], name: "index_lote_eventos_on_lote_id"
    t.index ["registrado_en"], name: "index_lote_eventos_on_registrado_en"
    t.index ["sala_destino_id"], name: "index_lote_eventos_on_sala_destino_id"
    t.index ["sala_origen_id"], name: "index_lote_eventos_on_sala_origen_id"
    t.index ["tipo"], name: "index_lote_eventos_on_tipo"
    t.index ["user_id"], name: "index_lote_eventos_on_user_id"
  end

  create_table "lotes", force: :cascade do |t|
    t.string "codigo"
    t.date "start_date"
    t.integer "plants_count"
    t.string "strain"
    t.text "notes"
    t.bigint "sala_id"
    t.bigint "club_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "grow_type", default: "sustrato", null: false
    t.string "light_type"
    t.string "estado"
    t.integer "tamanio_maceta"
    t.string "sustrato_especifico"
    t.string "fotoperiodo"
    t.integer "semanas_floracion"
    t.bigint "genetica_id"
    t.datetime "deleted_at"
    t.integer "plants_count_objetivo"
    t.decimal "rendimiento_objetivo_g", precision: 10, scale: 2
    t.date "fecha_cosecha_estimada"
    t.decimal "rendimiento_real_g", precision: 10, scale: 2
    t.integer "plants_count_cosechadas"
    t.bigint "manicurador_id"
    t.string "origen", default: "semilla", null: false
    t.bigint "planta_madre_id"
    t.string "fotoperiodo_vegetativo"
    t.integer "tamanio_maceta_inicial"
    t.date "fecha_trasplante"
    t.decimal "ph_riego", precision: 4, scale: 1
    t.text "fertilizacion_descripcion"
    t.string "sistema_hidro"
    t.string "codigo_qr_cosecha"
    t.string "codigo_qr"
    t.index ["club_id"], name: "index_lotes_on_club_id"
    t.index ["codigo"], name: "index_lotes_on_codigo"
    t.index ["codigo_qr"], name: "index_lotes_on_codigo_qr", unique: true, where: "(codigo_qr IS NOT NULL)"
    t.index ["codigo_qr_cosecha"], name: "index_lotes_on_codigo_qr_cosecha", unique: true
    t.index ["deleted_at"], name: "index_lotes_on_deleted_at"
    t.index ["estado"], name: "index_lotes_on_estado"
    t.index ["genetica_id"], name: "index_lotes_on_genetica_id"
    t.index ["manicurador_id"], name: "index_lotes_on_manicurador_id"
    t.index ["planta_madre_id"], name: "index_lotes_on_planta_madre_id"
    t.index ["sala_id"], name: "index_lotes_on_sala_id"
  end

  create_table "mails_enviados", force: :cascade do |t|
    t.bigint "paciente_id", null: false
    t.bigint "user_id", null: false
    t.bigint "club_id", null: false
    t.string "asunto", null: false
    t.text "cuerpo", null: false
    t.string "tipo", default: "personalizado", null: false
    t.string "email_destino", null: false
    t.datetime "enviado_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["club_id"], name: "index_mails_enviados_on_club_id"
    t.index ["paciente_id", "enviado_at"], name: "index_mails_enviados_on_paciente_id_and_enviado_at"
    t.index ["paciente_id"], name: "index_mails_enviados_on_paciente_id"
    t.index ["user_id"], name: "index_mails_enviados_on_user_id"
  end

  create_table "movimientos_contables", force: :cascade do |t|
    t.bigint "club_id", null: false
    t.bigint "sede_id", null: false
    t.bigint "lote_id"
    t.bigint "dispensacion_id"
    t.bigint "created_by_id", null: false
    t.string "tipo", null: false
    t.string "categoria", null: false
    t.string "descripcion", null: false
    t.decimal "monto_ars", precision: 12, scale: 2, null: false
    t.date "fecha", null: false
    t.string "comprobante_numero"
    t.string "comprobante_tipo"
    t.string "proveedor"
    t.boolean "pagado", default: false, null: false
    t.string "medio_pago"
    t.text "notas"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "paciente_id"
    t.index ["club_id", "fecha"], name: "index_movimientos_contables_on_club_id_and_fecha"
    t.index ["club_id", "tipo"], name: "index_movimientos_contables_on_club_id_and_tipo"
    t.index ["club_id"], name: "index_movimientos_contables_on_club_id"
    t.index ["dispensacion_id"], name: "index_movimientos_contables_on_dispensacion_id"
    t.index ["fecha"], name: "index_movimientos_contables_on_fecha"
    t.index ["lote_id"], name: "index_movimientos_contables_on_lote_id"
    t.index ["paciente_id"], name: "index_movimientos_contables_on_paciente_id"
    t.index ["sede_id", "fecha"], name: "index_movimientos_contables_on_sede_id_and_fecha"
    t.index ["sede_id"], name: "index_movimientos_contables_on_sede_id"
  end

  create_table "notas", force: :cascade do |t|
    t.string "noteable_type", null: false
    t.bigint "noteable_id", null: false
    t.bigint "club_id", null: false
    t.bigint "user_id", null: false
    t.text "contenido", null: false
    t.string "fuente", default: "manual"
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["club_id"], name: "index_notas_on_club_id"
    t.index ["deleted_at"], name: "index_notas_on_deleted_at"
    t.index ["noteable_type", "noteable_id"], name: "index_notas_on_noteable_type_and_noteable_id"
    t.index ["user_id"], name: "index_notas_on_user_id"
  end

  create_table "noticias", force: :cascade do |t|
    t.bigint "club_id", null: false
    t.string "titulo", null: false
    t.text "contenido", null: false
    t.string "cover_url"
    t.boolean "publicada", default: false, null: false
    t.datetime "publicada_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["club_id", "publicada", "publicada_at"], name: "index_noticias_on_club_id_and_publicada_and_publicada_at"
    t.index ["club_id"], name: "index_noticias_on_club_id"
    t.index ["publicada"], name: "index_noticias_on_publicada"
  end

  create_table "paciente_notas", force: :cascade do |t|
    t.bigint "club_id", null: false
    t.bigint "paciente_id", null: false
    t.text "contenido", null: false
    t.datetime "deleted_at"
    t.bigint "created_by_id", null: false
    t.bigint "deleted_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["club_id"], name: "index_paciente_notas_on_club_id"
    t.index ["deleted_at"], name: "index_paciente_notas_on_deleted_at"
    t.index ["paciente_id", "created_at"], name: "idx_socio_notas_socio_created_desc", order: { created_at: :desc }
  end

  create_table "pacientes", force: :cascade do |t|
    t.bigint "club_id", null: false
    t.string "nombre", null: false
    t.string "apellido", null: false
    t.string "dni", null: false
    t.string "dni_normalizado", null: false
    t.date "fecha_nacimiento", null: false
    t.boolean "es_paciente", default: true, null: false
    t.datetime "deleted_at"
    t.bigint "created_by_id", null: false
    t.bigint "updated_by_id"
    t.bigint "deleted_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "email"
    t.string "telefono"
    t.string "reprocann_numero"
    t.date "reprocann_vencimiento"
    t.text "notas_clinicas"
    t.boolean "con_seguimiento_medico", default: true, null: false
    t.string "reprocann_estado", default: "sin_registro", null: false
    t.decimal "limite_dispensacion_mensual_g", precision: 8, scale: 2
    t.string "carnet_token", null: false
    t.text "motivo_consulta"
    t.text "anamnesis"
    t.text "antecedentes_personales"
    t.text "antecedentes_familiares"
    t.string "diagnostico_principal"
    t.string "diagnostico_secundario"
    t.text "evolucion_clinica"
    t.text "alergias"
    t.text "medicacion_habitual"
    t.string "grupo_sanguineo", limit: 5
    t.decimal "descuento_porcentaje", precision: 5, scale: 2, default: "0.0", null: false
    t.index "lower((apellido)::text)", name: "index_socios_on_lower_apellido"
    t.index "lower((nombre)::text)", name: "index_socios_on_lower_nombre"
    t.index ["carnet_token"], name: "index_pacientes_on_carnet_token", unique: true
    t.index ["club_id"], name: "index_pacientes_on_club_id"
    t.index ["created_at"], name: "index_pacientes_on_created_at"
    t.index ["deleted_at"], name: "index_pacientes_on_deleted_at"
    t.index ["dni_normalizado"], name: "index_pacientes_on_dni_normalizado", unique: true
  end

  create_table "patient_documents", force: :cascade do |t|
    t.bigint "club_id", null: false
    t.bigint "paciente_id", null: false
    t.bigint "template_id"
    t.bigint "created_by_id", null: false
    t.string "nombre", null: false
    t.string "tipo", null: false
    t.string "estado", default: "borrador", null: false
    t.jsonb "datos", default: {}
    t.text "contenido_html"
    t.string "hash_documento"
    t.string "firma_paciente_nombre"
    t.string "firma_paciente_dni"
    t.text "firma_paciente_data"
    t.datetime "firmado_paciente_at"
    t.string "firma_medico_nombre"
    t.string "firma_medico_dni"
    t.text "firma_medico_data"
    t.datetime "firmado_medico_at"
    t.datetime "archivado_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["club_id", "estado"], name: "index_patient_documents_on_club_id_and_estado"
    t.index ["club_id", "paciente_id"], name: "index_patient_documents_on_club_id_and_paciente_id"
    t.index ["club_id", "tipo"], name: "index_patient_documents_on_club_id_and_tipo"
    t.index ["club_id"], name: "index_patient_documents_on_club_id"
    t.index ["created_by_id"], name: "index_patient_documents_on_created_by_id"
    t.index ["hash_documento"], name: "index_patient_documents_on_hash_documento", unique: true, where: "(hash_documento IS NOT NULL)"
    t.index ["paciente_id"], name: "index_patient_documents_on_paciente_id"
    t.index ["template_id"], name: "index_patient_documents_on_template_id"
  end

  create_table "pesadas", force: :cascade do |t|
    t.bigint "lote_id", null: false
    t.bigint "registrado_por_id", null: false
    t.string "fase_origen", null: false
    t.string "fase_destino", null: false
    t.decimal "peso_humedo_g", precision: 10, scale: 2
    t.decimal "peso_seco_g", precision: 10, scale: 2
    t.decimal "peso_curado_g", precision: 10, scale: 2
    t.boolean "manicurado", default: false, null: false
    t.text "notas"
    t.datetime "registrado_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "aprobada_at"
    t.bigint "aprobada_por_id"
    t.datetime "rechazada_at"
    t.bigint "rechazada_por_id"
    t.string "motivo_rechazo"
    t.integer "plantas_manicuradas"
    t.integer "plantas_cosechadas"
    t.boolean "borrador", default: false, null: false
    t.index ["aprobada_por_id"], name: "index_pesadas_on_aprobada_por_id"
    t.index ["lote_id", "borrador"], name: "index_pesadas_on_lote_id_and_borrador"
    t.index ["lote_id", "registrado_at"], name: "index_pesadas_on_lote_id_and_registrado_at"
    t.index ["lote_id"], name: "index_pesadas_on_lote_id"
    t.index ["registrado_por_id"], name: "index_pesadas_on_registrado_por_id"
  end

  create_table "pesadas_plantas", force: :cascade do |t|
    t.bigint "pesada_id", null: false
    t.bigint "plant_id", null: false
    t.decimal "peso_humedo_g", precision: 8, scale: 2
    t.decimal "peso_seco_g", precision: 8, scale: 2
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "pesaje_manicura_id"
    t.index ["pesada_id"], name: "index_pesadas_plantas_on_pesada_id"
    t.index ["pesaje_manicura_id"], name: "index_pesadas_plantas_on_pesaje_manicura_id"
    t.index ["plant_id"], name: "index_pesadas_plantas_on_plant_id"
  end

  create_table "pesajes_manicura", force: :cascade do |t|
    t.bigint "lote_id", null: false
    t.bigint "manicurador_id", null: false
    t.bigint "club_id", null: false
    t.bigint "stock_id"
    t.bigint "confirmado_por_id"
    t.date "fecha_pesaje", null: false
    t.string "estado", default: "borrador", null: false
    t.decimal "peso_total_g", precision: 10, scale: 2
    t.decimal "peso_confirmado_g", precision: 10, scale: 2
    t.integer "plantas_count"
    t.text "notas"
    t.datetime "enviado_at"
    t.datetime "confirmado_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["club_id", "estado"], name: "index_pesajes_manicura_on_club_id_and_estado"
    t.index ["club_id"], name: "index_pesajes_manicura_on_club_id"
    t.index ["confirmado_por_id"], name: "index_pesajes_manicura_on_confirmado_por_id"
    t.index ["fecha_pesaje"], name: "index_pesajes_manicura_on_fecha_pesaje"
    t.index ["lote_id", "estado"], name: "index_pesajes_manicura_on_lote_id_and_estado"
    t.index ["lote_id"], name: "index_pesajes_manicura_on_lote_id"
    t.index ["manicurador_id"], name: "index_pesajes_manicura_on_manicurador_id"
    t.index ["stock_id"], name: "index_pesajes_manicura_on_stock_id"
  end

  create_table "plan_tareas", force: :cascade do |t|
    t.bigint "plan_trabajo_id", null: false
    t.bigint "responsable_id"
    t.bigint "sala_id"
    t.bigint "tarea_generada_id"
    t.string "titulo"
    t.string "tipo", default: "otro", null: false
    t.string "prioridad", default: "normal", null: false
    t.text "descripcion"
    t.string "dias_semana"
    t.string "hora"
    t.boolean "es_recurrente", default: false, null: false
    t.string "recurrencia_id"
    t.date "fecha_especifica"
    t.boolean "origen_ia", default: false, null: false
    t.boolean "confirmada", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "dia_relativo"
    t.string "rol_sugerido"
    t.index ["plan_trabajo_id", "es_recurrente"], name: "index_plan_tareas_on_plan_trabajo_id_and_es_recurrente"
    t.index ["plan_trabajo_id"], name: "index_plan_tareas_on_plan_trabajo_id"
    t.index ["recurrencia_id"], name: "index_plan_tareas_on_recurrencia_id"
    t.index ["responsable_id"], name: "index_plan_tareas_on_responsable_id"
    t.index ["sala_id"], name: "index_plan_tareas_on_sala_id"
    t.index ["tarea_generada_id"], name: "index_plan_tareas_on_tarea_generada_id"
  end

  create_table "plan_trabajos", force: :cascade do |t|
    t.bigint "club_id", null: false
    t.bigint "creado_por_id", null: false
    t.bigint "sede_id"
    t.string "titulo", null: false
    t.integer "periodo_tipo", default: 0
    t.date "fecha_inicio"
    t.date "fecha_fin"
    t.integer "estado", default: 0, null: false
    t.boolean "repetir_automaticamente", default: false, null: false
    t.text "notas"
    t.datetime "publicado_en"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "es_plantilla", default: false, null: false
    t.index ["club_id", "estado"], name: "index_plan_trabajos_on_club_id_and_estado"
    t.index ["club_id", "fecha_inicio"], name: "index_plan_trabajos_on_club_id_and_fecha_inicio"
    t.index ["club_id"], name: "index_plan_trabajos_on_club_id"
    t.index ["creado_por_id"], name: "index_plan_trabajos_on_creado_por_id"
    t.index ["sede_id"], name: "index_plan_trabajos_on_sede_id"
  end

  create_table "plant_activities", force: :cascade do |t|
    t.bigint "plant_id", null: false
    t.bigint "user_id", null: false
    t.string "activity_type", null: false
    t.text "description"
    t.jsonb "metadata", default: {}
    t.datetime "occurred_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["activity_type"], name: "index_plant_activities_on_activity_type"
    t.index ["occurred_at"], name: "index_plant_activities_on_occurred_at"
    t.index ["plant_id"], name: "index_plant_activities_on_plant_id"
    t.index ["user_id"], name: "index_plant_activities_on_user_id"
  end

  create_table "plants", force: :cascade do |t|
    t.bigint "lote_id", null: false
    t.string "codigo_qr"
    t.string "nombre"
    t.string "state"
    t.date "fecha_germinacion"
    t.date "fecha_vegetativo"
    t.date "fecha_floracion"
    t.date "fecha_cosecha"
    t.decimal "peso_seco"
    t.text "notas"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "planta_madre_id"
    t.string "origen", default: "semilla"
    t.decimal "altura_actual", precision: 6, scale: 1
    t.integer "num_colas"
    t.string "estado_salud"
    t.string "color_hojas"
    t.boolean "es_seleccion", default: false, null: false
    t.string "pasada_cosecha"
    t.bigint "club_id"
    t.datetime "deleted_at"
    t.decimal "peso_humedo", precision: 8, scale: 2
    t.index ["club_id"], name: "index_plants_on_club_id"
    t.index ["codigo_qr"], name: "index_plants_on_codigo_qr", unique: true
    t.index ["deleted_at"], name: "index_plants_on_deleted_at"
    t.index ["lote_id", "es_seleccion"], name: "index_plants_on_lote_id_and_es_seleccion"
    t.index ["lote_id", "pasada_cosecha"], name: "idx_plants_lote_pasada"
    t.index ["lote_id"], name: "index_plants_on_lote_id"
    t.index ["origen"], name: "index_plants_on_origen"
    t.index ["planta_madre_id"], name: "index_plants_on_planta_madre_id"
  end

  create_table "push_subscriptions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "club_id", null: false
    t.string "endpoint", null: false
    t.string "p256dh_key", null: false
    t.string "auth_key", null: false
    t.string "device_name"
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["club_id"], name: "index_push_subscriptions_on_club_id"
    t.index ["endpoint"], name: "index_push_subscriptions_on_endpoint", unique: true
    t.index ["user_id"], name: "index_push_subscriptions_on_user_id"
  end

  create_table "registros_ambientales", force: :cascade do |t|
    t.bigint "lote_id", null: false
    t.bigint "user_id", null: false
    t.bigint "club_id", null: false
    t.decimal "temperatura", precision: 5, scale: 2
    t.decimal "humedad", precision: 5, scale: 2
    t.decimal "vpd", precision: 5, scale: 3
    t.decimal "co2", precision: 7, scale: 1
    t.decimal "ph", precision: 4, scale: 2
    t.decimal "ec", precision: 5, scale: 2
    t.decimal "horas_luz", precision: 4, scale: 1
    t.string "espectro_luz"
    t.string "fase_nutricional"
    t.decimal "ml_nutrientes_litro", precision: 6, scale: 2
    t.string "estado_general"
    t.text "observaciones"
    t.datetime "registrado_en", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "temperatura_sustrato", precision: 5, scale: 2
    t.decimal "ph_runoff", precision: 4, scale: 2
    t.decimal "ec_runoff", precision: 5, scale: 2
    t.decimal "ppfd", precision: 7, scale: 1
    t.string "plagas_observadas"
    t.text "notas_nutricion"
    t.string "fuente", default: "manual"
    t.string "nombre_archivo_csv"
    t.boolean "fertilizacion", default: false
    t.text "notas_fertilizacion"
    t.jsonb "tareas_realizadas", default: [], null: false
    t.index ["club_id"], name: "index_registros_ambientales_on_club_id"
    t.index ["lote_id"], name: "index_registros_ambientales_on_lote_id"
    t.index ["registrado_en"], name: "index_registros_ambientales_on_registrado_en"
    t.index ["user_id"], name: "index_registros_ambientales_on_user_id"
  end

  create_table "reglas_ambientales", force: :cascade do |t|
    t.bigint "club_id", null: false
    t.bigint "sala_id"
    t.string "nombre", null: false
    t.text "descripcion"
    t.string "tipo_lectura", null: false
    t.string "condicion", null: false
    t.decimal "umbral_a", precision: 10, scale: 4, null: false
    t.decimal "umbral_b", precision: 10, scale: 4
    t.integer "duracion_minutos", default: 5, null: false
    t.string "accion", default: "notificar", null: false
    t.string "prioridad", default: "media", null: false
    t.boolean "activa", default: true, null: false
    t.text "webhook_url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["club_id", "activa"], name: "idx_reglas_club_activa"
    t.index ["sala_id"], name: "idx_reglas_sala", where: "(sala_id IS NOT NULL)"
    t.index ["sala_id"], name: "index_reglas_ambientales_on_sala_id"
  end

  create_table "reprocann_renovaciones", force: :cascade do |t|
    t.bigint "paciente_id", null: false
    t.bigint "club_id", null: false
    t.string "estado", default: "en_tramite", null: false
    t.string "numero_tramite"
    t.date "fecha_inicio", null: false
    t.date "fecha_aprobacion"
    t.date "fecha_vencimiento_nueva"
    t.text "observaciones"
    t.string "reprocann_numero_nuevo"
    t.bigint "iniciada_por_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["club_id"], name: "index_reprocann_renovaciones_on_club_id"
    t.index ["estado"], name: "index_reprocann_renovaciones_on_estado"
    t.index ["iniciada_por_id"], name: "index_reprocann_renovaciones_on_iniciada_por_id"
    t.index ["paciente_id", "estado"], name: "index_reprocann_renovaciones_on_paciente_id_and_estado"
    t.index ["paciente_id"], name: "index_reprocann_renovaciones_on_paciente_id"
  end

  create_table "reservas", force: :cascade do |t|
    t.bigint "club_id", null: false
    t.bigint "paciente_id", null: false
    t.bigint "stock_id", null: false
    t.bigint "user_id", null: false
    t.bigint "dispensacion_id"
    t.decimal "cantidad", precision: 10, scale: 3, null: false
    t.string "estado", default: "pendiente", null: false
    t.date "fecha_entrega_estimada", null: false
    t.decimal "sena_ars", precision: 10, scale: 2, default: "0.0", null: false
    t.decimal "aporte_estimado_ars", precision: 10, scale: 2
    t.string "medio_pago"
    t.boolean "con_envio", default: false, null: false
    t.string "direccion_envio"
    t.string "contacto_nombre"
    t.string "contacto_telefono"
    t.text "notas"
    t.datetime "entregada_at"
    t.datetime "cancelada_at"
    t.datetime "vencida_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["club_id", "estado"], name: "index_reservas_on_club_id_and_estado"
    t.index ["club_id"], name: "index_reservas_on_club_id"
    t.index ["dispensacion_id"], name: "index_reservas_on_dispensacion_id"
    t.index ["fecha_entrega_estimada"], name: "index_reservas_on_fecha_entrega_estimada"
    t.index ["paciente_id"], name: "index_reservas_on_paciente_id"
    t.index ["stock_id", "estado"], name: "index_reservas_on_stock_id_and_estado"
    t.index ["stock_id"], name: "index_reservas_on_stock_id"
    t.index ["user_id"], name: "index_reservas_on_user_id"
  end

  create_table "sala_cultivadores", force: :cascade do |t|
    t.bigint "sala_id", null: false
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["sala_id", "user_id"], name: "index_sala_cultivadores_on_sala_id_and_user_id", unique: true
    t.index ["sala_id"], name: "index_sala_cultivadores_on_sala_id"
    t.index ["user_id"], name: "index_sala_cultivadores_on_user_id"
  end

  create_table "salas", force: :cascade do |t|
    t.string "nombre"
    t.string "state"
    t.integer "pots_count"
    t.text "notes"
    t.bigint "club_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "kind", default: "indoor", null: false
    t.bigint "created_by_id"
    t.string "camera_stream_url"
    t.string "camera_snapshot_url"
    t.bigint "sede_id"
    t.integer "plants_max", default: 0
    t.string "tipo", default: "cultivo", null: false
    t.datetime "deleted_at"
    t.bigint "responsable_id"
    t.index ["club_id"], name: "index_salas_on_club_id"
    t.index ["created_by_id"], name: "index_salas_on_created_by_id"
    t.index ["deleted_at"], name: "index_salas_on_deleted_at"
    t.index ["nombre"], name: "index_salas_on_nombre"
    t.index ["responsable_id"], name: "index_salas_on_responsable_id"
    t.index ["sede_id", "tipo"], name: "index_salas_on_sede_id_and_tipo"
    t.index ["sede_id"], name: "index_salas_on_sede_id"
  end

  create_table "sedes", force: :cascade do |t|
    t.bigint "club_id", null: false
    t.bigint "created_by_id", null: false
    t.string "nombre", null: false
    t.string "tipo", default: "produccion", null: false
    t.string "direccion"
    t.string "ciudad"
    t.string "provincia"
    t.string "pais", default: "Argentina"
    t.boolean "activa", default: true, null: false
    t.boolean "declarada_reprocann", default: false, null: false
    t.string "reprocann_domicilio_id"
    t.text "notas"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "deleted_at"
    t.index ["club_id", "activa"], name: "index_sedes_on_club_id_and_activa"
    t.index ["club_id", "tipo"], name: "index_sedes_on_club_id_and_tipo"
    t.index ["club_id"], name: "index_sedes_on_club_id"
    t.index ["created_by_id"], name: "index_sedes_on_created_by_id"
    t.index ["deleted_at"], name: "index_sedes_on_deleted_at"
  end

  create_table "setpoints_fase", force: :cascade do |t|
    t.bigint "club_id", null: false
    t.bigint "genetica_id"
    t.string "fase", null: false
    t.string "tipo_lectura", null: false
    t.decimal "valor_min", precision: 10, scale: 4
    t.decimal "valor_max", precision: 10, scale: 4
    t.decimal "valor_ideal", precision: 10, scale: 4
    t.string "unidad", limit: 20, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["club_id", "fase", "tipo_lectura"], name: "idx_setpoints_default", unique: true, where: "(genetica_id IS NULL)"
    t.index ["club_id", "fase"], name: "idx_setpoints_club_fase"
    t.index ["club_id", "genetica_id", "fase", "tipo_lectura"], name: "idx_setpoints_genetica", unique: true, where: "(genetica_id IS NOT NULL)"
    t.index ["genetica_id"], name: "index_setpoints_fase_on_genetica_id"
  end

  create_table "stock_movimientos", force: :cascade do |t|
    t.bigint "stock_id", null: false
    t.string "tipo", null: false
    t.decimal "gramos", precision: 10, scale: 2, null: false
    t.bigint "sede_origen_id"
    t.bigint "sede_destino_id"
    t.bigint "usuario_id", null: false
    t.text "notas"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["sede_destino_id"], name: "index_stock_movimientos_on_sede_destino_id"
    t.index ["sede_origen_id"], name: "index_stock_movimientos_on_sede_origen_id"
    t.index ["stock_id"], name: "index_stock_movimientos_on_stock_id"
    t.index ["tipo"], name: "index_stock_movimientos_on_tipo"
    t.index ["usuario_id"], name: "index_stock_movimientos_on_usuario_id"
  end

  create_table "stocks", force: :cascade do |t|
    t.bigint "sede_id"
    t.string "origen", null: false
    t.bigint "lote_id"
    t.decimal "lote_origen_consumido_g", precision: 10, scale: 2
    t.string "forma_producto", null: false
    t.string "unidad", default: "g", null: false
    t.decimal "cantidad", precision: 10, scale: 2, null: false
    t.decimal "costo_unitario_ars", precision: 10, scale: 2
    t.decimal "precio_sugerido_ars", precision: 10, scale: 2
    t.string "proveedor"
    t.string "descripcion"
    t.string "categoria"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "estado", default: "asignado", null: false
    t.bigint "pesada_id"
    t.bigint "club_id", null: false
    t.string "numero_lote_producto"
    t.date "fecha_elaboracion"
    t.date "fecha_vencimiento_est"
    t.string "codigo_qr"
    t.bigint "genetica_id"
    t.index ["club_id", "numero_lote_producto"], name: "index_stocks_on_club_id_and_numero_lote_producto", unique: true, where: "(numero_lote_producto IS NOT NULL)"
    t.index ["club_id"], name: "index_stocks_on_club_id"
    t.index ["codigo_qr"], name: "index_stocks_on_codigo_qr", unique: true, where: "(codigo_qr IS NOT NULL)"
    t.index ["estado"], name: "index_stocks_on_estado"
    t.index ["genetica_id"], name: "index_stocks_on_genetica_id"
    t.index ["lote_id", "forma_producto"], name: "index_stocks_on_lote_id_and_forma_producto"
    t.index ["lote_id"], name: "index_stocks_on_lote_id"
    t.index ["origen"], name: "index_stocks_on_origen"
    t.index ["pesada_id"], name: "index_stocks_on_pesada_id"
    t.index ["sede_id", "origen"], name: "index_stocks_on_sede_id_and_origen"
    t.index ["sede_id"], name: "index_stocks_on_sede_id"
  end

  create_table "tareas", force: :cascade do |t|
    t.bigint "club_id", null: false
    t.bigint "asignada_a_id"
    t.bigint "creada_por_id", null: false
    t.bigint "sala_id"
    t.bigint "lote_id"
    t.bigint "plant_id"
    t.string "titulo", null: false
    t.text "descripcion"
    t.string "tipo", default: "otro", null: false
    t.string "estado", default: "pendiente", null: false
    t.string "prioridad", default: "normal", null: false
    t.date "fecha_programada"
    t.datetime "fecha_completada"
    t.decimal "horas_estimadas", precision: 5, scale: 2
    t.decimal "horas_reales", precision: 5, scale: 2
    t.text "notas_completado"
    t.boolean "horas_aplicadas_al_lote", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "recurrente", default: false, null: false
    t.string "frecuencia"
    t.integer "intervalo", default: 1
    t.date "recurrencia_hasta"
    t.integer "recurrencia_veces"
    t.integer "parent_tarea_id"
    t.bigint "origen_plan_id"
    t.bigint "plan_tarea_id"
    t.bigint "aplicacion_plan_id"
    t.string "origen_plan_titulo"
    t.index ["aplicacion_plan_id"], name: "index_tareas_on_aplicacion_plan_id"
    t.index ["asignada_a_id", "estado"], name: "index_tareas_on_asignada_a_id_and_estado"
    t.index ["asignada_a_id"], name: "index_tareas_on_asignada_a_id"
    t.index ["club_id", "estado"], name: "index_tareas_on_club_id_and_estado"
    t.index ["club_id", "fecha_programada"], name: "index_tareas_on_club_id_and_fecha_programada"
    t.index ["club_id"], name: "index_tareas_on_club_id"
    t.index ["creada_por_id"], name: "index_tareas_on_creada_por_id"
    t.index ["lote_id", "horas_aplicadas_al_lote"], name: "index_tareas_on_lote_id_and_horas_aplicadas_al_lote"
    t.index ["lote_id"], name: "index_tareas_on_lote_id"
    t.index ["origen_plan_id"], name: "index_tareas_on_origen_plan_id"
    t.index ["parent_tarea_id"], name: "index_tareas_on_parent_tarea_id"
    t.index ["plan_tarea_id"], name: "index_tareas_on_plan_tarea_id"
    t.index ["plant_id"], name: "index_tareas_on_plant_id"
    t.index ["sala_id"], name: "index_tareas_on_sala_id"
  end

  create_table "turnos", force: :cascade do |t|
    t.bigint "paciente_id", null: false
    t.bigint "medico_id", null: false
    t.bigint "club_id", null: false
    t.datetime "fecha_hora", null: false
    t.integer "duracion_minutos", default: 30, null: false
    t.string "tipo", default: "seguimiento", null: false
    t.string "estado", default: "programado", null: false
    t.text "motivo"
    t.text "notas_post"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["club_id", "fecha_hora"], name: "index_turnos_on_club_id_and_fecha_hora"
    t.index ["club_id"], name: "index_turnos_on_club_id"
    t.index ["medico_id", "fecha_hora"], name: "index_turnos_on_medico_id_and_fecha_hora"
    t.index ["medico_id"], name: "index_turnos_on_medico_id"
    t.index ["paciente_id", "fecha_hora"], name: "index_turnos_on_paciente_id_and_fecha_hora"
    t.index ["paciente_id"], name: "index_turnos_on_paciente_id"
  end

  create_table "user_sedes", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "sede_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["sede_id"], name: "index_user_sedes_on_sede_id"
    t.index ["user_id", "sede_id"], name: "index_user_sedes_on_user_id_and_sede_id", unique: true
    t.index ["user_id"], name: "index_user_sedes_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "club_id"
    t.string "role", default: "cultivador", null: false
    t.string "first_name"
    t.string "last_name"
    t.string "dni"
    t.date "birth_date"
    t.string "phone"
    t.bigint "observer_club_id"
    t.string "observer_token"
    t.datetime "observer_expires_at"
    t.index ["club_id"], name: "index_users_on_club_id"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["first_name"], name: "index_users_on_first_name"
    t.index ["last_name"], name: "index_users_on_last_name"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["role"], name: "index_users_on_role"
  end

  create_table "webhook_deliveries", force: :cascade do |t|
    t.bigint "webhook_id", null: false
    t.string "event", null: false
    t.text "payload_json"
    t.string "status", default: "pending", null: false
    t.integer "http_code"
    t.integer "duration_ms"
    t.text "error_message"
    t.integer "attempts", default: 0, null: false
    t.datetime "last_attempted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["status"], name: "index_webhook_deliveries_on_status"
    t.index ["webhook_id", "created_at"], name: "index_webhook_deliveries_on_webhook_id_and_created_at"
    t.index ["webhook_id"], name: "index_webhook_deliveries_on_webhook_id"
  end

  create_table "webhooks", force: :cascade do |t|
    t.bigint "club_id", null: false
    t.bigint "created_by_id", null: false
    t.string "nombre", null: false
    t.string "url", null: false
    t.string "secret", null: false
    t.string "events", default: "[]", null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["club_id"], name: "index_webhooks_on_club_id"
    t.index ["created_by_id"], name: "index_webhooks_on_created_by_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "alertas", "lecturas_ambientales", column: "lectura_id"
  add_foreign_key "alertas", "reglas_ambientales", column: "regla_id"
  add_foreign_key "alertas", "salas"
  add_foreign_key "alertas", "users", column: "reconocida_por_id"
  add_foreign_key "alertas", "users", column: "resuelta_por_id"
  add_foreign_key "alertas_internas", "clubs"
  add_foreign_key "alertas_internas", "lotes"
  add_foreign_key "alertas_internas", "users", column: "creada_por_id"
  add_foreign_key "analisis_ia", "clubs"
  add_foreign_key "analisis_ia", "lotes"
  add_foreign_key "analisis_ia", "users"
  add_foreign_key "analisis_laboratorio", "geneticas"
  add_foreign_key "analisis_laboratorio", "lotes"
  add_foreign_key "aplicacion_planes", "clubs"
  add_foreign_key "aplicacion_planes", "plan_trabajos"
  add_foreign_key "aplicacion_planes", "users", column: "aplicado_por_id"
  add_foreign_key "ariccame_registros", "clubs"
  add_foreign_key "ariccame_registros", "dispensaciones", column: "dispensacion_id"
  add_foreign_key "ariccame_registros", "stocks"
  add_foreign_key "auditorias", "clubs"
  add_foreign_key "auditorias", "users"
  add_foreign_key "check_ins", "clubs"
  add_foreign_key "check_ins", "dispensaciones", column: "dispensacion_id"
  add_foreign_key "check_ins", "pacientes"
  add_foreign_key "conversaciones_asistente", "clubs"
  add_foreign_key "conversaciones_asistente", "users"
  add_foreign_key "costo_lotes", "clubs"
  add_foreign_key "costo_lotes", "lotes"
  add_foreign_key "costo_lotes", "users", column: "calculado_por_id"
  add_foreign_key "cuenta_corriente_movimientos", "cuenta_corrientes"
  add_foreign_key "cuenta_corriente_movimientos", "dispensaciones", column: "dispensacion_id"
  add_foreign_key "cuenta_corriente_movimientos", "users", column: "created_by_id"
  add_foreign_key "cuenta_corrientes", "clubs"
  add_foreign_key "cuenta_corrientes", "pacientes"
  add_foreign_key "dispensaciones", "indicacion_medicas"
  add_foreign_key "dispensaciones", "pacientes"
  add_foreign_key "dispensaciones", "sedes"
  add_foreign_key "dispensaciones", "stocks", on_delete: :nullify
  add_foreign_key "dispensaciones", "users"
  add_foreign_key "dispensaciones", "users", column: "delivery_id"
  add_foreign_key "disponibilidad_medicos", "clubs"
  add_foreign_key "disponibilidad_medicos", "users", column: "medico_id"
  add_foreign_key "dispositivos", "clubs"
  add_foreign_key "dispositivos", "salas"
  add_foreign_key "document_templates", "clubs"
  add_foreign_key "document_templates", "users", column: "created_by_id"
  add_foreign_key "documentos", "clubs"
  add_foreign_key "documentos", "pacientes"
  add_foreign_key "documentos", "users"
  add_foreign_key "documentos", "users", column: "subido_por_id"
  add_foreign_key "eventos", "clubs"
  add_foreign_key "geneticas", "clubs"
  add_foreign_key "indicacion_medicas", "pacientes"
  add_foreign_key "indicacion_medicas", "users"
  add_foreign_key "lecturas_ambientales", "dispositivos"
  add_foreign_key "lecturas_ambientales", "lotes"
  add_foreign_key "lecturas_ambientales", "salas"
  add_foreign_key "lecturas_ambientales_diarias", "salas"
  add_foreign_key "lote_eventos", "clubs"
  add_foreign_key "lote_eventos", "lotes"
  add_foreign_key "lote_eventos", "salas", column: "sala_destino_id"
  add_foreign_key "lote_eventos", "salas", column: "sala_origen_id"
  add_foreign_key "lote_eventos", "users"
  add_foreign_key "lotes", "clubs"
  add_foreign_key "lotes", "geneticas", on_delete: :nullify
  add_foreign_key "lotes", "plants", column: "planta_madre_id"
  add_foreign_key "lotes", "salas"
  add_foreign_key "lotes", "users", column: "manicurador_id"
  add_foreign_key "mails_enviados", "clubs"
  add_foreign_key "mails_enviados", "pacientes"
  add_foreign_key "mails_enviados", "users"
  add_foreign_key "movimientos_contables", "clubs"
  add_foreign_key "movimientos_contables", "dispensaciones", column: "dispensacion_id"
  add_foreign_key "movimientos_contables", "lotes"
  add_foreign_key "movimientos_contables", "pacientes"
  add_foreign_key "movimientos_contables", "sedes"
  add_foreign_key "movimientos_contables", "users", column: "created_by_id"
  add_foreign_key "notas", "clubs"
  add_foreign_key "notas", "users"
  add_foreign_key "noticias", "clubs"
  add_foreign_key "paciente_notas", "clubs"
  add_foreign_key "paciente_notas", "pacientes"
  add_foreign_key "paciente_notas", "users", column: "created_by_id"
  add_foreign_key "paciente_notas", "users", column: "deleted_by_id"
  add_foreign_key "pacientes", "clubs"
  add_foreign_key "pacientes", "users", column: "created_by_id"
  add_foreign_key "pacientes", "users", column: "deleted_by_id"
  add_foreign_key "pacientes", "users", column: "updated_by_id"
  add_foreign_key "patient_documents", "clubs"
  add_foreign_key "patient_documents", "document_templates", column: "template_id"
  add_foreign_key "patient_documents", "pacientes"
  add_foreign_key "patient_documents", "users", column: "created_by_id"
  add_foreign_key "pesadas", "lotes"
  add_foreign_key "pesadas", "users", column: "aprobada_por_id"
  add_foreign_key "pesadas", "users", column: "rechazada_por_id"
  add_foreign_key "pesadas", "users", column: "registrado_por_id"
  add_foreign_key "pesadas_plantas", "pesadas"
  add_foreign_key "pesadas_plantas", "pesajes_manicura", column: "pesaje_manicura_id"
  add_foreign_key "pesadas_plantas", "plants"
  add_foreign_key "pesajes_manicura", "clubs"
  add_foreign_key "pesajes_manicura", "lotes"
  add_foreign_key "pesajes_manicura", "stocks"
  add_foreign_key "pesajes_manicura", "users", column: "confirmado_por_id"
  add_foreign_key "pesajes_manicura", "users", column: "manicurador_id"
  add_foreign_key "plan_tareas", "plan_trabajos"
  add_foreign_key "plan_tareas", "salas"
  add_foreign_key "plan_tareas", "tareas", column: "tarea_generada_id"
  add_foreign_key "plan_tareas", "users", column: "responsable_id"
  add_foreign_key "plan_trabajos", "clubs"
  add_foreign_key "plan_trabajos", "sedes"
  add_foreign_key "plan_trabajos", "users", column: "creado_por_id"
  add_foreign_key "plant_activities", "plants"
  add_foreign_key "plant_activities", "users"
  add_foreign_key "plants", "clubs"
  add_foreign_key "plants", "lotes"
  add_foreign_key "push_subscriptions", "clubs"
  add_foreign_key "push_subscriptions", "users"
  add_foreign_key "registros_ambientales", "clubs"
  add_foreign_key "registros_ambientales", "lotes"
  add_foreign_key "registros_ambientales", "users"
  add_foreign_key "reglas_ambientales", "salas"
  add_foreign_key "reprocann_renovaciones", "clubs"
  add_foreign_key "reprocann_renovaciones", "pacientes"
  add_foreign_key "reprocann_renovaciones", "users", column: "iniciada_por_id"
  add_foreign_key "reservas", "clubs"
  add_foreign_key "reservas", "dispensaciones", column: "dispensacion_id"
  add_foreign_key "reservas", "pacientes"
  add_foreign_key "reservas", "stocks"
  add_foreign_key "reservas", "users"
  add_foreign_key "sala_cultivadores", "salas"
  add_foreign_key "sala_cultivadores", "users"
  add_foreign_key "salas", "clubs"
  add_foreign_key "salas", "sedes"
  add_foreign_key "salas", "users", column: "created_by_id"
  add_foreign_key "salas", "users", column: "responsable_id"
  add_foreign_key "sedes", "clubs"
  add_foreign_key "sedes", "users", column: "created_by_id"
  add_foreign_key "setpoints_fase", "geneticas"
  add_foreign_key "stock_movimientos", "sedes", column: "sede_destino_id"
  add_foreign_key "stock_movimientos", "sedes", column: "sede_origen_id"
  add_foreign_key "stock_movimientos", "stocks"
  add_foreign_key "stock_movimientos", "users", column: "usuario_id"
  add_foreign_key "stocks", "clubs"
  add_foreign_key "stocks", "geneticas"
  add_foreign_key "stocks", "lotes"
  add_foreign_key "stocks", "pesadas"
  add_foreign_key "stocks", "sedes"
  add_foreign_key "tareas", "aplicacion_planes", column: "aplicacion_plan_id"
  add_foreign_key "tareas", "clubs"
  add_foreign_key "tareas", "lotes"
  add_foreign_key "tareas", "plan_tareas"
  add_foreign_key "tareas", "plan_trabajos", column: "origen_plan_id"
  add_foreign_key "tareas", "salas"
  add_foreign_key "tareas", "users", column: "asignada_a_id"
  add_foreign_key "tareas", "users", column: "creada_por_id"
  add_foreign_key "turnos", "clubs"
  add_foreign_key "turnos", "pacientes"
  add_foreign_key "turnos", "users", column: "medico_id"
  add_foreign_key "user_sedes", "sedes"
  add_foreign_key "user_sedes", "users"
  add_foreign_key "users", "clubs"
  add_foreign_key "webhook_deliveries", "webhooks"
  add_foreign_key "webhooks", "clubs"
  add_foreign_key "webhooks", "users", column: "created_by_id"
end
