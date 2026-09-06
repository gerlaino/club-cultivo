require 'rails_helper'

# ¿ESTÁ COMO SIEMPRE, O CAMBIÓ ALGO?
#
# Un porcentaje solo no dice nada: 3% puede ser normal fraccionando flor y un escándalo en aceite.
# La regla es comparar la última semana contra las ocho anteriores DE ESA organización — y es la
# misma que dispara el aviso automático, que antes la tenía escrita sólo adentro del job: el admin
# recibía el mail diciendo "algo cambió", entraba a mirar y la pantalla no le decía nada de eso.
RSpec.describe Mostradores::Veredicto do
  let(:club)  { create(:club, features: { 'produccion_dispensa' => true }) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:ana)   { create(:user, :dispensador, club: club) }
  let(:sede)  { create(:sede, club: club, tipo: 'social', nombre: 'Centro') }
  let(:lote)  { ActsAsTenant.with_tenant(club) { create(:lote, club: club, sala: create(:sala, club: club, sede: sede)) } }

  let!(:stock) do
    ActsAsTenant.with_tenant(club) do
      create(:stock, club: club, sede: sede, lote: lote, forma_producto: 'flor_seca', unidad: 'g',
                     cantidad: 100_000, estado: 'asignado', disponibilidad: 'ambas',
                     costo_unitario_ars: 100, precio_sugerido_ars: 500)
    end
  end

  # Un turno cerrado con lo dispensado y el faltante que se le indique, fechado cuando haga falta.
  def turno!(dispensado:, faltante:, cuando: Time.current)
    ActsAsTenant.with_tenant(club) do
      mostrador = sede.mostrador!
      Mostradores::Cargar.call(mostrador: mostrador, usuario: admin, motivo: 'carga',
                               cambios: [{ stock_id: stock.id, cantidad: dispensado + 100 }])
      t = Mostradores::AbrirCaja.call(mostrador: mostrador, usuario: ana,
                                      efectivo_contado_ars: 0).turno
      mi = mostrador.items.find_by(stock_id: stock.id)
      mi.mover!(cantidad: -dispensado, tipo: 'dispensa', usuario: ana, turno: t)
      t.items.find_by(stock_id: stock.id).imputar_dispensa!(dispensado)

      Mostradores::CerrarCaja.call(turno: t, usuario: ana, efectivo_contado_ars: 0,
                                   conteos: [{ stock_id: stock.id, contado: mi.reload.cantidad - faltante }],
                                   notas: 'merma')
      t.reload.update_columns(cerrado_at: cuando)
      Mostradores::Cargar.call(mostrador: mostrador, usuario: admin, motivo: 'reset',
                               cambios: [{ stock_id: stock.id, cantidad: 0 }])
      t
    end
  end

  def veredicto = ActsAsTenant.with_tenant(club) { described_class.call(mostrador: sede.mostrador!) }

  describe 'cuando cambió' do
    before do
      8.times { |i| turno!(dispensado: 1_000, faltante: 5, cuando: (14 + i * 5).days.ago) }
      turno!(dispensado: 1_000, faltante: 50, cuando: 1.day.ago)
    end

    it 'lo dice, con los dos números para poder compararlos' do
      v = veredicto

      expect(v[:estado]).to eq('subio')
      expect(v[:pct]).to be > v[:pct_previo]
      expect(v[:semanas_previas]).to eq(8)
    end

    # Sin esto, "subió" manda a mirar tres tablas para encontrar el renglón que ya sabemos cuál es.
    it 'y dice qué producto la está moviendo' do
      expect(veredicto[:motor][:producto]).to be_present
      expect(veredicto[:motor][:faltante_ars]).to be > 0
    end
  end

  describe 'cuando está como siempre' do
    before do
      8.times { |i| turno!(dispensado: 1_000, faltante: 5, cuando: (14 + i * 5).days.ago) }
      turno!(dispensado: 1_000, faltante: 6, cuando: 1.day.ago)
    end

    it 'no inventa una alarma' do
      expect(veredicto[:estado]).to eq('normal')
      expect(veredicto[:motor]).to be_nil
    end
  end

  # Los dos pisos existen porque un aviso que grita en falso entrena a ignorar todos los demás.
  describe 'cuando no hay con qué comparar' do
    it 'con poca historia atrás lo dice, en vez de callarse' do
      turno!(dispensado: 1_000, faltante: 80, cuando: 1.day.ago)

      expect(veredicto[:estado]).to eq('sin_historia')
    end

    it 'con poco volumen esta semana, tampoco: 2 g sobre 10 es 20% y no dice nada' do
      8.times { |i| turno!(dispensado: 1_000, faltante: 5, cuando: (14 + i * 5).days.ago) }
      turno!(dispensado: 10, faltante: 2, cuando: 1.day.ago)

      expect(veredicto[:estado]).to eq('poco_volumen')
    end

    # La pantalla tiene que poder decirlo: quedarse en blanco se lee como que está todo bien.
    it 'sin ningún turno esta semana lo dice igual' do
      8.times { |i| turno!(dispensado: 1_000, faltante: 5, cuando: (14 + i * 5).days.ago) }

      expect(veredicto[:estado]).to eq('sin_datos')
    end
  end

  # La regla vive en UN lugar: la que muestra la pantalla es la que dispara el mail.
  it 'es la misma regla que usa el aviso automático' do
    8.times { |i| turno!(dispensado: 1_000, faltante: 5, cuando: (14 + i * 5).days.ago) }
    turno!(dispensado: 1_000, faltante: 50, cuando: 1.day.ago)

    expect(veredicto[:estado]).to eq('subio')
    expect { MermaMostradorJob.new.perform }
      .to change { AlertaInterna.unscoped.where(club_id: club.id, tipo: 'merma_mostrador').count }.by(1)
  end
end
