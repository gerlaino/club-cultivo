require 'rails_helper'

# La variedad del stock: obligatoria al DAR DE ALTA, editable siempre.
#
# El pedido salió de un caso real: se cargó stock sin indicarle la genética y después no había
# cómo completársela — el alta la aceptaba pero la edición descartaba el campo en silencio,
# porque `stock_update_params` no lo permitía.
#
# La asimetría entre alta y edición es a propósito y es la parte importante: si la genética
# fuera obligatoria también al editar, los stocks viejos que entraron sin ella quedarían
# INGUARDABLES, y esta pantalla es justamente donde se les completa. No se podría ni
# corregirles el precio sin antes adivinarles la variedad.
RSpec.describe 'Stock — variedad obligatoria al crear, editable después', type: :request do
  include AuthHelpers

  let(:club)     { create(:club) }
  let(:admin)    { create(:user, :admin, club: club) }
  let(:sede)     { create(:sede, club: club) }
  let(:genetica) { ActsAsTenant.with_tenant(club) { create(:genetica, club: club) } }

  before { sign_in_as(admin) }

  def alta(extra = {})
    post '/stocks', headers: auth_headers, as: :json, params: {
      stock: { descripcion: 'Flor de tercero', forma_producto: 'externo', cantidad: 500,
               origen: 'compra_externa', proveedor: 'Tercero SRL', sede_id: sede.id }.merge(extra)
    }
  end

  describe 'POST /stocks' do
    it 'rechaza el alta sin variedad' do
      expect { alta }.not_to change { Stock.count }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['errors'].join).to match(/variedad|genética/i)
    end

    it 'crea con variedad' do
      expect { alta(genetica_id: genetica.id) }.to change { Stock.count }.by(1)

      expect(response).to have_http_status(:created)
      expect(Stock.last.genetica_id).to eq(genetica.id)
    end

    # Cuando el stock sale de un lote la variedad ya la sabemos: pedirla de nuevo sería hacerle
    # tipear algo que el lote ya dice, y rebotar el alta por eso sería un error inventado.
    it 'la toma del lote cuando el stock sale de un lote y no vino en el form' do
      lote = ActsAsTenant.with_tenant(club) do
        create(:lote, club: club, genetica: genetica, sala: create(:sala, club: club, sede: sede))
      end

      expect {
        post '/stocks', headers: auth_headers, as: :json, params: {
          stock: { forma_producto: 'flor_seca', cantidad: 100, origen: 'lote',
                   lote_id: lote.id, sede_id: sede.id }
        }
      }.to change { Stock.count }.by(1)

      expect(response).to have_http_status(:created)
      expect(Stock.last.genetica_id).to eq(genetica.id)
    end

    it 'no acepta la variedad de otra organización' do
      ajena = create(:club)
      otra  = ActsAsTenant.with_tenant(ajena) { create(:genetica, club: ajena) }

      expect { alta(genetica_id: otra.id) }.not_to change { Stock.count }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['errors'].join).to match(/no es de esta organización/i)
    end
  end

  describe 'PATCH /stocks/:id' do
    # El caso que originó todo: el stock ya existe sin variedad y hay que podérsela poner.
    it 'le agrega la variedad a un stock que entró sin ella' do
      stock = ActsAsTenant.with_tenant(club) do
        create(:stock, club: club, sede: sede, genetica: nil, lote: nil,
                       origen: 'compra_externa', forma_producto: 'externo', cantidad: 500,
                       proveedor: 'Tercero SRL')
      end
      expect(stock.genetica_id).to be_nil

      patch "/stocks/#{stock.id}", headers: auth_headers, as: :json,
            params: { stock: { cantidad: 500, genetica_id: genetica.id } }

      expect(response).to have_http_status(:ok)
      expect(stock.reload.genetica_id).to eq(genetica.id)
    end

    it 'le cambia la variedad a un stock que la tenía mal' do
      stock = ActsAsTenant.with_tenant(club) do
        create(:stock, club: club, sede: sede, genetica: genetica, lote: nil,
                       origen: 'compra_externa', forma_producto: 'externo', cantidad: 500,
                       proveedor: 'Tercero SRL')
      end
      otra = ActsAsTenant.with_tenant(club) { create(:genetica, club: club, nombre: 'Otra cepa') }

      patch "/stocks/#{stock.id}", headers: auth_headers, as: :json,
            params: { stock: { cantidad: 500, genetica_id: otra.id } }

      expect(response).to have_http_status(:ok)
      expect(stock.reload.genetica_id).to eq(otra.id)
    end

    # Sin esto, editar el precio de un stock viejo lo obligaría a completar la variedad primero.
    it 'deja editar otros campos SIN mandar variedad' do
      stock = ActsAsTenant.with_tenant(club) do
        create(:stock, club: club, sede: sede, genetica: nil, lote: nil,
                       origen: 'compra_externa', forma_producto: 'externo', cantidad: 500,
                       proveedor: 'Tercero SRL')
      end

      patch "/stocks/#{stock.id}", headers: auth_headers, as: :json,
            params: { stock: { cantidad: 500, precio_sugerido_ars: 1500 } }

      expect(response).to have_http_status(:ok)
      expect(stock.reload.precio_sugerido_ars).to eq(1500)
      expect(stock.genetica_id).to be_nil
    end

    it 'no acepta la variedad de otra organización' do
      stock = ActsAsTenant.with_tenant(club) do
        create(:stock, club: club, sede: sede, genetica: nil, lote: nil,
                       origen: 'compra_externa', forma_producto: 'externo', cantidad: 500,
                       proveedor: 'Tercero SRL')
      end
      ajena = create(:club)
      otra  = ActsAsTenant.with_tenant(ajena) { create(:genetica, club: ajena) }

      patch "/stocks/#{stock.id}", headers: auth_headers, as: :json,
            params: { stock: { cantidad: 500, genetica_id: otra.id } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(stock.reload.genetica_id).to be_nil
    end
  end
end
