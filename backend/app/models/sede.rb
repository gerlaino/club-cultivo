class Sede < ApplicationRecord
  belongs_to :club
  belongs_to :created_by, class_name: 'User'

  has_many :salas,               dependent: :nullify
  has_many :inventario_items,    dependent: :destroy
  has_many :inventario_movimientos, dependent: :destroy
  has_many :dispensaciones,      dependent: :nullify

  TIPOS = %w[produccion social mixta].freeze
  TIPO_LABELS = {
    'produccion' => 'Producción',
    'social'     => 'Social / Dispensario',
    'mixta'      => 'Mixta',
  }.freeze

  validates :nombre, presence: true
  validates :tipo,   inclusion: { in: TIPOS }

  scope :activas,     -> { where(activa: true) }
  scope :produccion,  -> { where(tipo: ['produccion', 'mixta']) }
  scope :social,      -> { where(tipo: ['social', 'mixta']) }

  def tipo_label
    TIPO_LABELS[tipo] || tipo
  end

  def es_produccion?
    %w[produccion mixta].include?(tipo)
  end

  def es_social?
    %w[social mixta].include?(tipo)
  end
end