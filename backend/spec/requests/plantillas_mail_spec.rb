require 'rails_helper'

RSpec.describe 'Plantillas de correo', type: :request do
  include AuthHelpers

  let(:club)        { create(:club, name: 'Mitocondria') }
  let(:admin)       { create(:user, :admin, club: club) }
  let(:dispensador) { create(:user, :dispensador, club: club) }

  describe 'GET /plantillas_mail' do
    it 'siembra las de fábrica la primera vez y no las duplica en la segunda' do
      sign_in_as(admin)

      expect { get '/plantillas_mail', headers: auth_headers }
        .to change { club.plantillas_mail.count }.from(0).to(PlantillaMail::SEMILLA.size)

      expect { get '/plantillas_mail', headers: auth_headers }
        .not_to change { club.plantillas_mail.count }

      expect(response).to have_http_status(:ok)
    end

    it 'informa las variables disponibles, que es lo único que se puede escribir entre llaves' do
      sign_in_as(admin)
      get '/plantillas_mail', headers: auth_headers

      claves = JSON.parse(response.body)['variables'].map { |v| v['clave'] }
      expect(claves).to match_array(PlantillaMail::VARIABLES.keys)
    end

    # El add-on se puede dar de baja. Apagado, la pantalla no tiene que dar 500 ni devolver
    # datos: tiene que decir que la organización no tiene el módulo.
    it 'sin el add-on de correo, no hay plantillas' do
      club.update!(features: club.features.merge('mailer' => false))
      sign_in_as(admin)

      get '/plantillas_mail', headers: auth_headers

      expect(response).to have_http_status(:forbidden)
      expect(club.plantillas_mail.count).to eq(0)
    end
  end

  describe 'quién puede editarlas' do
    it 'el dispensador las lee pero no las toca: salen firmadas por la organización' do
      sign_in_as(dispensador)

      get '/plantillas_mail', headers: auth_headers
      expect(response).to have_http_status(:ok)

      post '/plantillas_mail',
           params: { plantilla_mail: { nombre: 'Mía', asunto: 'Hola', cuerpo: 'Texto' } },
           headers: auth_headers, as: :json
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'una sola plantilla de bienvenida' do
    it 'rechaza la segunda con un mensaje legible, no con un error de la base' do
      sign_in_as(admin)
      get '/plantillas_mail', headers: auth_headers # siembra, y la semilla ya trae una

      post '/plantillas_mail',
           params: { plantilla_mail: { nombre: 'Otra bienvenida', asunto: 'Hola',
                                       cuerpo: 'Texto', bienvenida: true } },
           headers: auth_headers, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['errors'].join).to match(/bienvenida/i)
    end
  end

  describe 'aislamiento entre organizaciones' do
    it 'no muestra ni deja editar las plantillas de otra organización' do
      otro_club = nil
      ajena     = nil
      ActsAsTenant.with_tenant(create(:club, name: 'Otra')) do |c|
        otro_club = ActsAsTenant.current_tenant
        ajena = PlantillaMail.create!(club: otro_club, nombre: 'Ajena',
                                      asunto: 'Asunto', cuerpo: 'Cuerpo')
      end

      sign_in_as(admin)
      get '/plantillas_mail', headers: auth_headers

      nombres = JSON.parse(response.body)['data'].map { |p| p['nombre'] }
      expect(nombres).not_to include('Ajena')

      patch "/plantillas_mail/#{ajena.id}",
            params: { plantilla_mail: { nombre: 'Robada' } },
            headers: auth_headers, as: :json
      expect(response).to have_http_status(:not_found)
      expect(ajena.reload.nombre).to eq('Ajena')
    end
  end
end

RSpec.describe PlantillaMail, '.render' do
  let(:club)     { create(:club, name: 'Mitocondria') }
  let(:paciente) do
    create(:paciente, club: club, nombre: 'Ana', apellido: 'Pérez',
                      reprocann_vencimiento: Date.new(2029, 3, 20))
  end

  it 'reemplaza las variables de la lista blanca' do
    texto = 'Hola {{nombre}} {{apellido}}, de {{organizacion}}. Vence el {{reprocann_vencimiento}}.'

    expect(described_class.render(texto, paciente: paciente, club: club))
      .to eq('Hola Ana Pérez, de Mitocondria. Vence el 20/03/2029.')
  end

  it 'tolera espacios adentro de las llaves, que es como se escribe naturalmente' do
    expect(described_class.render('Hola {{ nombre }}', paciente: paciente, club: club))
      .to eq('Hola Ana')
  end

  # El cuerpo lo escribe un usuario. Evaluarlo como código —ERB, `send`, lo que sea— sería
  # ejecución remota en el servidor. Lo que no está en la lista blanca se deja literal.
  it 'no evalúa código ni resuelve variables que no están declaradas' do
    peligro = '<%= User.first.email %> y {{password}} y {{club.destroy}}'

    expect(described_class.render(peligro, paciente: paciente, club: club)).to eq(peligro)
  end

  it 'deja el hueco vacío en vez de "nil" cuando el dato no está cargado' do
    sin_venc = create(:paciente, club: club, nombre: 'Beto', reprocann_vencimiento: nil)

    expect(described_class.render('Vence {{reprocann_vencimiento}}.', paciente: sin_venc, club: club))
      .to eq('Vence .')
  end
end
