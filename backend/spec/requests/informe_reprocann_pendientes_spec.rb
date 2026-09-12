require 'rails_helper'

# EL REPROCANN TIENE DOS LECTORES: el organismo recibe la nómina; el admin recibe los pendientes
# CON NOMBRE (a quién llamar porque vence, quién venció y sigue retirando). Cumplimiento decía
# «12 vencidos» y nada más. Y «retiró sin REPROCANN vigente» se juzga el DÍA DE LA ENTREGA, no
# hoy: un paciente en regla en marzo que venció en agosto figuraba en falta todo el año.
RSpec.describe 'REPROCANN — pendientes con nombre', type: :request do
  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, created_by: admin, tipo: 'mixta') }
  let!(:stock) { create(:stock, club: club, sede: sede, cantidad: 500) }

  let!(:vencida)   { create(:paciente, club: club, created_by: admin, nombre: 'Ana', apellido: 'Vencida', dni: '30111222', reprocann_numero: 'RP-1', reprocann_vencimiento: 20.days.ago.to_date) }
  let!(:por_vencer) { create(:paciente, club: club, created_by: admin, nombre: 'Beto', apellido: 'Pronto', reprocann_numero: 'RP-2', reprocann_vencimiento: 12.days.from_now.to_date) }
  let!(:en_regla)  { create(:paciente, club: club, created_by: admin, nombre: 'Cata', apellido: 'Regla', reprocann_numero: 'RP-3', reprocann_vencimiento: 1.year.from_now.to_date, con_seguimiento_medico: true) }

  before { sign_in_as(admin) }

  def informe(params = {})
    get '/api/informes/reprocann', params: params
    expect(response).to have_http_status(:ok), response.body
    JSON.parse(response.body)
  end

  it 'lista los pendientes por urgencia, con nombre y sin el DNI entero' do
    Dispensacion.create!(paciente: vencida, user: admin, stock: stock, sede: sede, cantidad: 5, fecha_dispensacion: Time.zone.today)

    pend = informe['lista_pendientes']
    expect(pend.map { |p| [p['pendiente'], p['paciente']] }.first(2)).to eq([['vencido_retiro', 'Ana Vencida'], ['por_vencer', 'Beto Pronto']])
    expect(pend.first['dni_ultimos_3']).to eq('222')
    expect(pend.first).not_to have_key('dni')
    expect(informe['pendientes_resumen']).to include('vencido_retiro' => 1, 'por_vencer' => 1)
  end

  it 'juzga «sin REPROCANN vigente» el día de la entrega, no hoy' do
    # Retiró hace 40 días, cuando todavía estaba vigente (venció hace 20).
    Dispensacion.create!(paciente: vencida, user: admin, stock: stock, sede: sede, cantidad: 5, fecha_dispensacion: 40.days.ago.to_date)
    Dispensacion.create!(paciente: vencida, user: admin, stock: stock, sede: sede, cantidad: 5, fecha_dispensacion: 5.days.ago.to_date)

    d = informe(desde: 60.days.ago.to_date.to_s, hasta: Time.zone.today.to_s)['dispensaciones']
    expect(d['total']).to eq(2)
    expect(d['entregas_sin_vigente']).to eq(1)
    expect(d['por_unidad']).to eq([{ 'unidad' => 'g', 'cantidad' => 10.0 }])
  end

  it 'las entregas son del período elegido' do
    Dispensacion.create!(paciente: en_regla, user: admin, stock: stock, sede: sede, cantidad: 5, fecha_dispensacion: 8.months.ago.to_date)
    expect(informe(periodo: 'mes_actual')['dispensaciones']['total']).to eq(0)
  end
end
