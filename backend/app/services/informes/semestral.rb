module Informes
  # LA DECLARACIÓN JURADA SEMESTRAL es el documento que va ante la autoridad, y NO CALCULA NADA POR
  # SU CUENTA: compone los informes ya revisados con el semestre como período.
  #
  #   · Pacientes — la población del REPROCANN (`Informes::Reprocann`), AL CIERRE del semestre.
  #   · Cultivo   — lo cosechado en el semestre por variedad acreditada (`Informes::Inase`, que a su
  #                 vez usa `Informes::Produccion`), y lo en pie al cierre.
  #   · Entregas  — a esa población, por línea y por unidad (`Informes::Reprocann#dispensaciones`).
  #
  # Reemplaza a `InformeSemestralService`, que tenía su propia versión de cada cosa y todas con
  # las reglas viejas: otra población que el REPROCANN (sin `es_paciente`, sin filtrar registrados),
  # la vigencia contra HOY (el 1° semestre 2025 bajado hoy marcaba «vencido» a quien venció en agosto
  # de 2026), `sum(cantidad)` con la primera línea y sin excluir canceladas, la producción de este
  # momento en el informe de cualquier semestre, y una tabla lote por lote cuya condición excluía
  # el caso normal. Dos documentos al mismo organismo con dos totales distintos.
  #
  # UNA REGLA, UN LUGAR: el día que REPROCANN cambie de criterio, la declaración cambia sola.
  #
  # TODO AL CIERRE: para un semestre terminado, la fecha de corte es su último día; para el que
  # está en curso, hoy. Un semestre cerrado deja de cambiar.
  class Semestral
    def initialize(club:, anio:, semestre:)
      @club     = club
      @anio     = anio.to_i
      @semestre = semestre.to_i == 2 ? 2 : 1
      @desde    = (@semestre == 1 ? Date.new(@anio, 1, 1) : Date.new(@anio, 7, 1))
      @hasta    = (@semestre == 1 ? Date.new(@anio, 6, 30) : Date.new(@anio, 12, 31))
      @al       = [@hasta, Time.zone.today].min
    end

    attr_reader :desde, :hasta, :al

    def call
      reprocann = Reprocann.new(club: @club, desde: @desde.beginning_of_day, hasta: @hasta.end_of_day)
      inase     = Inase.new(club: @club, desde: @desde.beginning_of_day, hasta: @hasta.end_of_day).call

      {
        periodo:  { anio: @anio, semestre: @semestre, desde: @desde, hasta: @hasta, al: @al,
                    cerrado: @hasta < Time.zone.today },
        club:     establecimiento,
        pacientes: pacientes(reprocann),
        cultivo:  cultivo(inase),
        entregas: entregas(reprocann),
        # Lo que hay que declarar y no está vinculado al INASE: mismo aviso, misma salvedad y mismo
        # candado que el informe INASE — sobre lo que aparece en ESTE documento.
        sin_vincular:               inase[:sin_vincular],
        geneticas_sin_vincular_ids: inase[:geneticas_sin_vincular_ids],
        generado_en: Time.current,
      }
    end

    private

    def establecimiento
      {
        nombre:       @club.name,
        nombre_legal: @club.legal_name,
        email:        @club.email,
        telefono:     @club.phone,
        direccion:    @club.address,
        ciudad:       @club.city,
        provincia:    @club.state,
        pais:         @club.country,
        # La resolución que habilita a la organización, la que carga en Configuración. Estaba
        # escrita a mano en la pantalla mientras el campo existía y nadie lo leía.
        numero_resolucion_reprocann: @club.numero_resolucion_reprocann,
        sedes_reprocann: @club.sedes.where(declarada_reprocann: true).map { |s|
          { nombre: s.nombre, tipo: s.tipo_label,
            direccion: [s.direccion, s.ciudad, s.provincia].compact_blank.join(', ') }
        },
      }
    end

    # La población registrada al cierre, con la vigencia juzgada ese día. «Por vencer» no existe
    # acá: en un semestre cerrado no significa nada, y es un pendiente del admin que ya vive en
    # REPROCANN con nombres. Quien vence en 20 días está VIGENTE para la declaración.
    def pacientes(reprocann)
      nomina  = reprocann.nomina(al: @al)
      conteos = nomina.group_by { |p| p[:reprocann_estado] }.transform_values(&:size)
      {
        registrados:  nomina.size,
        vigentes:     conteos.fetch('vigente', 0) + conteos.fetch('por_vencer', 0),
        vencidos:     conteos.fetch('vencido', 0),
        en_tramite:   conteos.fetch('pendiente', 0),
        sin_numero:   conteos.fetch('sin_reprocann', 0),
        # No se presentan; se informa el número.
        sin_registro: reprocann.activos(al: @al).count - nomina.size,
        nomina:       nomina,
      }
    end

    def cultivo(inase)
      k = inase[:kpis]
      {
        cosechados: { lotes: k[:lotes], plantas: k[:plantas], gramos: k[:gramos],
                      gramos_por_planta: k[:plantas].positive? ? (k[:gramos] / k[:plantas]).round(1) : nil },
        variedades: inase[:variedades],
        en_pie:     en_pie(inase),
      }
    end

    # Lo que había en cultivo al cierre. Con el semestre en curso es la foto de hoy, que el INASE ya
    # trae por variedad; cerrado, se reconstruye desde la cronología: los lotes que ya habían
    # arrancado y todavía no habían pasado a cosecha ese día.
    def en_pie(inase)
      if inase[:periodo][:incluye_hoy]
        return { lotes: inase[:kpis][:lotes_en_pie], plantas: inase[:kpis][:plantas_en_pie], variedades: inase[:en_cultivo] }
      end

      fin      = @hasta.end_of_day
      primeras = LoteEvento.where(lote_id: @club.lotes.select(:id), tipo: 'cambio_estado',
                                  estado_nuevo: Produccion::POST_COSECHA)
                           .group(:lote_id).minimum(:registrado_en)
      lotes = @club.lotes.where('start_date <= ?', @hasta).reject do |l|
        cosecha = primeras[l.id]
        # Sin fecha de corte pero ya post-cosecha: lote viejo sin cronología. No se sabe cuándo se
        # cortó, así que no se lo cuenta en pie — decir que sí sería inventar.
        (cosecha && cosecha <= fin) || (cosecha.nil? && Produccion::POST_COSECHA.include?(l.estado))
      end
      { lotes: lotes.size, plantas: lotes.sum { |l| l.plants_count.to_i }, variedades: nil }
    end

    def entregas(reprocann)
      d = reprocann.dispensaciones(al: @al)
      { entregas: d[:total], pacientes: d[:pacientes_atendidos], por_unidad: d[:por_unidad],
        sin_reprocann_vigente: d[:entregas_sin_vigente] }
    end
  end
end
