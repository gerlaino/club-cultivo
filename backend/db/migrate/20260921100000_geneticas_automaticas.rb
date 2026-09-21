# Una genética automática florece sola (a las 3–4 semanas de la germinación) y no depende de
# bajar la luz: no hay «pasar a floración» que decidir, vive en la sala de vegetativo todo el
# ciclo y se cosecha desde ahí. Lo que dice el banco es «tantos días de semilla a cosecha»,
# y eso es `dias_ciclo_objetivo`; el lote lo hereda al crearse, como los otros objetivos.
# Decisión de Germán (21-sep-2026): un solo tilde, y la floración queda como anotación opcional.
class GeneticasAutomaticas < ActiveRecord::Migration[7.2]
  def change
    add_column :geneticas, :automatica,          :boolean, default: false, null: false
    add_column :geneticas, :dias_ciclo_objetivo, :integer
    add_column :lotes,     :dias_ciclo_objetivo, :integer
  end
end
