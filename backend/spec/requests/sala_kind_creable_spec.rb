require 'rails_helper'

# AC: las salas son sólo de cultivo. La manicura y la cosecha son ETAPAS por las que pasa el
# lote (`en_manicura`, `cosecha`), no lugares que alguien tenga que dar de alta.
#
# El alta de escritorio ya sólo ofrecía vegetativo y floración, pero el ONBOARDING —la primera
# sala de una organización nueva— seguía ofreciendo Manicura, y el backend no validaba el kind:
# por API entraba cualquiera. Era pedirle a alguien que todavía no cargó una planta que decida
# algo que no existe hasta después de la cosecha, y que después la busque en Salas.
RSpec.describe 'Qué tipo de sala se puede crear', type: :request do
  include AuthHelpers

  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, created_by: admin) }

  before { sign_in_as(admin) }

  def crear(kind)
    post '/api/salas', params: { sala: { nombre: "Sala #{kind}", kind: kind, sede_id: sede.id } }
  end

  %w[vegetativo floracion].each do |kind|
    it "acepta #{kind}" do
      expect { crear(kind) }.to change(Sala, :count).by(1)
      expect(response).to have_http_status(:created)
    end
  end

  %w[manicura cosecha].each do |kind|
    it "rechaza #{kind} y explica que es una etapa del lote" do
      expect { crear(kind) }.not_to change(Sala, :count)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['error']).to match(/etapa del lote/i)
    end
  end

  describe 'editando una sala' do
    let(:sala) { create(:sala, club: club, sede: sede, kind: 'vegetativo', created_by: admin) }

    it 'no la deja convertir en sala de manicura' do
      patch "/api/salas/#{sala.id}", params: { sala: { kind: 'manicura' } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(sala.reload.kind).to eq('vegetativo')
    end

    # Quedaron salas de proceso de cuando se auto-creaban ("Cosecha · Sede"). Si el candado
    # mirara el kind guardado en vez del que se pide, no se le podría ni corregir el nombre.
    it 'a una que YA es de proceso la deja guardar igual' do
      vieja = create(:sala, club: club, sede: sede, kind: 'cosecha', created_by: admin)

      patch "/api/salas/#{vieja.id}", params: { sala: { nombre: 'Cosecha (galpón)' } }

      expect(response).to have_http_status(:ok), response.body
      expect(vieja.reload.nombre).to eq('Cosecha (galpón)')
    end
  end
end

# EN UN DISPENSARIO NO SE CULTIVA. La regla existía sólo para la sala de manicura; una de
# vegetativo se creaba en una sede social si la pantalla llegaba con la sede ya fijada (la ficha
# de la sede en la PWA). Apareció probando: una sede «Dispensario» con «1 salas».
RSpec.describe 'Dónde se puede crear una sala', type: :request do
  include AuthHelpers

  let(:club)        { create(:club) }
  let(:admin)       { create(:user, :admin, club: club) }
  let(:dispensario) { create(:sede, club: club, created_by: admin, tipo: 'social') }
  let(:mixta)       { create(:sede, club: club, created_by: admin, tipo: 'mixta') }

  before { sign_in_as(admin) }

  def crear(sede)
    post '/api/salas', params: { sala: { nombre: 'Vege 1', kind: 'vegetativo', sede_id: sede.id } }
  end

  it 'rechaza una sala de cultivo en una sede social, y dice por qué' do
    expect { crear(dispensario) }.not_to change(Sala, :count)
    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include('en un dispensario no se cultiva')
  end

  it 'la acepta en una mixta' do
    expect { crear(mixta) }.to change(Sala, :count).by(1)
  end

  it 'una sala que ya estaba en una sede social se puede seguir editando' do
    sala = ActsAsTenant.with_tenant(club) { Sala.new(club: club, sede: mixta, nombre: 'Vieja', kind: 'vegetativo', created_by: admin).tap(&:save!) }
    sala.update_column(:sede_id, dispensario.id)
    expect(sala.reload.update(nombre: 'Vieja renombrada')).to be true
  end
end
