# El formulario de /bienvenida: organizaciones, uso personal que prefiere hablar, y el «botón de
# arrepentimiento». Se guarda (`SolicitudContacto`) y se avisa al super admin por push y por mail;
# si el aviso falla, la consulta igual queda en el panel.
module Public
  class ContactoController < BaseController
    self.public_tenant_mode = :token

    def create
      return head :created if params[:sitio].present? # campo trampa: ver RegistroController

      s = SolicitudContacto.new(params.permit(:tipo, :nombre, :email, :telefono, :organizacion, :mensaje)
                                      .to_h.transform_values { |v| v.to_s.strip.presence })
      s.email = s.email&.downcase
      s.ip = request.remote_ip
      if s.save
        avisar(s)
        render json: { ok: true, codigo: s.codigo }, status: :created
      else
        render json: { error: s.errors.full_messages.first || 'Revisá los datos.' }, status: :unprocessable_entity
      end
    end

    private

    def avisar(s)
      AccesoMailer.acuse_consulta(solicitud: s).deliver_later
      titulo = s.tipo == 'baja' ? 'Pedido de arrepentimiento / baja' : "Consulta nueva: #{s.tipo_label}"
      User.where(role: 'super_admin').find_each do |u|
        PushNotificationService.notify_user_async(u, tipo: 'consulta_nueva', title: titulo,
                                                     body: "#{s.nombre} (#{s.email})", url: '/super-admin/consultas')
        destino = u.email_real
        AccesoMailer.nueva_consulta(solicitud: s, para: destino).deliver_later if destino.present?
      end
    rescue StandardError => e
      # El aviso es accesorio: la consulta ya está guardada.
      Rails.logger.warn("[contacto] no se pudo avisar: #{e.message}")
    end
  end
end
