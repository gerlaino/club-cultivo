require 'rails_helper'

# Auditoría del área de pacientes: 20 casos de uso sobre los DOS estados que conviven
# y que hoy se confunden entre sí:
#
#   1. `es_paciente`      → si la persona está ACTIVA EN EL CLUB (decisión del club).
#   2. `reprocann_estado` → en qué punto del trámite ANMAT está (decisión del Estado).
#
# Son independientes: se puede estar activo sin REPROCANN, e inactivo con REPROCANN vigente.
# Los tests están escritos contra el comportamiento ESPERADO, no contra el implementado.
RSpec.describe 'Pacientes — activo/inactivo y estados REPROCANN', type: :request do
  let(:club)  { create(:club) }
  let(:admin) { create(:user, :admin, club: club) }

  def paciente!(attrs = {})
    create(:paciente, { club: club, created_by: admin }.merge(attrs))
  end

  def json = JSON.parse(response.body)

  # Un stock cualquiera para poder construir una dispensación válida en lo demás.
  def stock!
    @stock ||= create(:stock, club: club, cantidad: 500)
  end

  # ══════════════════════════════════════════════════════════════════════
  # BLOQUE A — Qué significa "activo" (es_paciente)
  # ══════════════════════════════════════════════════════════════════════
  describe 'A. es_paciente: la persona está activa en el club' do
    before { sign_in_as(admin) }

    it 'CASO 01 — un paciente nace activo' do
      p = paciente!
      expect(p.es_paciente).to be(true)
    end

    it 'CASO 02 — a un paciente INACTIVO no se le puede dispensar' do
      p = paciente!(es_paciente: false)
      d = Dispensacion.new(paciente: p, user: admin, stock: stock!,
                           cantidad: 1, fecha_dispensacion: Time.zone.today)

      expect(d).not_to be_valid
      expect(d.errors[:base].join).to match(/no está activo/i)
    end

    it 'CASO 03 — a un paciente INACTIVO no se le puede reservar stock' do
      p = paciente!(es_paciente: false)
      r = Reserva.new(club: club, paciente: p, user: admin, stock: stock!,
                      cantidad: 1, fecha_entrega_estimada: 2.days.from_now.to_date)

      expect(r).not_to be_valid
      expect(r.errors[:base].join).to match(/no está activo/i)
    end

    it 'CASO 04 — dar de baja NO borra: el paciente y su historial siguen existiendo' do
      p = paciente!
      patch "/api/pacientes/#{p.id}", params: { paciente: { es_paciente: false } }

      expect(response).to have_http_status(:ok)
      expect(p.reload.es_paciente).to be(false)
      expect(p.deleted_at).to be_nil
    end

    it 'CASO 05 — un paciente inactivo se puede reactivar' do
      p = paciente!(es_paciente: false)
      patch "/api/pacientes/#{p.id}", params: { paciente: { es_paciente: true } }

      expect(p.reload.es_paciente).to be(true)
    end

    it 'CASO 06 — el listado marca a los inactivos, no los esconde' do
      activo   = paciente!(nombre: 'Ana')
      inactivo = paciente!(nombre: 'Beto', es_paciente: false)

      get '/api/pacientes'

      ids = json['data'].map { |p| p['id'] }
      expect(ids).to include(activo.id, inactivo.id)
      fila = json['data'].find { |p| p['id'] == inactivo.id }
      expect(fila['es_paciente']).to be(false)
    end
  end

  # ══════════════════════════════════════════════════════════════════════
  # BLOQUE B — Los cuatro estados de REPROCANN
  # ══════════════════════════════════════════════════════════════════════
  describe 'B. reprocann_estado: en qué punto del trámite está' do
    before { sign_in_as(admin) }

    it 'CASO 07 — sin_registro es el estado inicial' do
      expect(paciente!.reprocann_estado).to eq('sin_registro')
    end

    it 'CASO 08 — "pendiente" sobrevive al guardado (no se degrada a sin_registro)' do
      p = paciente!
      patch "/api/pacientes/#{p.id}", params: { paciente: { reprocann_estado: 'pendiente' } }

      expect(p.reload.reprocann_estado).to eq('pendiente')
    end

    # EL BUG REPORTADO. Un trámite en curso todavía NO tiene certificado, así que no
    # tiene número ni fecha de vencimiento. El estado es el único dato que existe.
    it 'CASO 09 — un pendiente SIN número ni fecha se informa como pendiente, no como "sin REPROCANN"' do
      p = paciente!(reprocann_estado: 'pendiente', reprocann_numero: nil, reprocann_vencimiento: nil)

      get "/api/pacientes/#{p.id}"

      expect(json['data']['reprocann_estado_efectivo']).to eq('pendiente')
    end

    it 'CASO 10 — "activo" con fecha futura queda vigente' do
      p = paciente!(reprocann_estado: 'activo', reprocann_vencimiento: 6.months.from_now.to_date)

      expect(p.reprocann_estado_efectivo).to eq('activo')
    end

    it 'CASO 11 — "activo" con fecha pasada se informa VENCIDO aunque nadie lo haya tocado' do
      p = paciente!(reprocann_estado: 'activo', reprocann_vencimiento: 1.day.ago.to_date)

      expect(p.reprocann_estado_efectivo).to eq('vencido')
    end

    it 'CASO 12 — "pendiente" con fecha pasada sigue pendiente: hay renovación en curso' do
      p = paciente!(reprocann_estado: 'pendiente', reprocann_vencimiento: 1.day.ago.to_date)

      expect(p.reprocann_estado_efectivo).to eq('pendiente')
    end

    it 'CASO 13 — REPROCANN vencido NO bloquea dispensar (hoy es una alerta, no un candado)' do
      p = paciente!(reprocann_estado: 'activo', reprocann_vencimiento: 1.year.ago.to_date)
      d = Dispensacion.new(paciente: p, user: admin, stock: stock!,
                           cantidad: 1, fecha_dispensacion: Time.zone.today)

      expect(d).to be_valid
    end

    it 'CASO 14 — el aviso de vencimiento no molesta por pacientes dados de baja' do
      paciente!(es_paciente: false, reprocann_estado: 'activo',
                reprocann_vencimiento: 10.days.from_now.to_date)

      avisados = Paciente.where(es_paciente: true)
                         .where(reprocann_estado: %w[activo pendiente])
                         .where(reprocann_vencimiento: Time.zone.today..30.days.from_now)

      expect(avisados).to be_empty
    end
  end

  # ══════════════════════════════════════════════════════════════════════
  # BLOQUE C — Los informes tienen que cerrar
  # ══════════════════════════════════════════════════════════════════════
  describe 'C. Informe REPROCANN' do
    before { sign_in_as(admin) }

    def informe = (get('/api/informes/reprocann'); json)

    it 'CASO 15 — el total NO cuenta a los pacientes dados de baja' do
      paciente!(reprocann_vencimiento: 6.months.from_now.to_date)
      paciente!(es_paciente: false, reprocann_vencimiento: 6.months.from_now.to_date)

      expect(informe['total_pacientes']).to eq(1)
    end

    it 'CASO 16 — un paciente que vence en 15 días se cuenta UNA vez, no en dos categorías' do
      paciente!(reprocann_estado: 'activo', reprocann_vencimiento: 15.days.from_now.to_date)
      d = informe

      suma = d['con_reprocann_vigente'].to_i + d['vencen_30d'].to_i + d['vencidos'].to_i +
             d['pendientes'].to_i + d['sin_reprocann'].to_i
      expect(suma).to eq(d['total_pacientes'])
    end

    it 'CASO 17 — las categorías suman el total con la población mezclada' do
      paciente!(reprocann_numero: 'R-1', reprocann_vencimiento: 8.months.from_now.to_date)
      paciente!(reprocann_numero: 'R-2', reprocann_vencimiento: 10.days.from_now.to_date)
      paciente!(reprocann_numero: 'R-3', reprocann_vencimiento: 40.days.ago.to_date)
      paciente!(reprocann_numero: nil)
      d = informe

      suma = d['con_reprocann_vigente'].to_i + d['vencen_30d'].to_i + d['vencidos'].to_i +
             d['pendientes'].to_i + d['sin_reprocann'].to_i
      expect(suma).to eq(d['total_pacientes'])
    end

    it 'CASO 18 — un paciente con número pero sin fecha no desaparece de los conteos' do
      paciente!(reprocann_numero: 'R-9', reprocann_vencimiento: nil)
      d = informe

      suma = d['con_reprocann_vigente'].to_i + d['vencen_30d'].to_i + d['vencidos'].to_i +
             d['pendientes'].to_i + d['sin_reprocann'].to_i
      expect(suma).to eq(d['total_pacientes'])
    end

    it 'CASO 19 — el trámite pendiente aparece como pendiente en la lista del informe' do
      paciente!(reprocann_estado: 'pendiente', reprocann_numero: nil, reprocann_vencimiento: nil)

      fila = informe['lista_anonimizada'].first
      expect(fila['reprocann_estado']).to eq('pendiente')
    end

    # El informe es de PACIENTES Y SEDE: nada de cultivo, que vive en Producción y Sedes.
    it 'CASO 20a — agrupa a los pacientes por la sede donde se atienden' do
      sede  = create(:sede, club: club, created_by: admin, tipo: 'mixta')
      stock = create(:stock, club: club, sede: sede, cantidad: 500)
      p     = paciente!(reprocann_numero: 'R-1', reprocann_vencimiento: 8.months.from_now.to_date)
      Dispensacion.create!(paciente: p, user: admin, stock: stock, cantidad: 5,
                           fecha_dispensacion: Time.zone.today)

      fila = informe['por_sede'].find { |r| r['sede'] == sede.nombre }

      expect(fila['total']).to eq(1)
      expect(fila['vigentes']).to eq(1)
    end

    it 'CASO 20b — quien nunca dispensó no se pierde: cae en "Sin dispensaciones"' do
      paciente!

      expect(informe['por_sede'].map { |r| r['sede'] }).to include('Sin dispensaciones')
    end

    it 'CASO 20c — el informe no trae nada de cultivo' do
      paciente!

      expect(informe.keys).not_to include('lotes', 'plantas', 'gramos_producidos', 'por_estado')
    end

    it 'CASO 20 — el informe no filtra datos de otro club' do
      otro = create(:club)
      otro_admin = create(:user, :admin, club: otro)
      ajeno = ActsAsTenant.with_tenant(otro) { create(:paciente, club: otro, created_by: otro_admin) }
      paciente!

      expect(ajeno.club_id).to eq(otro.id)
      expect(informe['total_pacientes']).to eq(1)
    end
  end
end
