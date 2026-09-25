# Un ciclo de una cama: desde que se planta el primer lote hasta que sale el último. Es lo que
# deja comparar la misma cama cosecha tras cosecha («ciclo 3: 480 g/m², ciclo 2: 410») y ver si el
# suelo mejora. Lo abre y lo cierra el lote (`Lote#ocupar_cama` / `Cama#cerrar_ciclo_si_vacia!`).
class CamaCiclo < ApplicationRecord
  include Transmite
  transmite_como 'camas'
  acts_as_tenant(:club)

  belongs_to :club
  belongs_to :cama
  has_many :lotes, dependent: :nullify
  has_many :registros, class_name: 'CamaRegistro', dependent: :nullify

  validates :numero, numericality: { only_integer: true, greater_than: 0 }
  validates :desde, presence: true

  def abierto? = hasta.nil?

  # Los gramos secos de los lotes del ciclo. Sólo cuentan los que ya tienen rendimiento.
  def gramos = lotes.sum(:rendimiento_real_g).to_d

  # g/m² contra la cama entera: en un ciclo la cama es la superficie que produjo.
  def g_m2
    m2 = cama.m2
    return nil if m2.nil? || m2.zero? || gramos <= 0
    (gramos / m2).round(1)
  end

  def dias(hoy = Time.zone.today) = ((hasta || hoy) - desde).to_i
end
