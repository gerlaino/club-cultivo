class Club < ApplicationRecord
  has_many :users, dependent: :restrict_with_error
  has_many :salas, dependent: :destroy
  has_many :lotes, dependent: :destroy
  has_many :socios, dependent: :destroy
  has_many :geneticas, dependent: :destroy
  has_many :noticias, dependent: :destroy
  has_many :eventos, dependent: :destroy
  has_many :sedes, dependent: :destroy
  has_many :movimientos_contables, class_name: "MovimientoContable", dependent: :destroy
  has_many :costo_lotes, class_name: "CostoLote", dependent: :destroy
  has_many :tareas, dependent: :destroy

  has_one_attached :logo

  validates :name, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
end
