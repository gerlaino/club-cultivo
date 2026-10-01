require 'rails_helper'

# AC (Germán, 29-sep-2026; fase 2 el 30-sep): el admin arma el informe que necesita —estos lotes,
# estas genéticas, esta sede, estos pacientes— en Pérdidas, Plan vs real, INASE y REPROCANN.
# Mismas reglas que la fase 1: un filtro que no vino es «todos»; uno con ids ajenos deja el
# informe vacío; el informe filtrado lo dice. Y una propia de los regulatorios: lo que se
# PRESENTA («para presentar») no se filtra.
RSpec.describe 'Informes: filtros, fase 2', type: :request do
  let(:club)   { create(:club) }
  let(:admin)  { create(:user, :admin, club: club) }
  let(:centro) { create(:sede, club: club, created_by: admin, nombre: 'Centro', tipo: 'produccion') }
  let(:norte)  { create(:sede, club: club, created_by: admin, nombre: 'Norte', tipo: 'produccion') }
  let(:lemon)  { create(:genetica, club: club, nombre: 'Lemon', registrada_inase: true, criador: 'INTA') }
  let(:kush)   { create(:genetica, club: club, nombre: 'Kush', registrada_inase: true, criador: 'INTA') }

  before { sign_in_as(admin) }

  def informe(nombre, params = {})
    get "/api/informes/#{nombre}", params: params
    expect(response).to have_http_status(:ok), response.body
    JSON.parse(response.body)
  end

  def lote!(sede, genetica, codigo, **attrs)
    create(:lote, club: club, sala: create(:sala, club: club, sede: sede, created_by: admin), genetica: genetica, codigo: codigo, **attrs)
  end

  def cosechado!(sede, genetica, codigo, gramos:)
    l = lote!(sede, genetica, codigo, estado: 'curado', rendimiento_real_g: gramos, plants_count_cosechadas: 10)
    l.lote_eventos.create!(tipo: 'cambio_estado', estado_nuevo: 'cosecha', club: club, user: admin, registrado_en: Time.zone.now.beginning_of_month)
    l
  end

  describe 'Pérdidas' do
    let!(:l_centro) { lote!(centro, lemon, 'L-C') }
    let!(:l_norte)  { lote!(norte, kush, 'L-N') }

    before do
      create(:plant, lote: l_centro, club: club, state: 'descartada', motivo_descarte: 'plaga')
      create(:plant, lote: l_norte,  club: club, state: 'descartada', motivo_descarte: 'macho')
      create(:plant, lote: l_norte,  club: club, state: 'descartada', motivo_descarte: 'macho')
      propio  = create(:stock, club: club, sede: centro, lote: l_centro, cantidad: 100)
      externo = Stock.create!(club: club, sede: norte, origen: 'compra_externa', proveedor: 'Coop', forma_producto: 'flor_seca', unidad: 'g', cantidad: 80)
      propio.stock_movimientos.create!(tipo: 'merma', gramos: -10, usuario: admin)
      externo.stock_movimientos.create!(tipo: 'merma', gramos: -5, usuario: admin)
    end

    it 'sin filtros, toda la organización' do
      d = informe('perdidas')
      expect(d['plantas']['total']).to eq(3)
      expect(d['producto']['lista'].size).to eq(2)
      expect(d['filtros']['activo']).to be(false)
    end

    it 'por sede: las plantas y el producto de esa sede, y lo dice' do
      d = informe('perdidas', sede_ids: [norte.id])
      expect(d['plantas']['total']).to eq(2)
      expect(d['producto']['lista'].map { |f| f['cantidad'] }).to eq([5.0])
      expect(d['filtros']['descripcion']).to eq('Sedes: Norte')
    end

    it 'por un lote: sus plantas y su producto; el stock externo no tiene lote' do
      d = informe('perdidas', lote_ids: [l_centro.id])
      expect(d['plantas']['total']).to eq(1)
      expect(d['producto']['lista'].map { |f| f['cantidad'] }).to eq([10.0])
    end

    it 'por genética, con dos genéticas: cuenta las dos (cualquiera cumple)' do
      d = informe('perdidas', genetica_ids: [lemon.id, kush.id])
      expect(d['plantas']['total']).to eq(3)
    end

    it 'sólo stock externo: ninguna planta (no tiene lotes) y sólo la merma del externo' do
      d = informe('perdidas', origen: 'externo')
      expect(d['plantas']['total']).to eq(0)
      expect(d['producto']['lista'].map { |f| f['cantidad'] }).to eq([5.0])
    end

    it 'el PDF acepta los mismos filtros' do
      get '/api/informes/perdidas.pdf', params: { sede_ids: [norte.id] }
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'Plan vs real' do
    before do
      cosechado!(centro, lemon, 'L-C1', gramos: 500)
      cosechado!(norte,  kush,  'L-N1', gramos: 300)
      lote!(norte, kush, 'L-N2', estado: 'vegetativo')
    end

    it 'por sede acota los tres bloques' do
      d = informe('plan_vs_real', sede_ids: [norte.id])
      expect(d['salio']['lotes'].map { |l| l['codigo'] }).to eq(['L-N1'])
      expect(d['viene'].map { |l| l['codigo'] }).to eq(['L-N2'])
      expect(d['geneticas'].map { |g| g['genetica'] }).to eq(['Kush'])
      expect(d['filtros']['descripcion']).to eq('Sedes: Norte')
    end

    it 'por un lote' do
      d = informe('plan_vs_real', lote_ids: [lote_c1 = Lote.find_by(codigo: 'L-C1').id])
      expect(d['salio']['lotes'].map { |l| l['id'] || l['codigo'] }).to eq(['L-C1']).or eq([lote_c1])
      expect(d['viene']).to be_empty
    end
  end

  describe 'INASE' do
    before do
      cosechado!(centro, lemon, 'L-C1', gramos: 500)
      cosechado!(norte,  kush,  'L-N1', gramos: 300)
    end

    it 'filtrado por genética: sólo esa variedad, y lo dice' do
      d = informe('inase', genetica_ids: [kush.id])
      expect(d['variedades'].map { |v| v['nombre'] }).to eq(['Kush'])
      expect(d['kpis']['gramos']).to eq(300.0)
      expect(d['filtros']['descripcion']).to eq('Genéticas: Kush')
    end

    it '«para presentar» sale completo aunque se pida filtrado' do
      get '/api/informes/inase', params: { genetica_ids: [kush.id], para_presentar: 1 }
      d = JSON.parse(response.body)
      expect(d['variedades'].map { |v| v['nombre'] }).to contain_exactly('Lemon', 'Kush')
      expect(d['filtros']['activo']).to be(false)
    end
  end

  describe 'REPROCANN' do
    let!(:ana)  { create(:paciente, club: club, created_by: admin, nombre: 'Ana', apellido: 'Uno', reprocann_numero: 'RP-1', reprocann_vencimiento: 1.year.from_now.to_date) }
    let!(:beto) { create(:paciente, club: club, created_by: admin, nombre: 'Beto', apellido: 'Dos', reprocann_numero: 'RP-2', reprocann_vencimiento: 10.days.ago.to_date) }

    it 'por paciente: la nómina y los conteos de ese paciente, y lo dice' do
      d = informe('reprocann', paciente_ids: [beto.id])
      expect(d['lista_anonimizada'].map { |p| p['nombre_completo'] }).to eq(['Beto Dos'])
      expect(d['total_pacientes']).to eq(1)
      expect(d['vencidos']).to eq(1)
      expect(d['filtros']['descripcion']).to include('Beto Dos')
    end

    it 'un paciente de otra organización deja la nómina vacía (no la de todos)' do
      otro = create(:club)
      ajeno = ActsAsTenant.with_tenant(otro) { create(:paciente, club: otro, created_by: create(:user, :admin, club: otro)) }
      d = informe('reprocann', paciente_ids: [ajeno.id])
      expect(d['lista_anonimizada']).to be_empty
      expect(d['filtros']['activo']).to be(true)
    end

    it '«para presentar» sale completo' do
      get '/api/informes/reprocann.pdf', params: { paciente_ids: [beto.id], para_presentar: 1 }
      expect(response).to have_http_status(:ok)
      texto = PDF::Reader.new(StringIO.new(response.body)).pages.map(&:text).join(' ')
      expect(texto).to include('Ana').and include('Beto')
      expect(texto).not_to include('Filtrado')
    end

    it 'la descarga sin «para presentar» dice que está filtrada' do
      get '/api/informes/reprocann.pdf', params: { paciente_ids: [beto.id] }
      texto = PDF::Reader.new(StringIO.new(response.body)).pages.map(&:text).join(' ')
      expect(texto).to include('Filtrado')
      expect(texto).not_to include('Ana Uno')
    end
  end
end
