module Lotes
  # ¿QUÉ RECIBIÓ ESTE LOTE? (29-sep-2026). Cada aplicación de nutrientes con sus productos y
  # cantidades, y los totales: por producto, por fase, EC/pH, plata. Es la fuente única de la
  # sección «Nutrición» de la ficha, del historial, de la trazabilidad y de la comparativa entre
  # lotes (`Analitica::Nutricion`): nadie más suma lo que recibió un lote.
  #
  # Reglas:
  # - La cantidad es la APLICADA (lo que dice la copia del registro), no la descontada: un producto
  #   que no salió del depósito igual se aplicó (o no: la app no lo sabe) y lleva su `motivo`.
  # - Lo compartido se cuenta por la PARTE del lote: una sala regada con 3 lotes le da un tercio a
  #   cada uno; lo que se le pone a una cama, por los m² de cada lote. Es el mismo reparto que el
  #   costo (`Insumo.partes_de`) y viaja en la copia; las copias viejas sin `parte` se reparten
  #   con la misma regla.
  # - Lo que se cargó como texto (la fertilización «sin especificar», las actividades viejas del
  #   historial) entra marcado `sin_cantidades`: no se inventa ningún número.
  # - Los `litros` son los de la solución preparada (la receta). El AGUA es otra cosa: todo lo que
  #   se regó, con o sin nutrientes (`volumen_l`, desde el 29-sep-2026; lo viejo se recupera del
  #   texto con `rake riegos:volumen_desde_texto`). Un riego sin volumen cargado no suma agua.
  class Nutricion
    FASE_CORTA = { 'enraizado' => 'E', 'vegetativo' => 'V', 'floracion' => 'F', 'cosecha' => 'C',
                   'en_manicura' => 'M', 'curado' => 'Cu' }.freeze
    MOTIVO_LABELS = {
      'sin_en_sede' => 'no había en esta sede', 'sin_stock' => 'no alcanzó el stock',
      'no_descontar' => 'se eligió no descontarlo', 'sin_descontar' => 'no se descontó',
    }.freeze

    COSTOS = %i[costo_ars costo_por_planta costo_por_gramo].freeze

    # `con_costo: false`: sin plata (quien no administra ve lo aplicado, no lo que costó).
    def initialize(lote, con_costo: true)
      @lote = lote
      @con_costo = con_costo
    end

    def call
      apps = (de_registros + de_cama + de_actividades).sort_by { |a| a[:fecha] }
      res = {
        lote_id:      lote.id,
        codigo:       lote.codigo,
        plantas:      plantas,
        con_costo:    @con_costo,
        aplicaciones: apps.reverse,
        totales:      totales(apps),
        por_fase:     por_fase(apps),
        por_semana:   por_semana,
      }
      @con_costo ? res : sin_costo(res)
    end

    # Lo aplicado de un producto, dicho en una línea: «Bio-Grow 40 ml (sin descontar: no había en
    # esta sede)». La usa el chip del historial.
    def self.linea_producto(p)
      txt = "#{p[:nombre]} #{num(p[:cantidad])} #{UNIDAD_CORTA[p[:unidad]] || p[:unidad]}"
      p[:motivo] ? "#{txt} (sin descontar: #{MOTIVO_LABELS[p[:motivo]]})" : txt
    end

    UNIDAD_CORTA = { 'mililitro' => 'ml', 'litro' => 'L', 'gramo' => 'g', 'kilogramo' => 'kg', 'unidad' => 'u' }.freeze

    def self.num(v)
      f = v.to_f.round(2)
      f == f.to_i ? f.to_i.to_s : f.to_s.sub('.', ',')
    end

    # Para el historial: la parte del lote en UNA copia de un registro suyo, y sus productos.
    def parte_de_copia(n, lote_id) = parte_en(n, lote_id, cama: false)

    def productos_de_copia(n, lote_id)
      parte = parte_de_copia(n, lote_id)
      Array(n['items']).map { |i| producto(i, parte) }
    end

    private

    attr_reader :lote

    def plantas = (lote.plants_count_cosechadas || lote.plants_count).to_i

    # ── Aplicaciones ───────────────────────────────────────────────────────────

    # Riegos del lote (el suyo, el de la sala, el de la cama) y la fertilización sin especificar.
    def de_registros
      registros.filter_map do |r|
        n = r.nutricion.presence
        next nil unless n || r.fertilizacion
        base = { fecha: r.registrado_en, fuente: 'registro', id: r.id, **cuando(r.registrado_en),
                 ec: r.ec&.to_f, ph: r.ph&.to_f }
        if n
          parte = parte_en(n, lote.id, cama: false)
          base.merge(origen: origen_de(n), titulo: n['receta_nombre'] || 'Productos sueltos',
                     receta_id: n['receta_id'], parte: parte.to_f.round(4),
                     litros: (n['litros'].to_f * parte).round(2),
                     ec_objetivo: n['ec_objetivo'], ph_objetivo: n['ph_objetivo'],
                     costo_ars: (n['costo_ars'].to_f * parte).round(2),
                     productos: Array(n['items']).map { |i| producto(i, parte) },
                     sin_cantidades: false)
        else
          base.merge(origen: 'lote', titulo: 'Fertilización', texto: r.notas_fertilizacion.presence,
                     productos: [], costo_ars: 0.0, litros: nil, sin_cantidades: true)
        end
      end
    end

    # Lo que se le puso a la cama mientras el lote estaba en ella (top dress, té al suelo…), por
    # la parte del lote (sus m²). Sólo lo que le costó a este lote: la mezcla de armado de antes
    # de plantar no es suya.
    def de_cama
      return [] unless lote.cama_ciclo_id
      CamaRegistro.where(cama_ciclo_id: lote.cama_ciclo_id).where.not(nutricion: nil).includes(:cama).filter_map do |cr|
        n = cr.nutricion.to_h
        next nil unless Array(n['lotes']).any? { |x| x['id'] == lote.id }
        parte = parte_en(n, lote.id, cama: true)
        { fecha: cr.registrado_en, fuente: 'cama', id: cr.id, **cuando(cr.registrado_en),
          origen: 'cama', titulo: "#{CamaRegistro::TIPO_LABELS[cr.tipo] || cr.tipo} · #{cr.cama&.nombre}",
          receta_id: n['receta_id'], receta_nombre: n['receta_nombre'], parte: parte.to_f.round(4),
          litros: nil, ec: nil, ph: nil,
          costo_ars: (n['costo_ars'].to_f * parte).round(2),
          productos: Array(n['items']).map { |i| producto(i, parte) }, sin_cantidades: false }
      end
    end

    # Las fertilizaciones que se cargaron por el formulario viejo del historial (texto y EC):
    # desde el 29-sep esa puerta abre el registro de riego, pero lo cargado antes se ve igual.
    def de_actividades
      lote.lote_eventos.select { |e| e.tipo == 'actividad' && e.categoria == 'fertilizacion' }.map do |e|
        m = e.metadata.to_h
        { fecha: e.registrado_en, fuente: 'actividad', id: e.id, **cuando(e.registrado_en),
          origen: 'lote', titulo: 'Fertilización',
          texto: [m['producto'].presence, e.descripcion.presence].compact.join(' — ').presence,
          ec: m['ec']&.to_f, ph: nil, productos: [], costo_ars: 0.0, litros: nil, sin_cantidades: true }
      end
    end

    def registros = @registros ||= lote.registros_ambientales.order(:registrado_en).to_a

    def origen_de(n)
      Array(n['lotes']).size > 1 ? 'sala' : 'lote'
    end

    def producto(i, parte)
      falt = i['faltante'].to_f
      motivo = i['motivo'] || (falt.positive? ? (i['insumo_id'].nil? ? 'sin_en_sede' : 'sin_descontar') : nil)
      { nombre: i['nombre'], unidad: i['unidad'],
        cantidad: (i['cantidad'].to_f * parte).round(3),
        descontado: (i['descontado'].to_f * parte).round(3),
        dosis: i['dosis'], dosis_unidad: i['dosis_unidad'], motivo: motivo, motivo_label: MOTIVO_LABELS[motivo] }
    end

    # La parte del lote en una aplicación compartida. La copia nueva la trae; la vieja se reparte
    # con la misma regla que el costo: partes iguales en un riego, m² en la cama.
    def parte_en(n, lote_id, cama:)
      ls = Array(n['lotes'])
      return 1.0 if ls.size <= 1
      propia = ls.find { |x| x['id'] == lote_id }
      return propia['parte'].to_f if propia && propia['parte']
      ids = ls.map { |x| x['id'] }
      lotes = Lote.where(id: ids).to_a
      pesos = cama ? lotes.to_h { |l| [l.id, l.m2_ocupados.to_d] } : nil
      (Insumo.partes_de(lotes, pesos)[lote_id] || 0).to_f
    end

    # ── En qué fase y semana ───────────────────────────────────────────────────

    # La fase de ese día y la semana DENTRO de esa fase (V3, F2): así dos lotes se comparan
    # alineados al arranque de la floración, aunque hayan empezado en fechas distintas. Una
    # automática vive en vege todo el ciclo: V1… desde que va a maceta.
    def cuando(t)
      d = t.to_date
      fase = fase_en(d)
      desde = inicio_de(fase, d) || lote.start_date || d
      semana = [((d - desde).to_i / 7) + 1, 1].max
      { fase: fase, semana: semana, semana_label: "#{FASE_CORTA[fase] || fase}#{semana}" }
    end

    def cambios
      @cambios ||= lote.lote_eventos.select { |e| e.tipo == 'cambio_estado' && e.registrado_en }.sort_by(&:registrado_en)
    end

    def fase_en(d)
      return lote.estado if cambios.empty?
      ultimo = cambios.reverse.find { |e| e.registrado_en.to_date <= d }
      ultimo ? ultimo.estado_nuevo : (cambios.first.estado_anterior.presence || lote.estado)
    end

    # La última entrada a esa fase hasta ese día (un rebote por error no alarga la fase).
    def inicio_de(fase, d)
      cambios.select { |e| e.estado_nuevo == fase && e.registrado_en.to_date <= d }.max_by(&:registrado_en)&.registrado_en&.to_date
    end

    # ── Totales ────────────────────────────────────────────────────────────────

    def totales(apps)
      con = apps.reject { |a| a[:sin_cantidades] }
      litros = con.sum { |a| a[:litros].to_f }
      costo  = apps.sum { |a| a[:costo_ars].to_f }
      {
        aplicaciones:   apps.size,
        con_cantidades: con.size,
        sin_cantidades: apps.size - con.size,
        riegos:         registros.count { |r| Array(r.tareas_realizadas).include?('riego') },
        agua_l:         agua(registros),
        agua_por_planta: plantas.positive? && agua(registros) ? (agua(registros) / plantas).round(2) : nil,
        riegos_con_volumen: registros.count(&:volumen_l),
        litros:         litros.round(2),
        litros_por_planta: plantas.positive? ? (litros / plantas).round(2) : nil,
        costo_ars:      costo.round(2),
        costo_por_planta: plantas.positive? ? (costo / plantas).round(2) : nil,
        costo_por_gramo: lote.rendimiento_real_g.to_f.positive? ? (costo / lote.rendimiento_real_g.to_f).round(2) : nil,
        productos:      por_producto(con),
        ec:             promedio(registros.map { |r| r.ec&.to_f }),
        ph:             promedio(registros.map { |r| r.ph&.to_f }),
      }
    end

    # Cuánto de cada producto, sumando todas sus aplicaciones. Mismo nombre y unidad = mismo
    # producto (el criterio de `Insumo#equivalente_en`): el de dos sedes se suma junto.
    def por_producto(apps)
      apps.flat_map { |a| a[:productos] }
          .group_by { |p| [p[:nombre].to_s.strip.downcase, p[:unidad]] }
          .map do |(_, unidad), ps|
            cant = ps.sum { |p| p[:cantidad].to_f }
            { nombre: ps.first[:nombre].to_s.strip, unidad: unidad, veces: ps.size, cantidad: cant.round(3),
              por_planta: plantas.positive? ? (cant / plantas).round(3) : nil,
              sin_descontar: ps.sum { |p| p[:cantidad].to_f - p[:descontado].to_f }.round(3) }
          end
          .sort_by { |p| -p[:cantidad] }
    end

    def por_fase(apps)
      apps.group_by { |a| a[:fase] }.to_h do |fase, as|
        regs = registros.select { |r| fase_en(r.registrado_en.to_date) == fase }
        [fase, { aplicaciones: as.size, litros: as.sum { |a| a[:litros].to_f }.round(2),
                 agua_l: agua(regs),
                 costo_ars: as.sum { |a| a[:costo_ars].to_f }.round(2),
                 ec: promedio(regs.map { |r| r.ec&.to_f }), ph: promedio(regs.map { |r| r.ph&.to_f }),
                 productos: por_producto(as.reject { |a| a[:sin_cantidades] }) }]
      end
    end

    # La curva: EC y pH medidos por semana de fase (todas las mediciones del lote, no sólo las de
    # los riegos con receta), en el orden del ciclo.
    def por_semana
      orden = Lotes::Nutricion::FASE_CORTA.keys
      registros.select { |r| r.ec || r.ph || r.volumen_l }.group_by { |r| cuando(r.registrado_en).values_at(:fase, :semana) }
               .map { |(fase, semana), rs|
                 a = agua(rs)
                 { fase: fase, semana: semana, semana_label: "#{FASE_CORTA[fase] || fase}#{semana}",
                   ec: promedio(rs.map { |r| r.ec&.to_f }), ph: promedio(rs.map { |r| r.ph&.to_f }),
                   agua_l: a, agua_por_planta: a && plantas.positive? ? (a / plantas).round(2) : nil,
                   mediciones: rs.size }
               }
               .sort_by { |w| [orden.index(w[:fase]) || 99, w[:semana]] }
    end

    def sin_costo(obj)
      case obj
      when Hash  then obj.except(*COSTOS).transform_values { |v| sin_costo(v) }
      when Array then obj.map { |v| sin_costo(v) }
      else obj
      end
    end

    # Litros de agua de esos registros; nil si ninguno tiene el volumen cargado (no es «0 L»).
    def agua(regs)
      con = regs.select(&:volumen_l)
      con.any? ? con.sum { |r| r.volumen_l.to_f }.round(2) : nil
    end

    def promedio(vals)
      v = vals.compact.select(&:positive?)
      v.any? ? (v.sum / v.size).round(2) : nil
    end
  end
end
