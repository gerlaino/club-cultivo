class CreateDocumentos < ActiveRecord::Migration[7.2]
  def change

    # ── Templates de documentos (los crea el admin) ──────────────────
    create_table :document_templates do |t|
      t.references :club,       null: false, foreign_key: true
      t.references :created_by, null: false, foreign_key: { to_table: :users }

      t.string  :nombre,       null: false
      t.string  :tipo,         null: false   # consentimiento_informado | indicacion_medica | declaracion_jurada | informe_semestral | otro
      t.text    :descripcion
      t.text    :contenido_html              # HTML con variables {{nombre}}, {{dni}}, etc.
      t.jsonb   :campos,       default: []   # definición de campos variables
      t.boolean :activo,       default: true, null: false
      t.boolean :requiere_firma_paciente,  default: false, null: false
      t.boolean :requiere_firma_medico,    default: false, null: false

      t.timestamps
    end

    add_index :document_templates, [:club_id, :tipo]
    add_index :document_templates, [:club_id, :activo]

    # ── Documentos generados por paciente ────────────────────────────
    create_table :patient_documents do |t|
      t.references :club,      null: false, foreign_key: true
      t.references :socio,     null: false, foreign_key: true
      t.references :template,  null: true,  foreign_key: { to_table: :document_templates }
      t.references :created_by, null: false, foreign_key: { to_table: :users }

      t.string  :nombre,       null: false
      t.string  :tipo,         null: false   # mismo enum que template
      t.string  :estado,       null: false, default: 'borrador'  # borrador | pendiente_firma | firmado | archivado
      t.jsonb   :datos,        default: {}   # valores de los campos variables
      t.text    :contenido_html              # HTML final con datos interpolados
      t.string  :hash_documento             # SHA256 del contenido para integridad

      # Firmas
      t.string  :firma_paciente_nombre
      t.string  :firma_paciente_dni
      t.text    :firma_paciente_data        # base64 del canvas
      t.datetime :firmado_paciente_at

      t.string  :firma_medico_nombre
      t.string  :firma_medico_dni
      t.text    :firma_medico_data          # base64 del canvas
      t.datetime :firmado_medico_at

      t.datetime :archivado_at

      t.timestamps
    end

    add_index :patient_documents, [:club_id, :socio_id]
    add_index :patient_documents, [:club_id, :tipo]
    add_index :patient_documents, [:club_id, :estado]
    add_index :patient_documents, :hash_documento, unique: true, where: "hash_documento IS NOT NULL"
  end
end
