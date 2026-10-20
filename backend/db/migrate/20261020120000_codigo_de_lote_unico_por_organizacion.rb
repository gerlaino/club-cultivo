# El código de un lote no se repite dentro de una organización (20-oct-2026). `Lote` ya lo valida,
# pero lo que escribe sin validar (la mudanza `cultivo:mudar`, `update_columns`) dejó cinco
# repetidos en el Club Modelo: dos plantas «L-26-001-P001» en el buscador y una trazabilidad que no
# sabe de cuál se habla. Producción se revisó antes con `lotes:codigos_repetidos`: sin repetidos.
#
# Parcial, igual que la validación: los eliminados (paranoia) y los sin código no cuentan.
class CodigoDeLoteUnicoPorOrganizacion < ActiveRecord::Migration[7.2]
  def change
    add_index :lotes, %i[club_id codigo], unique: true,
              where: 'deleted_at IS NULL AND codigo IS NOT NULL',
              name: 'index_lotes_codigo_unico_por_club'
  end
end
