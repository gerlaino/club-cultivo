# Depósito: contenedor de mercadería de una SEDE (Cultivo, General, Salón, Dispensación, y los que
# cree el admin). Reemplaza al enum `tipo` de Insumo. Multi-sede: cada sede tiene sus depósitos
# (la sede vive en el depósito). Los legacy sin sede (`sede_id` nil) los sede-ifica SembrarDepositos.
#
# Los de sistema (`clave_sistema` presente, `es_sistema: true`) se siembran y no se borran ni se
# renombran a una clave distinta; el admin puede crear los propios (clave nil).
class Deposito < ApplicationRecord
  acts_as_paranoid
  acts_as_tenant(:club)

  belongs_to :club
  belongs_to :sede, optional: true # la sede a la que pertenece (nil = legacy club-wide, pre multi-sede)
  belongs_to :unidad_negocio, optional: true # el área a la que pertenece (para el P&L)
  has_many :insumos, dependent: :restrict_with_error

  # Área (unidad de negocio) por defecto de cada depósito de sistema.
  AREA_TIPO_POR_CLAVE = {
    'cultivo'      => 'cultivo',
    'general'      => 'administracion',
    'salon'        => 'bar',
    'dispensacion' => 'dispensario',
    'otro'         => 'otro',
  }.freeze

  # Depósitos de sistema y su nombre por defecto. Dispensación aloja la flor/derivados (fase 3).
  # UN depósito por SECTOR y por SEDE. Los cinco sectores (ver UnidadNegocio::CANONICOS) tienen
  # el suyo; cuáles se siembran en cada sede depende del tipo de sede.
  CLAVES_SISTEMA = {
    'cultivo'      => 'Cultivo',
    'general'      => 'General',
    'salon'        => 'Salón',
    'dispensacion' => 'Dispensación',
    'otro'         => 'Otro',
  }.freeze

  # Familia contable/operativa que deriva del depósito (reemplaza al viejo "comportamiento").
  # Los depósitos propios se comportan como 'general' salvo que se indique otra cosa.
  FAMILIA = {
    'cultivo'      => 'insumo',
    'general'      => 'insumo_general',
    'salon'        => 'mercaderia',
    'dispensacion' => 'mercaderia',
    'otro'         => 'insumo_general',
  }.freeze

  validates :nombre, presence: true
  validates :clave_sistema, inclusion: { in: CLAVES_SISTEMA.keys }, allow_nil: true
  # Un depósito de sistema por (club, sede, clave): cada sede tiene su Cultivo, General, etc.
  # La validación da el mensaje lindo; la garantía real la da el índice único parcial
  # `index_depositos_sistema_unico` (una validación no protege de una race, y la siembra corre
  # desde un before_action: dos requests simultáneos duplicaban los depósitos del club).
  validates :clave_sistema, uniqueness: { scope: %i[club_id sede_id] }, allow_nil: true
  # UN depósito por sector y por sede. Sin esto, cada área nueva sumaba otro depósito al mismo
  # sector y no había forma de saber cuál era el bueno: el alta de una compra ofrecía tres
  # "Cultivo" y el stock terminaba repartido entre ellos.
  #
  # Sólo frena los NUEVOS: si una organización ya quedó con duplicados, se siguen pudiendo
  # guardar y corregir (una validación no puede volver inguardable lo que ya existe).
  validates :unidad_negocio_id,
            uniqueness: { scope: %i[club_id sede_id],
                          conditions: -> { where(deleted_at: nil) },
                          message: 'ya tiene un depósito en esta sede' },
            allow_nil: true, on: :create

  scope :activos,   -> { where(activo: true) }
  scope :ordenados, -> { order(:orden, :nombre) }
  scope :sistema,   -> { where(es_sistema: true) }

  def familia
    FAMILIA[clave_sistema] || 'general'
  end

  # El depósito de Salón depende del feature bar; el resto siempre disponible.
  def disponible_para?(club)
    return club.feature?(:bar) if clave_sistema == 'salon'

    true
  end
end
