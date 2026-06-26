class PreferencesController < ApplicationController
  include Rails.application.routes.url_helpers
  before_action :authenticate_user!
  before_action :require_club_user!
  before_action :set_club

  def show
    render json: serialize(@club)
  end

  def update
    if ActiveModel::Type::Boolean.new.cast(params[:purge_logo])
      @club.logo.purge if @club.logo.attached?
    end

    if (ac = params.dig(:club, :alertas_config))
      @club.alertas_config = ac.is_a?(ActionController::Parameters) ? ac.to_unsafe_h : ac
    end

    if @club.update(club_params)
      render json: serialize(@club)
    else
      render json: { errors: @club.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def upload_logo
    unless params[:logo].present?
      return render json: { errors: ["Archivo no recibido"] }, status: :bad_request
    end

    @club.logo.purge if @club.logo.attached?
    @club.logo.attach(params[:logo])

    if @club.logo.attached?
      render json: serialize(@club)
    else
      render json: { errors: ["No se pudo adjuntar el logo"] }, status: :unprocessable_entity
    end
  end

  # PATCH /preferences/twilio
  def update_twilio
    unless current_user.admin? || current_user.super_admin?
      return render json: { error: 'Sin permiso' }, status: :forbidden
    end

    raw_token = params[:twilio_auth_token]
    @club.twilio_account_sid    = params[:twilio_account_sid]   if params[:twilio_account_sid].present?
    @club.twilio_auth_token     = raw_token                      if raw_token.present?
    @club.twilio_whatsapp_from  = params[:twilio_whatsapp_from] if params[:twilio_whatsapp_from].present?

    if @club.save
      render json: {
        twilio_configurado:    @club.twilio_configurado?,
        twilio_account_sid:    @club.twilio_account_sid,
        twilio_whatsapp_from:  @club.twilio_whatsapp_from,
      }
    else
      render json: { errors: @club.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /preferences/twilio
  def destroy_twilio
    unless current_user.admin? || current_user.super_admin?
      return render json: { error: 'Sin permiso' }, status: :forbidden
    end

    @club.update!(twilio_account_sid: nil, twilio_auth_token_enc: nil, twilio_whatsapp_from: nil)
    render json: { twilio_configurado: false }
  end

  # POST /preferences/test_twilio
  def test_twilio
    unless @club.twilio_configurado?
      return render json: { error: 'WhatsApp no configurado' }, status: :unprocessable_entity
    end

    telefono_destino = current_user.phone.presence
    unless telefono_destino
      return render json: { error: 'Tu perfil no tiene número de teléfono configurado. Agregá uno en tu perfil para probar.' }, status: :unprocessable_entity
    end

    client = Twilio::REST::Client.new(@club.twilio_account_sid, @club.twilio_auth_token)
    limpio  = telefono_destino.gsub(/[^0-9+]/, '')
    numero  = limpio.start_with?('+') ? limpio : (limpio.start_with?('0') ? "+54#{limpio[1..]}" : "+54#{limpio}")

    client.messages.create(
      from: @club.twilio_whatsapp_from,
      to:   "whatsapp:#{numero}",
      body: "✅ Prueba exitosa de WhatsApp para #{@club.name}. Las notificaciones de delivery están listas."
    )

    render json: { ok: true, enviado_a: numero }
  rescue Twilio::REST::RestError => e
    render json: { error: "Error Twilio: #{e.message}" }, status: :unprocessable_entity
  rescue => e
    render json: { error: "Error de conexión: #{e.message}" }, status: :unprocessable_entity
  end

  def test_smtp
    unless @club.smtp_configured?
      return render json: { error: 'SMTP no configurado' }, status: :unprocessable_entity
    end

    dest = current_user.email
    Mail.deliver do
      from    "#{@club.smtp_from_name.presence || @club.name} <#{@club.smtp_from.presence || @club.smtp_user}>"
      to      dest
      subject "✓ Prueba de correo — #{@club.name}"
      body    "Este es un correo de prueba enviado desde Club Cultivo para verificar la configuración SMTP del club #{@club.name}."
      delivery_method :smtp, @club.smtp_settings
    end

    render json: { ok: true, enviado_a: dest }
  rescue => e
    render json: { error: "Error de conexión SMTP: #{e.message}" }, status: :unprocessable_entity
  end

  # PATCH /preferences/conectar_email — el club conecta su propia casilla. Solo carga email +
  # contraseña de aplicación (+ nombre opcional); el servidor/puerto se autodetectan del dominio.
  # Verifica la conexión ANTES de guardar (manda un mail de confirmación al admin).
  def conectar_email
    return render json: { error: 'Sin permiso' }, status: :forbidden unless current_user.admin? || current_user.super_admin?

    email    = params[:email].to_s.strip
    password = params[:app_password].to_s.strip
    nombre   = params[:from_name].to_s.strip.presence || @club.name
    return render json: { error: 'Ingresá el email del club.' }, status: :unprocessable_entity if email.blank?
    return render json: { error: 'Ingresá la contraseña de aplicación.' }, status: :unprocessable_entity if password.blank?

    proveedor = Club.smtp_provider_for(email)
    host = params[:smtp_host].presence || proveedor&.dig(:host)
    port = (params[:smtp_port].presence || proveedor&.dig(:port) || 587).to_i
    if host.blank?
      return render json: { error: 'No reconocemos ese proveedor. Si no es Gmail/Outlook/Yahoo, indicá el servidor SMTP.' }, status: :unprocessable_entity
    end

    settings = { address: host, port: port, user_name: email, password: password,
                 authentication: :plain, enable_starttls_auto: true }
    # En test no abrimos conexión SMTP real (usa el delivery :test).
    metodo, opts_envio = Rails.env.test? ? [:test, {}] : [:smtp, settings]
    begin
      destino = current_user.email
      Mail.deliver do
        from    "#{nombre} <#{email}>"
        to      destino
        subject "✓ Correo conectado — #{nombre}"
        body    "Tu casilla quedó conectada a Club Cultivo. Desde ahora los correos del club salen desde acá."
        delivery_method metodo, opts_envio
      end
    rescue => e
      return render json: { error: "No se pudo conectar: #{e.message}. Revisá el email y la contraseña de aplicación." }, status: :unprocessable_entity
    end

    @club.update!(smtp_host: host, smtp_port: port, smtp_user: email, smtp_pass: password,
                  smtp_from: email, smtp_from_name: nombre)
    render json: serialize(@club)
  end

  # DELETE /preferences/desconectar_email — vuelve al modo plataforma-gestionado.
  def desconectar_email
    return render json: { error: 'Sin permiso' }, status: :forbidden unless current_user.admin? || current_user.super_admin?
    @club.update!(smtp_host: nil, smtp_port: nil, smtp_user: nil, smtp_pass: nil, smtp_from: nil, smtp_from_name: nil)
    render json: serialize(@club)
  end

  private

  def require_club_user!
    return head :no_content if current_user.super_admin?
  end

  def set_club
    @club = current_user.club
  end

  def club_params
    # fetch (no require): hay requests legítimos sin clave :club (ej. purge_logo
    # suelto), que con require devolvían 400 ParameterMissing.
    params.fetch(:club, {}).permit(
      :name, :legal_name, :email, :phone, :website,
      :address, :city, :state, :timezone, :theme_primary,
      :cuit, :numero_igj, :numero_resolucion_reprocann,
      :fecha_resolucion_reprocann, :tipo_organizacion,
      :descripcion_web, :whatsapp, :instagram_url,
      :facebook_url, :horarios_atencion, :web_activa,
      :benchmark_opt_in,
      :smtp_host, :smtp_port, :smtp_user, :smtp_pass,
      :smtp_from, :smtp_from_name,
      :umbral_stock_g
    )
  end

  def serialize(club)
    {
      id:                           club.id,
      name:                         club.name,
      legal_name:                   club.legal_name,
      email:                        club.email,
      phone:                        club.phone,
      website:                      club.website,
      address:                      club.address,
      city:                         club.city,
      state:                        club.state,
      timezone:                     club.timezone,
      theme_primary:                club.theme_primary,
      cuit:                         club.cuit,
      numero_igj:                   club.numero_igj,
      numero_resolucion_reprocann:  club.numero_resolucion_reprocann,
      fecha_resolucion_reprocann:   club.fecha_resolucion_reprocann,
      tipo_organizacion:            club.tipo_organizacion,
      logo_url:                     club.logo.attached? ? url_for(club.logo) : nil,
      descripcion_web:              club.descripcion_web,
      whatsapp:                     club.whatsapp,
      instagram_url:                club.instagram_url,
      facebook_url:                 club.facebook_url,
      horarios_atencion:            club.horarios_atencion,
      web_activa:                   club.web_activa,
      benchmark_opt_in:             club.benchmark_opt_in,
      features:                     club.features,
      smtp_configured:              club.smtp_configured?,
      smtp_host:                    club.smtp_host,
      smtp_port:                    club.smtp_port || 587,
      smtp_user:                    club.smtp_user,
      smtp_from:                    club.smtp_from,
      smtp_from_name:               club.smtp_from_name,
      email_modo:                   club.email_propio? ? 'propio' : 'plataforma',
      email_remitente:              club.email_from,
      email_reply_to:               club.email_reply_to,
      # smtp_pass / twilio_auth_token_enc nunca se serializan
      twilio_configurado:           club.twilio_configurado?,
      twilio_account_sid:           club.twilio_account_sid,
      twilio_whatsapp_from:         club.twilio_whatsapp_from,
      umbral_stock_g:               club.umbral_stock_g,
      alertas_config:               club.alertas_config || {},
    }
  end
end
