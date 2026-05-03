class ExtendDocumentos < ActiveRecord::Migration[7.2]
  def change
    add_column :documentos, :subido_por_id, :bigint
    add_column :documentos, :paciente_id,   :bigint

    add_foreign_key :documentos, :users,     column: :subido_por_id
    add_foreign_key :documentos, :pacientes, column: :paciente_id

    add_index :documentos, :subido_por_id
    add_index :documentos, :paciente_id
  end
end
