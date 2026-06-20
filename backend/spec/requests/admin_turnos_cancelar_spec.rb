require 'rails_helper'

RSpec.describe 'DELETE /api/admin/turnos/:id (cancelar turno)', type: :request do
  let(:club)     { create(:club) }
  let(:admin)    { create(:user, :admin, club: club) }
  let(:medico)   { create(:user, :medico, club: club) }
  let(:paciente) { create(:paciente, club: club, created_by: admin) }

  def crear_turno(estado: 'programado')
    Turno.create!(club: club, paciente: paciente, medico: medico,
                  fecha_hora: 2.days.from_now, duracion_minutos: 30, tipo: 'seguimiento', estado: estado)
  end

  before { sign_in_as(admin) }

  it 'cancela un turno programado' do
    t = crear_turno
    delete "/api/admin/turnos/#{t.id}", as: :json
    expect(response).to have_http_status(:no_content)
    expect(t.reload.estado).to eq('cancelado')
  end

  it 'cancela aunque el turno tenga un campo inválido (dato legacy) — no debe 500' do
    t = crear_turno
    t.update_columns(tipo: 'legacy_invalido')   # update! completo fallaría por inclusion
    delete "/api/admin/turnos/#{t.id}", as: :json
    expect(response).to have_http_status(:no_content)
    expect(t.reload.estado).to eq('cancelado')
  end

  it 'no cancela un turno ya realizado' do
    t = crear_turno(estado: 'realizado')
    delete "/api/admin/turnos/#{t.id}", as: :json
    expect(response).to have_http_status(:unprocessable_entity)
    expect(t.reload.estado).to eq('realizado')
  end
end
