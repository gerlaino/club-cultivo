require 'rails_helper'

# AC: "Mis Pacientes" del médico se pagina en el servidor, y el orden es de AGENDA
# (primero a quién tiene que ver), no alfabético.
RSpec.describe 'GET /api/medico/pacientes', type: :request do
  let(:club)   { create(:club) }
  let(:medico) { create(:user, :medico, club: club) }

  def crear_paciente(apellido, **attrs)
    create(:paciente, club: club, created_by: medico, apellido: apellido, **attrs)
  end

  def get_index(params = {})
    get '/api/medico/pacientes', params: params
    JSON.parse(response.body)
  end

  before { sign_in_as(medico) }

  describe 'paginación' do
    it 'devuelve solo la página pedida y el total en meta' do
      5.times { |i| crear_paciente("Apellido#{i}") }

      body = get_index(limite: 2)

      expect(response).to have_http_status(:ok)
      expect(body['data'].size).to eq(2)
      expect(body['meta']).to include('pagina' => 1, 'limite' => 2, 'total' => 5)
    end

    it 'la segunda página trae pacientes distintos de la primera' do
      5.times { |i| crear_paciente("Apellido#{i}") }

      primera = get_index(limite: 2, pagina: 1)['data'].map { |p| p['id'] }
      segunda = get_index(limite: 2, pagina: 2)['data'].map { |p| p['id'] }

      expect(primera & segunda).to be_empty
    end
  end

  describe 'orden de agenda' do
    it 'pone primero al paciente con turno próximo, aunque su apellido vaya último' do
      crear_paciente('Aaaa')
      con_turno = crear_paciente('Zzzz')
      Turno.create!(club: club, paciente: con_turno, medico: medico,
                    fecha_hora: 2.days.from_now, tipo: 'seguimiento', estado: 'programado')

      body = get_index

      expect(body['data'].first['id']).to eq(con_turno.id)
      expect(body['data'].first['proximo_turno_at']).to be_present
    end

    it 'no considera turnos pasados ni cancelados' do
      crear_paciente('Aaaa')
      con_turno_viejo = crear_paciente('Zzzz')
      Turno.create!(club: club, paciente: con_turno_viejo, medico: medico,
                    fecha_hora: 3.days.ago, tipo: 'seguimiento', estado: 'realizado')

      body = get_index

      expect(body['data'].first['apellido']).to eq('Aaaa')
    end

    it 'después del turno prioriza la indicación por vencer' do
      crear_paciente('Aaaa')
      con_indicacion = crear_paciente('Zzzz')
      IndicacionMedica.create!(paciente: con_indicacion, user: medico,
                               patologia: 'Dolor', dosificacion: '1 ml', via_administracion: 'oral',
                               fecha_emision: Time.zone.today, duracion_dias: 20, activa: true)

      body = get_index

      expect(body['data'].first['id']).to eq(con_indicacion.id)
      expect(body['data'].first['indicacion_vence_at']).to be_present
    end
  end

  describe 'búsqueda y filtros' do
    it 'busca por apellido' do
      crear_paciente('Gonzalez')
      crear_paciente('Rodriguez')

      body = get_index(query: 'gonz')

      expect(body['data'].map { |p| p['apellido'] }).to eq(['Gonzalez'])
    end

    it 'busca por DNI exacto' do
      objetivo = crear_paciente('Gonzalez', dni: '31222333')
      crear_paciente('Rodriguez', dni: '28111222')

      body = get_index(query: '31222333')

      expect(body['data'].map { |p| p['id'] }).to eq([objetivo.id])
    end

    it 'filtra por REPROCANN vencido' do
      vencido = crear_paciente('Vencido', reprocann_vencimiento: 5.days.ago.to_date)
      crear_paciente('Vigente', reprocann_vencimiento: 1.year.from_now.to_date)

      body = get_index(filtro: 'vencidos')

      expect(body['data'].map { |p| p['id'] }).to eq([vencido.id])
    end
  end

  describe 'KPIs' do
    it 'cuenta sobre el total y no sobre la página' do
      3.times { |i| crear_paciente("Venc#{i}", reprocann_vencimiento: 5.days.ago.to_date) }
      crear_paciente('SinRep')

      body = get_index(limite: 1)

      expect(body['data'].size).to eq(1)
      expect(body['meta']['kpis']).to include('total' => 4, 'vencidos' => 3, 'sin_rep' => 1)
    end
  end

  describe 'aislamiento de tenant' do
    it 'no devuelve pacientes de otro club' do
      crear_paciente('DelClub')
      otro_club = create(:club)
      otro_admin = create(:user, :admin, club: otro_club)
      ActsAsTenant.with_tenant(otro_club) do
        create(:paciente, club: otro_club, created_by: otro_admin, apellido: 'Ajeno')
      end

      body = get_index

      expect(body['data'].map { |p| p['apellido'] }).to eq(['DelClub'])
      expect(body['meta']['total']).to eq(1)
    end
  end
end
