class HistorialController < ApplicationController
  before_action :authenticate_user!

  PER_PAGE = 30

  def index
    page  = [(params[:page] || 1).to_i, 1].max
    tipo  = params[:tipo].presence
    q     = params[:q].to_s.strip.downcase.presence
    club  = current_user.club

    items = []

    # ── Tareas completadas / canceladas asignadas al usuario ──────────────
    tareas = club.tareas
      .where(asignada_a_id: current_user.id)
      .where(estado: %w[completada cancelada])
      .includes(:sala, :lote)
      .order(updated_at: :desc)
      .limit(500)

    tareas.each do |t|
      items << {
        id:          "tarea-#{t.id}",
        tipo:        "tarea",
        subtipo:     t.tipo,
        estado:      t.estado,
        titulo:      t.titulo,
        descripcion: t.notas_completado.presence || t.descripcion,
        sala:        t.sala  ? { id: t.sala.id,  nombre: t.sala.nombre  } : nil,
        lote:        t.lote  ? { id: t.lote.id,  codigo: t.lote.codigo  } : nil,
        fecha:       (t.fecha_completada || t.updated_at).iso8601,
      }
    end

    # ── Lote eventos registrados por el usuario ───────────────────────────
    unless tipo == "tarea"
      eventos = LoteEvento
        .where(user_id: current_user.id, club_id: club.id)
        .joins(:lote).where(lotes: { deleted_at: nil })
        .includes(lote: :sala)
        .order(registrado_en: :desc)
        .limit(500)

      eventos.each do |e|
        titulo = case e.tipo
                 when "cambio_estado"
                   "#{label_estado(e.estado_anterior)} → #{label_estado(e.estado_nuevo)}"
                 when "movimiento_sala"
                   "Movimiento entre salas"
                 when "nota"
                   e.descripcion.presence || "Nota registrada"
                 else
                   e.tipo.humanize
                 end

        items << {
          id:              "evento-#{e.id}",
          tipo:            "lote_evento",
          subtipo:         e.tipo,
          estado_anterior: e.estado_anterior,
          estado_nuevo:    e.estado_nuevo,
          titulo:          titulo,
          descripcion:     e.descripcion,
          sala:            e.lote&.sala ? { id: e.lote.sala.id, nombre: e.lote.sala.nombre } : nil,
          lote:            e.lote       ? { id: e.lote.id, codigo: e.lote.codigo }           : nil,
          fecha:           e.registrado_en.iso8601,
        }
      end
    end

    # ── Filtro por tipo ───────────────────────────────────────────────────
    items.select! { |i| i[:tipo] == tipo } if tipo && tipo != "todos"

    # ── Búsqueda texto ────────────────────────────────────────────────────
    if q
      items.select! do |i|
        i[:titulo].to_s.downcase.include?(q) ||
          i[:lote]&.dig(:codigo)&.downcase&.include?(q) ||
          i[:sala]&.dig(:nombre)&.downcase&.include?(q) ||
          i[:descripcion].to_s.downcase.include?(q)
      end
    end

    # ── Ordenar y paginar ─────────────────────────────────────────────────
    items.sort_by! { |i| i[:fecha] }.reverse!

    total  = items.size
    offset = (page - 1) * PER_PAGE
    paged  = items[offset, PER_PAGE] || []

    render json: { items: paged, total: total, page: page, per_page: PER_PAGE }
  end

  private

  ESTADO_LABELS = {
    "planificacion" => "Planificación",
    "vegetativo"    => "Vegetativo",
    "floracion"     => "Floración",
    "cosecha"       => "Cosecha",
    "secado"        => "Secado",
    "curado"        => "Curado",
    "finalizado"    => "Finalizado",
  }.freeze

  def label_estado(e)
    ESTADO_LABELS[e] || e.to_s.humanize
  end
end
