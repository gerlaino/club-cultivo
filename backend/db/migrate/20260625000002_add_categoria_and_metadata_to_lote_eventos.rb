class AddCategoriaAndMetadataToLoteEventos < ActiveRecord::Migration[7.2]
  # Eventos de lote tipados (backfill de historia real): `categoria` discrimina la
  # actividad (riego/fertilizacion/poda/…) cuando tipo='actividad', y `metadata`
  # guarda el detalle estructurado (ferti: producto + EC, riego: EC/volumen, etc.).
  def change
    add_column :lote_eventos, :categoria, :string
    add_column :lote_eventos, :metadata,  :jsonb, null: false, default: {}
    add_index  :lote_eventos, :categoria
  end
end
