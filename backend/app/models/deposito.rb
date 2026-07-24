# Depósito: contenedor lógico de mercadería del club (Cultivo, General, Salón, Dispensación, y
# los que cree el admin). Reemplaza al enum `tipo` de Insumo. Es transversal a la sede: un mismo
# depósito puede tener stock en varias sedes (la sede vive en el producto, no en el depósito).
#
# Los de sistema (`clave_sistema` presente, `es_sistema: true`) se siembran y no se borran ni se
# renombran a una clave distinta; el admin puede crear los propios (clave nil).
class Deposito < ApplicationRecord
  acts_as_paranoid
  acts_as_tenant(:club)

  belongs_to :club
  has_many :insumos, dependent: :restrict_with_error

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
  validates :clave_sistema, uniqueness: { scope: :club_id }, allow_nil: true

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
