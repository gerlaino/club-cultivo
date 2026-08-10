require 'rails_helper'

# Los informes estaban armados por ENTIDAD (pacientes, lotes, stock) y no por PREGUNTA, así que
# cada uno mostraba el conteo de su tabla y entre ellos se contradecían. Estos specs fijan a
# quién le habla cada uno, que es lo que decide qué entra y qué no.
RSpec.describe 'Informes — a quién le habla cada uno', type: :request do
  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, created_by: admin) }

  before { sign_in_as(admin) }

  describe 'REPROCANN — le habla al ORGANISMO' do
    let!(:con_registro) do
      create(:paciente, club: club, created_by: admin, es_paciente: true,
                        reprocann_estado: 'activo', reprocann_numero: 'RC-1',
                        reprocann_vencimiento: Date.current + 1.year)
    end
    let!(:en_tramite) do
      create(:paciente, club: club, created_by: admin, es_paciente: true,
                        reprocann_estado: 'pendiente', reprocann_numero: 'RC-2')
    end
    let!(:sin_registro) do
      create(:paciente, club: club, created_by: admin, es_paciente: true,
                        reprocann_estado: 'sin_registro', reprocann_numero: nil)
    end

    def informe
      get '/api/informes/reprocann'
      expect(response).to have_http_status(:ok), response.body
      JSON.parse(response.body)
    end

    # Declara la población REGISTRADA. Que existan pacientes sin REPROCANN es un pendiente
    # interno del club, no algo que se presenta ante nadie.
    it 'cuenta sólo a los que tienen REPROCANN' do
      expect(informe['total_pacientes']).to eq(2)
    end

    it 'el que está en trámite sí cuenta: tiene registro iniciado' do
      expect(informe['pendientes']).to eq(1)
    end

    it 'no esconde a los que faltan: los informa aparte' do
      expect(informe['pacientes_sin_registro']).to eq(1)
    end

    # Un PACIENTE ES DEL CLUB, no de una sede. El corte por sede agrupaba por la sede de su
    # última dispensación —una dimensión que no existe en el modelo— y dejaba a los que nunca
    # retiraron en una fila que parecía una sede llamada "sin dispensaciones".
    it 'ya no corta por sede: un paciente no tiene sede' do
      expect(informe).not_to have_key('por_sede')
    end

    it 'la tasa de cumplimiento se calcula sobre los registrados' do
      # 1 vigente + 0 por vencer sobre 2 registrados = 50%
      expect(informe['cumplimiento']['tasa']).to eq(50.0)
    end
  end

  describe 'Producción — separa el período de la foto de hoy' do
    let(:sala) { create(:sala, club: club, sede: sede, created_by: admin) }
    let!(:curado_viejo) do
      create(:lote, club: club, sala: sala, estado: 'curado', rendimiento_real_g: 1_500)
        .tap { |l| l.update_columns(updated_at: 6.months.ago) }
    end

    def informe
      get '/api/informes/produccion'
      expect(response).to have_http_status(:ok), response.body
      JSON.parse(response.body)
    end

    # El bug que veía Germán: un lote curado con peso confirmado mostraba 0 g, porque la tabla
    # de estados —que habla del PRESENTE— traía una columna filtrada por el período elegido.
    it 'la tabla de hoy muestra el rendimiento acumulado, no el del período' do
      fila = informe['por_estado'].find { |e| e['estado'] == 'curado' }

      expect(fila['rendimiento']).to eq(1500.0)
    end

    it 'el KPI del período sigue siendo del período' do
      # El lote se curó hace medio año: no entra en el mes actual.
      expect(informe['gramos_producidos']).to eq(0.0)
    end
  end

  describe 'Dispensaciones — se puede cruzar con producción' do
    let(:lote)     { create(:lote, club: club) }
    let(:genetica) { create(:genetica, club: club, nombre: 'Northern Lights') }
    let(:paciente) { create(:paciente, club: club, created_by: admin, dni: '30111518') }
    let(:stock) do
      create(:stock, club: club, sede: sede, lote: lote, genetica: genetica,
                     cantidad: 500, forma_producto: 'flor_seca')
    end

    before do
      Dispensacion.create!(paciente: paciente, stock: stock, sede: sede, cantidad: 10,
                           fecha_dispensacion: Time.zone.today, user: admin,
                           medio_pago: 'efectivo', aporte_socio_ars: 1000)
    end

    def fila
      get '/api/informes/dispensaciones'
      expect(response).to have_http_status(:ok), response.body
      JSON.parse(response.body)['resumen_anonimizado'].first
    end

    it 'identifica al paciente sin ambigüedad: nombre y DNI parcial' do
      expect(fila['paciente']).to eq(paciente.nombre_completo)
      expect(fila['dni_ultimos_3']).to eq('518')
    end

    it 'dice QUÉ se entregó, que es lo que permite cruzarlo con el cultivo' do
      expect(fila['geneticas']).to include('Northern Lights')
      expect(fila['formas']).to include('flor_seca')
    end
  end
end
