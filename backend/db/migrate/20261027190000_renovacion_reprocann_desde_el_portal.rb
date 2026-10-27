# El paciente sube la constancia de renovación de su REPROCANN desde el portal y queda EN REVISIÓN
# hasta que administración la mira y carga la fecha nueva (27-oct-2026). Se usa la tabla de
# renovaciones que ya existía (`ReprocannRenovacion`, sin pantalla hasta hoy): la constancia va
# adjunta (Active Storage, sin columna), `origen` dice de dónde vino y `revisada_por` quién la
# aprobó o la rechazó.
class RenovacionReprocannDesdeElPortal < ActiveRecord::Migration[7.2]
  def change
    add_column :reprocann_renovaciones, :origen, :string, null: false, default: 'organizacion'
    add_reference :reprocann_renovaciones, :revisada_por, foreign_key: { to_table: :users }
    add_column :reprocann_renovaciones, :revisada_at, :datetime
  end
end
