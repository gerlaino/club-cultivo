require 'rails_helper'

# AC (9-oct-2026, Germán): «ningún archivo descargado puede ser así, ninguno»: todas las descargas
# son un informe profesional —membrete, tablas armadas, que se entienda—, se presenten o sean de
# un autocultivo. Cada listado se baja en Excel (por defecto) o en PDF. No hay más CSV.
RSpec.describe 'Descargas: Excel o PDF, nunca CSV', type: :request do
  let(:club)   { create(:club) }
  let(:sede)   { create(:sede, club: club) }
  let(:admin)  { create(:user, :admin,  club: club) }
  let(:medico) { create(:user, :medico, club: club) }
  let(:disp)   { create(:user, :dispensador, club: club) }

  around { |ej| ActsAsTenant.with_tenant(club) { ej.run } }

  def bajar(url, **params)
    get url, params: params
    expect(response).to have_http_status(:ok), response.body.to_s.first(300)
    response
  end

  def es_excel(r)
    expect(r.content_type).to include(DescargasHelper::XLSX)
    expect(r.headers['Content-Disposition']).to include('.xlsx')
  end

  def es_pdf(r)
    expect(r.content_type).to include('application/pdf')
    expect(es_pdf?(r.body)).to be(true)
  end

  describe 'pacientes' do
    before { create(:paciente, club: club, nombre: 'Ana', apellido: 'Pérez') }

    it 'Excel con encabezados legibles y el paciente; sin id interno ni límite mensual' do
      sign_in_as(admin)
      r = bajar('/api/pacientes/export_csv')
      es_excel(r)
      texto = texto_xlsx(r.body)
      expect(texto).to include('Apellido', 'DNI', 'REPROCANN', 'Pérez')
      expect(texto).not_to include('Límite', 'ID')
    end

    it 'PDF con formato=pdf' do
      sign_in_as(admin)
      es_pdf(bajar('/api/pacientes/export_csv', formato: 'pdf'))
    end

    it 'el médico también la baja; el dispensador no' do
      sign_in_as(medico)
      bajar('/api/pacientes/export_csv')
      sign_in_as(disp)
      get '/api/pacientes/export_csv'
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'dispensaciones' do
    it 'Excel y PDF, con filtro de fechas' do
      sign_in_as(admin)
      es_excel(bajar('/api/dispensaciones/export_csv', desde: '2026-01-01', hasta: '2026-12-31'))
      es_pdf(bajar('/api/dispensaciones/export_csv', formato: 'pdf'))
      expect(texto_xlsx(bajar('/api/dispensaciones/export_csv').body)).to include('Qué se llevó', 'Pagó con')
    end

    it 'el dispensador la baja' do
      sign_in_as(disp)
      es_excel(bajar('/api/dispensaciones/export_csv'))
    end
  end

  describe 'lotes' do
    it 'Excel con el estado con su nombre, y PDF' do
      create(:lote, club: club, codigo: 'L-XLS', estado: 'vegetativo')
      sign_in_as(admin)
      texto = texto_xlsx(bajar('/api/lotes/export_csv').body)
      expect(texto).to include('L-XLS', 'Vegetativo')
      es_pdf(bajar('/api/lotes/export_csv', formato: 'pdf'))
    end
  end

  describe 'movimientos contables' do
    it 'Excel (también por .xlsx) y PDF; el .csv ya no es CSV' do
      sign_in_as(admin)
      es_excel(bajar('/api/movimientos_contables/export_csv'))
      es_excel(bajar('/api/movimientos_contables/export_csv.xlsx'))
      es_pdf(bajar('/api/movimientos_contables/export_csv', formato: 'pdf'))
    end
  end

  describe 'reporte de finanzas' do
    it 'Excel y PDF del período' do
      sign_in_as(admin)
      es_excel(bajar('/api/finanzas/reporte/export', desde: '2026-10-01', hasta: '2026-10-31'))
      es_pdf(bajar('/api/finanzas/reporte/export', desde: '2026-10-01', hasta: '2026-10-31', formato: 'pdf'))
    end
  end

  describe 'plan de trabajo' do
    let(:plan) do
      PlanTrabajo.create!(club: club, creado_por: admin, titulo: 'Automaticas', estado: :publicado, es_plantilla: true).tap do |p|
        PlanTarea.create!(plan_trabajo: p, titulo: 'Trasplante', tipo: 'trasplante', prioridad: 'normal', dia_relativo: 14,
                          descripcion: "Técnica: apical\n---\nPasar de vasos a maceta de 10 lt definitiva")
      end
    end

    it 'la plantilla dice semana, tarea y qué hacer, sin columnas técnicas' do
      sign_in_as(admin)
      filas = filas_xlsx(bajar("/api/plan_trabajos/#{plan.id}/export_csv", modo: 'plantilla').body)
      texto = filas.flatten.join(' | ')
      expect(texto).to include('Semana 3 · día 1', 'Trasplante', 'Pasar de vasos a maceta de 10 lt definitiva')
      expect(texto).not_to include('rol_sugerido', 'dia_relativo', '---')
    end

    it 'como calendario lleva la fecha real, y sale en PDF' do
      sign_in_as(admin)
      texto = texto_xlsx(bajar("/api/plan_trabajos/#{plan.id}/export_csv", modo: 'calendario', fecha_inicio: '2026-10-03').body)
      expect(texto).to include('Fecha')
      es_pdf(bajar("/api/plan_trabajos/#{plan.id}/export_csv", modo: 'calendario', fecha_inicio: '2026-10-03', formato: 'pdf'))
    end
  end

  describe 'analítica' do
    let(:tabla) do
      { titulo: 'Analítica — Genéticas', nombre: 'geneticas', periodo: 'Todo el historial',
        headers: ['Genética', 'Lotes', 'g/planta'], formatos: %w[texto numero numero],
        rows: [['Gelato 41', 3, 42.5], ['Amnesia', 2, nil]] }
    end

    it 'la tabla de la solapa sale como informe, en Excel y en PDF' do
      sign_in_as(admin)
      post '/api/analytics/descargar', params: tabla.merge(formato: 'xlsx'), as: :json
      expect(response.content_type).to include(DescargasHelper::XLSX)
      expect(texto_xlsx(response.body)).to include('Gelato 41', 'g/planta')
      post '/api/analytics/descargar', params: tabla.merge(formato: 'pdf'), as: :json
      expect(es_pdf?(response.body)).to be(true)
    end

    it 'sólo quien ve la analítica' do
      sign_in_as(disp)
      post '/api/analytics/descargar', params: tabla, as: :json
      expect(response).to have_http_status(:forbidden)
    end
  end

  it 'aislamiento: el plan de otra organización no se baja' do
    otro = create(:club)
    ajeno = ActsAsTenant.with_tenant(otro) do
      PlanTrabajo.create!(club: otro, creado_por: create(:user, :admin, club: otro), titulo: 'Ajeno', estado: :publicado, es_plantilla: true)
    end
    sign_in_as(admin)
    get "/api/plan_trabajos/#{ajeno.id}/export_csv"
    expect(response).to have_http_status(:not_found)
  end
end
