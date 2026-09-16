# Con quién hablo y qué quedamos. La ficha tenía razón social y sitio web, pero no había dónde
# anotar «habló con Juan el 3/9, quiere Delivery en octubre» ni quién es Juan. Y la próxima
# acción con fecha es lo que alimenta la cola del panel: sin ella, cada llamada pendiente vivía
# en la cabeza de quien vende.
#
# `club_notas` NO es tenant: la escribe el super admin, que no tiene organización fijada, y con
# `require_tenant=true` un modelo tenant reventaría. Es dato de la PLATAFORMA sobre la
# organización, no de la organización.
class AddCrmMinimoAClubs < ActiveRecord::Migration[7.2]
  def change
    add_column :clubs, :contacto_nombre,   :string
    add_column :clubs, :proxima_accion,    :string
    add_column :clubs, :proxima_accion_el, :date
    add_index  :clubs, :proxima_accion_el

    create_table :club_notas do |t|
      t.references :club, null: false, foreign_key: true
      t.references :user, null: true,  foreign_key: true
      t.text :texto, null: false
      t.timestamps
    end
  end
end
