# Lo que el super admin le contestó a una consulta de /bienvenida. Ver la migración que la crea.
class ConsultaRespuesta < ApplicationRecord
  self.table_name = 'consulta_respuestas'

  belongs_to :solicitud_contacto
  belongs_to :autor, class_name: 'User', foreign_key: :user_id

  validates :texto, presence: true, length: { maximum: 5000 }
end
