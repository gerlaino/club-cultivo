require 'rails_helper'

# AC: un módulo apagado devuelve 403 EN LA API. Esconder el botón no es gating: hasta ahora
# 10 de las 13 banderas no bloqueaban nada y el club entraba igual por la API.
RSpec.describe 'Gating por módulo', type: :request do
  let(:club)   { create(:club) }
  let(:admin)  { create(:user, :admin, club: club) }
  let(:medico) { create(:user, :medico, club: club) }

  def features!(hash)
    club.update_columns(features: hash)
  end

  # El módulo médico ya no se apaga por separado: viene DENTRO de la suite de Producción y
  # dispensa, porque vive de la ficha del paciente. Un club que no la tiene —sólo Cultivo— no
  # tiene pacientes, así que no tiene médico.
  describe 'club sin la suite que incluye al módulo médico' do
    before do
      features!('cultivo' => true, 'produccion_dispensa' => false)
    end

    # Se prueba con el ADMIN y no con el médico: desde el gating de roles, un médico en un
    # club sin módulo médico ya no llega a hacer este request —lo frena el login, porque no
    # tendría nada que hacer adentro— y el rechazo que devuelve es otro
    # (`modulo_rol_apagado`, ver spec/requests/rol_modulo_apagado_spec.rb). El admin sí entra
    # siempre, así que es con quien se verifica que el candado del MÓDULO sigue puesto.
    it 'rechaza la lista de pacientes del médico con 403 y explica por qué' do
      sign_in_as(admin)

      get '/api/medico/pacientes'

      expect(response).to have_http_status(:forbidden)
      body = JSON.parse(response.body)
      expect(body['requiere_modulo']).to be(true)
      expect(body['modulo']).to eq('medico')
      expect(body['error']).to match(/Módulo médico/i)
      # Y dice dónde está el problema de verdad: le falta la suite, no el módulo.
      expect(body['error']).to match(/Producción y dispensa/i)
    end

    it 'al médico lo frena antes, en el login' do
      post '/api/users/sign_in',
           params: { user: { email: medico.email, password: 'password123' } }, as: :json

      expect(response).to have_http_status(:forbidden)
      expect(JSON.parse(response.body)['modulo_rol_apagado']).to be(true)
    end
  end

  describe 'club con la suite de Producción y dispensa' do
    # Sin tildar nada: el módulo médico VIENE con la suite. Que hiciera falta acordarse de
    # prenderlo aparte era lo que dejaba clubes con media ficha de paciente.
    it 'tiene el módulo médico sin que nadie lo prenda' do
      features!('cultivo' => true, 'produccion_dispensa' => true)
      sign_in_as(medico)

      get '/api/medico/pacientes'

      expect(response).to have_http_status(:ok)
      expect(club.reload.feature?(:medico)).to be(true)
      expect(club.feature?(:mailer)).to be(true)
    end

    # No se guarda como bandera: se deriva. Si se guardara, podría contradecir a su suite.
    it 'no guarda el módulo incluido como una feature suelta' do
      features!('cultivo' => true, 'produccion_dispensa' => true)

      expect(club.reload.features).not_to have_key('medico')
      expect(club.features_expandidas['medico']).to be(true)
    end
  end

  describe 'módulos incompletos' do
    # ARICCAME simula el envío: viene APAGADO y el panel advierte qué le falta, pero se puede
    # prender a conciencia.
    it 'no vienen activados por defecto en un club nuevo' do
      expect(Club::FEATURES_POR_DEFECTO).not_to have_key('ariccame')
    end

    it 'quedan marcados como incompletos, con el motivo a la vista' do
      expect(club.addon_incompleto?(:ariccame)).to be(true)
      expect(club.addon_incompleto?(:eventos)).to be(true)
      expect(Club::ADDONS['ariccame'][:requiere]).to match(/INCOMPLETO/)
    end

    # Eventos existe y funciona, pero todavía no está pulido: se prende cuando lo esté.
    it 'los eventos del Buffet no vienen activados' do
      expect(Club::FEATURES_POR_DEFECTO).not_to have_key('eventos')

      sign_in_as(admin)
      bar = club.bares.create!(nombre: 'Buffet', sede: create(:sede, club: club, created_by: admin, tipo: 'mixta'))
      get "/api/bares/#{bar.id}/eventos"

      expect(response).to have_http_status(:forbidden)
      expect(JSON.parse(response.body)['modulo']).to eq('eventos')
    end

    it 'el que está terminado no aparece como incompleto' do
      expect(club.addon_incompleto?(:bar)).to be(false)
    end
  end

  # Distinto de "incompleto": lo que está EN CONSTRUCCIÓN no existe todavía, así que no se
  # puede prender ni por la API. Prometerle al club algo que no está es peor que no ofrecerlo.
  describe 'módulos en construcción' do
    it 'la vista del paciente no está disponible para nadie' do
      expect(Club::EN_CONSTRUCCION).to have_key('vista_paciente')
      expect(club.feature?(:vista_paciente)).to be(false)
      expect(club.estado_modulo(:vista_paciente)).to eq(:en_construccion)
    end

    it 'no se habilita ni forzando la bandera a mano' do
      features!('vista_paciente' => true)

      expect(club.reload.feature?(:vista_paciente)).to be(false)
    end

    it 'no es una feature editable por el super admin' do
      expect(Club::FEATURES_EDITABLES).not_to include('vista_paciente')
    end
  end

  # Prender el interruptor no es lo mismo que funcionar: el WhatsApp sin Twilio y el Correo sin
  # SMTP quedan prendidos y no hacen nada. El panel tiene que poder decir la diferencia.
  describe 'estado real de un módulo' do
    it 'un módulo prendido al que le falta configuración no cuenta como andando' do
      features!('cultivo' => true, 'produccion_dispensa' => true, 'whatsapp' => true)

      club.reload
      expect(club.feature?(:whatsapp)).to be(true)
      expect(club.estado_modulo(:whatsapp)).to eq(:falta_config)
      expect(club.falta_para_funcionar(:whatsapp)).to match(/Twilio/i)
    end

    it 'un módulo sin dependencias externas anda apenas se prende' do
      features!('cultivo' => true, 'produccion_dispensa' => true, 'bar' => true)

      expect(club.reload.estado_modulo(:bar)).to eq(:andando)
      expect(club.falta_para_funcionar(:bar)).to be_nil
    end

    it 'un módulo apagado es apagado, no "le falta configuración"' do
      features!('cultivo' => true)

      expect(club.reload.estado_modulo(:whatsapp)).to eq(:apagado)
    end

    it 'los eventos avisan que dependen del Buffet' do
      features!('cultivo' => true, 'produccion_dispensa' => true, 'eventos' => true, 'bar' => false)

      expect(club.reload.falta_para_funcionar(:eventos)).to match(/Buffet/i)
    end
  end

  describe 'compatibilidad con las banderas viejas' do
    it 'un club con ia_voz sigue teniendo el asistente' do
      features!('cultivo' => true, 'ia_voz' => true)

      expect(club.reload.feature?(:ia)).to be(true)
    end

    it 'cuenta_corriente vieja equivale a la suite de dispensa' do
      features!('cuenta_corriente' => true)

      expect(club.reload.feature?(:cuenta_corriente)).to be(true)
    end
  end

  # Al reagrupar, `multi_sede` dejó de existir como bandera y la sección Sedes desapareció
  # del menú: el frontend la consulta por nombre. La app expone las claves viejas derivadas.
  describe 'features expandidas (compatibilidad del frontend)' do
    it 'un club con la suite de cultivo sigue viendo multi_sede, insumos y analytics' do
      features!('cultivo' => true)

      expandidas = club.reload.features_expandidas

      expect(expandidas['multi_sede']).to be(true)
      expect(expandidas['insumos']).to be(true)
      expect(expandidas['analytics']).to be(true)
      expect(expandidas['alertas']).to be(true)
    end

    it 'sin la suite, tampoco aparecen' do
      features!({})

      expect(club.reload.features_expandidas['multi_sede']).to be_nil
    end
  end

  describe 'un club sin nada habilitado' do
    it 'no habilita ningún add-on' do
      features!({})

      club.reload
      Club::ADDONS.each_key do |addon|
        expect(club.addon_disponible?(addon)).to be(false), "#{addon} no debería estar disponible"
      end
    end
  end
end
