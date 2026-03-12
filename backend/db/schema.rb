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

ActiveRecord::Schema[7.2].define(version: 2026_03_12_204310) do
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
  end

  create_table "dispensaciones", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "socio_id", null: false
    t.bigint "user_id", null: false
    t.bigint "indicacion_medica_id"
    t.bigint "lote_id"
    t.decimal "cantidad_gramos", precision: 8, scale: 2, null: false
    t.string "tipo_producto", default: "flores", null: false
    t.text "observaciones"
    t.date "fecha_dispensacion", null: false
    t.index ["fecha_dispensacion"], name: "index_dispensaciones_on_fecha_dispensacion"
    t.index ["indicacion_medica_id"], name: "index_dispensaciones_on_indicacion_medica_id"
    t.index ["lote_id"], name: "index_dispensaciones_on_lote_id"
    t.index ["socio_id", "fecha_dispensacion"], name: "index_dispensaciones_on_socio_id_and_fecha_dispensacion"
    t.index ["socio_id"], name: "index_dispensaciones_on_socio_id"
    t.index ["user_id"], name: "index_dispensaciones_on_user_id"
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
    t.bigint "club_id", null: false
    t.string "nombre", null: false
    t.text "descripcion"
    t.decimal "thc", precision: 5, scale: 2
    t.decimal "cbd", precision: 5, scale: 2
    t.boolean "disponible", default: true, null: false
    t.boolean "activa", default: true, null: false
    t.string "tipo"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["activa"], name: "index_geneticas_on_activa"
    t.index ["club_id", "activa"], name: "index_geneticas_on_club_id_and_activa"
    t.index ["club_id"], name: "index_geneticas_on_club_id"
  end

  create_table "indicacion_medicas", force: :cascade do |t|
    t.bigint "socio_id", null: false
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
    t.index ["socio_id"], name: "index_indicacion_medicas_on_socio_id"
    t.index ["user_id"], name: "index_indicacion_medicas_on_user_id"
  end

  create_table "jwt_denylists", force: :cascade do |t|
    t.string "jti"
    t.datetime "exp"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["jti"], name: "index_jwt_denylists_on_jti"
  end

  create_table "lotes", force: :cascade do |t|
    t.string "code"
    t.date "start_date"
    t.string "stage"
    t.integer "plants_count"
    t.string "strain"
    t.text "notes"
    t.bigint "sala_id", null: false
    t.bigint "club_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "grow_type"
    t.string "light_type"
    t.string "state"
    t.index ["club_id"], name: "index_lotes_on_club_id"
    t.index ["sala_id"], name: "index_lotes_on_sala_id"
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
    t.bigint "genetica_id"
    t.string "state"
    t.date "fecha_germinacion"
    t.date "fecha_vegetativo"
    t.date "fecha_floracion"
    t.date "fecha_cosecha"
    t.decimal "peso_seco"
    t.text "notas"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["codigo_qr"], name: "index_plants_on_codigo_qr", unique: true
    t.index ["genetica_id"], name: "index_plants_on_genetica_id"
    t.index ["lote_id"], name: "index_plants_on_lote_id"
  end

  create_table "salas", force: :cascade do |t|
    t.string "name"
    t.string "state"
    t.integer "pots_count"
    t.text "notes"
    t.bigint "club_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "kind"
    t.bigint "created_by_id", null: false
    t.string "camera_stream_url"
    t.string "camera_snapshot_url"
    t.index ["club_id"], name: "index_salas_on_club_id"
    t.index ["created_by_id"], name: "index_salas_on_created_by_id"
  end

  create_table "socio_nota", force: :cascade do |t|
    t.bigint "socio_id", null: false
    t.bigint "user_id", null: false
    t.text "contenido"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "deleted_at"
    t.index ["deleted_at"], name: "index_socio_nota_on_deleted_at"
    t.index ["socio_id"], name: "index_socio_nota_on_socio_id"
    t.index ["user_id"], name: "index_socio_nota_on_user_id"
  end

  create_table "socio_notas", force: :cascade do |t|
    t.bigint "club_id", null: false
    t.bigint "socio_id", null: false
    t.text "contenido", null: false
    t.datetime "deleted_at"
    t.bigint "created_by_id", null: false
    t.bigint "deleted_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["club_id"], name: "index_socio_notas_on_club_id"
    t.index ["deleted_at"], name: "index_socio_notas_on_deleted_at"
    t.index ["socio_id", "created_at"], name: "idx_socio_notas_socio_created_desc", order: { created_at: :desc }
  end

  create_table "socios", force: :cascade do |t|
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
    t.string "reprocann_adjunto"
    t.index "lower((apellido)::text)", name: "index_socios_on_lower_apellido"
    t.index "lower((nombre)::text)", name: "index_socios_on_lower_nombre"
    t.index ["club_id"], name: "index_socios_on_club_id"
    t.index ["created_at"], name: "index_socios_on_created_at"
    t.index ["deleted_at"], name: "index_socios_on_deleted_at"
    t.index ["dni_normalizado"], name: "index_socios_on_dni_normalizado", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "club_id", null: false
    t.string "role", default: "cultivador", null: false
    t.string "first_name"
    t.string "last_name"
    t.string "dni"
    t.date "birth_date"
    t.string "phone"
    t.index ["club_id"], name: "index_users_on_club_id"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["first_name"], name: "index_users_on_first_name"
    t.index ["last_name"], name: "index_users_on_last_name"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["role"], name: "index_users_on_role"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "dispensaciones", "indicacion_medicas"
  add_foreign_key "dispensaciones", "lotes"
  add_foreign_key "dispensaciones", "socios"
  add_foreign_key "dispensaciones", "users"
  add_foreign_key "eventos", "clubs"
  add_foreign_key "geneticas", "clubs"
  add_foreign_key "indicacion_medicas", "socios"
  add_foreign_key "indicacion_medicas", "users"
  add_foreign_key "lotes", "clubs"
  add_foreign_key "lotes", "salas"
  add_foreign_key "noticias", "clubs"
  add_foreign_key "plant_activities", "plants"
  add_foreign_key "plant_activities", "users"
  add_foreign_key "plants", "geneticas"
  add_foreign_key "plants", "lotes"
  add_foreign_key "salas", "clubs"
  add_foreign_key "salas", "users", column: "created_by_id"
  add_foreign_key "socio_nota", "socios"
  add_foreign_key "socio_nota", "users"
  add_foreign_key "socio_notas", "clubs"
  add_foreign_key "socio_notas", "socios"
  add_foreign_key "socio_notas", "users", column: "created_by_id"
  add_foreign_key "socio_notas", "users", column: "deleted_by_id"
  add_foreign_key "socios", "clubs"
  add_foreign_key "socios", "users", column: "created_by_id"
  add_foreign_key "socios", "users", column: "deleted_by_id"
  add_foreign_key "socios", "users", column: "updated_by_id"
  add_foreign_key "users", "clubs"
end
