# GET /buscar?q= — el buscador general de la barra de arriba (Ctrl+K).
#
# Reemplaza a la lista de TODAS las plantas (/plantas), que tardaba en cargar y que nadie miraba:
# lo que se necesita es llegar a UNA planta, un lote o un paciente sabiendo cómo se llama
# (Germán, 12-oct-2026).
#
# Cada sección respeta lo que ese rol ya ve en su pantalla, con las MISMAS reglas y no con unas
# nuevas: el cultivo por `Lote.al_alcance_de` (y sus salas), los pacientes por `PacientePolicy`
# (el médico sólo sus vinculados, el dispensador sólo pacientes activos). Lo que el rol no ve no
# viene, ni siquiera vacío: la pantalla dibuja las secciones que llegan.
class BuscarController < ApplicationController
  before_action :authenticate_user!

  LIMITE = 6
  ROLES_CULTIVO = %w[admin supervisor cultivador manicura].freeze

  def index
    q = params[:q].to_s.strip
    return render json: { q: q, resultados: {} } if q.length < 2

    @like = "%#{ActiveRecord::Base.sanitize_sql_like(q.downcase)}%"
    @q    = q
    resultados = {}
    if ve_cultivo?
      resultados[:plantas]   = plantas
      resultados[:lotes]     = lotes unless club.personal? # en autocultivo el lote vive por debajo
      resultados[:salas]     = salas
      resultados[:geneticas] = geneticas
    end
    resultados[:pacientes] = pacientes if ve_pacientes?

    render json: { q: q, resultados: resultados }
  end

  private

  def club = current_user.club

  def ve_cultivo?
    club.present? && ROLES_CULTIVO.include?(current_user.role) && club.feature?(:cultivo)
  end

  def ve_pacientes?
    club.present? && !club.personal? && PacientePolicy::ROLES_LECTURA.include?(current_user.role)
  end

  def lotes_visibles = club.lotes.merge(Lote.al_alcance_de(current_user))

  def plantas
    Plant.joins(:lote).merge(lotes_visibles)
         .where('LOWER(plants.nombre) LIKE :q OR LOWER(plants.codigo_qr) LIKE :q', q: @like)
         .includes(lote: %i[genetica sala]).order(Arel.sql("plants.state = 'descartada'"), :nombre).limit(LIMITE)
         .map do |p|
           { id: p.id, titulo: p.nombre.presence || p.codigo_qr || "Planta #{p.id}",
             detalle: [p.lote&.genetica&.nombre || p.lote&.strain, p.lote&.sala&.nombre, estado_planta(p)].compact.join(' · '),
             ruta: "/plantas/#{p.id}" }
         end
  end

  def lotes
    lotes_visibles.left_joins(:genetica)
                  .where('LOWER(lotes.codigo) LIKE :q OR LOWER(lotes.strain) LIKE :q OR LOWER(geneticas.nombre) LIKE :q', q: @like)
                  .includes(:genetica, :sala).order(created_at: :desc).limit(LIMITE)
                  .map do |l|
                    { id: l.id, titulo: l.codigo.presence || "Lote #{l.id}",
                      detalle: [l.genetica&.nombre || l.strain, l.sala&.nombre, l.estado_label].compact.join(' · '),
                      ruta: "/lotes/#{l.id}" }
                  end
  end

  def salas
    scope = club.salas.where('LOWER(salas.nombre) LIKE ?', @like)
    case current_user.role
    when 'cultivador', 'manicura' then scope = scope.where(id: current_user.salas_ids_asignadas)
    when 'supervisor'             then scope = scope.where(id: current_user.salas_ids_en_sedes_asignadas)
    end
    scope.includes(:sede).order(:nombre).limit(LIMITE).map do |s|
      { id: s.id, titulo: s.nombre, detalle: s.sede&.nombre, ruta: "/salas/#{s.id}" }
    end
  end

  def geneticas
    club.geneticas.where('LOWER(geneticas.nombre) LIKE ?', @like).order(:nombre).limit(LIMITE).map do |g|
      { id: g.id, titulo: g.nombre, detalle: g.criador.presence, ruta: "/geneticas/#{g.id}" }
    end
  end

  # La misma búsqueda que la lista de pacientes: nombre, apellido o apodo, o el DNI exacto (va
  # cifrado: no admite parcial). Sólo identidad: nada clínico en el resultado.
  def pacientes
    scope = PacientePolicy::Scope.new(current_user, Paciente).resolve
    por_nombre = scope.where('LOWER(nombre) LIKE :q OR LOWER(apellido) LIKE :q OR LOWER(apodo) LIKE :q', q: @like)
    dni = @q.gsub(/\D/, '')
    scope = dni.length >= 6 ? por_nombre.or(scope.where(dni_normalizado: dni)) : por_nombre
    scope.order(:apellido, :nombre).limit(LIMITE).map do |p|
      { id: p.id, titulo: [p.apellido, p.nombre].compact_blank.join(', '),
        detalle: p.apodo.present? ? "«#{p.apodo}»" : nil, ruta: "/pacientes/#{p.id}" }
    end
  end

  def estado_planta(p)
    { 'vegetativo' => 'Vegetativo', 'floracion' => 'Floración', 'cosechado' => 'Cosechada',
      'descartada' => 'Descartada' }[p.state]
  end
end
