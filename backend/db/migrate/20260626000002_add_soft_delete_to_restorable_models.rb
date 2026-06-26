class AddSoftDeleteToRestorableModels < ActiveRecord::Migration[7.2]
  # Fundación del soft-delete unificado (papelera/restauración). Set curado de modelos de
  # negocio/regulatorios. Excluye logs (auditorias, webhooks), auth (jwt_denylists), telemetría
  # masiva (lecturas/registros ambientales), efímeros (push, conversaciones, alertas internas).
  # Todo aditivo y nullable: no cambia datos existentes (deleted_at IS NULL = vigente).

  # Necesitan deleted_at + deleted_by_id.
  NEW_TABLES = %w[
    alertas analisis_ia analisis_laboratorio aplicacion_planes ariccame_registros
    check_ins cobros costo_lotes cuenta_corriente_movimientos cuenta_corrientes
    dispensaciones disponibilidad_medicos dispositivos document_templates documentos
    eventos geneticas indicacion_medicas jornadas_laborales lote_eventos
    mails_enviados movimientos_contables noticias patient_documents pesadas
    pesadas_plantas pesajes_manicura plan_tareas plan_trabajos plant_activities
    reglas_ambientales reprocann_renovaciones reservas rutas_entrega sala_cultivadores
    setpoints_fase stock_movimientos stocks tareas turnos
    user_sedes users
  ].freeze

  # Ya tienen deleted_at (paranoia/manual): solo falta el rastro de quién borró.
  EXISTING_NEED_DELETED_BY = %w[clubs lotes notas plants salas sedes].freeze

  def change
    NEW_TABLES.each do |t|
      add_column t, :deleted_at, :datetime unless column_exists?(t, :deleted_at)
      add_index  t, :deleted_at unless index_exists?(t, :deleted_at)
    end

    (NEW_TABLES + EXISTING_NEED_DELETED_BY).each do |t|
      next if column_exists?(t, :deleted_by_id)
      add_reference t, :deleted_by, null: true, foreign_key: { to_table: :users }
    end
  end
end
