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
  # El contenido de la mesa: permanente, del mostrador y no del turno.
  has_many :items, class_name: 'MostradorItem', dependent: :destroy

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

  # Lo que hay sobre la mesa ahora. Cero filas no es lo mismo que "cerrado": el mostrador existe
  # siempre, y puede estar vacío esperando que el admin lo cargue.
  def sobre_la_mesa = items.con_stock.includes(:stock)

  def vacio? = !items.con_stock.exists?

  # El renglón de un producto, creándolo si hace falta. Es la puerta de entrada de todo lo que
  # sube a la mesa: el admin cargando, un reparto que vuelve, una dispensa revertida.
  def item_de!(stock)
    items.create_with(club: club, cantidad: 0).find_or_create_by!(stock_id: stock.id)
  rescue ActiveRecord::RecordNotUnique
    items.reset
    items.find_by!(stock_id: stock.id)
  end

  # La mesa cambió: que la pantalla de quien está atendiendo lo refleje sin recargar. Recargar es
  # justo lo que nadie hace cuando tiene a alguien esperando enfrente.
  def avisar_cambio
    ActionCable.server.broadcast("stocks_club_#{club_id}", {
      tipo: 'mostrador_actualizado', mostrador_id: id, sede_id: sede_id,
    })
  rescue => e
    Rails.logger.warn "Mostrador#avisar_cambio falló: #{e.message}"
  end

  private

  def sede_habilitada
    return if sede.nil? || sede.es_social?

    errors.add(:sede, 'debe ser una sede social o mixta para tener mostrador')
  end
end
