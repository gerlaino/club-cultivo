require 'rails_helper'

# El aviso de merma no tiene umbral fijo, y es a propósito: un 3% puede ser normal fraccionando
# flor y un escándalo en aceite. Lo que importa no es el número sino que CAMBIÓ respecto del
# patrón de esa misma organización.
#
# Y no acusa a nadie: dice "acá cambió algo, andá a mirar".
RSpec.describe MermaMostradorJob do
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
      t = Mostradores::AbrirTurno.call(
        mostrador: sede.mostrador, usuario: admin, monto_inicial_ars: 0,
        items: [{ stock_id: stock.id, cantidad: dispensado + 100 }]
      ).turno
      Mostradores::ConfirmarApertura.call(turno: t, usuario: ana)
      item = t.items.first
      item.update!(cantidad_dispensada: dispensado)
      Mostradores::CerrarTurno.call(turno: t, usuario: ana, efectivo_contado_ars: 0,
                                    conteos: [{ item_id: item.id, contado: item.esperado - faltante,
                                                motivo: 'merma' }])
      t.reload.update_columns(cerrado_at: cuando)
      t
    end
  end

  def alertas = AlertaInterna.unscoped.where(club_id: club.id, tipo: 'merma_mostrador')

  describe 'cuando la merma se dispara' do
    before do
      # Ocho semanas tranquilas: 0,5%.
      8.times { |i| turno!(dispensado: 1_000, faltante: 5, cuando: (14 + i * 5).days.ago) }
      # Y esta semana, 5%.
      turno!(dispensado: 1_000, faltante: 50, cuando: 1.day.ago)
    end

    it 'avisa, diciendo contra qué cambió' do
      expect { described_class.new.perform }.to change { alertas.count }.by(1)

      a = alertas.last
      expect(a.mensaje).to include('Centro')
      expect(a.severidad).to eq('warning')
      expect(a.destinada_a_role).to eq('admin')
      expect(a.contexto['sede_id']).to eq(sede.id)
    end

    # Repetirlo todos los días es cómo se aprende a ignorarlo.
    it 'no lo repite al día siguiente' do
      described_class.new.perform

      expect { described_class.new.perform }.not_to change { alertas.count }
    end
  end

  it 'con la merma estable no dice nada' do
    9.times { |i| turno!(dispensado: 1_000, faltante: 5, cuando: (1 + i * 6).days.ago) }

    expect { described_class.new.perform }.not_to change { alertas.count }
  end

  # Sin historia, "cambió" no significa nada: con dos turnos cualquier diferencia parece un salto.
  it 'sin semanas previas suficientes, se calla' do
    turno!(dispensado: 1_000, faltante: 50, cuando: 1.day.ago)
    2.times { |i| turno!(dispensado: 1_000, faltante: 5, cuando: (20 + i).days.ago) }

    expect { described_class.new.perform }.not_to change { alertas.count }
  end

  # 2 g sobre 10 dispensados es 20% y no dice nada.
  it 'con poco volumen esta semana, se calla' do
    8.times { |i| turno!(dispensado: 1_000, faltante: 5, cuando: (14 + i * 5).days.ago) }
    turno!(dispensado: 50, faltante: 10, cuando: 1.day.ago)

    expect { described_class.new.perform }.not_to change { alertas.count }
  end
end
