# Lo que la plataforma configura y no es de ninguna organización (12-oct-2026). Hoy: el precio en
# pesos del autocultivo, que se carga en super admin y usa la suscripción de Mercado Pago.
class AjustePlataforma < ApplicationRecord
  self.table_name = 'ajustes_plataforma'

  belongs_to :actualizado_por, class_name: 'User', optional: true
  validates :clave, presence: true, uniqueness: true

  PRECIO_AUTOCULTIVO = 'precio_autocultivo_ars'.freeze

  def self.leer(clave) = find_by(clave: clave)&.valor
  def self.escribir!(clave, valor, por: nil)
    a = find_or_initialize_by(clave: clave)
    a.update!(valor: valor, actualizado_por: por)
    a
  end

  # nil mientras no se cargó: sin precio no se ofrece suscribirse.
  def self.precio_autocultivo_ars
    v = leer(PRECIO_AUTOCULTIVO)
    v.is_a?(Hash) ? v['monto']&.to_d : nil
  end
end
