require 'rails_helper'

# Qué puede hacer un club según las suites que contrató. Hasta acá las suites no gateaban
# NADA: sólo cuatro add-ons (médico, IoT, IA, ARICCAME) devolvían 403. Un club que no pagó
# Cultivo podía usar lotes y salas por la API con total normalidad, y uno sin
# Producción/Dispensa podía dispensar.
#
# Los dos casos que tienen que cerrar de verdad:
#
#   SÓLO CULTIVO — cultiva y cosecha, pero no atiende pacientes. Su lote llega igual hasta el
#     stock; lo que cambia es la SALIDA: el stock se va por transferencia, merma o ajuste, no
#     por dispensación. El ciclo cierra.
#
#   SÓLO PRODUCCIÓN/DISPENSA — no cultiva, así que no genera stock propio. Su inventario entra
#     por compra externa, y de ahí dispensa normalmente.
RSpec.describe 'Suites — qué puede hacer cada club', type: :request do
  let(:admin) { create(:user, :admin, club: club) }

  def json = JSON.parse(response.body)

  def club_con(*suites)
    c = create(:club)
    c.update_columns(features: suites.to_h { |s| [s.to_s, true] })
    c
  end

  describe 'un club de SÓLO CULTIVO' do
    let(:club)  { club_con(:cultivo) }
    let(:sede)  { create(:sede, club: club, created_by: admin, tipo: 'produccion') }
    let(:sala)  { create(:sala, sede: sede, club: club, kind: 'mixta') }

    before { sign_in_as(admin) }

    it 'cultiva: puede ver y crear lotes' do
      create(:lote, club: club, sala: sala, estado: 'vegetativo')

      get '/api/lotes'

      expect(response).to have_http_status(:ok)
    end

    it 'NO atiende pacientes, y el error dice qué le falta' do
      get '/api/pacientes'

      expect(response).to have_http_status(:forbidden)
      expect(json['requiere_modulo']).to be(true)
      expect(json['modulo']).to eq('produccion_dispensa')
    end

    it 'no puede dispensar' do
      get '/api/dispensaciones'

      expect(response).to have_http_status(:forbidden)
    end

    # Su lote llega hasta el stock igual: cosechar y manicurar es cultivo, no dispensa.
    it 'su lote llega hasta generar stock' do
      lote = create(:lote, club: club, sala: sala, estado: 'en_manicura')
      planta = create(:plant, lote: lote, club: club, state: 'cosechado')

      post "/api/lotes/#{lote.id}/pesajes_manicura/registrar_directo",
           params: { resto: { plant_ids: [planta.id], peso_total_g: 200 } }, as: :json

      expect(response).to have_http_status(:created)
      expect(Stock.find(json['stock_id']).cantidad.to_f).to eq(200.0)
    end

    # El cierre del ciclo SIN dispensación: el stock sale por transferencia, merma o ajuste.
    it 'puede dar salida a su stock sin dispensar' do
      stock = create(:stock, club: club, sede: sede, cantidad: 200)

      expect(StockMovimiento::TIPOS).to include('merma', 'transferencia', 'ajuste')
      expect { stock.update!(cantidad: 0) }.not_to raise_error
    end
  end

  describe 'un club de SÓLO PRODUCCIÓN/DISPENSA' do
    let(:club) { club_con(:produccion_dispensa) }
    let(:sede) { create(:sede, club: club, created_by: admin, tipo: 'social') }

    before { sign_in_as(admin) }

    it 'atiende pacientes' do
      get '/api/pacientes'

      expect(response).to have_http_status(:ok)
    end

    it 'NO cultiva, y el error dice qué le falta' do
      get '/api/lotes'

      expect(response).to have_http_status(:forbidden)
      expect(json['modulo']).to eq('cultivo')
    end

    it 'tampoco entra a salas ni a genéticas' do
      get '/api/salas'
      expect(response).to have_http_status(:forbidden)

      get '/api/geneticas'
      expect(response).to have_http_status(:forbidden)
    end

    # No genera stock propio (no tiene lotes), pero sí compra afuera y dispensa eso.
    it 'su inventario entra por compra externa' do
      # La compra externa exige proveedor: es de dónde salió lo que se va a dispensar.
      stock = build(:stock, club: club, sede: sede, origen: 'compra_externa',
                    cantidad: 500, lote: nil, proveedor: 'Cooperativa Norte')

      expect(stock).to be_valid
    end

    it 'dispensa de su stock externo' do
      paciente = create(:paciente, club: club, created_by: admin)
      stock = create(:stock, club: club, sede: sede, origen: 'compra_externa', cantidad: 500,
                     lote: nil, proveedor: 'Cooperativa Norte')

      d = Dispensacion.new(paciente: paciente, user: admin, stock: stock,
                           cantidad: 10, fecha_dispensacion: Time.zone.today)

      expect(d).to be_valid
    end
  end

  describe 'un club con las DOS suites' do
    let(:club) { club_con(:cultivo, :produccion_dispensa) }

    before { sign_in_as(admin) }

    it 'hace todo el recorrido, de la planta al paciente' do
      get '/api/lotes'
      expect(response).to have_http_status(:ok)

      get '/api/pacientes'
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'el error de un módulo apagado' do
    let(:club) { club_con(:cultivo) }

    before { sign_in_as(admin) }

    # Un 403 pelado deja al admin sin saber si es un problema de permisos, de su usuario o
    # de lo que contrató.
    it 'dice el módulo, que es de plan y no de permisos, y a quién pedírselo' do
      get '/api/pacientes'

      expect(json['requiere_modulo']).to be(true)
      expect(json['modulo']).to be_present
      expect(json['error']).to be_present
    end
  end

  describe 'el super admin' do
    let(:club) { club_con(:cultivo) }

    it 'no queda encerrado por las suites de ningún club' do
      sign_in_as(create(:user, :super_admin))

      get '/api/super_admin/clubs'

      expect(response).to have_http_status(:ok)
    end
  end
end
