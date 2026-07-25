# Un bar del club, ligado a una sede social o mixta. Es una entidad independiente: sus
# productos, ventas, caja y resultado son propios de esa sede. Un club puede tener varios
# (uno por sede social/mixta). Recuperable desde la papelera.
#
# Se llama `Barra` (no `Bar`) para no chocar con el namespace `Bar::` de los controllers y
# servicios (Zeitwerk no admite una constante que sea clase y módulo a la vez). La tabla es
# `bares` y la UI dice "bar".
class Barra < ApplicationRecord
  self.table_name = 'bares'

  include Restorable
  acts_as_tenant(:club)

  belongs_to :club
  belongs_to :sede
  # La FK real es bar_id (el modelo se llama Barra, así que hay que declararla explícita: si no,
  # Rails inferiría barra_id y rompería con "columna inexistente").
  has_many :bar_productos, foreign_key: :bar_id, dependent: :destroy
  has_many :bar_ventas,    foreign_key: :bar_id, dependent: :destroy
  has_many :eventos_bar,   class_name: 'EventoBar', foreign_key: :bar_id, dependent: :destroy
  has_many :caja_turnos,   foreign_key: :bar_id
  # Las cajas se borran con el bar, pero solo si la tabla ya existe (feature nueva sin migrar
  # no debe romper el borrado del bar).
  before_destroy { caja_turnos.destroy_all if CajaTurno.table_exists? }

  # Caja de turno abierta ahora (o nil). Una sola por bar (índice único parcial).
  # Tolerante: si la tabla caja_turnos todavía no fue migrada, devuelve nil (la caja queda
  # inactiva) en vez de romper el panel/POS. Se activa sola al correr la migración.
  def caja_abierta
    return nil unless CajaTurno.table_exists?

    caja_turnos.abiertas.first
  end

  # Caja que "ocupa" el bar: abierta o pendiente de cierre (esperando el visto del admin).
  # Es la que ve el panel/chip; las ventas siguen enganchándose solo a caja_abierta.
  def caja_activa
    return nil unless CajaTurno.table_exists?

    caja_turnos.activas.first
  end

  validates :nombre, presence: true
  validate  :sede_habilitada
  validate  :una_por_sede, on: :create

  scope :activos, -> { where(activo: true) }

  # Resultado del bar en un período = ingresos − egresos del libro etiquetados con esta sede
  # y la unidad de negocio "Bar". Es la fuente de verdad contable (no se calcula de las ventas).
  def resultado_periodo(desde, hasta)
    movs = club.movimientos_contables
               .where(sede_id: sede_id, unidad_negocio_id: unidad_negocio_bar&.id)
               .del_periodo(desde, hasta)
    ingresos = movs.ingresos.sum(:monto_ars)
    egresos  = movs.egresos.sum(:monto_ars)
    { ingresos: ingresos.to_f, egresos: egresos.to_f, resultado: (ingresos - egresos).to_f }
  end

  # Unidad de negocio "Bar" del club (compartida por todos los bares; el aislamiento por bar
  # se logra con la sede). La crea si el catálogo no fue sembrado.
  def unidad_negocio_bar
    @unidad_negocio_bar ||= club.unidades_negocio.create_with(nombre: 'Bar', es_sistema: true)
                                .find_or_create_by!(tipo: 'bar')
  end

  private

  def sede_habilitada
    return if sede.nil?
    return if sede.es_social?

    errors.add(:sede, 'debe ser una sede social o mixta para tener bar')
  end

  def una_por_sede
    return if sede_id.nil?
    return unless club&.bares&.where(sede_id: sede_id)&.exists?

    errors.add(:sede, 'ya tiene un bar')
  end
end
