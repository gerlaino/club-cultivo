class InformesController < ApplicationController
  include DeclaracionInaseGuard
  before_action :authenticate_user!
  before_action :require_auditor_o_admin!

  # Cómo se llama lo que se mide en cada unidad, para el título de un KPI. Lo que no está acá se
  # dice «En <unidad>».
  FORMAS_UNIDAD = { 'g' => 'En gramos', 'un' => 'En unidades', 'ml' => 'En mililitros' }.freeze

  PERIODO_RANGOS = {
    'mes_actual'   => -> { [Time.zone.today.beginning_of_month, Time.zone.today.end_of_month] },
    'mes_anterior' => -> { [1.month.ago.beginning_of_month, 1.month.ago.end_of_month] },
    'trimestre'    => -> { [3.months.ago.beginning_of_month, Time.zone.today.end_of_month] },
    'anio'         => -> { [Time.zone.today.beginning_of_year, Time.zone.today.end_of_year] },
  }.freeze

  # EL DNI VA COMPLETO EN LO QUE SE DESCARGA Y PARCIAL EN LA PANTALLA.
  #
  # Son dos usos distintos: la pantalla la mira cualquiera que pase por atrás y con los últimos
  # tres alcanza para desambiguar homónimos; el PDF y el Excel se PRESENTAN —ante el organismo, un
  # auditor, un abogado— y un padrón con el documento tapado no acredita a nadie.
  #
  # El dato completo NO viaja en el JSON: si viajara, estaría en el navegador de cualquiera que
  # abra el informe, se vea o no en pantalla. Se agrega recién al armar el archivo.
  def reprocann
    desde, hasta = periodo_rango
    data = reprocann_data(current_user.club, desde: desde, hasta: hasta)

    respond_to do |format|
      format.json { render json: sin_dni_completo(data) }
      format.pdf do
        next if bloquear_descarga_si_falta_declarar!

        pdf = ReprocannDocument.new(club: current_user.club, usuario: current_user, data: data,
                                    salvedad_inase: salvedad_inase).render
        send_data pdf,
                  filename:    "informe_reprocann_#{Time.zone.today.strftime('%Y%m%d')}.pdf",
                  type:        "application/pdf",
                  disposition: "attachment"
      end
      format.xlsx do
        next if bloquear_descarga_si_falta_declarar!

        send_data reprocann_xlsx(current_user.club, data),
                  filename:    "informe_reprocann_#{Time.zone.today.strftime('%Y%m%d')}.xlsx",
                  type:        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
                  disposition: "attachment"
      end
    end
  end

  # Un informe se define una sola vez (KPIs + tablas) y de esa definición salen la respuesta
  # JSON, el PDF y el Excel. Antes el PDF era una captura de pantalla con html2canvas y el
  # Excel no existía.
  # `resena`: en una o dos frases, qué pregunta contesta este informe y con qué criterio está
  # armado. Un informe que no dice de qué habla obliga a adivinar a partir de los números —y con
  # dos informes que cortan el mismo dato distinto, adivinar termina en "esto no coincide".
  def responder_informe(titulo:, datos:, kpis:, secciones:, nombre:, periodo: nil, nota: nil,
                        resena: nil, exige_declaracion_inase: false)
    respond_to do |format|
      format.json { render json: datos.merge(resena: resena) }
      format.pdf do
        # Sólo frena si quien descarga dijo que es PARA PRESENTAR. Si no, sale con la salvedad.
        next if exige_declaracion_inase && bloquear_descarga_si_falta_declarar!

        pdf = InformeDocument.new(club: current_user.club, usuario: current_user, titulo: titulo,
                                  kpis: kpis, secciones: secciones, periodo: periodo, nota: nota,
                                  salvedad_inase: (salvedad_inase if exige_declaracion_inase)).render
        send_data pdf, filename: "#{nombre}_#{Time.zone.today.strftime('%Y%m%d')}.pdf",
                  type: 'application/pdf', disposition: 'attachment'
      end
      format.xlsx do
        next if exige_declaracion_inase && bloquear_descarga_si_falta_declarar!

        principal = secciones.first || { headers: [], rows: [] }
        # El Excel no tiene recuadro, así que la salvedad entra al resumen: la misma advertencia
        # tiene que viajar en los dos formatos o el que se baje el Excel no se entera.
        pendientes = (salvedad_inase if exige_declaracion_inase)
        resumen = kpis.to_h { |k| [k[:label], k[:valor]] }
        resumen['Variedades sin acreditar ante el INASE'] = pendientes.join(', ') if pendientes
        xlsx = XlsxExport.new(
          club: current_user.club, titulo: titulo, subtitulo: periodo,
          headers: principal[:headers], rows: principal[:rows],
          formatos: principal[:formatos], totales: principal[:totales],
          resumen: resumen,
        ).render
        send_data xlsx, filename: "#{nombre}_#{Time.zone.today.strftime('%Y%m%d')}.xlsx",
                  type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
                  disposition: 'attachment'
      end
    end
  end

  # Tres bloques en tres marcos de tiempo: lo cosechado del período (comparado con el anterior),
  # la foto de hoy y lo que viene. El cálculo vive en `Informes::Produccion`; acá sólo se arma
  # cómo se muestra en el PDF y el Excel.
  def produccion
    club  = current_user.club
    desde, hasta = periodo_rango
    datos = Informes::Produccion.new(club: club, desde: desde, hasta: hasta).call
    per   = datos[:periodo]
    hoy   = datos[:hoy]

    fmt_g   = ->(g) { g.nil? ? '—' : "#{ActiveSupport::NumberHelper.number_to_delimited(g.round(1), delimiter: '.', separator: ',')} g" }
    fmt_var = ->(v) { v.nil? ? 'sin período anterior' : "#{v.positive? ? '+' : ''}#{v} %" }

    responder_informe(
      titulo: 'Informe de producción', nombre: 'informe_produccion',
      resena: 'Qué se cosechó en el período elegido —comparado con el anterior—, qué hay hoy en cada etapa del cultivo y hace cuánto, y qué está por cortarse. Un lote cuenta como cosechado el día que se corta, y sus gramos pertenecen a ese período aunque se pesen después.',
      datos: datos, periodo: etiqueta_periodo(desde, hasta),
      kpis: [
        { label: 'Flor seca cosechada', valor: fmt_g.call(per[:gramos]), tono: :ok },
        { label: 'Lotes cosechados',    valor: per[:total_lotes] },
        { label: 'Por planta',          valor: fmt_g.call(per[:gramos_por_planta]) },
        { label: 'Plantas en cultivo',  valor: hoy[:plantas_en_pie] },
        # No «Lotes cosechados» como en la pantalla: en esta fila ya está el del período, y dos
        # KPIs con el mismo nombre y distinto número al lado se leen como un error.
        { label: 'Cosechados sin terminar', valor: hoy[:lotes_en_proceso] },
      ],
      secciones: [
        {
          titulo: 'Lotes cosechados en el período',
          headers: ['Lote', 'Genética', 'Sede', 'Cosecha', 'Plantas', 'Flor seca (g)', 'g / planta', 'Días de ciclo'],
          rows: per[:lotes].map do |l|
            [l[:codigo], l[:genetica] || '—', l[:sede] || '—', fmt_fecha(l[:fecha]), l[:plantas],
             l[:gramos] || 'sin peso', l[:gramos_por_planta] || '—', l[:dias_ciclo] || '—']
          end,
          formatos: [:texto, :texto, :texto, :texto, :numero, :numero, :numero, :numero],
          totales: [4, 5],
          aligns: { 4 => :right, 5 => :right, 6 => :right, 7 => :right },
          col_min: { 5 => 58 },
          vacio: 'No se cosechó ningún lote en el período elegido.',
        },
        {
          titulo: 'Comparado con el período anterior',
          headers: ['', 'Este período', 'Anterior', 'Variación'],
          rows: [
            ['Flor seca cosechada', fmt_g.call(per[:gramos]), fmt_g.call(per[:anterior][:gramos]), fmt_var.call(per[:variacion][:gramos])],
            ['Lotes cosechados',    per[:total_lotes],        per[:anterior][:total_lotes],        fmt_var.call(per[:variacion][:total_lotes])],
            ['Plantas cosechadas',  per[:plantas],            per[:anterior][:plantas],            fmt_var.call(per[:variacion][:plantas])],
            ['Por planta',          fmt_g.call(per[:gramos_por_planta]), fmt_g.call(per[:anterior][:gramos_por_planta]), fmt_var.call(per[:variacion][:gramos_por_planta])],
          ],
          aligns: { 1 => :right, 2 => :right, 3 => :right },
          # «Este período» y «sin período anterior» no entran en 46 pt: se partían en sílabas.
          col_min: { 1 => 80, 2 => 70, 3 => 100 },
        },
        {
          # LA FOTO DE HOY, no del período: estos lotes están en ese estado AHORA.
          titulo: 'Hoy en el cultivo',
          headers: ['Etapa', 'Lotes', 'Plantas', 'Días (prom.)', 'El más viejo', 'Rendimiento acumulado'],
          rows: hoy[:por_estado].map do |e|
            viejo = e[:mas_viejo]
            [e[:estado].to_s.tr('_', ' ').capitalize, e[:lotes], e[:plantas] || '—', e[:dias_promedio] || '—',
             viejo ? "#{viejo[:codigo]} · #{viejo[:dias]} d#{viejo[:excedido] ? " (objetivo #{viejo[:objetivo]})" : ''}" : '—',
             e[:rendimiento].positive? ? fmt_g.call(e[:rendimiento]) : '—']
          end,
          totales: [1, 2],
          aligns: { 1 => :right, 2 => :right, 3 => :right, 5 => :right },
          col_min: { 4 => 90 },
          vacio: 'No hay lotes en el cultivo ahora mismo.',
        },
        {
          titulo: 'Lo que viene',
          headers: ['Lote', 'Genética', 'Sala', 'Plantas', 'Cosecha estimada', 'Estimado'],
          rows: datos[:proximas].map do |p|
            [p[:codigo], p[:genetica] || '—', p[:sala] || '—', p[:plantas],
             p[:fecha] ? "#{fmt_fecha(p[:fecha])} (#{p[:dias]} d)" : 'sin fecha',
             p[:estimado] ? "≈ #{fmt_g.call(p[:estimado])}" : 'sin historia']
          end,
          aligns: { 3 => :right, 5 => :right },
          col_min: { 4 => 80 },
          vacio: 'No hay lotes en floración.',
        },
        {
          titulo: 'Por sede',
          headers: ['Sede', 'Salas', 'Plantas en cultivo', 'Flor seca (g)'],
          rows: datos[:por_sede].map { |s| [s[:nombre], s[:salas], s[:plantas], s[:stock_disponible]] },
          formatos: [:texto, :numero, :numero, :numero],
          totales: [1, 2, 3],
          aligns: { 1 => :right, 2 => :right, 3 => :right },
          vacio: 'La organización todavía no tiene sedes cargadas.',
        },
      ],
    )
  end

  # Tres preguntas del período: QUÉ salió (por unidad, contra el anterior), A QUIÉN y POR DÓNDE.
  # El cálculo vive en `Informes::Dispensaciones`; acá sólo se arma cómo se muestra.
  def dispensaciones
    club  = current_user.club
    desde, hasta = periodo_rango
    datos = Informes::Dispensaciones.new(club: club, desde: desde, hasta: hasta).call
    salio = datos[:salio]

    fmt_u   = ->(c, u) { "#{ActiveSupport::NumberHelper.number_to_delimited(c.to_f.round(1).to_s.sub(/\.0\z/, ''), delimiter: '.', separator: ',')} #{u}" }
    fmt_var = ->(v) { v.nil? ? 'sin período anterior' : "#{v.positive? ? '+' : ''}#{v} %" }
    unidades = ->(lista) { lista.map { |x| fmt_u.call(x[:cantidad], x[:unidad]) }.join(' · ').presence || '—' }
    otros    = ->(lista) { lista.map { |x| "#{fmt_u.call(x[:cantidad], x[:unidad])} #{x[:forma].to_s.tr('_', ' ')}" }.join(' · ').presence || '—' }

    # Al navegador va sin el documento completo y con la lista cortada: la pantalla muestra los
    # últimos tres y lista 100, y dice cuántos más. Los totales de arriba son sobre todos.
    pacientes_pantalla = datos[:pacientes].first(Informes::Dispensaciones::LISTA_PANTALLA).map { |r| r.except(:dni) }
    json = datos.merge(
      pacientes: pacientes_pantalla,
      pacientes_omitidos: [datos[:pacientes].size - pacientes_pantalla.size, 0].max,
    )

    responder_informe(
      titulo: 'Informe de dispensaciones', nombre: 'informe_dispensaciones',
      resena: 'Qué salió de la organización en el período elegido —por unidad, nunca sumado—, a quién y por dónde. Una fila por paciente con el DNI parcial y la genética y forma de lo que retiró, que es lo que cruza con la trazabilidad.',
      datos: json, periodo: etiqueta_periodo(desde, hasta),
      kpis: salio[:por_unidad].map { |x| { label: FORMAS_UNIDAD[x[:unidad]] || "En #{x[:unidad]}", valor: fmt_u.call(x[:cantidad], x[:unidad]), tono: :ok } } +
            [{ label: 'Entregas',  valor: salio[:entregas][:valor] },
             { label: 'Pacientes', valor: salio[:pacientes][:valor] },
             { label: 'Nuevos',    valor: salio[:nuevos] }],
      secciones: [
        {
          titulo: 'A quién',
          headers: ['Paciente', 'DNI', 'Entregas', 'Flor seca (g)', 'Otros', 'Genéticas', 'Última entrega'],
          rows: datos[:pacientes].map { |r|
            [r[:paciente], r[:dni].presence || '—', r[:entregas], r[:flor_seca_g],
             otros.call(r[:otros]), r[:geneticas].join(', ').presence || '—', fmt_fecha(r[:ultima_fecha])]
          },
          formatos: [:texto, :texto, :numero, :numero, :texto, :texto, :texto],
          totales: [2, 3],
          aligns: { 2 => :right, 3 => :right },
          # El documento completo no se puede partir en dos líneas: este informe se presenta.
          col_min: { 1 => 62, 2 => 60, 3 => 60, 4 => 88, 5 => 96, 6 => 68 },
          vacio: 'No se dispensó nada en el período elegido.',
        },
        {
          titulo: 'Lo que salió, comparado con el período anterior',
          headers: ['', 'Este período', 'Anterior', 'Variación'],
          rows: salio[:por_unidad].map { |x| [FORMAS_UNIDAD[x[:unidad]] || x[:unidad], fmt_u.call(x[:cantidad], x[:unidad]), x[:anterior] ? fmt_u.call(x[:anterior], x[:unidad]) : '—', fmt_var.call(x[:variacion])] } +
                [['Entregas', salio[:entregas][:valor], salio[:entregas][:anterior], fmt_var.call(salio[:entregas][:variacion])],
                 ['Pacientes', salio[:pacientes][:valor], salio[:pacientes][:anterior], '—'],
                 (salio[:regalos_entregas].positive? ? ['De eso, regalos', "#{unidades.call(salio[:regalos])} en #{salio[:regalos_entregas]} #{salio[:regalos_entregas] == 1 ? 'entrega' : 'entregas'}", '', ''] : nil)].compact,
          aligns: { 1 => :right, 2 => :right, 3 => :right },
          col_min: { 1 => 110, 2 => 70, 3 => 100 },
        },
        {
          titulo: 'Por producto',
          headers: ['Producto', 'Genética', 'Entregas', 'Cantidad', 'Pacientes', 'vs. anterior'],
          rows: datos[:productos].flat_map { |f|
            [[f[:forma].to_s.tr('_', ' ').capitalize, 'Todas', f[:entregas], fmt_u.call(f[:cantidad], f[:unidad]), f[:pacientes], '']] +
              f[:geneticas].map { |g| ['', g[:genetica], g[:entregas], fmt_u.call(g[:cantidad], f[:unidad]), g[:pacientes], fmt_var.call(g[:variacion])] }
          },
          aligns: { 2 => :right, 3 => :right, 4 => :right, 5 => :right },
          col_min: { 1 => 110, 2 => 60, 3 => 60, 4 => 64, 5 => 70 },
          vacio: 'No se dispensó nada en el período elegido.',
        },
        {
          titulo: 'Por dónde',
          headers: ['Canal', 'Entregas', 'Flor seca (g)', 'Otros', 'Pacientes'],
          rows: datos[:canales].map { |c|
            [c[:sin_llegar].to_i.positive? ? "#{c[:canal]} (#{c[:sin_llegar]} sin llegar todavía)" : c[:canal],
             c[:entregas], c[:flor_seca_g], otros.call(c[:otros]), c[:pacientes]]
          },
          aligns: { 1 => :right, 2 => :right, 4 => :right },
          col_min: { 1 => 60, 2 => 60, 3 => 130, 4 => 64 },
          vacio: 'No se dispensó nada en el período elegido.',
        },
      ],
      nota: 'Contiene datos personales de pacientes: tratar como información sensible.',
    )
  end

  # Cómo salió, cómo viene y qué dice la genética. El cálculo vive en `Informes::PlanVsReal`.
  def plan_vs_real
    club = current_user.club
    desde, hasta = periodo_rango
    datos = Informes::PlanVsReal.new(club: club, desde: desde, hasta: hasta).call
    sa = datos[:salio]

    pct  = ->(v) { v.nil? ? '—' : "#{v.positive? ? '+' : ''}#{v} %" }
    dias = ->(plan, real) { "#{plan || '—'} / #{real || '—'}" }
    g    = ->(v) { v.nil? ? '—' : ActiveSupport::NumberHelper.number_to_delimited(v.round(1).to_s.sub(/\.0\z/, ''), delimiter: '.', separator: ',') }

    responder_informe(
      titulo: 'Plan vs. real', nombre: 'informe_plan_vs_real', datos: datos,
      resena: 'Qué se propuso cada lote y qué consiguió, en gramos y en días: los lotes cosechados en el período contra su plan, los que están en cultivo contra su plan hasta hoy, y lo que rinde cada genética de verdad contra lo que dice su ficha.',
      periodo: etiqueta_periodo(desde, hasta),
      kpis: [
        { label: 'Gramos, contra el plan', valor: pct.call(sa[:gramos][:desvio_pct]), tono: sa[:gramos][:desvio_pct] && sa[:gramos][:desvio_pct] < -Informes::PlanVsReal::TOLERANCIA_GRAMOS_PCT ? :warn : :ok },
        { label: 'Floración plan / real', valor: dias.call(sa[:floracion][:plan], sa[:floracion][:real]) },
        { label: 'g / planta plan / real', valor: dias.call(g.call(sa[:gramos_por_planta][:plan]), g.call(sa[:gramos_por_planta][:real])) },
        { label: 'Cumplieron el plan', valor: "#{sa[:cumplieron]} de #{sa[:evaluables]}" },
      ],
      secciones: [
        {
          titulo: 'Cómo salió',
          headers: ['Lote', 'Genética', 'Plantas', 'g plan', 'g real', 'g/planta', 'Vege plan / real', 'Flora plan / real', 'Veredicto'],
          rows: sa[:lotes].map { |l| [l[:codigo], l[:genetica] || '—', l[:plantas], g.call(l[:g_plan]), g.call(l[:g_real]), g.call(l[:g_por_planta]), dias.call(l[:vege_plan], l[:vege_real]), dias.call(l[:flora_plan], l[:flora_real]), l[:veredicto]] },
          aligns: { 2 => :right, 3 => :right, 4 => :right, 5 => :right, 6 => :right, 7 => :right },
          col_min: { 2 => 46, 6 => 60, 7 => 60, 8 => 110 },
          vacio: 'No se cosechó ningún lote en el período elegido.',
        },
        {
          titulo: 'Cómo viene',
          headers: ['Lote', 'Genética', 'Etapa', 'Días plan / hoy', 'Cosecha planeada', 'Cómo viene'],
          rows: datos[:viene].map { |l| [l[:codigo], l[:genetica] || '—', l[:estado].to_s.tr('_', ' ').capitalize, dias.call(l[:dias_plan], l[:dias_hoy]), fmt_fecha(l[:cosecha_planeada]), l[:como_viene]] },
          aligns: { 3 => :right },
          col_min: { 3 => 70, 4 => 70, 5 => 120 },
          vacio: 'No hay lotes en cultivo.',
        },
        {
          titulo: 'Qué dice la genética',
          headers: ['Genética', 'Lotes cerrados', 'g/planta ficha', 'g/planta real', 'Floración ficha / real', ''],
          rows: datos[:geneticas].map { |x| [x[:genetica], x[:lotes], x[:g_por_planta_ficha] || '—', g.call(x[:g_por_planta_real]), dias.call(x[:floracion_ficha], x[:floracion_real]), x[:frase]] },
          aligns: { 1 => :right, 2 => :right, 3 => :right, 4 => :right },
          col_min: { 1 => 56, 2 => 60, 3 => 60, 4 => 80, 5 => 130 },
          vacio: 'Todavía no hay lotes cerrados con rendimiento.',
        },
      ],
    )
  end

  # INASE — Registro de variedades de la organización + trazabilidad a producción.
  # Liga cada genética (con su dato INASE) con lo que realmente produjo: lotes,
  # plantas y gramos. Es el informe regulatorio de variedades cultivadas.
  # Qué se perdió, y por qué. Ningún informe lo decía: producción cuenta lo que salió bien y
  # trazabilidad cierra el balance de UN producto, pero la organización no tenía dónde ver cuánto se
  # cayó en total. Para quien audita es de lo primero que se pregunta; para el dueño es plata.
  # Dos preguntas del período: qué no llegó a cosecha y qué se perdió después, cada cosa por
  # unidad y con lo que costó producirla. El cálculo vive en `Informes::Perdidas`.
  def perdidas
    club = current_user.club
    desde, hasta = periodo_rango
    datos = Informes::Perdidas.new(club: club, desde: desde, hasta: hasta).call
    pl = datos[:plantas]
    pr = datos[:producto]

    fmt_u   = ->(c, u) { "#{ActiveSupport::NumberHelper.number_to_delimited(c.to_f.round(1).to_s.sub(/\.0\z/, ''), delimiter: '.', separator: ',')} #{u}" }
    fmt_ars = ->(v) { v.nil? ? '—' : "$ #{ActiveSupport::NumberHelper.number_to_delimited(v.round, delimiter: '.', separator: ',')}" }
    motivo_label = ->(m) { m.to_s.tr('_', ' ').capitalize }

    responder_informe(
      titulo: 'Informe de pérdidas', nombre: 'informe_perdidas',
      resena: 'Qué se perdió la organización en el período y por qué: las plantas que no llegaron a cosecha, ' \
              'con su motivo y su lote, y el producto que salió del inventario sin entregarse —merma declarada ' \
              'y diferencias de conteo del mostrador, neteadas por cierre—. Cada cosa en su unidad, con lo que ' \
              'costó producirla al lado.',
      datos: datos, periodo: etiqueta_periodo(desde, hasta),
      kpis: [{ label: 'Plantas descartadas', valor: pl[:total], tono: pl[:total].positive? ? :warn : :ok },
             { label: 'Producirlas costó', valor: fmt_ars.call(pl[:costo_ars]) }] +
            pr[:por_unidad].map { |x| { label: "Producto perdido, #{FORMAS_UNIDAD[x[:unidad]]&.downcase || x[:unidad]}", valor: fmt_u.call(x[:cantidad], x[:unidad]), tono: :warn } } +
            [{ label: 'Producirlo costó', valor: fmt_ars.call(pr[:costo_ars]) }],
      secciones: [
        {
          titulo: 'Lo que no llegó a cosecha, por motivo',
          headers: ['Motivo', 'Plantas', 'Lotes', 'Última'],
          rows: pl[:por_motivo].map { |m| [motivo_label.call(m[:motivo]), m[:plantas], m[:lotes].map { |l| "#{l[:codigo]}#{l[:plantas] > 1 ? " (#{l[:plantas]})" : ''}" }.join(', '), fmt_fecha(m[:ultima])] },
          formatos: [:texto, :numero, :texto, :texto],
          totales: [1],
          aligns: { 1 => :right },
          col_min: { 1 => 60, 3 => 68 },
          vacio: 'No se descartó ninguna planta en el período.',
        },
        {
          titulo: 'Planta por planta',
          headers: ['Fecha', 'Lote', 'Planta', 'Genética', 'Motivo', 'Costó'],
          rows: pl[:lista].map { |p| [fmt_fecha(p[:fecha]) + (p[:fecha_estimada] ? ' (aprox.)' : ''), p[:lote], p[:nombre], p[:genetica] || '—', motivo_label.call(p[:motivo]), fmt_ars.call(p[:costo_ars])] },
          aligns: { 5 => :right },
          col_min: { 0 => 80, 5 => 70 },
          vacio: 'No se descartó ninguna planta en el período.',
        },
        {
          titulo: 'Lo que se perdió después',
          headers: ['Fecha', 'Frasco', 'Qué pasó', 'Cantidad', 'Costó'],
          rows: pr[:lista].map { |f| [fmt_fecha(f[:fecha]), [f[:frasco], f[:genetica]].compact.join(' · '), [f[:que_paso], f[:detalle]].compact.join(' · «') + (f[:detalle] ? '»' : ''), fmt_u.call(f[:cantidad], f[:unidad]), fmt_ars.call(f[:costo_ars])] },
          aligns: { 3 => :right, 4 => :right },
          col_min: { 0 => 68, 3 => 64, 4 => 70 },
          vacio: 'No se perdió producto en el período.',
        },
      ],
    )
  end

  def inase
    club  = current_user.club
    lotes = club.lotes

    # Qué genéticas se declaran: las que la organización TIENE, más las que archivó pero llegó a
    # cultivar.
    #
    # Leía `club.geneticas` a secas y listaba también las archivadas —"eliminar" una genética es
    # `activa: false`, no un borrado—, así que el informe declaraba ante el organismo variedades
    # que la organización ya no trabaja. Filtrar sólo por activas sería el error opuesto: lo que
    # se cultivó en el período hay que declararlo aunque después se haya archivado, o el informe
    # deja de cuadrar contra las plantas y los gramos que sí figuran.
    cultivadas = lotes.where.not(genetica_id: nil).distinct.pluck(:genetica_id)
    geneticas  = club.geneticas.where(activa: true)
                     .or(club.geneticas.where(id: cultivadas))
                     .order(:nombre)

    lotes_por_gen   = lotes.group(:genetica_id).count
    plantas_por_gen = lotes.group(:genetica_id).sum(:plants_count)
    gramos_por_gen  = lotes.where.not(rendimiento_real_g: nil).group(:genetica_id).sum(:rendimiento_real_g)

    filas = geneticas.includes(:declarada_como).map do |g|
      {
        id:                    g.id,
        # `nombre` es el que usa la organización puertas adentro; `nombre_declarado` es el que se
        # presenta ante el organismo. Un club cultiva "Northern Lights" y la declara contra
        # una variedad inscripta: el informe tiene que decir la inscripta.
        nombre:                g.nombre_declarado,
        nombre_propio:         g.nombre,
        declarada:             g.declarada_como.present?,
        acreditada:            g.acreditada_inase?,
        tipo:                  g.tipo,
        registrada_inase:      g.registrada_inase,
        numero_registro_inase: g.numero_inase_declarado,
        categoria_inase:       g.categoria_inase,
        fecha_registro_inase:  g.fecha_registro_inase,
        criador:               g.criador,
        # El del criador de la VARIEDAD contra la que acredita, que es el que va al informe: si
        # el club cultiva "Amarillo" y lo declara como TROPICANA WFC, el obtentor es el de
        # Tropicana, no el que le puso el nombre de fantasía.
        criador_variedad:      (g.declarada_como&.criador || g.criador),
        thc:                   g.thc&.to_f,
        cbd:                   g.cbd&.to_f,
        lotes:                 lotes_por_gen[g.id] || 0,
        plantas:               plantas_por_gen[g.id].to_i,
        gramos_producidos:     (gramos_por_gen[g.id] || 0).to_f.round(1),
      }
    end

    # Lo que le falta a la organización: lo que cultiva sin poder acreditarlo, ni por registro propio
    # ni por declaración. Es la única fila accionable del informe.
    pendientes  = filas.reject { |f| f[:acreditada] }

    # UNA FILA POR VARIEDAD ACREDITABLE, no por genética de la organización. Si veinte genéticas
    # propias se declaran contra TROPICANA WFC, listarlas por separado da veinte filas con el
    # mismo nombre —parece un error de datos— y al organismo le importa cuánto se cultivó de esa
    # variedad, no cómo la llama la organización puertas adentro.
    #
    # Por eso mismo los nombres propios NO viajan: este informe se presenta ante el INASE, y cómo
    # la organización llama a sus genéticas es asunto suyo. La traducción se audita en la pantalla
    # de Genéticas, que es donde se declara cada una.
    #
    # Y se agrupan sólo las ACREDITADAS: una genética sin declarar no es una variedad, y entraba
    # igual a la tabla haciéndose pasar por una (su `nombre_declarado` cae en su propio nombre).
    # Las que no se pueden acreditar tienen su propia sección, que es la accionable.
    agrupadas = filas.select { |f| f[:acreditada] }
                     .group_by { |g| g[:nombre] }.map do |nombre, gs|
      {
        nombre:   nombre,
        # Quién obtuvo la variedad. Es dato del registro del INASE —a diferencia del "N° de
        # registro", que no existe— y es lo que permite identificarla sin ambigüedad ante el
        # organismo. Sale de la variedad ACREDITANTE, no de la genética del club.
        criador:  gs.filter_map { |g| g[:criador_variedad] }.first,
        lotes:    gs.sum { |g| g[:lotes] },
        plantas:  gs.sum { |g| g[:plantas] },
        gramos:   gs.sum { |g| g[:gramos_producidos] }.round(1),
      }
    end.sort_by { |g| g[:nombre].to_s }

    # LOS KPIs VAN EN LA MISMA UNIDAD QUE LA TABLA: la variedad acreditable.
    #
    # Contaban genéticas propias mientras la tabla agrupaba por variedad, así que un club con 24
    # genéticas declaradas contra TROPICANA WFC leía "24 genéticas" arriba de UNA sola fila. Dos
    # unidades distintas en la misma pantalla, y ninguna manera de saber cuál mirar.
    #
    # `sin_acreditar` es la excepción y va en genéticas propias a propósito: son justamente las
    # que NO son una variedad todavía, y tienen su propia sección abajo.
    datos = {
      total_variedades: agrupadas.size,
      sin_acreditar:    pendientes.size,
      gramos_totales:   agrupadas.sum { |v| v[:gramos] }.round(1),
      lotes_totales:    agrupadas.sum { |v| v[:lotes] },
      geneticas:        filas,
      agrupadas:        agrupadas,
      pendientes:       pendientes,
    }

    secciones = [{
      titulo: 'Variedades cultivadas',
      headers: ['Variedad', 'Obtentor', 'Lotes', 'Plantas', 'Gramos'],
      rows: agrupadas.map { |g| [g[:nombre], g[:criador].presence || '—', g[:lotes], g[:plantas], g[:gramos]] },
      formatos: [:texto, :texto, :numero, :numero, :numero],
      totales: [2, 3, 4],
      aligns: { 2 => :right, 3 => :right, 4 => :right },
    }]

    if pendientes.any?
      secciones << {
        titulo: 'Sin acreditar — hay que declararlas contra una variedad inscripta',
        headers: ['Variedad', 'Lotes', 'Plantas'],
        rows: pendientes.map { |g| [g[:nombre_propio], g[:lotes], g[:plantas]] },
        formatos: [:texto, :numero, :numero],
        aligns: { 1 => :right, 2 => :right },
      }
    end

    responder_informe(
      titulo: 'Informe INASE — variedades', nombre: 'informe_inase', datos: datos,
      resena: 'Las variedades del registro INASE con las que la organización acredita lo que cultiva, y cuánto produjo de cada una. Una fila por variedad. Al pie, lo que todavía no se puede acreditar.',
      kpis: [
        { label: 'Variedades',    valor: datos[:total_variedades] },
        { label: 'Sin acreditar', valor: pendientes.size, tono: pendientes.any? ? :warn : :ok },
        { label: 'Lotes',         valor: datos[:lotes_totales] },
      ],
      secciones: secciones,
      nota: 'Cada variedad de esta tabla acredita una o más genéticas de la organización. Con qué ' \
            'nombre las cultiva puertas adentro es asunto suyo y no se informa acá: el par se ' \
            'audita en la pantalla de Genéticas. La variedad se identifica por su NOMBRE en el ' \
            'Catálogo Nacional de Cultivares — el INASE no asigna un número por variedad.',
      # La pantalla se abre siempre —es la que lista los pendientes—; el archivo que se
      # presenta ante el organismo, no, mientras haya variedades sin acreditar.
      exige_declaracion_inase: true,
    )
  end

  private

  # Gramos producidos en el período, opcionalmente acotados a un estado de lote.
  #
  # La fuente es `lotes.rendimiento_real_g`: el peso que deja el cierre de manicura. La fecha
  # del lote es la de su paso a CURADO —el momento en que el producto existe— y si ese evento
  # falta se cae a `updated_at`. Antes esto salía de la tabla `pesadas`, que el flujo real no
  # llena, y el informe decía "0 gramos" con veinte lotes curados.
  # Datos del informe REPROCANN — compartidos por la respuesta JSON y el PDF
  def reprocann_data(club, desde: nil, hasta: nil)
    desde ||= Time.zone.today.beginning_of_month.beginning_of_day
    hasta ||= Time.zone.today.end_of_month.end_of_day
    servicio = Informes::Reprocann.new(club: club, desde: desde, hasta: hasta)
    # Este informe le habla AL ORGANISMO: declara la población registrada en REPROCANN. Por eso
    # sólo entran los pacientes que tienen registro —vigente, vencido o en trámite—. Que existan
    # pacientes sin REPROCANN es un pendiente interno de la organización, no algo que se presenta: eso se
    # gestiona desde Pacientes, donde además se puede hacer algo al respecto.
    #
    # Antes entraban todos, así que el total del informe no coincidía con nada y la tasa de
    # cumplimiento se calculaba contra una población que incluía a quienes ni siquiera iniciaron
    # el trámite.
    activos   = Paciente.for_club(club.id).where(es_paciente: true)
    # "Tiene registro" = tiene número, o su estado dice algo distinto de `sin_registro` (que es
    # el default de la columna: el paciente que nunca inició el trámite).
    pacientes = activos.where.not(reprocann_numero: [nil, ''])
                       .or(activos.where.not(reprocann_estado: [nil, '', 'sin_registro']))

    # Los que quedaron afuera se informan como un pendiente, con su número, no escondidos.
    sin_registro = activos.count - pacientes.count

    # Una sola clasificación para todo: los conteos son el histograma de la misma
    # categoría que se muestra en la lista, así el total cierra siempre.
    conteos = Hash.new(0)
    pacientes.pluck(:reprocann_estado, :reprocann_numero, :reprocann_vencimiento).each do |e, n, v|
      conteos[Paciente.reprocann_categoria(estado: e, numero: n, vencimiento: v)] += 1
    end

    # COMPLETA: el archivo lleva a todos; la pantalla lista 200 y dice cuántos más.
    lista = pacientes.map do |p|
      {
        # Nombre completo y los últimos TRES del documento: este informe se presenta ante la
        # autoridad, que necesita saber de quién se habla. Las iniciales sirven para un
        # tablero interno, no para acreditar una nómina.
        nombre_completo:       p.nombre_completo,
        iniciales:             "#{p.nombre[0]}.#{p.apellido[0]}.",
        # Completo para el PDF y el Excel; `sin_dni_completo` lo saca del JSON de la pantalla.
        dni:                   p.dni_normalizado.to_s,
        dni_ultimos_3:         p.dni_normalizado.to_s.last(3),
        dni_ultimos_4:         p.dni_normalizado.to_s.last(4),
        reprocann_estado:      p.reprocann_categoria,
        reprocann_vencimiento: p.reprocann_vencimiento,
      }
    end

    {
      total_pacientes:        conteos.values.sum,
      con_reprocann_vigente:  conteos['vigente'],
      vencen_30d:             conteos['por_vencer'],
      vencidos:               conteos['vencido'],
      pendientes:             conteos['pendiente'],
      sin_reprocann:          conteos['sin_reprocann'],
      lista_anonimizada:      lista,
      # Sin corte por sede: un PACIENTE NO TIENE SEDE — es de la organización. Lo que había agrupaba por
      # la sede de su última dispensación, una dimensión inventada que además dejaba a los que
      # nunca dispensaron en una fila fantasma. La actividad por sede es otra pregunta y vive
      # en el informe de dispensaciones.
      pacientes_sin_registro: sin_registro,
      periodo:                etiqueta_periodo(desde, hasta),
      # Del PERÍODO, por línea y por unidad, y «sin vigente» juzgado el día de la entrega.
      dispensaciones:         servicio.dispensaciones,
      # Lo que hay que hacer, con nombre: la parte del admin. No va al PDF que se presenta.
      lista_pendientes:       servicio.pendientes,
      pendientes_resumen:     servicio.resumen_pendientes(servicio.pendientes),
      # El informe de Cumplimiento era esto mismo con otro título: sus cuatro KPIs salían de
      # los conteos que ya se calculan acá arriba. Vive adentro de REPROCANN, que es de lo que
      # habla.
      cumplimiento:           cumplimiento_data(club, conteos),
    }
  end

  # Tasa de cumplimiento y alertas de la población de pacientes. Recibe los conteos ya hechos
  # por `reprocann_data` para no recorrer dos veces lo mismo.
  def cumplimiento_data(club, conteos)
    total     = conteos.values.sum
    vigente   = conteos['vigente']
    por_vencer = conteos['por_vencer']
    vencidos  = conteos['vencido']
    sin_seg   = Paciente.for_club(club.id).where(es_paciente: true, con_seguimiento_medico: false).count

    # Quien vence en 20 días HOY está en regla: cuenta como cumplimiento, aunque tenga alerta.
    en_regla = vigente + por_vencer
    tasa = total.positive? ? ((en_regla.to_f / total) * 100).round(1) : 0

    alertas = []
    alertas << { severidad: 'error',   detalle: "#{vencidos} pacientes con REPROCANN vencido" } if vencidos > 0
    alertas << { severidad: 'warning', detalle: "#{por_vencer} pacientes vencen en ≤30 días" }  if por_vencer > 0
    alertas << { severidad: 'warning', detalle: "#{sin_seg} pacientes sin seguimiento médico" } if sin_seg > 0

    { tasa: tasa, en_regla: en_regla, sin_seguimiento_medico: sin_seg, alertas: alertas }
  end

  # Actividad de dispensación de la población informada. Es lo que le da sentido al informe:
  # no alcanza con decir cuántos pacientes hay en regla, importa a quién se le entregó y si
  # tenía el certificado al día. Nada de cultivo: eso vive en los informes de Producción.
  # Pacientes por sede de atención. El paciente NO tiene sede propia: se atiende donde
  # dispensa, así que la sede sale de sus dispensaciones (la más reciente manda, porque
  # alguien que se mudó de sede cuenta en la que se atiende hoy).
  #
  # Es lo único no-clínico que el informe agrega más allá de los pacientes: nada de cultivo,
  # que vive en los informes de Producción y Sedes.
  # Se perdió al sacar el corte por sede (estaba en ese rango de líneas) y la exportación a
  # Excel del informe REPROCANN se caía con NameError.
  ESTADO_REPROCANN_LABEL = {
    'vigente'                 => 'Vigente',
    'vigente_sin_vencimiento' => 'Vigente sin vencimiento',
    'por_vencer'              => 'Por vencer (hasta 30 días)',
    'vencido'                 => 'Vencido',
    'pendiente'               => 'Pendiente de aprobación',
    'sin_reprocann'           => 'Sin REPROCANN',
  }.freeze

  def reprocann_xlsx(club, data)
    rows = (data[:lista_anonimizada] || []).map do |p|
      venc = p[:reprocann_vencimiento].present? ? Date.parse(p[:reprocann_vencimiento].to_s).strftime('%d/%m/%Y') : '—'
      [
        p[:nombre_completo].presence || p[:iniciales].to_s,
        p[:dni].presence || '—',
        ESTADO_REPROCANN_LABEL[p[:reprocann_estado].to_s] || p[:reprocann_estado].to_s,
        venc,
      ]
    end
    XlsxExport.new(
      club:    club,
      titulo:  'Informe REPROCANN',
      headers: ['Paciente', 'DNI', 'Estado', 'Vencimiento'],
      rows:    rows,
      anchos:  [14, 16, 28, 16],
    ).render
  end

  # Rótulo legible del período, para el encabezado del PDF y del Excel.
  def etiqueta_periodo(desde, hasta)
    return nil if desde.blank? || hasta.blank?
    "#{desde.strftime('%d/%m/%Y')} — #{hasta.strftime('%d/%m/%Y')}"
  end

  def fmt_fecha(f)
    return '—' if f.blank?
    (f.is_a?(String) ? Date.parse(f) : f).strftime('%d/%m/%Y')
  rescue ArgumentError
    f.to_s
  end

  # El borde de arriba llega hasta el FINAL del día, no hasta su medianoche.
  #
  # `end_of_month` devuelve una Date, y `where(created_at: desde..hasta)` la compara como
  # `<= '2026-08-31 00:00:00'`: todo lo que pasó ESE día quedaba afuera. Durante el mes no se
  # nota porque el borde está en el futuro; el día 31 el informe pierde la jornada entera — que
  # es justo el día en que alguien cierra el mes y lo mira.
  #
  # Los cuatro informes que usan este rango filtran por `created_at`/`updated_at`, así que el
  # arreglo va acá y no en cada query.
  # Saca el DNI completo de lo que se manda al navegador. La pantalla usa `dni_ultimos_3`.
  def sin_dni_completo(data)
    lista = data[:lista_anonimizada] || []
    pend  = data[:lista_pendientes] || []
    data.merge(
      lista_anonimizada: lista.first(Informes::Reprocann::LISTA_PANTALLA).map { |p| p.except(:dni) },
      lista_omitidos:    [lista.size - Informes::Reprocann::LISTA_PANTALLA, 0].max,
      lista_pendientes:  pend.map { |p| p.except(:dni) },
    )
  end

  # Los cuatro períodos de siempre, o un rango a elección (`desde`/`hasta`): «del 1 al 15» es lo
  # que pide un auditor. Vale para todos los informes que pasan por acá. Un rango dado vuelta se
  # endereza; sin `hasta`, hasta hoy.
  def periodo_rango
    if params[:desde].present?
      desde = Date.parse(params[:desde].to_s)
      hasta = params[:hasta].present? ? Date.parse(params[:hasta].to_s) : Time.zone.today
      desde, hasta = hasta, desde if hasta < desde
      return [desde.beginning_of_day, hasta.end_of_day]
    end

    periodo = params[:periodo].presence_in(PERIODO_RANGOS.keys) || 'mes_actual'
    desde, hasta = PERIODO_RANGOS[periodo].call
    [desde.to_date.beginning_of_day, hasta.to_date.end_of_day]
  rescue Date::Error
    desde, hasta = PERIODO_RANGOS['mes_actual'].call
    [desde.to_date.beginning_of_day, hasta.to_date.end_of_day]
  end

  def require_auditor_o_admin!
    unless current_user&.admin? || current_user&.auditor?
      render json: { error: 'No autorizado' }, status: :forbidden
    end
  end
end
