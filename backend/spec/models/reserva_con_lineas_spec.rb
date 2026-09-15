require 'rails_helper'

# UNA RESERVA TIENE LÍNEAS, COMO LA DISPENSA (Germán, 15-sep-2026).
#
# Lo que este spec fija: la fila espeja las líneas (primera y suma) sin que nadie la escriba;
# lo apartado por reserva se cuenta POR LÍNEA, también cuando dos reservas distintas o dos
# líneas de la misma comprometen el mismo frasco; una sola línea que se pasa rechaza la reserva
# entera; y quien construye una reserva "a la vieja" (stock + cantidad) sigue obteniendo lo
# mismo que antes.
RSpec.describe Reserva, 'con líneas', type: :model do
  let(:club)     { create(:club) }
  let(:admin)    { create(:user, :admin, club: club) }
  let(:sede)     { create(:sede, club: club, created_by: admin) }
  let(:sala)     { create(:sala, club: club, sede: sede, created_by: admin) }
  let(:lote)     { create(:lote, club: club, sala: sala) }
  let(:paciente) { create(:paciente, club: club, created_by: admin) }

  let!(:flor) do
    Stock.create!(sede: sede, lote: lote, origen: 'lote',
                  forma_producto: 'flor_seca', unidad: 'g', cantidad: 100)
  end
  let!(:prerolls) do
    Stock.create!(sede: sede, lote: lote, origen: 'lote',
                  forma_producto: 'preroll', unidad: 'un', cantidad: 20)
  end

  def nueva(lineas)
    r = Reserva.new(club: club, paciente: paciente, user: admin,
                    fecha_entrega_estimada: 3.days.from_now.to_date)
    lineas.each { |st, cant| r.items.build(stock: st, cantidad: cant) }
    r
  end

  describe 'la fila espeja las líneas' do
    it 'stock = primera línea y cantidad = suma, sin que nadie las escriba' do
      r = nueva([[flor, 10], [prerolls, 3]])
      expect(r).to be_valid
      r.save!
      expect(r.stock).to eq(flor)
      expect(r.cantidad).to eq(13)
      expect(r.items.count).to eq(2)
    end

    it 'sin ninguna línea no es válida' do
      r = Reserva.new(club: club, paciente: paciente, user: admin,
                      fecha_entrega_estimada: 3.days.from_now.to_date)
      expect(r).not_to be_valid
      expect(r.errors[:base].join).to include('al menos un producto')
    end
  end

  describe 'compatibilidad con la reserva de un producto' do
    it 'construida con stock + cantidad, nace con su única línea' do
      r = Reserva.create!(club: club, paciente: paciente, user: admin, stock: flor, cantidad: 10,
                          fecha_entrega_estimada: 3.days.from_now.to_date)
      expect(r.items.count).to eq(1)
      expect(r.items.first.stock).to eq(flor)
      expect(r.items.first.cantidad).to eq(10)
    end

    it 'editar `cantidad` en una reserva de una línea edita esa línea' do
      r = Reserva.create!(club: club, paciente: paciente, user: admin, stock: flor, cantidad: 10,
                          fecha_entrega_estimada: 3.days.from_now.to_date)
      r.update!(cantidad: 25)
      expect(r.items.reload.first.cantidad).to eq(25)
      expect(flor.reload.apartado_para_reservas).to eq(25)
    end
  end

  describe 'lo apartado se cuenta por línea' do
    it 'cada stock ve sólo lo que sus líneas le comprometen' do
      nueva([[flor, 10], [prerolls, 3]]).save!
      expect(flor.reload.apartado_para_reservas).to eq(10)
      expect(prerolls.reload.apartado_para_reservas).to eq(3)
      expect(flor.cantidad_disponible_real).to eq(90.0)
      expect(prerolls.cantidad_disponible_real).to eq(17.0)
    end

    it 'un stock que es SEGUNDA línea de una reserva también queda apartado' do
      nueva([[flor, 10], [prerolls, 3]]).save!
      # Antes lo apartado se leía de `reservas.stock_id`, que es sólo la primera línea: los
      # prerolls quedaban libres con una reserva encima.
      expect(prerolls.reload.apartado_para_reservas).to eq(3)
    end

    it 'la precarga de listados dice lo mismo que el cálculo de a uno' do
      nueva([[flor, 10], [prerolls, 3]]).save!
      nueva([[prerolls, 2]]).save!
      lista = Stock.precargar_apartado_reservas([flor.reload, prerolls.reload])
      expect(lista.map(&:apartado_para_reservas)).to eq([10, 5])
    end

    it 'una reserva cancelada deja de apartar todas sus líneas' do
      r = nueva([[flor, 10], [prerolls, 3]])
      r.save!
      r.cancelar!
      expect(flor.reload.apartado_para_reservas).to eq(0)
      expect(prerolls.reload.apartado_para_reservas).to eq(0)
    end
  end

  describe 'el disponible se valida por línea' do
    it 'rechaza la reserva entera si UNA sola línea se pasa' do
      r = nueva([[flor, 10], [prerolls, 21]])
      expect(r).not_to be_valid
      expect(r.errors[:cantidad].join).to include('supera el stock disponible')
      expect(r.errors[:cantidad].join).to include('20')
    end

    it 'dos líneas del mismo frasco se suman contra ese frasco' do
      r = nueva([[flor, 60], [flor, 60]])
      expect(r).not_to be_valid
      expect(nueva([[flor, 60], [flor, 40]])).to be_valid
    end

    it 'lo que otra reserva ya apartó no se puede volver a reservar' do
      nueva([[prerolls, 18]]).save!
      expect(nueva([[prerolls, 3]])).not_to be_valid
      expect(nueva([[prerolls, 2]])).to be_valid
    end
  end

  describe 'la descripción' do
    it 'nombra cada línea con su cantidad y su unidad' do
      r = nueva([[flor, 10], [prerolls, 3]])
      r.save!
      expect(r.descripcion_items).to include('10.0g')
      expect(r.descripcion_items).to include('3.0un')
      expect(r.descripcion_items).to include(' · ')
    end
  end
end
