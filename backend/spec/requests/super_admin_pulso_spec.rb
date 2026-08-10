require 'rails_helper'

# AC del panel de plataforma (ago-2026): responde "quién vence, quién necesita algo hoy y quién
# se está por ir", no "cuántas plantas hay entre todos los clubes".
#
# Los agregados se mudaron a Informes: para quien vende el software no son su cultivo, y
# ocupando el panel tapaban lo único accionable.
RSpec.describe 'SuperAdmin pulso', type: :request do
  let(:super_admin) { create(:user, :super_admin) }

  def pulso
    get '/api/super_admin/pulso'
    JSON.parse(response.body)
  end

  before { sign_in_as(super_admin) }

  describe 'suscripciones' do
    it 'separa lo vencido de lo que está por vencer' do
      vencido  = create(:club, name: 'Vencido',  plan_activo_hasta: Time.zone.today - 1)
      esta_sem = create(:club, name: 'Esta',     plan_activo_hasta: Time.zone.today + 3)
      proximo  = create(:club, name: 'Proximo',  plan_activo_hasta: Time.zone.today + 20)
      lejano   = create(:club, name: 'Lejano',   plan_activo_hasta: Time.zone.today + 90)

      s = pulso['suscripciones']

      expect(s['vencidos'].map  { |c| c['id'] }).to  include(vencido.id)
      expect(s['vencen_7'].map  { |c| c['id'] }).to  include(esta_sem.id)
      expect(s['vencen_30'].map { |c| c['id'] }).to  include(proximo.id)
      expect(s['vencen_30'].map { |c| c['id'] }).not_to include(lejano.id)
    end

    it 'cuenta los que no vencen nunca' do
      create(:club, plan_activo_hasta: nil)

      expect(pulso['suscripciones']['sin_vencimiento']).to be >= 1
    end

    it 'agrupa por los planes vigentes, normalizando los viejos' do
      create(:club, plan: 'basico')
      create(:club, plan: 'total')
      create(:club).update_columns(plan: 'federacion')

      por_plan = pulso['suscripciones']['por_plan']

      expect(por_plan.keys).to all(be_in(%w[basico total]))
      expect(por_plan['total']).to be >= 2
    end
  end

  # Lo más caro del panel viejo: se prendían los módulos, se mostraba la demo y no funcionaba
  # ninguno, sin que nada dijera por qué.
  describe 'requiere atención' do
    it 'lista los módulos prendidos que no funcionan, con qué les falta' do
      club = create(:club, name: 'Con WhatsApp muerto',
                           features: { 'cultivo' => true, 'produccion_dispensa' => true, 'whatsapp' => true })

      fila = pulso['atencion']['modulos_a_medias'].find { |m| m['id'] == club.id }

      expect(fila['modulo']).to       eq('whatsapp')
      expect(fila['modulo_label']).to eq('WhatsApp')
      expect(fila['falta']).to        match(/Twilio/i)
    end

    it 'no lista el módulo que sí funciona' do
      club = create(:club, features: { 'cultivo' => true, 'bar' => true })

      medias = pulso['atencion']['modulos_a_medias'].select { |m| m['id'] == club.id }

      expect(medias.map { |m| m['modulo'] }).not_to include('bar')
    end

    it 'marca al club que no puede operar porque no tiene ninguna suite' do
      club = create(:club, features: {})

      expect(pulso['atencion']['sin_suites'].map { |c| c['id'] }).to include(club.id)
    end

    it 'lista los suspendidos, que son plata que no entra' do
      club = create(:club)
      club.suspender!

      expect(pulso['atencion']['suspendidos'].map { |c| c['id'] }).to include(club.id)
    end
  end

  # El churn que importa es el que todavía no pasó.
  describe 'clubes en silencio' do
    it 'marca al club sin actividad reciente' do
      club = create(:club, name: 'Callado')

      expect(pulso['sin_actividad'].map { |c| c['id'] }).to include(club.id)
    end

    it 'no marca al club que abrió un lote hace poco' do
      club = create(:club, name: 'Activo')
      ActsAsTenant.with_tenant(club) { create(:lote, club: club) }

      expect(pulso['sin_actividad'].map { |c| c['id'] }).not_to include(club.id)
    end
  end

  describe 'salud' do
    # El fallo silencioso que sólo se cazaba corriendo un rake a mano.
    it 'marca al club que paga IoT y tiene las sondas calladas' do
      club = create(:club, name: 'Sin señal',
                           features: { 'cultivo' => true, 'iot' => true })

      expect(pulso['salud']['iot_mudo'].map { |c| c['id'] }).to include(club.id)
    end

    it 'no mira el IoT de un club que no lo contrató' do
      club = create(:club, features: { 'cultivo' => true })

      expect(pulso['salud']['iot_mudo'].map { |c| c['id'] }).not_to include(club.id)
    end

    # Sin Redis el panel no puede reventar: que no haya cola es un dato, no un error de página.
    it 'informa el estado de la cola sin romperse' do
      expect(pulso['salud']['sidekiq']).to have_key('disponible')
      expect(response).to have_http_status(:ok)
    end
  end

  # La diferencia entre "lo tienen" y "lo tienen andando" es el trabajo pendiente.
  describe 'adopción' do
    it 'separa cuántos lo tienen de cuántos lo tienen funcionando' do
      create(:club, features: { 'cultivo' => true, 'produccion_dispensa' => true, 'whatsapp' => true })

      wa = pulso['adopcion'].find { |a| a['clave'] == 'whatsapp' }

      expect(wa['tienen']).to  be >= 1
      expect(wa['andando']).to eq(0)
    end
  end

  describe 'lo que ya NO está en el panel' do
    it 'no cuenta plantas ni lotes: eso es un informe, no el panel' do
      p = pulso

      expect(p).not_to have_key('total_plantas')
      expect(p).not_to have_key('total_lotes')
      expect(p.dig('totales', 'clubes_operando')).to be_present
    end
  end

  describe 'clubes demo' do
    it 'quedan fuera: tienen datos inventados' do
      demo = create(:club, name: 'Modelo', demo: true, features: {})

      expect(pulso['atencion']['sin_suites'].map { |c| c['id'] }).not_to include(demo.id)
    end
  end

  it 'un admin de club no accede' do
    sign_in_as(create(:user, :admin, club: create(:club)))

    get '/api/super_admin/pulso'

    expect(response).to have_http_status(:forbidden)
  end
end
