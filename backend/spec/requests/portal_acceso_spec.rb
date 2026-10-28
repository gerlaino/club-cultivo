require 'rails_helper'

# LA ENTRADA AL PORTAL DEL PACIENTE (27-oct-2026, Germán: «que los pacientes ya puedan usar el
# portal, teniendo en cuenta todas las entradas»).
#
# AC:
#   - El paciente entra con su DNI y su clave. Si es paciente en más de una organización, elige a
#     cuál DESPUÉS de validar la clave (la lista nunca se muestra a quien no la sabe).
#   - La primera vez (y cuando perdió la clave) entra por un link: sirve una vez, vence, pide su
#     DNI y ahí elige la clave. Un link nuevo anula al anterior; 5 DNI equivocados lo tiran.
#   - «Me olvidé la clave» con el DNI: si tiene mail, le llega un link. La respuesta es la misma
#     exista o no el DNI.
#   - «Es mi primera vez» (28-oct-2026, el QR del mostrador) es la misma puerta: el que nunca eligió
#     su clave recibe la invitación, aunque nadie de la organización lo haya invitado. Un link de
#     hace menos de 10 minutos no se reemplaza (no se le anula el que le acaban de mandar).
#   - No entra: el dado de baja, el que no fue aprobado, el de una organización con el portal
#     cerrado o sin contratar.
#   - La puerta de UNA organización (`/paciente/<slug>`, 28-oct-2026, Germán: «abrí el portal de
#     Club Modelo, me llegó el mail de Mitocondria y entré a Mitocondria»): por ahí el link que
#     llega y la cuenta en la que entra son SÓLO de esa organización, aunque sea paciente en otra.
#   - Por la puerta general, el paciente en varias con el mismo mail recibe UN mail (de la
#     plataforma) con un botón por organización, y elige ahí: la pantalla nunca muestra la lista.
RSpec.describe 'La entrada al portal del paciente', type: :request do
  include AuthHelpers

  def club!(nombre, abierto: true, contratado: true)
    create(:club, name: nombre, vista_paciente_activa: abierto,
                  features: { 'produccion_dispensa' => true, 'vista_paciente' => contratado })
  end

  let(:club) { club!('Raíces') }

  # Como en producción: el pedido llega SIN organización (no hay sesión). El hook general de specs
  # fija `club` como tenant de prueba y eso tapaba un NoTenantSet al abrir el link.
  before { ActsAsTenant.test_tenant = nil }

  def sin_tenant(&) = ActsAsTenant.without_tenant(&)

  def ficha!(en: club, dni: '30.111.222', nombre: 'Lucía', **attrs)
    ActsAsTenant.with_tenant(en) do
      create(:paciente, club: en, dni: dni, nombre: nombre, apellido: 'Fernández',
                        aprobado_at: Time.current, email: 'lucia@example.com', **attrs)
    end
  end

  # Una cuenta ya activada con esta clave (como si hubiera usado su link).
  def con_clave!(paciente, clave = 'clave-larga-1')
    ActsAsTenant.with_tenant(paciente.club) do
      user = Pacientes::Acceso.crear!(paciente).user
      user.update!(password: clave, password_confirmation: clave)
      AccesoPortal.emitir!(paciente).acceso.usar!
      paciente.reload
    end
  end

  def entrar(dni, password, **extra)
    post '/api/portal_acceso/sesion', params: { dni: dni, password: password, **extra }, as: :json
  end

  def json = JSON.parse(response.body)

  def quien_soy
    get '/api/me'
    response.status == 200 ? json['email'] || json.dig('user', 'email') : nil
  end

  describe 'entrar con DNI y clave' do
    it 'con el DNI escrito como sea (con o sin puntos) y su clave, entra a SU cuenta' do
      paciente = con_clave!(ficha!)

      entrar('30111222', 'clave-larga-1')

      expect(response).to have_http_status(:ok), response.body
      expect(json['role']).to eq('paciente')
      expect(quien_soy).to eq(sin_tenant { paciente.reload.user.email })
    end

    it 'con la clave equivocada no entra, y el mensaje no dice si el DNI existe' do
      con_clave!(ficha!)

      entrar('30111222', 'otra-clave')
      equivocada = json['error']
      entrar('99888777', 'otra-clave')

      expect(response).to have_http_status(:unauthorized)
      expect(json['error']).to eq(equivocada)
      expect(quien_soy).to be_nil
    end

    it 'la cuenta que nunca activó su link no entra con nada que alguien sepa' do
      paciente = ficha!
      ActsAsTenant.with_tenant(club) { Pacientes::Acceso.crear!(paciente) }

      entrar('30111222', '')

      expect(response).to have_http_status(:unauthorized)
    end

    describe 'paciente en dos organizaciones' do
      let(:otra) { club!('Mundo Verde') }

      it 'si la clave sirve en las dos, recién ahí le pregunta a cuál entra' do
        con_clave!(ficha!)
        con_clave!(ficha!(en: otra))

        entrar('30111222', 'clave-larga-1')

        expect(response).to have_http_status(:ok)
        expect(json['elegir'].map { |o| o['nombre'] }).to contain_exactly('Raíces', 'Mundo Verde')
        expect(quien_soy).to be_nil
      end

      it 'y con la que elige, entra a esa' do
        con_clave!(ficha!)
        en_otra = con_clave!(ficha!(en: otra))

        entrar('30111222', 'clave-larga-1', organizacion_id: otra.id)

        expect(quien_soy).to eq(sin_tenant { en_otra.reload.user.email })
      end

      it 'si la clave sirve sólo en una, entra directo: la otra no aparece en ningún lado' do
        propia = con_clave!(ficha!)
        con_clave!(ficha!(en: otra), 'clave-de-la-otra')

        entrar('30111222', 'clave-larga-1')

        expect(json).not_to have_key('elegir')
        expect(quien_soy).to eq(sin_tenant { propia.reload.user.email })
      end

      it 'con la clave equivocada no se entera de en qué organizaciones está' do
        con_clave!(ficha!)
        con_clave!(ficha!(en: otra))

        entrar('30111222', 'nada-que-ver')

        expect(response).to have_http_status(:unauthorized)
        expect(response.body).not_to include('Mundo Verde')
      end
    end

    describe 'quién no entra aunque la clave esté bien' do
      it 'el paciente dado de baja' do
        con_clave!(ficha!(es_paciente: false))
        entrar('30111222', 'clave-larga-1')
        expect(response).to have_http_status(:unauthorized)
      end

      it 'el que todavía no fue aprobado (alta del mostrador)' do
        pendiente = ficha!
        pendiente.update_column(:aprobado_at, nil) # el alta lo aprueba sola si no viene del mostrador
        con_clave!(pendiente)
        entrar('30111222', 'clave-larga-1')
        expect(response).to have_http_status(:unauthorized)
      end

      it 'el de una organización con el portal cerrado' do
        con_clave!(ficha!(en: club!('Cerrada', abierto: false)))
        entrar('30111222', 'clave-larga-1')
        expect(response).to have_http_status(:unauthorized)
      end

      it 'el de una organización sin el portal contratado' do
        con_clave!(ficha!(en: club!('Sin portal', contratado: false)))
        entrar('30111222', 'clave-larga-1')
        expect(response).to have_http_status(:unauthorized)
      end

      it 'el de una organización eliminada' do
        borrada = club!('Borrada')
        con_clave!(ficha!(en: borrada))
        borrada.update_column(:deleted_at, Time.current)

        entrar('30111222', 'clave-larga-1')
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'el link (invitación o «me olvidé la clave»)' do
    let(:paciente) { ficha! }

    def link!(motivo: 'invitacion')
      ActsAsTenant.with_tenant(club) { AccesoPortal.emitir!(paciente, motivo: motivo) }.token
    end

    def activar(token, dni: '30111222', password: 'mi-clave-nueva', confirmacion: password)
      post "/api/portal_acceso/links/#{token}/activar",
           params: { dni: dni, password: password, password_confirmation: confirmacion }, as: :json
    end

    it 'dice de qué organización es y a quién saluda, sin datos de salud ni el DNI' do
      get "/api/portal_acceso/links/#{link!}"

      expect(response).to have_http_status(:ok)
      expect(json['nombre']).to eq('Lucía')
      expect(json['organizacion']['nombre']).to eq('Raíces')
      expect(response.body).not_to include('30111222')
    end

    it 'con su DNI y una clave elige su clave y queda adentro' do
      activar(link!)

      expect(response).to have_http_status(:ok), response.body
      expect(quien_soy).to eq(sin_tenant { paciente.reload.user.email })
    end

    it 'después entra con DNI y la clave que eligió' do
      activar(link!)
      reset!

      entrar('30111222', 'mi-clave-nueva')
      expect(quien_soy).to eq(sin_tenant { paciente.reload.user.email })
    end

    it 'le crea la cuenta si no la tenía (los pacientes de antes del portal)' do
      expect(sin_tenant { paciente.user }).to be_nil

      activar(link!)

      expect(sin_tenant { paciente.reload.user }).to be_present
    end

    it 'sirve una sola vez' do
      token = link!
      activar(token)
      reset!

      activar(token, password: 'otra-clave-mas')

      expect(response).to have_http_status(:gone)
      expect(json['error']).to include('ya se usó')
    end

    it 'vence: la invitación a las 72 horas' do
      token = link!
      travel 73.hours do
        get "/api/portal_acceso/links/#{token}"
        expect(response).to have_http_status(:gone)
        expect(json['error']).to include('venció')
      end
    end

    it 'el de «me olvidé la clave» vence antes, a las 6 horas' do
      token = link!(motivo: 'recuperacion')
      travel 7.hours do
        activar(token)
        expect(response).to have_http_status(:gone)
      end
    end

    it 'un link nuevo anula el anterior' do
      viejo = link!
      link!

      get "/api/portal_acceso/links/#{viejo}"
      expect(response).to have_http_status(:gone)
      expect(json['error']).to include('más nuevo')
    end

    it 'con otro DNI no sirve: si se lo reenviaron a alguien, no entra' do
      activar(link!, dni: '99888777')

      expect(response).to have_http_status(:unprocessable_entity)
      expect(quien_soy).to be_nil
    end

    it 'a los 5 DNI equivocados el link se cae, aunque después pongan el correcto' do
      token = link!
      5.times { activar(token, dni: '11111111') }

      activar(token)

      expect(response).to have_http_status(:gone)
      expect(quien_soy).to be_nil
    end

    it 'pide una clave de 8 caracteres o más, y las dos iguales' do
      token = link!
      activar(token, password: 'corta')
      expect(json['error']).to include('8 caracteres')

      activar(token, password: 'clave-larga', confirmacion: 'clave-larguisima')
      expect(json['error']).to include('no son iguales')
    end

    it 'con el portal cerrado después de mandarlo, no entra' do
      token = link!
      club.update!(vista_paciente_activa: false)

      activar(token)

      expect(response).to have_http_status(:forbidden)
      expect(json['error']).to include('cerrado')
    end

    it 'un link inventado no existe' do
      get '/api/portal_acceso/links/cualquier-cosa'
      expect(response).to have_http_status(:not_found)
    end

    it 'en la base queda el hash, no el link' do
      token = link!
      expect(AccesoPortal.unscoped.where(token_digest: token)).to be_empty
    end
  end

  describe '«Me olvidé la clave»' do
    def recuperar(dni) = post('/api/portal_acceso/recuperar', params: { dni: dni }, as: :json)

    it 'con mail cargado le llega el link de recuperación' do
      con_clave!(ficha!)

      expect { recuperar('30.111.222') }.to have_enqueued_mail(AccesoMailer, :portal_link)
      expect(AccesoPortal.unscoped.last.motivo).to eq('recuperacion')
    end

    it 'la respuesta es la misma para un DNI que no está: no dice quién es paciente' do
      con_clave!(ficha!)
      recuperar('30111222')
      existe = response.body

      expect { recuperar('99888777') }.not_to have_enqueued_mail
      expect(response.body).to eq(existe)
    end

    it 'sin mail en la ficha no se manda nada (ni se le anula el link que tenía)' do
      paciente = con_clave!(ficha!(email: nil))
      ActsAsTenant.with_tenant(club) { AccesoPortal.emitir!(paciente) }

      expect { recuperar('30111222') }.not_to have_enqueued_mail
      expect(AccesoPortal.unscoped.where(paciente_id: paciente.id, usado_at: nil, anulado_at: nil).count).to eq(1)
    end

    it 'el link que manda sirve para elegir la clave nueva' do
      paciente = con_clave!(ficha!)
      token = nil
      allow(AccesoMailer).to receive(:portal_link).and_wrap_original do |m, **kw|
        token = kw[:token]
        m.call(**kw)
      end

      recuperar('30111222')
      post "/api/portal_acceso/links/#{token}/activar",
           params: { dni: '30111222', password: 'clave-recuperada', password_confirmation: 'clave-recuperada' }, as: :json
      reset!
      entrar('30111222', 'clave-recuperada')

      expect(quien_soy).to eq(sin_tenant { paciente.reload.user.email })
    end

    it 'primera vez: sin cuenta todavía, con mail cargado, le llega la invitación' do
      paciente = ficha!

      expect { recuperar('30111222') }.to have_enqueued_mail(AccesoMailer, :portal_link)
      expect(AccesoPortal.unscoped.where(paciente_id: paciente.id).last.motivo).to eq('invitacion')
    end

    it 'primera vez: la invitación que le llega sirve para elegir su clave y entrar' do
      paciente = ficha!
      token = nil
      allow(AccesoMailer).to receive(:portal_link).and_wrap_original do |m, **kw|
        token = kw[:token]
        m.call(**kw)
      end

      recuperar('30111222')
      post "/api/portal_acceso/links/#{token}/activar",
           params: { dni: '30111222', password: 'mi-primera-clave', password_confirmation: 'mi-primera-clave' }, as: :json
      reset!
      entrar('30111222', 'mi-primera-clave')

      expect(quien_soy).to eq(sin_tenant { paciente.reload.user.email })
    end

    it 'un link de hace menos de 10 minutos no se reemplaza: no se le anula el que le mandaron' do
      paciente = ficha!
      ActsAsTenant.with_tenant(club) { AccesoPortal.emitir!(paciente) }

      expect { recuperar('30111222') }.not_to have_enqueued_mail
      expect(AccesoPortal.unscoped.where(paciente_id: paciente.id, anulado_at: nil).count).to eq(1)
    end

    it 'pasados los 10 minutos sí se manda uno nuevo' do
      paciente = ficha!
      ActsAsTenant.with_tenant(club) { AccesoPortal.emitir!(paciente) }

      travel 11.minutes do
        expect { recuperar('30111222') }.to have_enqueued_mail(AccesoMailer, :portal_link)
      end
    end

    it 'primera vez en una organización con el portal cerrado: no se manda nada' do
      ficha!(en: club!('Cerrada', abierto: false))

      expect { recuperar('30111222') }.not_to have_enqueued_mail
    end

    it 'paciente en dos organizaciones con el mismo mail: UN mail con las dos para elegir' do
      ficha!
      ficha!(en: club!('Mitocondria'))

      expect { recuperar('30111222') }
        .to have_enqueued_mail(AccesoMailer, :portal_varias).once
        .and not_have_enqueued_mail(AccesoMailer, :portal_link)
    end

    it 'con un mail distinto en cada organización, le llega uno a cada mail' do
      ficha!
      ficha!(en: club!('Mitocondria'), email: 'otro@example.com')

      expect { recuperar('30111222') }.to have_enqueued_mail(AccesoMailer, :portal_link).twice
    end
  end

  describe 'la puerta de una organización' do
    let(:modelo)      { club!('Club Modelo') }
    let(:mitocondria) { club!('Mitocondria') }

    def recuperar(dni, **extra) = post('/api/portal_acceso/recuperar', params: { dni: dni, **extra }, as: :json)

    it 'muestra de qué organización es, sin nada de ningún paciente' do
      get "/api/portal_acceso/organizaciones/#{modelo.slug}"

      expect(response).to have_http_status(:ok)
      expect(json.keys).to contain_exactly('id', 'slug', 'nombre', 'logo_url', 'theme_primary')
      expect(json['nombre']).to eq('Club Modelo')
    end

    it 'con el portal cerrado, sin contratar o un slug que no existe, no hay puerta' do
      cerrada = club!('Cerrada', abierto: false)
      sin_contratar = club!('Sin contratar', contratado: false)

      [cerrada.slug, sin_contratar.slug, 'no-existe'].each do |slug|
        get "/api/portal_acceso/organizaciones/#{slug}"
        expect(response).to have_http_status(:not_found), slug
      end
    end

    it '«Es mi primera vez» desde Club Modelo manda SÓLO el link de Club Modelo, aunque sea paciente en Mitocondria' do
      en_modelo = ficha!(en: modelo)
      en_mito   = ficha!(en: mitocondria)

      expect { recuperar('30111222', organizacion: modelo.slug) }.to have_enqueued_mail(AccesoMailer, :portal_link).once
      expect(AccesoPortal.unscoped.where(paciente_id: en_modelo.id).count).to eq(1)
      expect(AccesoPortal.unscoped.where(paciente_id: en_mito.id).count).to eq(0)
    end

    it 'si sólo es paciente en Mitocondria, por la puerta de Club Modelo no le llega nada' do
      ficha!(en: mitocondria)
      modelo

      expect { recuperar('30111222', organizacion: modelo.slug) }.not_to have_enqueued_mail
    end

    it 'la misma respuesta haya mandado o no: la puerta no dice quién es paciente' do
      ficha!(en: modelo)
      recuperar('30111222', organizacion: modelo.slug)
      mando = response.body

      recuperar('99888777', organizacion: modelo.slug)
      expect(response.body).to eq(mando)
    end

    it 'el link que llega por la puerta de Club Modelo activa la cuenta de Club Modelo' do
      en_modelo = ficha!(en: modelo)
      ficha!(en: mitocondria)
      token = nil
      allow(AccesoMailer).to receive(:portal_link).and_wrap_original do |m, **kw|
        token = kw[:token]
        m.call(**kw)
      end

      recuperar('30111222', organizacion: modelo.slug)
      get "/api/portal_acceso/links/#{token}"
      expect(json.dig('organizacion', 'nombre')).to eq('Club Modelo')

      post "/api/portal_acceso/links/#{token}/activar",
           params: { dni: '30111222', password: 'clave-de-modelo', password_confirmation: 'clave-de-modelo' }, as: :json
      expect(json['club_id']).to eq(modelo.id)
      expect(quien_soy).to eq(sin_tenant { en_modelo.reload.user.email })
    end

    it 'con la misma clave en las dos, por la puerta de Club Modelo entra a Club Modelo sin preguntar' do
      en_modelo = con_clave!(ficha!(en: modelo))
      con_clave!(ficha!(en: mitocondria))

      entrar('30111222', 'clave-larga-1', organizacion: modelo.slug)

      expect(json).not_to have_key('elegir')
      expect(json['club_id']).to eq(modelo.id)
      expect(quien_soy).to eq(sin_tenant { en_modelo.reload.user.email })
    end

    it 'con la clave de Mitocondria, por la puerta de Club Modelo no entra a ningún lado' do
      ficha!(en: modelo) # nunca eligió su clave en Club Modelo
      con_clave!(ficha!(en: mitocondria))

      entrar('30111222', 'clave-larga-1', organizacion: modelo.slug)

      expect(response).to have_http_status(:unauthorized)
      expect(response.body).not_to include('Mitocondria')
      expect(quien_soy).to be_nil
    end

    it 'por la puerta de Club Modelo, elegir Mitocondria a mano no la abre' do
      con_clave!(ficha!(en: modelo))
      con_clave!(ficha!(en: mitocondria))

      entrar('30111222', 'clave-larga-1', organizacion: modelo.slug, organizacion_id: mitocondria.id)

      expect(json['club_id']).to eq(modelo.id)
    end

    it 'por la puerta general le llega un mail con un botón por organización, y cada uno abre la suya' do
      en_modelo = ficha!(en: modelo)
      en_mito   = ficha!(en: mitocondria)
      items = nil
      allow(AccesoMailer).to receive(:portal_varias).and_wrap_original do |m, **kw|
        items = kw[:items]
        m.call(**kw)
      end

      recuperar('30111222')
      perform_enqueued_jobs
      mail = ActionMailer::Base.deliveries.last
      expect(mail.to).to eq(['lucia@example.com'])
      expect(mail.from).to eq([Club::PLATFORM_FROM[/[^<\s]+@[^>\s]+/]])
      expect(mail.body.encoded).to include('Club Modelo', 'Mitocondria')

      link_modelo = items.find { |i| i[:club] == modelo }[:link]
      token = link_modelo.split('/').last
      post "/api/portal_acceso/links/#{token}/activar",
           params: { dni: '30111222', password: 'clave-de-modelo', password_confirmation: 'clave-de-modelo' }, as: :json
      expect(json['club_id']).to eq(modelo.id)
      expect(quien_soy).to eq(sin_tenant { en_modelo.reload.user.email })
      expect(AccesoPortal.unscoped.where(paciente_id: en_mito.id, usado_at: nil).count).to eq(1)
    end

    it 'la pantalla nunca muestra en qué organizaciones es paciente' do
      ficha!(en: modelo)
      ficha!(en: mitocondria)

      recuperar('30111222')

      expect(response.body).not_to include('Club Modelo')
      expect(response.body).not_to include('Mitocondria')
    end
  end
end
