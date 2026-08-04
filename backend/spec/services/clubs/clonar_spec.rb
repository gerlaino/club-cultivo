require 'rails_helper'

# Copiar el cultivo de un club a otro. Lo que fija este spec es lo que rompe una copia hecha a mano:
# los campos únicos A NIVEL BASE (no por club), las personas que no viajan, y la historia del lote
# —sin sus eventos, los lotes del club nuevo pierden las fechas de fase y su ciclo se cuenta mal—.
RSpec.describe Clubs::Clonar do
  let(:origen) { create(:club, name: 'Mitocondria') }
  let(:admin)  { create(:user, :admin, club: origen) }
  let(:sede)   { create(:sede, club: origen, created_by: admin) }
  let(:sala)   { create(:sala, club: origen, sede: sede, created_by: admin, kind: 'vegetativo') }

  def clonar = described_class.call(origen: origen.reload, nombre: 'Mitocondria 2')

  before do
    ActsAsTenant.with_tenant(origen) do
      genetica = create(:genetica, club: origen)
      @lote = create(:lote, club: origen, sala: sala, genetica: genetica, estado: 'vegetativo',
                            codigo: 'L-26-001', tamanio_maceta: 3, start_date: 30.days.ago.to_date)
      @planta = create(:plant, lote: @lote, club: origen, state: 'vegetativo', nombre: 'P1',
                               codigo_qr: 'QR-UNICO-1')
      @lote.lote_eventos.create!(tipo: 'cambio_estado', estado_anterior: 'enraizado',
                                 estado_nuevo: 'vegetativo', registrado_en: 12.days.ago,
                                 club: origen, user: admin)
      @lote.registros_ambientales.create!(club: origen, user: admin, registrado_en: 2.days.ago,
                                          temperatura: 24, humedad: 60, fuente: 'manual')
    end
  end

  it 'copia la estructura de cultivo' do
    res = clonar
    nuevo = res.club

    expect(nuevo.name).to eq('Mitocondria 2')
    ActsAsTenant.with_tenant(nuevo) do
      expect(Sede.count).to eq(1)
      expect(Sala.count).to eq(1)
      # Solo las del club: `Genetica.count` incluiría además las globales del INASE, que ya existen
      # y no se copian.
      expect(Genetica.where(club_id: nuevo.id).count).to eq(1)
      expect(Lote.count).to eq(1)
      expect(Plant.count).to eq(1)
      # La sala del lote copiado es la del club NUEVO, no la del original.
      expect(Lote.first.sala_id).to eq(Sala.first.id)
      expect(Sala.first.sede_id).to eq(Sede.first.id)
    end
  end

  # `plants.codigo_qr` y `lotes.codigo_qr` tienen índice único a nivel BASE, no por club: copiarlos
  # tal cual revienta contra el índice.
  it 'regenera los códigos QR en vez de duplicarlos' do
    nuevo = clonar.club

    ActsAsTenant.with_tenant(nuevo) do
      expect(Plant.first.codigo_qr).not_to eq('QR-UNICO-1')
      expect(Lote.first.codigo_qr).to be_present
      expect(Lote.first.codigo_qr).not_to eq(@lote.codigo_qr)
    end
  end

  # `users.email` es único global: los usuarios no se copian, se crea un admin y todo queda a su
  # nombre.
  it 'no copia usuarios: crea un admin y le atribuye la historia' do
    nuevo = clonar.club

    ActsAsTenant.with_tenant(nuevo) do
      expect(User.where(club_id: nuevo.id).count).to eq(1)
      expect(User.where(club_id: nuevo.id).first.role).to eq('admin')
      expect(LoteEvento.first.user_id).to eq(User.where(club_id: nuevo.id).first.id)
    end
    # y el club original queda intacto
    expect(origen.users.count).to eq(1)
  end

  # Sin los eventos, el lote copiado no sabe cuándo entró a vegetativo y su ciclo se cuenta desde el
  # esqueje: el mismo lote marcaría 30 días en un club y 12 en el otro.
  it 'se lleva la historia del lote, así los relojes dan lo mismo en los dos clubes' do
    # Se leen ANTES: dentro del tenant nuevo, las queries del lote original no ven sus propios
    # eventos (son del otro club) y caerían al fallback.
    dias_ciclo_original = ActsAsTenant.with_tenant(origen) { @lote.reload.dias_ciclo }
    fecha_veg_original  = ActsAsTenant.with_tenant(origen) { @lote.fecha_inicio_vegetativo }

    nuevo = clonar.club

    ActsAsTenant.with_tenant(nuevo) do
      copia = Lote.first
      expect(copia.lote_eventos.where(tipo: 'cambio_estado').count).to eq(1)
      expect(copia.dias_ciclo).to eq(dias_ciclo_original)
      expect(copia.fecha_inicio_vegetativo).to eq(fecha_veg_original)
      expect(copia.registros_ambientales.count).to eq(1)
    end
  end

  it 'no se lleva lo que no es cultivo' do
    ActsAsTenant.with_tenant(origen) do
      create(:paciente, club: origen)
      create(:movimiento_contable, club: origen, lote: @lote, tipo: 'egreso',
                                   categoria: 'insumo', monto_ars: 5_000, fecha: Date.current)
    end

    nuevo = clonar.club

    ActsAsTenant.with_tenant(nuevo) do
      expect(Paciente.count).to eq(0)
      expect(MovimientoContable.count).to eq(0)
    end
  end

  it 'rechaza un slug ya usado en vez de dejar dos clubes iguales' do
    described_class.call(origen: origen.reload, nombre: 'Mitocondria 2')
    expect {
      described_class.call(origen: origen.reload, nombre: 'Mitocondria 2')
    }.to raise_error(ArgumentError, /slug/i)
  end

  it 'si algo falla no deja un club a medio copiar' do
    allow(Plant).to receive(:new).and_raise(ActiveRecord::StatementInvalid, 'boom')

    expect { clonar }.to raise_error(ActiveRecord::StatementInvalid)
    expect(Club.unscoped.where(name: 'Mitocondria 2')).to be_empty
  end
end
