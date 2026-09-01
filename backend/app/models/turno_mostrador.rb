# Turno del mostrador: la caja de turno, pero con mercadería. Ver la migración
# `CreateTurnosMostrador` para el porqué del diseño.
#
# Esqueleto de B0: la estructura y las relaciones. Abrir, operar y cerrar llegan en B1–B3.
class TurnoMostrador < ApplicationRecord
  acts_as_tenant(:club)

  # Se audita por el mismo motivo que la caja de plata: acá se decide quién abrió, quién recibió,
  # quién cerró y con qué números — y el cierre AJUSTA EL INVENTARIO REAL. La caja se auditaba
  # "porque es plata"; esto mueve mercadería, que es lo mismo con otra unidad.
  #
  # Allowlist: si mañana aparece una columna, entra al rastro sólo si alguien la agrega a
  # propósito.
  include Auditable
  auditar_solo :estado, :abierto_por_id, :confirmado_por_id, :cerrado_por_id, :revisado_por_id,
               :notas_apertura, :notas_cierre

  belongs_to :club
  belongs_to :mostrador
  belongs_to :caja_turno,     optional: true
  belongs_to :turno_anterior, class_name: 'TurnoMostrador', optional: true
  belongs_to :abierto_por,  class_name: 'User'
  belongs_to :cerrado_por,  class_name: 'User', optional: true
  belongs_to :revisado_por, class_name: 'User', optional: true
  # Quien ATIENDE confirma que lo que declaró el admin está sobre la mesa.
  belongs_to :confirmado_por, class_name: 'User', optional: true

  has_many :items, class_name: 'TurnoMostradorItem', dependent: :destroy

  ESTADOS = %w[abierto cerrado anulado].freeze

  validates :estado, inclusion: { in: ESTADOS }

  scope :abiertos,  -> { where(estado: 'abierto') }
  scope :cerrados,  -> { where(estado: 'cerrado') }
  scope :recientes, -> { order(abierto_at: :desc) }

  def confirmado? = confirmado_at.present?

  # Listo para atender: abierto Y recibido por quien va a responder por la mercadería.
  def operativo? = abierto? && confirmado?

  # Avisar que la mesa cambió. La pantalla del que atiende no se enteraba de que el admin le
  # bajó producto desde su oficina hasta que recargaba — con el paquete ya sobre el mostrador.
  after_commit :avisar_cambio

  def abierto? = estado == 'abierto'
  def cerrado? = estado == 'cerrado'
  def anulado? = estado == 'anulado'

  delegate :sede, :sede_id, to: :mostrador

  # Se usa el canal del club, que ya existe: es la misma conexión y el mismo alcance. Un fallo
  # de ActionCable no puede tumbar una apertura ni un cierre, así que va con rescue.
  def avisar_cambio
    ActionCable.server.broadcast("stocks_club_#{club_id}", {
      tipo: 'mostrador_actualizado', mostrador_id: mostrador_id, sede_id: sede_id,
    })
  rescue => e
    Rails.logger.warn "TurnoMostrador#avisar_cambio falló: #{e.message}"
  end
end
