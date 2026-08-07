class ReprocannRenovacion < ApplicationRecord
  include Restorable
  self.table_name = 'reprocann_renovaciones'

  ESTADOS = %w[en_tramite aprobada rechazada].freeze

  belongs_to :paciente
  belongs_to :club
  acts_as_tenant(:club)
  belongs_to :iniciada_por, class_name: 'User', optional: true

  validates :estado,       inclusion: { in: ESTADOS }
  validates :fecha_inicio, presence: true

  scope :activas,    -> { where(estado: 'en_tramite') }
  scope :recientes,  -> { order(created_at: :desc) }

  def aprobar!(reprocann_numero_nuevo: nil, fecha_vencimiento_nueva: nil)
    update!(
      estado:                 'aprobada',
      fecha_aprobacion:       Time.zone.today,
      reprocann_numero_nuevo: reprocann_numero_nuevo,
      fecha_vencimiento_nueva: fecha_vencimiento_nueva,
    )
    if reprocann_numero_nuevo.present?
      paciente.update!(reprocann_numero: reprocann_numero_nuevo)
    end
    if fecha_vencimiento_nueva.present?
      paciente.update!(reprocann_vencimiento: fecha_vencimiento_nueva)
    end
  end

  def rechazar!(observaciones: nil)
    update!(estado: 'rechazada', observaciones: observaciones)
  end
end
