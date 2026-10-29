require 'rails_helper'

# LOS TRES BARRIDOS DE SEGURIDAD (29-oct-2026, Germán: «necesito que analicemos todo el tema
# ciberseguridad y datos, no podemos fallar nada»).
#
# Cada uno recorre TODAS las rutas de la API, así que una ruta nueva queda probada sola: no hay que
# acordarse de agregarla acá. Lo que contesta cada ruta se mira por los datos que devuelve (marcas
# únicas sembradas en el paciente), no sólo por el código de estado.
#
#   1. Sin sesión, fuera de lo público nada contesta, y nada devuelve datos de un paciente.
#   2. El admin de una organización, con los números de un paciente de OTRA, no ve nada de él.
#   3. Lo clínico (diagnóstico, notas, alergias, medicación, indicaciones) lo ven admin y médico
#      vinculado, nadie más. Hasta hoy lo veía también el supervisor (`PacientePolicy::ROLES_CLINICA`).
#
# El del paciente está aparte: `paciente_solo_su_portal_spec.rb`.
RSpec.describe 'Barrido de seguridad de todas las rutas', type: :request do
  include AuthHelpers

  # Todo prendido: una ruta que contesta 403 porque el módulo está apagado no prueba nada.
  TODOS_LOS_MODULOS = (Club::SUITES.keys + Club::ADDONS.keys).map(&:to_s).index_with(true)

  let(:club) { create(:club, vista_paciente_activa: true, features: Club::FEATURES_POR_DEFECTO.merge(TODOS_LOS_MODULOS)) }
  let(:otra) { create(:club, vista_paciente_activa: true, features: Club::FEATURES_POR_DEFECTO.merge(TODOS_LOS_MODULOS)) }

  def rutas
    Rails.application.routes.routes.filter_map do |r|
      path  = r.path.spec.to_s.sub('(.:format)', '')
      verbo = r.verb.to_s[/GET|POST|PATCH|PUT|DELETE/]
      next unless verbo && path.start_with?('/api/')
      next if path.start_with?('/api/users/sign_out', '/api/users/sign_in')

      [verbo, path, r.defaults[:controller].to_s, r.defaults[:action].to_s]
    end.uniq
  end

  def pegar(verbo, path, id)
    send(verbo.downcase, path.gsub(/:token/, 'x').gsub(/:\w+/, id.to_s).gsub(/\*\w+/, 'x'), as: :json)
    [response.status, response.body.to_s]
  rescue StandardError => e
    [:excepcion, "#{e.class}: #{e.message[0, 120]}"]
  end

  # Si la sesión se cae a mitad del barrido, lo que sigue da 401 y el barrido mentiría.
  def seguir_logueado(user)
    get '/api/me', as: :json
    sign_in_as(user) unless response.status == 200
  end

  it '1. sin sesión, fuera de lo público ninguna ruta contesta ni devuelve datos de un paciente' do
    ActsAsTenant.test_tenant = club
    p = create(:paciente, club: club, nombre: 'Anonimosecreto', dni: '30123123', aprobado_at: Time.current)
    publica = ->(c) { c.start_with?('public/', 'webhooks') || %w[portal_acceso users/sessions users/passwords health].include?(c) }

    malas = rutas.filter_map do |v, path, c, a|
      st, body = pegar(v, path, p.id)
      if body.include?('Anonimosecreto') || body.include?('30123123')
        "DEVUELVE DATOS #{st} #{v} #{path} (#{c}##{a})"
      elsif !publica.call(c) && ![401, 403, 404, 405].include?(st)
        "#{st} #{v} #{path} (#{c}##{a})"
      end
    end

    expect(malas).to be_empty, "Rutas que contestan sin sesión:\n#{malas.join("\n")}"
  end

  it '2. el admin de una organización no ve nada de un paciente de otra' do
    ajeno = ActsAsTenant.with_tenant(otra) do
      pa = create(:paciente, club: otra, nombre: 'Deotraorg', apellido: 'Ajenisimo', dni: '31777666',
                             aprobado_at: Time.current, diagnostico_principal: 'Diagajeno')
      create(:indicacion_medica, paciente: pa, user: create(:user, :medico, club: otra), patologia: 'Patoajena')
      pa
    end
    ActsAsTenant.test_tenant = club
    admin = create(:user, :admin, club: club)
    sign_in_as(admin)
    marcas = %w[Deotraorg Ajenisimo 31777666 Diagajeno Patoajena]

    fugas = rutas.filter_map do |v, path, c, a|
      next if c.start_with?('super_admin')

      st, body = pegar(v, path, ajeno.id)
      seguir_logueado(admin)
      "#{st} #{v} #{path} (#{c}##{a})" if marcas.any? { |m| body.include?(m) }
    end

    expect(fugas).to be_empty, "Rutas que le muestran a un admin un paciente de otra organización:\n#{fugas.join("\n")}"
  end

  it '3. lo clínico lo ven admin y médico vinculado; ningún otro rol, en ninguna ruta' do
    ActsAsTenant.test_tenant = club
    p = create(:paciente, club: club, nombre: 'Propio', dni: '30555444', aprobado_at: Time.current,
                          diagnostico_principal: 'Diagsecreto', notas_clinicas: 'Notasecreta',
                          alergias: 'Alergiasecreta', medicacion_habitual: 'Medsecreta')
    create(:indicacion_medica, paciente: p, user: create(:user, :medico, club: club),
                               patologia: 'Patosecreta', dosificacion: 'Dosisecreta')
    marcas = %w[Diagsecreto Notasecreta Alergiasecreta Medsecreta Patosecreta Dosisecreta]

    # El médico NO vinculado va en la lista: ve sólo a sus pacientes.
    fugas = %w[supervisor cultivador manicura dispensador delivery abogado auditor medico].flat_map do |rol|
      u = create(:user, role: rol, club: club)
      sign_in_as(u)
      rutas.filter_map do |v, path, c, a|
        next unless v == 'GET'

        st, body = pegar(v, path, p.id)
        seguir_logueado(u)
        vistas = marcas.select { |m| body.include?(m) }
        "#{rol}: #{st} #{path} (#{c}##{a}) → #{vistas.join(', ')}" if vistas.any?
      end
    end

    expect(fugas).to be_empty, "Roles que ven lo clínico:\n#{fugas.join("\n")}"

    # Y el control: el admin sí lo ve. Sin esto, un barrido que no encuentra nada podría ser un
    # barrido que no mira nada.
    sign_in_as(create(:user, :admin, club: club))
    get "/api/pacientes/#{p.id}", as: :json
    expect(response.body).to include('Diagsecreto')
  end
end
