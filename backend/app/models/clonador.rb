# Un clonador (domo, propagador, cámara de esquejes) dentro de una SALA.
#
# Regla de fotoperíodo: solo puede vivir en una sala que corra 18/6. Un clonador en una sala de
# FLORACIÓN recibiría 12 horas de oscuridad, y un esqueje sin raíz necesita luz casi continua para
# prender. No es una preferencia: es un error de cultivo, por eso es una validación dura.
class Clonador < ApplicationRecord
  include Restorable
  acts_as_tenant(:club)

  belongs_to :club
  belongs_to :sala
  # TODOS los lotes que enraizaron acá, hayan salido o no: `clonador_id` es del lote para siempre.
  # Es lo que permite cruzar el % de prendimiento POR CLONADOR —una manta térmica muerta se ve
  # como un clonador con mal prendimiento; por genética se ve como ruido—.
  has_many :lotes, dependent: :nullify
  has_many :registros_ambientales, dependent: :nullify

  # Vegetativo, madre, clon y mixta corren 18/6 (o más). Floración es la única incompatible.
  KINDS_INCOMPATIBLES = %w[floracion].freeze

  validates :nombre, presence: true
  validates :capacidad, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validate  :sala_con_fotoperiodo_compatible

  scope :activos, -> { where(activo: true) }

  # UN CLONADOR ALOJA UN SOLO LOTE A LA VEZ. En el domo real pueden convivir esquejes de varias
  # genéticas, pero en la app se abstrae igual que el lote: tantos clonadores como agrupaciones
  # homogéneas haya. Así el domo tiene una historia limpia y su prendimiento significa algo.
  # (`has_many :lotes` sigue siendo muchos A LO LARGO DEL TIEMPO: uno prende, sale, y entra otro.)
  #
  # Estar adentro no es un flag que haya que mantener: se deriva del estado —enraizando adentro,
  # prendido afuera—, así que no se puede desincronizar.
  def lotes_adentro = lotes.where(estado: 'enraizado')
  def lote_adentro  = lotes_adentro.first
  def ocupado? = lotes_adentro.exists?

  # Cuántos alvéolos ocupan hoy. Las descartadas no ocupan: el alvéolo quedó libre.
  def ocupados
    Plant.where(lote_id: lotes_adentro.select(:id)).where.not(state: 'descartada').count
  end

  def disponibles = capacidad ? [capacidad - ocupados, 0].max : nil

  private

  def sala_con_fotoperiodo_compatible
    return if sala.blank?
    return unless KINDS_INCOMPATIBLES.include?(sala.kind)

    errors.add(:sala, 'está en floración (12/12) y los esquejes necesitan luz casi continua para prender')
  end
end
