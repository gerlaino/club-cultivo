require 'rails_helper'

# AC: en /lotes se eligen varios lotes y se imprimen las banderitas de TODAS sus plantas. La
# pantalla las pide de una con `lote_ids[]`: trae las plantas de esos lotes y de ningún otro, y un
# id de otra organización no trae nada.
RSpec.describe 'GET /plants?lote_ids[]', type: :request do
  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, created_by: admin) }
  let(:sala)  { create(:sala, club: club, sede: sede, created_by: admin, kind: 'floracion') }

  def lote_con_plantas(n, en_club: club, en_sala: sala, estado: 'floracion', state: 'floracion')
    lote = ActsAsTenant.with_tenant(en_club) { create(:lote, club: en_club, sala: en_sala, estado: estado) }
    n.times do |i|
      ActsAsTenant.with_tenant(en_club) do
        Plant.create!(lote: lote, club: en_club, nombre: "#{lote.codigo}-P#{i + 1}", state: state)
      end
    end
    lote
  end

  def ids_de_lote(body) = body.map { |p| p.dig('lote', 'id') }.uniq

  before { sign_in_as(admin) }

  it 'con UN lote trae sólo sus plantas' do
    uno  = lote_con_plantas(2)
    _otro = lote_con_plantas(3)

    get '/api/plants', params: { lote_ids: [uno.id] }

    body = JSON.parse(response.body)
    expect(body.size).to eq(2)
    expect(ids_de_lote(body)).to eq([uno.id])
  end

  it 'con varios lotes trae las plantas de todos, y no las de un lote no elegido' do
    a = lote_con_plantas(2)
    b = lote_con_plantas(3, estado: 'cosecha', state: 'cosechado')
    _c = lote_con_plantas(4)

    get '/api/plants', params: { lote_ids: [a.id, b.id] }

    body = JSON.parse(response.body)
    expect(body.size).to eq(5)
    expect(ids_de_lote(body)).to match_array([a.id, b.id])
  end

  it 'aislamiento: el lote de otra organización no trae plantas aunque se pase su id' do
    propio = lote_con_plantas(1)
    otro_club  = create(:club)
    otro_admin = create(:user, :admin, club: otro_club)
    otra_sede  = ActsAsTenant.with_tenant(otro_club) { create(:sede, club: otro_club, created_by: otro_admin) }
    otra_sala  = ActsAsTenant.with_tenant(otro_club) { create(:sala, club: otro_club, sede: otra_sede, created_by: otro_admin) }
    ajeno = lote_con_plantas(3, en_club: otro_club, en_sala: otra_sala)

    get '/api/plants', params: { lote_ids: [propio.id, ajeno.id] }

    body = JSON.parse(response.body)
    expect(ids_de_lote(body)).to eq([propio.id])
  end
end
