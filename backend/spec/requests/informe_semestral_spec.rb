require 'rails_helper'

# GET /informe_semestral: el cálculo vive en `Informes::Semestral` (ver su spec). Acá, lo del
# endpoint: el DNI parcial en pantalla y entero en el archivo, el PDF con las secciones nuevas.
RSpec.describe 'La declaración jurada semestral', type: :request do
  let(:club)  { create(:club, name: 'Club Verde') }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, created_by: admin, tipo: 'mixta') }
  let(:sala)  { create(:sala, club: club, sede: sede, kind: 'mixta') }

  before do
    sign_in_as(admin)
    create(:paciente, club: club, created_by: admin, nombre: 'Beto', apellido: 'Ruiz', dni: '30111222',
                      reprocann_numero: 'RP-123', reprocann_vencimiento: 6.months.from_now.to_date)
    g = create(:genetica, club: club, nombre: 'Lemon', registrada_inase: true, criador: 'INTA')
    l = create(:lote, club: club, sala: sala, genetica: g, estado: 'curado', rendimiento_real_g: 420, plants_count_cosechadas: 6)
    l.lote_eventos.create!(tipo: 'cambio_estado', estado_nuevo: 'cosecha', club: club, user: admin, registrado_en: Time.zone.today)
  end

  let(:semestre) { Time.zone.today.month <= 6 ? 1 : 2 }

  def texto_pdf
    PDF::Reader.new(StringIO.new(response.body)).pages.map(&:text).join("\n").gsub(/\s+/, ' ')
  end

  it 'la pantalla recibe el DNI parcial; el archivo, entero' do
    get '/api/informe_semestral', params: { anio: Time.zone.today.year, semestre: semestre }

    expect(response).to have_http_status(:ok)
    fila = JSON.parse(response.body).dig('pacientes', 'nomina').first
    expect(fila).not_to have_key('dni')
    expect(fila['dni_ultimos_3']).to eq('222')

    get '/api/informe_semestral.pdf', params: { anio: Time.zone.today.year, semestre: semestre }
    expect(texto_pdf).to include('30111222')
  end

  it 'el PDF lleva la población al cierre, el cultivo por variedad con su origen y las entregas' do
    get '/api/informe_semestral.pdf', params: { anio: Time.zone.today.year, semestre: semestre }

    expect(response).to have_http_status(:ok)
    t = texto_pdf
    expect(t).to match(/DECLARACIÓN SEMESTRAL/i)
    expect(t).to include('Estado al cierre')
    expect(t).to include('Lemon')
    expect(t).to include('INTA')
    expect(t).to include('Semilla / esqueje')
    expect(t).to match(/ENTREGAS DEL PERÍODO/)
    expect(t).not_to match(/aporte/i)
    expect(t).to include('Firma y aclaración')
  end
end
