# Una tarea de riego dice CÓMO regar: con qué receta, cuántos litros y a qué pH/EC (Germán,
# 12-oct-2026). Al completarla se registra el riego del lote con eso precargado.
class AgregarRiegoATareas < ActiveRecord::Migration[7.2]
  def change
    add_reference :tareas, :receta, foreign_key: { to_table: :recetas }, null: true
    add_column :tareas, :riego_litros, :decimal, precision: 8, scale: 2
    add_column :tareas, :riego_ph,     :decimal, precision: 4, scale: 2
    add_column :tareas, :riego_ec,     :decimal, precision: 5, scale: 2
  end
end
