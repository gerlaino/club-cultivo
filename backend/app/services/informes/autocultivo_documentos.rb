# CÓMO SE MUESTRAN los tres informes del autocultivo (Mi cosecha, De dónde salió, Mis gastos): título,
# reseña, KPIs y tablas, a partir de los números de `Informes::Autocultivo`.
#
# Vivía adentro de `InformesController`; salió acá (11-oct-2026) para que «Exportar mis datos»
# (`Autocultivo::ExportarDatos`) arme los MISMOS PDF y Excel que se bajan desde «Mis informes», sin
# una segunda definición que algún día diga distinto.
module Informes
  class AutocultivoDocumentos
    TIPOS = %w[mi_cosecha de_donde_salio mis_gastos].freeze

    def initialize(club:, desde:, hasta:)
      @club, @desde, @hasta = club, desde, hasta
      @fuente = Informes::Autocultivo.new(club: club, desde: desde, hasta: hasta)
    end

    # Los argumentos de `responder_informe` (sin el período, que el que llama sabe escribir).
    def para(tipo)
      raise ArgumentError, "informe desconocido: #{tipo}" unless TIPOS.include?(tipo.to_s)
      send(tipo)
    end

    private

    def mi_cosecha
      d = @fuente.mi_cosecha
      g = ->(n) { n.nil? ? '—' : "#{num(n)} g" }
      {
        titulo: 'Mi cosecha', nombre: 'mi_cosecha', datos: d,
        resena: '¿Cuánto rindió cada planta y cada genética? Cuenta las plantas cosechadas en el período. Si varias se pesaron juntas, a cada una le toca su parte y se aclara.',
        kpis: [
          { label: 'Plantas cosechadas', valor: d[:total_plantas] },
          { label: 'Seco', valor: g.call(d[:seco_g]), tono: :ok },
          { label: 'Por planta', valor: g.call(d[:por_planta_g]) },
        ],
        secciones: [
          { titulo: 'Planta por planta',
            headers: ['Planta', 'Genética', 'Tipo', 'Cosechada', 'Días', 'Húmedo (g)', 'Seco (g)', ''],
            rows: d[:plantas].map { |f| [f[:nombre], f[:genetica], f[:tipo], fmt_fecha(f[:cosechada]), f[:dias] || '—',
                                         f[:humedo_g] || '—', f[:seco_g] || 'sin peso', f[:repartido] ? 'repartido' : ''] },
            formatos: [:texto, :texto, :texto, :texto, :numero, :numero, :numero, :texto],
            aligns: { 4 => :right, 5 => :right, 6 => :right },
            vacio: 'No se cosechó ninguna planta en el período elegido.' },
          { titulo: 'Por genética',
            headers: ['Genética', 'Plantas', 'Seco (g)', 'Por planta (g)'],
            rows: d[:por_genetica].map { |x| [x[:genetica], x[:plantas], x[:seco_g] || 'sin peso', x[:por_planta_g] || '—'] },
            formatos: [:texto, :numero, :numero, :numero], aligns: { 1 => :right, 2 => :right, 3 => :right },
            vacio: 'Sin cosechas en el período.' },
        ],
      }
    end

    def de_donde_salio
      d = @fuente.de_donde_salio
      {
        titulo: 'De dónde salió', nombre: 'de_donde_salio', datos: d,
        resena: 'Cada frasco del período con las plantas de las que salió, su genética y el QR de cada planta: escaneándolo se abre su diario entero.',
        kpis: [
          { label: 'Frascos', valor: d[:total_frascos] },
          { label: 'Gramos', valor: "#{num(d[:gramos])} g" },
          { label: 'Plantas de origen', valor: d[:plantas_de_origen] },
        ],
        secciones: [
          { titulo: 'Frasco por frasco',
            headers: ['Frasco', 'Producto', 'Cantidad', 'Quedan', 'Plantas', 'Genética', 'Cosechada', 'QR de las plantas'],
            rows: d[:frascos].map { |f| [f[:codigo], f[:producto], "#{num(f[:gramos])} #{f[:unidad]}", "#{num(f[:quedan])} #{f[:unidad]}",
                                         f[:plantas].join(', ').presence || '—', f[:genetica] || '—', fmt_fecha(f[:cosechada]),
                                         f[:qr_plantas].join(', ').presence || '—'] },
            aligns: { 2 => :right, 3 => :right },
            vacio: 'No se armó ningún frasco en el período elegido.' },
        ],
      }
    end

    def mis_gastos
      d = @fuente.mis_gastos
      pesos = ->(n) { n.nil? ? '—' : "$ #{ActiveSupport::NumberHelper.number_to_delimited(n.round, delimiter: '.')}" }
      {
        titulo: 'Mis gastos', nombre: 'mis_gastos', datos: d,
        resena: 'Lo que anotaste como gasto en el período, por mes y por tipo, y cuánto costó cada gramo: lo gastado dividido por lo que se cosechó en el mismo período.',
        kpis: [
          { label: 'Gastado', valor: pesos.call(d[:total]) },
          { label: 'Seco cosechado', valor: d[:seco_g].to_f.positive? ? "#{num(d[:seco_g])} g" : '—' },
          { label: 'Cada gramo', valor: pesos.call(d[:por_gramo]), tono: :ok },
        ],
        secciones: [
          { titulo: 'Mes por mes',
            headers: ['Mes', *d[:tipos], 'Total'],
            rows: d[:por_mes].map { |m| [I18n.l(m[:mes], format: '%B %Y').capitalize, *d[:tipos].map { |t| pesos.call(m[:por_tipo][t]) }, pesos.call(m[:total])] },
            aligns: (1..d[:tipos].size + 1).to_h { |i| [i, :right] },
            vacio: 'No anotaste gastos en el período elegido.' },
          { titulo: 'Por cosecha (gastos asignados a esas plantas)',
            headers: ['Plantas', 'Genética', 'Gastado', 'Seco (g)', 'Cada gramo'],
            rows: d[:por_cosecha].map { |c| [c[:plantas].join(', '), c[:genetica] || '—', pesos.call(c[:gastado]), c[:gramos] || 'sin peso', pesos.call(c[:por_gramo])] },
            aligns: { 2 => :right, 3 => :right, 4 => :right },
            vacio: 'Ningún gasto del período está asignado a una cosecha.' },
        ],
      }
    end

    def num(n) = ActiveSupport::NumberHelper.number_to_delimited(n.to_f.round(1).to_s.sub(/\.0\z/, ''), delimiter: '.', separator: ',')

    def fmt_fecha(f)
      return '—' if f.blank?
      (f.is_a?(String) ? Date.parse(f) : f).strftime('%d/%m/%Y')
    rescue ArgumentError
      f.to_s
    end
  end
end
