class Pesada < ApplicationRecord
  include Restorable
  belongs_to :lote
  belongs_to :registrado_por,  class_name: 'User'
  belongs_to :aprobada_por,    class_name: 'User', optional: true, foreign_key: :aprobada_por_id
  belongs_to :rechazada_por,   class_name: 'User', optional: true, foreign_key: :rechazada_por_id

  has_many :pesadas_plantas, class_name: 'PesadaPlanta', dependent: :destroy
  has_many :stocks,          dependent: :nullify

  FASES_VALIDAS = %w[vegetativo floracion cosecha en_manicura secado manicura_pendiente curado finalizado].freeze

  validates :fase_origen,  inclusion: { in: FASES_VALIDAS }
  validates :fase_destino, inclusion: { in: FASES_VALIDAS }
  validates :registrado_at, presence: true
  validate  :peso_requerido_segun_destino

  def merma_porcentual
    previa = lote.pesadas.where('registrado_at < ?', registrado_at).order(registrado_at: :desc).first
    return nil unless previa

    peso_previo = previa.peso_curado_g || previa.peso_seco_g || previa.peso_humedo_g
    peso_actual = peso_curado_g || peso_seco_g || peso_humedo_g
    return nil if peso_previo.nil? || peso_previo.zero? || peso_actual.nil?

    ((1 - peso_actual.to_d / peso_previo.to_d) * 100).round(1)
  end

  private

  def peso_requerido_segun_destino
    return if borrador?
    case fase_destino
    when 'curado'             then errors.add(:peso_seco_g,   'requerido para entrada a curado')   unless peso_seco_g.present?
    when 'finalizado'
      # curado → finalizado necesita peso_curado_g; en_manicura/secado → finalizado necesita peso_seco_g
      unless peso_curado_g.present? || peso_seco_g.present?
        errors.add(:base, 'Se requiere peso (seco o curado) para finalizar el lote')
      end
    when 'manicura_pendiente' then errors.add(:peso_seco_g,   'requerido para manicura')           unless peso_seco_g.present?
    end
  end
end
