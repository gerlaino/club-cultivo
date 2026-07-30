require 'rails_helper'

# Mover un lote de sala es una operación que hasta ahora no existía: la única forma de cambiar de
# sala era avanzando de fase. La regla que estos specs fijan es la que importa: **el lote toma la
# fase de la sala a la que va**, porque el cuarto define el fotoperiodo.
RSpec.describe 'POST /lotes/mover', type: :request do
  include AuthHelpers

  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, created_by: admin) }
  let(:sede2) { create(:sede, club: club, created_by: admin, nombre: 'Sede Norte') }

  let(:sala_vege)  { create(:sala, club: club, sede: sede,  created_by: admin, kind: 'vegetativo') }
  let(:sala_flora) { create(:sala, club: club, sede: sede,  created_by: admin, kind: 'floracion') }
  let(:sala_otra_sede) { create(:sala, club: club, sede: sede2, created_by: admin, kind: 'vegetativo') }
  let(:sala_mixta) { create(:sala, club: club, sede: sede, created_by: admin, kind: 'mixta') }

  def mover(ids, sala)
    post '/lotes/mover', params: { lote_ids: Array(ids), sala_id: sala.id }, headers: auth_headers
  end

  describe 'el lote toma la fase de la sala destino' do
    it 'a una sala de floración, el lote y sus plantas pasan a floración' do
      lote = create(:lote, club: club, sala: sala_vege, estado: 'vegetativo')
      p1   = create(:plant, lote: lote, state: 'vegetativo')
      sign_in_as(admin)

      mover(lote.id, sala_flora)

      expect(response).to have_http_status(:ok)
      expect(lote.reload.estado).to eq('floracion')
      expect(lote.sala_id).to eq(sala_flora.id)
      expect(p1.reload.state).to eq('floracion')
    end

    # El caso que motivó todo: un lote de ESQUEJES movido a una sala de vegetativo. Es la fase que
    # el resto del sistema se venía olvidando.
    it 'un lote en esqueje movido a una sala de vegetativo pasa a vegetativo' do
      lote = create(:lote, club: club, sala: sala_flora, estado: 'esqueje')
      create(:plant, lote: lote, state: 'esqueje')
      sign_in_as(admin)

      mover(lote.id, sala_vege)

      expect(lote.reload.estado).to eq('vegetativo')
      expect(lote.plants.pluck(:state).uniq).to eq(['vegetativo'])
    end

    it 'a una sala mixta NO le impone fase: ahí conviven fases distintas a propósito' do
      lote = create(:lote, club: club, sala: sala_vege, estado: 'esqueje')
      sign_in_as(admin)

      mover(lote.id, sala_mixta)

      expect(lote.reload.estado).to eq('esqueje')
      expect(lote.sala_id).to eq(sala_mixta.id)
      expect(JSON.parse(response.body)['cambios_de_fase']).to be_empty
    end

    it 'si ya está en la fase de la sala, se mueve sin registrar cambio de fase' do
      lote = create(:lote, club: club, sala: sala_vege, estado: 'vegetativo')
      otra_vege = create(:sala, club: club, sede: sede, created_by: admin, kind: 'vegetativo')
      sign_in_as(admin)

      mover(lote.id, otra_vege)

      expect(JSON.parse(response.body)['cambios_de_fase']).to be_empty
      expect(lote.reload.sala_id).to eq(otra_vege.id)
    end
  end

  describe 'sedes' do
    it 'mover a una sala de otra sede cambia la sede del lote' do
      lote = create(:lote, club: club, sala: sala_vege, sede: sede, estado: 'vegetativo')
      sign_in_as(admin)

      mover(lote.id, sala_otra_sede)

      expect(lote.reload.sede_id).to eq(sede2.id)
      expect(lote.sala_id).to eq(sala_otra_sede.id)
    end
  end

  describe 'en tanda' do
    it 'mueve varios lotes de una y devuelve solo los que cambiaron de fase' do
      en_vege  = create(:lote, club: club, sala: sala_vege, estado: 'vegetativo')
      en_esq   = create(:lote, club: club, sala: sala_vege, estado: 'esqueje')
      sign_in_as(admin)

      mover([en_vege.id, en_esq.id], sala_flora)

      body = JSON.parse(response.body)
      expect(body['movidos']).to eq(2)
      expect(body['cambios_de_fase'].map { |c| c['codigo'] }).to match_array([en_vege.codigo, en_esq.codigo])
      expect([en_vege.reload.estado, en_esq.reload.estado]).to all(eq('floracion'))
    end

    it 'ignora un lote que ya está en la sala destino en vez de duplicar historia' do
      ya_ahi = create(:lote, club: club, sala: sala_flora, estado: 'floracion')
      sign_in_as(admin)

      expect { mover(ya_ahi.id, sala_flora) }.not_to change(LoteEvento, :count)
      expect(JSON.parse(response.body)['movidos']).to eq(0)
    end
  end

  describe 'trazabilidad' do
    it 'deja un LoteEvento con de dónde vino y a dónde fue' do
      lote = create(:lote, club: club, sala: sala_vege, estado: 'vegetativo')
      sign_in_as(admin)

      expect { mover(lote.id, sala_flora) }.to change(LoteEvento, :count).by(1)

      ev = lote.lote_eventos.order(:created_at).last
      expect(ev.tipo).to eq('cambio_estado')
      expect(ev.estado_anterior).to eq('vegetativo')
      expect(ev.estado_nuevo).to eq('floracion')
      expect(ev.descripcion).to include(sala_vege.nombre, sala_flora.nombre)
    end
  end

  describe 'guardas' do
    it 'rechaza una sala destino de otro club' do
      otro_club = create(:club)
      otro_admin = create(:user, :admin, club: otro_club)
      ajena = ActsAsTenant.with_tenant(otro_club) do
        create(:sala, club: otro_club, sede: create(:sede, club: otro_club, created_by: otro_admin), created_by: otro_admin)
      end
      lote = create(:lote, club: club, sala: sala_vege, estado: 'vegetativo')
      sign_in_as(admin)

      mover(lote.id, ajena)

      expect(response).to have_http_status(:not_found)
      expect(lote.reload.sala_id).to eq(sala_vege.id)
    end

    it 'no mueve un lote de otro club aunque venga su id' do
      otro_club  = create(:club)
      otro_admin = create(:user, :admin, club: otro_club)
      lote_ajeno = ActsAsTenant.with_tenant(otro_club) do
        s = create(:sala, club: otro_club, sede: create(:sede, club: otro_club, created_by: otro_admin), created_by: otro_admin)
        create(:lote, club: otro_club, sala: s, estado: 'vegetativo')
      end
      sign_in_as(admin)

      mover(lote_ajeno.id, sala_flora)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(lote_ajeno.reload.sala_id).not_to eq(sala_flora.id)
    end

    it 'no mueve un lote que ya no está en sala (cosechado en adelante)' do
      lote = create(:lote, club: club, sala: nil, estado: 'curado')
      sign_in_as(admin)

      mover(lote.id, sala_vege)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(lote.reload.sala_id).to be_nil
    end

    it 'sin lotes elegidos avisa en vez de romper' do
      sign_in_as(admin)
      post '/lotes/mover', params: { lote_ids: [], sala_id: sala_vege.id }, headers: auth_headers
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
