require 'rails_helper'

# AC (Germán, 18 y 19-oct-2026):
# · El REPROCANN de un vinculado sigue un ciclo: pendiente de entrevista → «Inicié el trámite» →
#   pendiente de aprobación → número y vencimiento → activo.
# · «No indicado» (la médica no lo pide) y «Rechazado» (el Ministerio): el paciente queda inactivo
#   —«no debería poder dispensar»— y de los dos se sale con una entrevista nueva.
# · «Faltó al turno» se muestra como dato chico, con la fecha.
# · El turno es opcional en el alta.
RSpec.describe 'El ciclo del REPROCANN de un paciente', type: :request do
  let(:club)   { create(:club) }
  let(:admin)  { create(:user, :admin, club: club) }
  let(:medico) { create(:user, :medico, club: club) }
  let(:hoy)    { Time.zone.today }

  def paciente(**attrs)
    create(:paciente, club: club, created_by: admin, reprocann_vinculo: 'organizacion', **attrs)
  end

  def vincular(p, m = medico)
    ActsAsTenant.with_tenant(club) { MedicoPaciente.vincular!(medico: m, paciente: p, por: admin) }
  end

  def turno(p, cuando:, estado:, medico: self.medico)
    ActsAsTenant.with_tenant(club) do
      Turno.create!(club: club, paciente: p, medico: medico, fecha_hora: cuando,
                    duracion_minutos: 30, tipo: 'seguimiento', estado: estado)
    end
  end

  def situacion(p)
    get "/api/pacientes/#{p.id}"
    JSON.parse(response.body).dig('data', 'situacion')
  end

  def json = JSON.parse(response.body)

  describe 'el ciclo completo' do
    it 'pendiente de entrevista → iniciar trámite → pendiente de aprobación → aprobado → activo' do
      sign_in_as(admin)
      p = paciente
      expect(situacion(p)).to include('vinculo' => 'vinculado', 'reprocann' => 'pendiente_entrevista',
                                      'pendiente_entrevista' => true, 'paciente' => 'activo')
      expect(situacion(p)['acciones']).to include('iniciar_tramite', 'no_indicado', 'dar_turno')

      post "/api/pacientes/#{p.id}/iniciar_tramite_reprocann"
      expect(response).to have_http_status(:ok)
      expect(json.dig('data', 'situacion')).to include('reprocann' => 'pendiente_aprobacion', 'pendiente_entrevista' => false)
      expect(json.dig('data', 'situacion', 'acciones')).to contain_exactly('cargar_aprobado', 'rechazado')

      post "/api/pacientes/#{p.id}/reprocann_aprobado", params: { numero: 'REP-123', vencimiento: (hoy + 3.years).iso8601 }
      expect(response).to have_http_status(:ok)
      expect(json.dig('data', 'situacion')).to include('reprocann' => 'activo', 'pendiente_entrevista' => false)
      expect(p.reload).to have_attributes(reprocann_estado: 'activo', reprocann_numero: 'REP-123')
    end

    it 'no se inicia dos veces ni se carga «aprobado» sin trámite en curso' do
      sign_in_as(admin)
      p = paciente(reprocann_estado: 'pendiente')
      post "/api/pacientes/#{p.id}/iniciar_tramite_reprocann"
      expect(response).to have_http_status(:unprocessable_entity)
      expect(json['error']).to match(/ya está iniciado/)

      q = paciente
      post "/api/pacientes/#{q.id}/reprocann_aprobado", params: { numero: 'R', vencimiento: (hoy + 1.year).iso8601 }
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'un adherente no inicia trámite: su organización lo tramita' do
      sign_in_as(admin)
      p = paciente(reprocann_vinculo: 'otra_organizacion', reprocann_estado: 'activo')
      expect(situacion(p)).to include('vinculo' => 'adherente', 'reprocann' => 'activo', 'pendiente_entrevista' => false)
      expect(situacion(p)['acciones']).to eq(['vincular'])
      post "/api/pacientes/#{p.id}/iniciar_tramite_reprocann"
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe '«No indicado» (la médica)' do
    it 'el médico de sus vinculados lo marca con motivo: queda inactivo y administración se entera' do
      p = paciente
      vincular(p)
      sign_in_as(medico)
      expect {
        post "/api/pacientes/#{p.id}/reprocann_no_indicado", params: { motivo: 'No corresponde por ahora' }
      }.to change { AlertaInterna.where(tipo: 'reprocann_no_indicado').count }.by(1)

      expect(response).to have_http_status(:ok)
      expect(json.dig('data', 'situacion')).to include('reprocann' => 'no_indicado', 'paciente' => 'inactivo')
      expect(p.reload).to have_attributes(es_paciente: false, reprocann_resultado_motivo: 'No corresponde por ahora',
                                          reprocann_resultado_el: hoy)
    end

    it 'sin motivo no se marca' do
      sign_in_as(admin)
      p = paciente
      post "/api/pacientes/#{p.id}/reprocann_no_indicado", params: { motivo: '  ' }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(p.reload.es_paciente).to be(true)
    end

    it 'no se marca a quien tiene el REPROCANN vigente y lejos de vencer' do
      sign_in_as(admin)
      p = paciente(reprocann_estado: 'activo', reprocann_numero: 'R1', reprocann_vencimiento: hoy + 1.year)
      post "/api/pacientes/#{p.id}/reprocann_no_indicado", params: { motivo: 'x' }
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'un médico no lo marca a un paciente que no es suyo' do
      p = paciente
      sign_in_as(medico)
      post "/api/pacientes/#{p.id}/reprocann_no_indicado", params: { motivo: 'x' }
      expect(response).to have_http_status(:not_found)
      expect(p.reload.reprocann_estado).to eq('sin_registro')
    end

    it 'después de «No indicado» no se le puede dispensar' do
      sign_in_as(admin)
      p = paciente
      post "/api/pacientes/#{p.id}/reprocann_no_indicado", params: { motivo: 'x' }
      ActsAsTenant.with_tenant(club) do
        d = Dispensacion.new(paciente: p.reload, user: admin, cantidad: 1, fecha_dispensacion: hoy)
        d.valid?
        expect(d.errors[:base]).to include('El paciente no está activo en la organización')
      end
    end
  end

  describe '«Rechazado» (el Ministerio)' do
    it 'sólo desde un trámite en curso; queda inactivo con el motivo' do
      sign_in_as(admin)
      sin_tramite = paciente
      post "/api/pacientes/#{sin_tramite.id}/reprocann_rechazado", params: { motivo: 'x' }
      expect(response).to have_http_status(:unprocessable_entity)

      p = paciente(reprocann_estado: 'pendiente')
      post "/api/pacientes/#{p.id}/reprocann_rechazado", params: { motivo: 'Falta documentación' }
      expect(response).to have_http_status(:ok)
      expect(json.dig('data', 'situacion')).to include('reprocann' => 'rechazado', 'paciente' => 'inactivo')
      expect(json.dig('data', 'situacion', 'acciones')).to eq(['volver_a_entrevistar'])
    end
  end

  describe 'volver a entrevistar' do
    it 'administración lo devuelve al ciclo y activo; el médico no reactiva' do
      p = paciente(reprocann_estado: 'pendiente', reprocann_numero: 'R1', reprocann_vencimiento: hoy - 10)
      vincular(p)
      sign_in_as(admin)
      post "/api/pacientes/#{p.id}/reprocann_rechazado", params: { motivo: 'x' }

      # El médico ve sólo a sus vinculados ACTIVOS: el inactivo ya no le aparece, y no lo reactiva.
      sign_in_as(medico)
      post "/api/pacientes/#{p.id}/volver_a_entrevistar"
      expect(response).to have_http_status(:not_found)
      expect(p.reload.reprocann_estado).to eq('rechazado')

      sign_in_as(admin)
      post "/api/pacientes/#{p.id}/volver_a_entrevistar"
      expect(response).to have_http_status(:ok)
      # Tenía un REPROCANN vencido: vuelve a mostrar los dos datos.
      expect(json.dig('data', 'situacion')).to include('reprocann' => 'vencido', 'pendiente_entrevista' => true,
                                                       'paciente' => 'activo')
    end

    it 'desde la edición no se cierra el REPROCANN ni se reactiva a un cerrado' do
      sign_in_as(admin)
      p = paciente
      patch "/api/pacientes/#{p.id}", params: { paciente: { reprocann_estado: 'no_indicado' } }
      expect(response).to have_http_status(:unprocessable_entity)

      post "/api/pacientes/#{p.id}/reprocann_no_indicado", params: { motivo: 'x' }
      patch "/api/pacientes/#{p.id}", params: { paciente: { es_paciente: true } }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(json['errors'].join).to match(/Volver a entrevistar/)
    end
  end

  describe 'lo que dicen los turnos, al lado' do
    before { sign_in_as(admin) }

    it '«faltó al turno» con la fecha, si su último turno quedó ausente y no tiene otro' do
      p = paciente
      cuando = 3.days.ago.change(hour: 11)
      turno(p, cuando: cuando, estado: 'ausente')
      expect(situacion(p)['falto_turno_el']).to eq(cuando.to_date.iso8601)

      turno(p, cuando: 2.days.from_now, estado: 'programado')
      sit = situacion(p)
      expect(sit['falto_turno_el']).to be_nil
      expect(sit['proximo_turno_at']).to be_present
      expect(sit['acciones']).not_to include('dar_turno') # ya tiene turno
    end

    it 'el turno que pasó sin cerrar es un aviso aparte, no cambia el REPROCANN' do
      p = paciente(reprocann_estado: 'activo', reprocann_numero: 'R1', reprocann_vencimiento: hoy + 1.year)
      turno(p, cuando: 2.days.ago, estado: 'confirmado')
      expect(situacion(p)).to include('turno_sin_cerrar' => true, 'reprocann' => 'activo', 'pendiente_entrevista' => false)
    end

    it 'administración sigue viendo, por médico, cuántos turnos ya pasaron sin cerrar' do
      otro = create(:user, :medico, club: club)
      turno(paciente, cuando: 2.days.ago, estado: 'programado')
      turno(paciente, cuando: 1.day.ago,  estado: 'confirmado')
      turno(paciente, cuando: 1.day.ago,  estado: 'realizado')
      turno(paciente, cuando: 1.day.ago,  estado: 'programado', medico: otro)
      get '/api/admin/medicos'
      expect(json.to_h { |m| [m['id'], m['turnos_sin_cerrar']] }).to eq(medico.id => 2, otro.id => 1)
    end

    it 'el mostrador no recibe la situación (el REPROCANN no es asunto suyo)' do
      paciente
      sign_in_as(create(:user, :dispensador, club: club))
      get '/api/pacientes'
      expect(json['data'].first).not_to have_key('situacion')
    end
  end

  describe 'los contadores dicen lo mismo que las filas' do
    before { sign_in_as(admin) }

    it 'cuenta sólo al que pide entrevista, y a los cerrados aparte de la nómina' do
      paciente(reprocann_estado: 'activo', reprocann_numero: 'R1', reprocann_vencimiento: hoy + 1.year) # no
      paciente(reprocann_estado: 'activo', reprocann_numero: 'R2', reprocann_vencimiento: hoy + 10)     # por vencer
      paciente(reprocann_estado: 'activo', reprocann_numero: 'R3', reprocann_vencimiento: hoy - 1)      # vencido
      paciente(reprocann_vinculo: 'otra_organizacion', reprocann_estado: 'activo', reprocann_vencimiento: hoy - 1) # adherente
      paciente(reprocann_estado: 'pendiente')
      paciente(reprocann_estado: 'rechazado', es_paciente: false, reprocann_resultado_motivo: 'x')

      get '/api/pacientes'
      filas = json['data']
      kpis  = json.dig('meta', 'kpis')
      en_nomina = filas.select { |f| f['es_paciente'] }

      expect(kpis['entrevista_pendiente']).to eq(2)
      expect(kpis['entrevista_pendiente']).to eq(en_nomina.count { |f| f.dig('situacion', 'pendiente_entrevista') })
      expect(kpis['proximos']).to eq(1)
      expect(kpis['vencidos']).to eq(2) # el vinculado y el adherente
      expect(kpis['pendientes']).to eq(1)
      expect(kpis['adherentes']).to eq(1)
      expect(kpis['cerrados']).to eq(1)
      expect(kpis['total']).to eq(5)
      expect(kpis['baja']).to eq(1)
    end
  end

  describe 'alta con turno opcional' do
    let(:manana) { (hoy + 2).in_time_zone.change(hour: 10) }
    let(:datos)  { { nombre: 'Ana', apellido: 'Paz', dni: '30111222', fecha_nacimiento: '1990-01-01', reprocann_vinculo: 'organizacion' } }

    before { sign_in_as(admin) }

    it 'crea el paciente y su turno, y lo vincula con el médico' do
      expect {
        post '/api/pacientes', params: { paciente: datos, turno: { medico_id: medico.id, fecha_hora: manana.iso8601 } }
      }.to change(Turno, :count).by(1)
      expect(response).to have_http_status(:created)
      p = Paciente.find(json.dig('data', 'id'))
      expect(p.turnos.first).to have_attributes(medico_id: medico.id, tipo: 'primera_vez', estado: 'programado')
      expect(p.medicos).to include(medico)
    end

    it 'sin turno, el alta sale igual' do
      post '/api/pacientes', params: { paciente: datos }
      expect(response).to have_http_status(:created)
      expect(Turno.count).to eq(0)
    end

    it 'si el turno no entra (ya pasó), no queda un alta a medias' do
      expect {
        post '/api/pacientes', params: { paciente: datos, turno: { medico_id: medico.id, fecha_hora: 2.days.ago.iso8601 } }
      }.not_to change(Paciente, :count)
      expect(response).to have_http_status(:unprocessable_entity)
      expect(json['errors'].join).to match(/turno/i)
    end

    it 'un médico de otra organización no sirve (aislamiento)' do
      otro = create(:club)
      ajeno = ActsAsTenant.with_tenant(otro) { create(:user, :medico, club: otro) }
      expect(ajeno.club_id).to eq(otro.id)
      expect {
        post '/api/pacientes', params: { paciente: datos, turno: { medico_id: ajeno.id, fecha_hora: manana.iso8601 } }
      }.not_to change(Paciente, :count)
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'un alta no nace «No indicado»' do
      post '/api/pacientes', params: { paciente: datos.merge(reprocann_estado: 'no_indicado') }
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'aislamiento de tenant' do
    it 'un paciente de otra organización no se toca' do
      otro_club = create(:club)
      otro_admin = create(:user, :admin, club: otro_club)
      ajeno = ActsAsTenant.with_tenant(otro_club) { create(:paciente, club: otro_club, created_by: otro_admin) }
      expect(ajeno.club_id).to eq(otro_club.id)
      sign_in_as(admin)
      post "/api/pacientes/#{ajeno.id}/reprocann_no_indicado", params: { motivo: 'x' }
      expect(response).to have_http_status(:not_found)
      expect(ajeno.reload.es_paciente).to be(true)
    end
  end
end
