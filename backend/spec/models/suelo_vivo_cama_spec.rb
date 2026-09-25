require 'rails_helper'

# Suelo vivo: lo que la cama sabe de sí misma y lo que dispara (avisos, «Cómo salió», analítica,
# tareas). Ver `docs/PLAN_SUELO_VIVO.md`.
RSpec.describe Cama, type: :model do
  let(:club)  { create(:club, features: { 'cultivo' => true }) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sala)  { create(:sala, club: club, created_by: admin, kind: 'mixta', m2: 3) }
  let(:cama)  { Cama.create!(club: club, sala: sala, nombre: 'Cama A', largo_m: 1.2, ancho_m: 1.2, profundidad_cm: 30) }

  def plantar(estado: 'vegetativo', m2: nil)
    Current.user = admin
    create(:lote, club: club, sala: sala, cama: cama, estado: estado, start_date: Time.zone.today, m2_ocupados: m2)
  ensure
    Current.user = nil
  end

  describe 'qué viene' do
    it 'con frecuencia de top dress cargada, avisa cuándo toca; sin frecuencia no inventa' do
      plantar
      expect(cama.reload.proximo_paso).to be_nil
      cama.update!(frecuencia_top_dress_dias: 21)
      expect(cama.proximo_paso).to include(tipo: 'top_dress', fecha: Time.zone.today + 21)
    end

    it 'descansando sin fecha dice desde cuándo, no hasta cuándo' do
      cama.update!(descansa_desde: 3.days.ago.to_date)
      expect(cama.estado).to eq('descansando')
      expect(cama.proximo_paso).to include(tipo: 'descansando', lleva_dias: 3)
    end
  end

  describe 'borrar el único lote' do
    it 'no deja un ciclo vacío ni pone a descansar la cama' do
      lote = plantar
      expect(cama.ciclos.count).to eq(1)
      lote.soft_delete!
      expect(cama.reload.ciclos.count).to eq(0)
      expect(cama.estado).to eq('lista')
    end
  end

  describe 'avisos (AlertaDetectorService)' do
    it 'el día que termina el descanso avisa UNA vez (y ese día la cama ya está lista)' do
      cama.update!(descansa_desde: 10.days.ago.to_date, descansa_hasta: Time.zone.today + 2)
      expect { AlertaDetectorService.new(club).detectar! }.not_to(change { AlertaInterna.where(tipo: 'hito_cama').count })
      travel_to(Time.zone.today + 2) do
        expect(cama.reload.estado).to eq('lista')
        expect { AlertaDetectorService.new(club).detectar! }.to change { AlertaInterna.where(tipo: 'hito_cama').count }.by(1)
        expect { AlertaDetectorService.new(club).detectar! }.not_to(change { AlertaInterna.where(tipo: 'hito_cama').count })
        expect(AlertaInterna.where(tipo: 'hito_cama').last.mensaje).to include('terminó su descanso')
      end
    end

    it 'un descanso que terminó hace dos meses no se avisa hoy' do
      cama.update!(descansa_desde: 90.days.ago.to_date, descansa_hasta: 60.days.ago.to_date)
      expect { AlertaDetectorService.new(club).detectar! }.not_to(change { AlertaInterna.where(tipo: 'hito_cama').count })
    end

    it 'cuando toca top dress avisa una sola vez por fecha' do
      plantar
      cama.update!(frecuencia_top_dress_dias: 7)
      travel_to(Time.zone.today + 7) do
        expect { AlertaDetectorService.new(club).detectar! }.to change { AlertaInterna.where(tipo: 'hito_cama').count }.by(1)
        expect { AlertaDetectorService.new(club).detectar! }.not_to(change { AlertaInterna.where(tipo: 'hito_cama').count })
      end
      expect(AlertaInterna.where(tipo: 'hito_cama').last.mensaje).to include('le toca top dress')
    end

    it 'el aviso de camas está en el catálogo (lo que no está en el catálogo no se manda)' do
      expect(Notificaciones::Catalogo.tipo('camas')).to be_present
    end
  end

  describe '«Cómo salió» y analítica' do
    it 'compara el ciclo con el anterior de la MISMA cama, en g/m²' do
      l1 = plantar
      l1.update!(estado: 'cosecha', sala_id: nil, rendimiento_real_g: 576) # 576 / 1,44 = 400 g/m²
      expect(cama.reload.estado).to eq('descansando')
      l2 = plantar
      l2.update!(rendimiento_real_g: 720) # 500 g/m²
      r = Lotes::ResumenCiclo.new(l2.reload).call[:cama]
      expect(r).to include(nombre: 'Cama A', ciclo: 2, g_m2: 500.0)
      expect(r[:anterior]).to eq(ciclo: 1, g_m2: 400.0)
    end

    it 'el método de un lote en cama es suelo vivo (sale de la cama), y hay corte por cama' do
      l = plantar
      expect(l.metodo_cultivo).to eq('suelo_vivo')
      expect(Analitica::DondeYComo::CORTES).to include('cama')
    end
  end

  describe 'tareas automáticas en una cama' do
    it 'al cosechar dice «cortar al ras y dejar las raíces», no «limpiar la sala»' do
      l = plantar
      TareasAutoService.new(lote: l, estado_nuevo: 'cosecha', user: admin, club: club).call
      titulos = Tarea.where(lote_id: l.id).pluck(:titulo)
      expect(titulos).to include('Cortar al ras y dejar las raíces; tapar la cama con mulch')
      expect(titulos).not_to include('Limpiar y preparar sala post-cosecha')
    end

    it 'un lote sin cama sigue con las tareas de siempre' do
      l = create(:lote, club: club, sala: sala)
      TareasAutoService.new(lote: l, estado_nuevo: 'cosecha', user: admin, club: club).call
      expect(Tarea.where(lote_id: l.id).pluck(:titulo)).to include('Limpiar y preparar sala post-cosecha')
    end
  end
end

RSpec.describe RecetaItem, type: :model do
  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }
  let(:sede)  { create(:sede, club: club, created_by: admin) }

  it 'convierte la dosis a la unidad del insumo también en el riego (ml/L contra un bidón en litros)' do
    bidon = club.insumos.create!(nombre: 'Bio-Grow 5 L', unidad_medida: 'litro', sede: sede)
    r = club.recetas.create!(nombre: 'Vege', receta_items_attributes: [{ insumo_id: bidon.id, dosis: 2, unidad: 'ml_l' }])
    expect(r.calcular(20).first[:cantidad]).to eq(0.04) # 40 ml = 0,04 L
  end

  it 'si la unidad del insumo no tiene equivalencia, no inventa un factor' do
    otro = club.insumos.create!(nombre: 'Tabletas', unidad_medida: 'unidad', sede: sede)
    r = club.recetas.create!(nombre: 'X', receta_items_attributes: [{ insumo_id: otro.id, dosis: 1, unidad: 'g_l' }])
    expect(r.calcular(10).first[:cantidad]).to eq(10.0)
  end
end
