# Lo que alguien dejó en el formulario de /bienvenida. Se guarda SIEMPRE (el correo de la
# plataforma puede fallar) y le llega al super admin como push y, si hay correo, por mail.
#
# `baja` es el «botón de arrepentimiento» (Res. SCI 424/2020): quien contrató por internet puede
# revocar la aceptación dentro de los 10 días, y el pedido tiene que poder hacerse desde la
# página, sin registrarse ni dar explicaciones.
class SolicitudContacto < ApplicationRecord
  self.table_name = 'solicitudes_contacto'

  TIPOS = {
    'organizacion' => 'Organización',
    'personal'     => 'Uso personal',
    'baja'         => 'Arrepentimiento / baja',
  }.freeze

  belongs_to :atendida_por, class_name: 'User', optional: true

  validates :tipo,   inclusion: { in: TIPOS.keys }
  validates :nombre, presence: true, length: { maximum: 120 }
  validates :email,  presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }, length: { maximum: 160 }
  validates :telefono,     length: { maximum: 40 }
  validates :organizacion, length: { maximum: 160 }
  validates :mensaje,      length: { maximum: 3000 }

  scope :pendientes, -> { where(atendida_at: nil) }

  def tipo_label = TIPOS[tipo]

  # El código de trámite que se le da a quien escribe. Para el arrepentimiento es obligatorio
  # (Res. SCI 424/2020: dentro de las 24 h); se da en el momento, a todos.
  def codigo = "CE-#{id.to_s.rjust(6, '0')}"
end
