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
  }.freeze

  # Depósitos de sistema y su nombre por defecto. Dispensación aloja la flor/derivados (fase 3).
  CLAVES_SISTEMA = {
    'cultivo'      => 'Cultivo',
    'general'      => 'General',
    'salon'        => 'Salón',
    'dispensacion' => 'Dispensación',
  }.freeze

  # Familia contable/operativa que deriva del depósito (reemplaza al viejo "comportamiento").
  # Los depósitos propios se comportan como 'general' salvo que se indique otra cosa.
  FAMILIA = {
    'cultivo'      => 'insumo',
    'general'      => 'insumo_general',
    'salon'        => 'mercaderia',
    'dispensacion' => 'mercaderia',
  }.freeze

  validates :nombre, presence: true
  validates :clave_sistema, inclusion: { in: CLAVES_SISTEMA.keys }, allow_nil: true
  # Un depósito de sistema por (club, sede, clave): cada sede tiene su Cultivo, General, etc.
  validates :clave_sistema, uniqueness: { scope: %i[club_id sede_id] }, allow_nil: true

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
