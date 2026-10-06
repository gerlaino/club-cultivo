# Lo que una organización compra POR ENCIMA de su escalón (6-oct-2026): packs de 10 pacientes
# (cada uno suma 10 pacientes y 90 plantas en floración) y sedes extra. Son cantidades, no
# banderas: van en columnas y no en `features`.
class AgregarExtrasDePlanAClubs < ActiveRecord::Migration[7.2]
  def change
    add_column :clubs, :packs_pacientes_extra, :integer, default: 0, null: false
    add_column :clubs, :sedes_extra,           :integer, default: 0, null: false
  end
end
