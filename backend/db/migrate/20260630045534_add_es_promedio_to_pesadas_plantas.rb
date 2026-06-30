class AddEsPromedioToPesadasPlantas < ActiveRecord::Migration[7.2]
  def change
    # Marca un peso por planta como estimado (promedio de una carga conjunta del lote),
    # para distinguirlo de un peso medido individualmente. Default false.
    add_column :pesadas_plantas, :es_promedio, :boolean, default: false, null: false
  end
end
