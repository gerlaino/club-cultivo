require 'rails_helper'

# AC: el paciente ve SU turno y SU indicación desde el portal, y nada más que eso.
#
# El módulo médico existe desde hace meses y el portal no lo leía: el paciente tenía que llamar
# para saber cuándo era su turno o cuánto le habían indicado tomar. Lo que se sirve son datos de
# salud encriptados at-rest (Ley 25.326 art. 9), así que los tres casos que importan son: los suyos
# salen, los del vecino no, y lo que el médico escribió PARA EL MÉDICO no sale nunca.
RSpec.describe 'Portal — mi salud', type: :request do
  include AuthHelpers

  let(:club)  { create(:club, vista_paciente_activa: true,
                  features: { 'produccion_dispensa' => true, 'vista_paciente' => true }) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:medico) { create(:user, :medico, club: club, first_name: 'Ana', last_name: 'Pérez') }

  def paciente!(**attrs)
    ActsAsTenant.with_tenant(club) { create(:paciente, club: club, created_by: admin, **attrs) }
  end

  def entrar_como(paciente)
    user = ActsAsTenant.with_tenant(club) do
      u = Pacientes::Acceso.crear!(paciente).user
      u.update!(password: AuthHelpers::DEFAULT_PASSWORD, password_confirmation: AuthHelpers::DEFAULT_PASSWORD)
      u
    end
    sign_in_as(user)
    get '/api/portal/mi_salud'
    JSON.parse(response.body)['data']
  end

  let(:paciente) { paciente!(reprocann_estado: 'activo', reprocann_numero: 'RP-1') }

  describe 'los turnos' do
    it 'muestra el próximo y no los pasados' do
      ActsAsTenant.with_tenant(club) do
        create(:turno, paciente: paciente, medico: medico, club: club,
                       fecha_hora: 3.days.from_now, tipo: 'seguimiento')
        create(:turno, paciente: paciente, medico: medico, club: club,
                       fecha_hora: 3.days.ago, estado: 'realizado')
      end

      datos = entrar_como(paciente)

      expect(datos['turnos'].size).to eq(1)
      expect(datos['proximo_turno']['tipo_label']).to eq('Seguimiento')
      expect(datos['proximo_turno']['medico']).to eq('Ana Pérez')
    end

    it 'no cuenta como próximo un turno cancelado: si lo mostrara, el paciente se presenta' do
      ActsAsTenant.with_tenant(club) do
        create(:turno, paciente: paciente, medico: medico, club: club,
                       fecha_hora: 2.days.from_now, estado: 'cancelado')
      end

      expect(entrar_como(paciente)['proximo_turno']).to be_nil
    end

    # Lo que el médico escribe DESPUÉS de la consulta es para el médico. Que la lista sea blanca y
    # no un `as_json` es justamente para que un campo nuevo no se filtre solo.
    it 'no expone las notas posteriores del médico' do
      ActsAsTenant.with_tenant(club) do
        create(:turno, paciente: paciente, medico: medico, club: club,
                       fecha_hora: 2.days.from_now,
                       notas_post: 'Refiere consumo problemático de alcohol')
      end

      datos = entrar_como(paciente)

      expect(datos['proximo_turno']).not_to have_key('notas_post')
      expect(response.body).not_to include('consumo problemático')
    end

    it 'no muestra el turno de otro paciente de la misma organización' do
      otro = paciente!(dni: '39111222')
      ActsAsTenant.with_tenant(club) do
        create(:turno, paciente: otro, medico: medico, club: club, fecha_hora: 1.day.from_now)
      end

      datos = entrar_como(paciente)

      expect(datos['turnos']).to be_empty
      expect(datos['proximo_turno']).to be_nil
    end
  end

  describe 'la indicación médica' do
    it 'devuelve la vigente con su dosis, su vía y su vencimiento' do
      ActsAsTenant.with_tenant(club) do
        create(:indicacion_medica, paciente: paciente, user: medico,
                                   patologia: 'Dolor crónico', dosificacion: '3 gotas cada 8 horas',
                                   via_administracion: 'sublingual', duracion_dias: 90)
      end

      i = entrar_como(paciente)['indicacion']

      expect(i['dosificacion']).to eq('3 gotas cada 8 horas')
      expect(i['via_administracion']).to eq('sublingual')
      expect(i['patologia']).to eq('Dolor crónico')
      expect(i['medico']).to eq('Ana Pérez')
      expect(i['vencida']).to be(false)
    end

    # Una indicación vencida SÍ se muestra: que diga "venció" es el aviso de que hay que renovarla.
    # Ocultarla deja al paciente creyendo que sigue con la misma pauta.
    it 'muestra la vencida marcada como vencida, en vez de esconderla' do
      ActsAsTenant.with_tenant(club) do
        create(:indicacion_medica, paciente: paciente, user: medico,
                                   fecha_emision: 200.days.ago.to_date, duracion_dias: 30)
      end

      expect(entrar_como(paciente)['indicacion']['vencida']).to be(true)
    end

    it 'no devuelve la indicación de otro paciente' do
      otro = paciente!(dni: '39111333')
      ActsAsTenant.with_tenant(club) do
        create(:indicacion_medica, paciente: otro, user: medico, patologia: 'Epilepsia refractaria')
      end

      expect(entrar_como(paciente)['indicacion']).to be_nil
      expect(response.body).not_to include('Epilepsia refractaria')
    end
  end

  describe 'sin el módulo médico' do
    let(:club) { create(:club, vista_paciente_activa: true, features: { 'vista_paciente' => true }) }

    it 'contesta que no lo tiene en vez de romper: la pantalla lo explica' do
      datos = entrar_como(paciente)

      expect(response).to have_http_status(:ok)
      expect(datos['tiene_modulo']).to be(false)
      expect(datos['turnos']).to be_empty
    end
  end

  describe 'quién puede pedirlo' do
    it 'un admin de la organización no entra al área de pacientes' do
      sign_in_as(admin)
      get '/api/portal/mi_salud'

      expect(response).to have_http_status(:forbidden)
    end
  end
end
