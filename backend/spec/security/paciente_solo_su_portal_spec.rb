require 'rails_helper'

# EL PACIENTE SÓLO LLEGA A SU PORTAL (28-oct-2026, Germán: «al iniciar sesión el paciente vería lo del
# paciente, nada más, ¿eso está bien seguro?»).
#
# Hasta hoy NO lo estaba: un paciente logueado pedía `/api/pacientes` y recibía el padrón entero de su
# organización. Este spec barre TODAS las rutas de la API con la sesión de un paciente (y los ids de
# OTRO paciente de su organización y de otra organización) y exige:
#
#   - Fuera de su portal, ninguna le contesta nada: 401/403/404/405.
#   - En lo que sí puede pedir, nunca aparece el nombre ni el DNI de otro paciente.
#   - La sesión no se cae a mitad del barrido (si se cayera, el resto daría 401 y el spec mentiría).
#
# Una ruta nueva del equipo queda cubierta sola: no hay que acordarse de agregarla acá.
RSpec.describe 'El paciente sólo llega a su portal', type: :request do
  include AuthHelpers

  let(:club) { create(:club, vista_paciente_activa: true, features: { 'produccion_dispensa' => true, 'vista_paciente' => true }) }
  let(:otra) { create(:club, vista_paciente_activa: true, features: { 'produccion_dispensa' => true, 'vista_paciente' => true }) }

  # Lo que el paciente sí puede pedir: su portal, su sesión y lo público.
  PERMITIDO = lambda do |controller|
    controller.start_with?('portal/', 'public/') ||
      %w[portal_acceso me push_subscriptions users/sessions users/passwords health profile].include?(controller)
  end

  def rutas
    Rails.application.routes.routes.filter_map do |r|
      path  = r.path.spec.to_s.sub('(.:format)', '')
      verbo = r.verb.to_s[/GET|POST|PATCH|PUT|DELETE/]
      next unless verbo && path.start_with?('/api/')
      next if path.start_with?('/api/users/sign_out', '/api/users/sign_in')

      [verbo, path, r.defaults[:controller].to_s]
    end.uniq
  end

  it 'fuera de su portal no le contesta nada ninguna ruta, y en su portal nunca ve a otro paciente' do
    ActsAsTenant.test_tenant = club
    yo   = create(:paciente, club: club, nombre: 'Yo', dni: '30111222', aprobado_at: Time.current, email: 'yo@example.com')
    otro = create(:paciente, club: club, nombre: 'Vecinodelpadron', dni: '30999888', aprobado_at: Time.current, email: 'vecino@example.com')
    ajeno = ActsAsTenant.with_tenant(otra) do
      create(:paciente, club: otra, nombre: 'Deotraorganizacion', dni: '31777666', aprobado_at: Time.current)
    end
    user = Pacientes::Acceso.crear!(yo).user
    user.update!(password: AuthHelpers::DEFAULT_PASSWORD, password_confirmation: AuthHelpers::DEFAULT_PASSWORD)
    sign_in_as(user)

    abiertas = []
    filtran  = []
    caidas   = []
    [otro.id, ajeno.id].each do |id|
      rutas.each do |verbo, path, controller|
        url = path.gsub(/:token/, 'x').gsub(/:\w+/, id.to_s).gsub(/\*\w+/, 'x')
        begin
          send(verbo.downcase, url, as: :json)
        rescue StandardError => e
          abiertas << "EXC #{e.class} #{verbo} #{path} (#{controller})"
          next
        end
        status = response.status
        cuerpo = response.body.to_s

        if PERMITIDO.call(controller)
          filtran << "#{verbo} #{path}" if cuerpo.include?('Vecinodelpadron') || cuerpo.include?('30999888') ||
                                           cuerpo.include?('Deotraorganizacion') || cuerpo.include?('31777666')
        elsif ![401, 403, 404, 405].include?(status)
          abiertas << "#{status} #{verbo} #{path} (#{controller})"
        end

        get '/api/me', as: :json
        next if response.status == 200

        caidas << "#{verbo} #{path}"
        sign_in_as(user)
      end
    end

    expect(abiertas).to be_empty, "Rutas del equipo que le contestan a un paciente:\n#{abiertas.uniq.join("\n")}"
    expect(filtran).to be_empty, "Respuestas con datos de otro paciente:\n#{filtran.uniq.join("\n")}"
    expect(caidas).to be_empty, "La sesión se cayó (el barrido no valdría):\n#{caidas.uniq.join("\n")}"
  end

  it 'el padrón de su organización le contesta 403' do
    ActsAsTenant.test_tenant = club
    yo = create(:paciente, club: club, dni: '30111222', aprobado_at: Time.current, email: 'yo@example.com')
    user = Pacientes::Acceso.crear!(yo).user
    user.update!(password: AuthHelpers::DEFAULT_PASSWORD, password_confirmation: AuthHelpers::DEFAULT_PASSWORD)
    sign_in_as(user)

    %w[/api/pacientes /api/socios /api/preferences /api/stats /api/plantillas_mail /api/buscar?q=a].each do |u|
      get u, as: :json
      expect(response).to have_http_status(:forbidden), u
    end
  end

  it 'del perfil sólo puede su clave y sus avisos, no cambiar su usuario' do
    ActsAsTenant.test_tenant = club
    yo = create(:paciente, club: club, dni: '30111222', aprobado_at: Time.current, email: 'yo@example.com')
    user = Pacientes::Acceso.crear!(yo).user
    user.update!(password: AuthHelpers::DEFAULT_PASSWORD, password_confirmation: AuthHelpers::DEFAULT_PASSWORD)
    sign_in_as(user)

    patch '/api/profile', params: { user: { email: 'otro@x.com' } }, as: :json
    expect(response).to have_http_status(:forbidden)
    get '/api/profile/notificaciones', as: :json
    expect(response).to have_http_status(:ok)
  end

  # Recargar /portal (Ctrl+Shift+R, un link, el ícono instalado) pide la PÁGINA al servidor, que la
  # sirve `application#spa_fallback`. La barrera la dejaba afuera y el paciente veía el 403 en JSON
  # en lugar de su portal (29-oct-2026). El barrido de arriba mira sólo /api: esto mira la página.
  describe 'la página de la app' do
    let(:index_html) { Rails.root.join('public', 'index.html') }

    around do |ex|
      creado = !index_html.exist?
      File.write(index_html, '<!doctype html><title>app</title><div id="app">CASCARA</div>') if creado
      ex.run
    ensure
      File.delete(index_html) if creado && index_html.exist?
    end

    it 'le carga al paciente logueado en cualquier dirección del portal' do
      ActsAsTenant.test_tenant = club
      yo = create(:paciente, club: club, dni: '30111222', aprobado_at: Time.current, email: 'yo@example.com')
      user = Pacientes::Acceso.crear!(yo).user
      user.update!(password: AuthHelpers::DEFAULT_PASSWORD, password_confirmation: AuthHelpers::DEFAULT_PASSWORD)
      sign_in_as(user)

      ['/', '/portal', '/portal/cuenta', '/portal/historial', "/paciente/#{club.slug}"].each do |url|
        # Dirección completa: el helper de specs le antepone /api a todo lo que empieza con «/».
        get "http://www.example.com#{url}", headers: { 'Accept' => 'text/html' }
        expect(response).to have_http_status(:ok), "#{url}: #{response.status} #{response.body[0, 80]}"
        expect(response.body).to include('CASCARA'), url
      end
    end
  end
end
