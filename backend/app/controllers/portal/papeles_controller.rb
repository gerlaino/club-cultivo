module Portal
  # Sus papeles: el REPROCANN y la renovación que sube él (27-oct-2026).
  #
  #   GET  /portal/papeles              su REPROCANN y la última renovación que subió (y en qué quedó)
  #   POST /portal/papeles/renovacion   subir la constancia de renovación (foto o PDF)
  #
  # Lo que sube NO cambia nada solo: queda «en revisión» hasta que administración la aprueba y
  # carga el vencimiento nuevo (`ReprocannRenovacionesController#update`). Mientras, sigue
  # retirando como hasta ahora.
  class PapelesController < BaseController
    def show
      return render json: { data: { reprocann: nil, renovacion: nil } } if ficha.nil?

      render json: { data: { reprocann: reprocann_json, renovacion: renovacion_json(ultima_renovacion) } }
    end

    def renovacion
      return render json: { error: 'Tu cuenta no tiene ficha de paciente.' }, status: :unprocessable_entity if ficha.nil?
      return render json: { error: 'Elegí la foto o el PDF de la constancia.' }, status: :unprocessable_entity if params[:constancia].blank?

      nueva = nil
      ActiveRecord::Base.transaction do
        # Una sola en revisión: si sube otra (la anterior no se leía), reemplaza a la pendiente.
        ficha.reprocann_renovaciones.del_portal.where(estado: 'en_tramite').find_each(&:destroy!)
        nueva = ficha.reprocann_renovaciones.new(club: current_club, origen: 'portal', estado: 'en_tramite',
                                                 fecha_inicio: Time.zone.today, iniciada_por: current_user)
        nueva.constancia.attach(params[:constancia])
        nueva.save!
      end
      nueva.avisar_a_la_organizacion!
      PushNotificationService.notify_roles_async(
        current_club, 'admin', title: "#{ficha.nombre} #{ficha.apellido}".strip + ' subió su renovación del REPROCANN',
        body: 'Revisala y cargá el vencimiento nuevo.', url: "/pacientes/#{ficha.id}?tab=reprocann", tipo: 'renovacion_subida'
      )
      render json: { data: renovacion_json(nueva) }, status: :created
    rescue ActiveRecord::RecordInvalid => e
      render json: { error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
    end

    private

    def ficha
      @ficha ||= current_club.pacientes.find_by(user_id: current_user.id)
    end

    def ultima_renovacion = ficha.reprocann_renovaciones.del_portal.recientes.first

    def reprocann_json
      dias = ficha.reprocann_vencimiento && (ficha.reprocann_vencimiento - Time.zone.today).to_i
      {
        numero:      ficha.reprocann_numero,
        vencimiento: ficha.reprocann_vencimiento,
        dias_para_vencer: dias,
        categoria:   Paciente.reprocann_categoria(estado: ficha.reprocann_estado_efectivo, numero: ficha.reprocann_numero,
                                                  vencimiento: ficha.reprocann_vencimiento),
      }
    end

    def renovacion_json(r)
      return nil unless r

      {
        id: r.id, estado: r.estado, subida_at: r.created_at, revisada_at: r.revisada_at,
        # El motivo, si la rechazaron: es para él («la foto no se lee, subila de nuevo»).
        observaciones: r.estado == 'rechazada' ? r.observaciones : nil,
        vencimiento_nuevo: r.fecha_vencimiento_nueva,
        constancia: r.constancia.attached? ? { nombre: r.constancia.filename.to_s, url: url_for(r.constancia) } : nil,
      }
    end
  end
end
