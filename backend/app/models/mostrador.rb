# El MOSTRADOR: el punto de venta del dispensario. Hermano de `Barra`, que es el del buffet.
#
#   Sede (social o mixta)
#    ├── Barra      → CajaTurno
#    └── Mostrador  → CajaTurno + TurnoMostrador (la mercadería sobre la mesa)
#
# Antes la caja del dispensario apuntaba a la `Sede` porque esta entidad no existía. Eso dejaba
# dos ideas de "punto de venta" conviviendo y ninguna forma de decir "este stock está sobre la
# mesa de este mostrador".
#
# El esquema admite varios por sede (dos ventanillas con su propio cajón), pero se siembra UNO.
# Quién atiende cada mostrador NO necesita tabla nueva: `UserSede` ya asigna dispensadores a
# sedes y el mostrador es de la sede — asignar la sede ya asigna el mostrador.
class Mostrador < ApplicationRecord
  include Restorable
  acts_as_tenant(:club)

  belongs_to :club
  belongs_to :sede

  has_many :caja_turnos, as: :punto
  has_many :turno_mostradores, dependent: :destroy

  validates :nombre, presence: true
  # Sólo al CREAR: una sede puede cambiar de tipo, y volver inguardable un mostrador que ya
  # existe impediría hasta renombrarlo.
  validate :sede_habilitada, on: :create

  scope :activos, -> { where(activo: true) }

  # La caja de plata abierta ahora en este mostrador, o nil.
  def caja_abierta = caja_turnos.abiertas.first

  # La que "ocupa" el mostrador: abierta o esperando el visto del admin.
  def caja_activa  = caja_turnos.activas.first

  # El turno de mercadería abierto ahora, o nil. Tolerante mientras la tabla no esté migrada,
  # igual que `Barra#caja_abierta`: una feature nueva sin migrar no debe romper el mostrador.
  def turno_abierto
    return nil unless TurnoMostrador.table_exists?

    turno_mostradores.abiertos.first
  end

  private

  def sede_habilitada
    return if sede.nil? || sede.es_social?

    errors.add(:sede, 'debe ser una sede social o mixta para tener mostrador')
  end
end
