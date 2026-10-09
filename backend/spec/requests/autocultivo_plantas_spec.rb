require 'rails_helper'

# AUTOCULTIVO: PLANTAS, NO LOTES (8-oct-2026, Germán, con Martín López probando la app).
# En la carpa de casa conviven autos y fotos, la persona piensa en plantas y la luz es de la carpa.
# AC:
#   · una automática entra al espacio en cualquier fase de su ciclo y con la luz que tenga la carpa;
#   · al cambiar la luz se mueven las fotos y las autos siguen su propio reloj;
#   · las plantas se llaman por su genética y siguen la numeración («Ananda 3» después de «Ananda 2»);
#   · se puede cosechar UNA planta de las que se cargaron juntas;
#   · en una organización NADA de esto cambia (la auto vive en su sala de vege, se mueve con la sala,
#     y las plantas se llaman por el código del lote).
RSpec.describe 'Autocultivo: plantas, no lotes', type: :request do
  include AuthHelpers
  def json = JSON.parse(response.body)

  shared_context 'un club' do |plan|
    let(:club)  { plan == 'personal' ? create(:club, plan: 'personal', features: Club::FEATURES_PERSONAL) : create(:club) }
    let(:admin) { create(:user, :admin, club: club) }
    let(:sede)  { create(:sede, club: club, created_by: admin) }
    let(:carpa_vege)  { create(:sala, club: club, sede: sede, created_by: admin, kind: 'vegetativo', nombre: 'Carpa chica') }
    let(:carpa_flora) { create(:sala, club: club, sede: sede, created_by: admin, kind: 'floracion', nombre: 'Carpa grande') }
    let(:auto) { create(:genetica, club: club, nombre: 'Kings Juice', automatica: true, dias_ciclo_objetivo: 77) }
    let(:foto) { create(:genetica, club: club, nombre: 'Ananda', dias_vegetativo_objetivo: 30, tiempo_floracion: 60) }

    before { sign_in_as(admin) }
  end

  def plantar(sala, genetica, cantidad: 1, estado: 'enraizado', codigo: nil)
    post '/lotes', params: { sala_id: sala.id, lote: { codigo: codigo || "L-#{SecureRandom.hex(3)}", genetica_id: genetica.id,
                                                       estado: estado, origen: 'semilla', start_date: Time.zone.today,
                                                       plants_count: cantidad } }, headers: auth_headers
  end

  def lote_en(sala, genetica, estado:, plantas: 1)
    l = create(:lote, club: club, sala: sala, genetica: genetica, estado: estado, start_date: 40.days.ago.to_date)
    plantas.times { create(:plant, lote: l, state: estado) }
    l
  end

  describe 'autos en cualquier espacio' do
    context 'en autocultivo' do
      include_context 'un club', 'personal'

      it 'una semilla de auto se pone a germinar en la carpa que ya está en 12/12' do
        plantar(carpa_flora, auto)
        expect(response).to have_http_status(:created), response.body
      end

      it 'una foto sigue sin poder germinar en 12/12 (sí depende de la luz)' do
        plantar(carpa_flora, foto)
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it '/me manda la tabla de autos de casa: una auto en vegetativo entra a un espacio de floración' do
        get '/me', headers: auth_headers
        expect(json.dig('reglas_cultivo', 'kinds_sala_por_estado_automatica', 'vegetativo')).to include('floracion')
        expect(json.dig('reglas_cultivo', 'kinds_sala_por_estado', 'vegetativo')).not_to include('floracion')
      end
    end

    context 'en una organización (no cambia)' do
      include_context 'un club', 'organizacion'

      it 'la auto no entra a germinar en una sala de floración' do
        plantar(carpa_flora, auto)
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it '/me manda la tabla de siempre' do
        get '/me', headers: auth_headers
        expect(json.dig('reglas_cultivo', 'kinds_sala_por_estado_automatica', 'vegetativo')).not_to include('floracion')
      end
    end
  end

  describe 'cambiar la luz de la carpa' do
    context 'en autocultivo' do
      include_context 'un club', 'personal'

      it 'pasa a 12/12 las fotos y deja a la auto en la fase en que estaba' do
        f = lote_en(carpa_vege, foto, estado: 'vegetativo', plantas: 2)
        a = lote_en(carpa_vege, auto, estado: 'vegetativo')

        post "/salas/#{carpa_vege.id}/cambiar_fase", params: { confirmar_cambio_fase: true }, headers: auth_headers
        expect(response).to have_http_status(:ok), response.body

        expect(f.reload.estado).to eq('floracion')
        expect(f.plants.pluck(:state).uniq).to eq(['floracion'])
        expect(a.reload.estado).to eq('vegetativo')
        expect(a.plants.pluck(:state).uniq).to eq(['vegetativo'])
        expect(json['lotes_afectados']).to eq(1)
      end

      it 'una auto germinando no impide pasar la carpa a 12/12' do
        lote_en(carpa_vege, foto, estado: 'vegetativo')
        lote_en(carpa_vege, auto, estado: 'enraizado')

        post "/salas/#{carpa_vege.id}/cambiar_fase", params: { confirmar_cambio_fase: true }, headers: auth_headers
        expect(response).to have_http_status(:ok), response.body
        expect(carpa_vege.reload.kind).to eq('floracion')
      end

      it 'volver a 18/6 deshace sólo a las fotos: la auto que floreció en la carpa sigue en floración' do
        f = lote_en(carpa_flora, foto, estado: 'floracion')
        a = lote_en(carpa_flora, auto, estado: 'floracion')

        post "/salas/#{carpa_flora.id}/cambiar_fase", params: { confirmar_cambio_fase: true }, headers: auth_headers
        expect(response).to have_http_status(:ok), response.body
        expect(f.reload.estado).to eq('vegetativo')
        expect(a.reload.estado).to eq('floracion')
      end
    end

    context 'en una organización (no cambia)' do
      include_context 'un club', 'organizacion'

      it 'la auto de la sala se mueve con la sala, como siempre' do
        a = lote_en(carpa_vege, auto, estado: 'vegetativo')
        post "/salas/#{carpa_vege.id}/cambiar_fase", params: { confirmar_cambio_fase: true }, headers: auth_headers
        expect(response).to have_http_status(:ok), response.body
        expect(a.reload.estado).to eq('floracion')
      end

      it 'un lote enraizando, auto o no, sigue frenando el paso a floración' do
        lote_en(carpa_vege, auto, estado: 'enraizado')
        post "/salas/#{carpa_vege.id}/cambiar_fase", params: { confirmar_cambio_fase: true }, headers: auth_headers
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'el nombre de las plantas' do
    context 'en autocultivo' do
      include_context 'un club', 'personal'

      it 'se llaman por su genética y la numeración sigue entre una carga y otra' do
        plantar(carpa_vege, foto, cantidad: 2)
        expect(response).to have_http_status(:created), response.body
        plantar(carpa_vege, foto, cantidad: 1)
        expect(response).to have_http_status(:created), response.body

        nombres = Plant.joins(:lote).where(lotes: { club_id: club.id }).order(:id).pluck(:nombre)
        expect(nombres).to eq(['Ananda 1', 'Ananda 2', 'Ananda 3'])
      end

      it 'cada genética lleva su propia cuenta' do
        plantar(carpa_vege, foto, cantidad: 1)
        plantar(carpa_vege, auto, cantidad: 2)
        nombres = Plant.joins(:lote).where(lotes: { club_id: club.id }).order(:id).pluck(:nombre)
        expect(nombres).to eq(['Ananda 1', 'Kings Juice 1', 'Kings Juice 2'])
      end
    end

    context 'en una organización (no cambia)' do
      include_context 'un club', 'organizacion'

      it 'se llaman por el código del lote' do
        plantar(carpa_vege, foto, cantidad: 2)
        expect(response).to have_http_status(:created), response.body
        codigo = json['codigo']
        expect(Plant.joins(:lote).where(lotes: { club_id: club.id }).order(:id).pluck(:nombre))
          .to eq(["#{codigo}-P001", "#{codigo}-P002"])
      end
    end

    context 'aislamiento entre organizaciones' do
      include_context 'un club', 'personal'

      it 'la numeración no mira las plantas de otra cuenta' do
        otro = create(:club, plan: 'personal', features: Club::FEATURES_PERSONAL)
        ActsAsTenant.with_tenant(otro) do
          otro_admin = create(:user, :admin, club: otro)
          s = create(:sala, club: otro, sede: create(:sede, club: otro, created_by: otro_admin), created_by: otro_admin, kind: 'vegetativo')
          g = create(:genetica, club: otro, nombre: 'Ananda')
          l = create(:lote, club: otro, sala: s, genetica: g, estado: 'vegetativo', start_date: Time.zone.today)
          create(:plant, lote: l, state: 'vegetativo', nombre: 'Ananda 7')
        end

        plantar(carpa_vege, foto, cantidad: 1)
        expect(Plant.joins(:lote).where(lotes: { club_id: club.id }).pluck(:nombre)).to eq(['Ananda 1'])
      end
    end
  end

  describe 'cosechar una sola de las que se cargaron juntas' do
    include_context 'un club', 'personal'

    it 'se cosecha esa planta y las otras siguen en la carpa' do
      l = lote_en(carpa_flora, foto, estado: 'floracion', plantas: 3)
      una = l.plants.first

      post "/lotes/#{l.id}/cosechar_plantas", params: { plantas_ids: [una.id], peso_total_g: 212 }, headers: auth_headers
      expect(response).to have_http_status(:created), response.body

      expect(una.reload.state).to eq('cosechado')
      expect(l.plants.where.not(id: una.id).pluck(:state).uniq).to eq(['floracion'])
      expect(l.reload.estado).to eq('floracion')
    end
  end
end
