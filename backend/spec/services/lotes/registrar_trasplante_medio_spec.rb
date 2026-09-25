require 'rails_helper'

# AC (Germán, 24-sep-2026): el enraizado se hace en incubadora (hidroponía) o en jiffy; al pasar al
# vasito de 0,335 L lo que estaba en la incubadora pasa a sustrato. Hay que saber dónde enraizó
# (para comparar después) y que el trasplante que lo prende registre el cambio de medio.
RSpec.describe Lotes::RegistrarTrasplante, 'medio y método de enraizado' do
  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, created_by: admin) }
  let(:sala)  { create(:sala, club: club, sede: sede, created_by: admin, kind: 'vegetativo') }

  around { |ex| ActsAsTenant.with_tenant(club) { ex.run } }

  def lote_enraizando(metodo: 'incubadora', grow_type: 'hidroponia', plantas: 3)
    lote = create(:lote, club: club, sala: sala, estado: 'enraizado', metodo_enraizado: metodo, grow_type: grow_type)
    create_list(:plant, plantas, lote: lote, club: club, state: 'enraizado')
    lote.reload
  end

  describe 'qué medio sugiere el formulario' do
    it 'de la incubadora al vasito: sustrato' do
      expect(lote_enraizando(metodo: 'incubadora').medio_al_trasplantar).to eq('sustrato')
    end

    it 'del jiffy también: sustrato' do
      expect(lote_enraizando(metodo: 'jiffy', grow_type: 'sustrato').medio_al_trasplantar).to eq('sustrato')
    end

    it 'un taco puede seguir en hidro: se queda en lo que estaba' do
      expect(lote_enraizando(metodo: 'taco', grow_type: 'hidroponia').medio_al_trasplantar).to eq('hidroponia')
    end

    it 'un trasplante de vege a vege no cambia de medio' do
      lote = create(:lote, club: club, sala: sala, estado: 'vegetativo', tamanio_maceta: 3, grow_type: 'hidroponia', metodo_enraizado: 'incubadora')
      expect(lote.medio_al_trasplantar).to eq('hidroponia')
    end
  end

  describe 'el trasplante que lo prende' do
    it 'deja el lote en vegetativo, en el vasito y en sustrato' do
      lote = lote_enraizando

      res = described_class.call(lote: lote, usuario: admin, destino: '0.335', medio: 'sustrato', sustrato: 'turba + perlita')

      expect(res).to be_ok
      lote.reload
      expect(lote.estado).to eq('vegetativo')
      expect(lote.tamanio_maceta.to_f).to eq(0.335)
      expect(lote.grow_type).to eq('sustrato')
      expect(lote.sustrato_especifico).to eq('turba + perlita')
      expect(lote.metodo_enraizado).to eq('incubadora')
    end

    it 'deja en el historial de dónde venía, a qué medio fue, las raíces y las observaciones' do
      lote = lote_enraizando

      described_class.call(lote: lote, usuario: admin, destino: '0.335', medio: 'sustrato',
                           estado_raices: 'buena', observaciones: 'raíz blanca, 3 cm')

      ev = lote.lote_eventos.find_by(categoria: 'trasplante')
      expect(ev.metadata).to include('medio_origen' => 'incubadora', 'medio_destino' => 'sustrato', 'estado_raices' => 'buena')
      expect(ev.descripcion).to eq('raíz blanca, 3 cm')
    end

    it 'sin medio elegido no toca el tipo de cultivo' do
      lote = lote_enraizando(grow_type: 'hidroponia')

      described_class.call(lote: lote, usuario: admin, destino: '0.335')

      expect(lote.reload.grow_type).to eq('hidroponia')
    end

    it 'rechaza un medio que no existe' do
      lote = lote_enraizando

      res = described_class.call(lote: lote, usuario: admin, destino: '0.335', medio: 'aire')

      expect(res).not_to be_ok
      expect(lote.reload.estado).to eq('enraizado')
    end
  end

  describe 'sólo algunas plantas' do
    it 'en un lote en vege registra el trasplante de esas y no toca la maceta del lote' do
      lote = create(:lote, club: club, sala: sala, estado: 'vegetativo', tamanio_maceta: 3)
      plantas = create_list(:plant, 3, lote: lote, club: club, state: 'vegetativo')

      res = described_class.call(lote: lote, usuario: admin, destino: '11', plant_ids: [plantas.first.id])

      expect(res).to be_ok
      expect(plantas.first.activities.where(activity_type: 'transplant').count).to eq(1)
      expect(plantas.last.activities.where(activity_type: 'transplant').count).to eq(0)
      expect(lote.reload.tamanio_maceta.to_f).to eq(3.0)
    end

    # Una parte a maceta y otra enraizando es un lote en dos fases: eso es Desprender.
    it 'en un lote enraizando se rechaza y dice qué hacer' do
      lote = lote_enraizando(plantas: 3)

      res = described_class.call(lote: lote, usuario: admin, destino: '0.335', plant_ids: [lote.plants.first.id])

      expect(res).not_to be_ok
      expect(res.error).to include('Desprender')
      expect(lote.reload.estado).to eq('enraizado')
    end

    it 'con todas elegidas es un trasplante entero y prende' do
      lote = lote_enraizando(plantas: 2)

      res = described_class.call(lote: lote, usuario: admin, destino: '0.335', plant_ids: lote.plants.pluck(:id))

      expect(res).to be_ok
      expect(lote.reload.estado).to eq('vegetativo')
    end

    it 'rechaza una planta de otro lote' do
      lote = lote_enraizando(plantas: 2)
      ajena = create(:plant, lote: create(:lote, club: club, sala: sala), club: club)

      res = described_class.call(lote: lote, usuario: admin, destino: '0.335', plant_ids: lote.plants.pluck(:id) + [ajena.id])

      expect(res).not_to be_ok
    end
  end

  it 'el método de enraizado sólo acepta los conocidos' do
    lote = lote_enraizando
    lote.metodo_enraizado = 'maceta'
    expect(lote).not_to be_valid
  end
end
