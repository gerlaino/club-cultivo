class PapeleraController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin_o_super!
  before_action :set_club

  PER_PAGE   = 30
  MODEL_CAP  = 500 # tope por modelo antes de mergear (evita cargar papeleras patológicas)

  # GET /papelera — historial de borrados (top-level, restaurables) con buscador y filtro de fecha.
  def index
    q     = params[:q].to_s.strip.downcase
    desde = parse_fecha(params[:desde])&.beginning_of_day
    hasta = parse_fecha(params[:hasta])&.end_of_day

    filas = []
    grupos = Hash.new(0)

    ActsAsTenant.without_tenant do
      restorable_entries.each do |entry|
        rel = scope_para(entry.model, desde: desde, hasta: hasta)
        next if rel.nil?

        rel.limit(MODEL_CAP).each do |record|
          desc = entry.describe(record).to_s
          next if q.present? && !"#{desc} #{entry.label}".downcase.include?(q)

          grupos[entry.group] += 1
          filas << {
            tipo:        entry.key,
            tipo_label:  entry.label,
            grupo:       entry.group,
            id:          record.id,
            descripcion: desc,
            deleted_at:  record.deleted_at,
            deleted_by:  nombre_deleter(record),
            restaurable: entry.restaurable_ahora?,
          }
        end
      end
    end

    filas.sort_by! { |f| f[:deleted_at] || Time.at(0) }
    filas.reverse!

    page  = [params[:pagina].to_i, 1].max
    total = filas.size
    paginadas = filas[(page - 1) * PER_PAGE, PER_PAGE] || []

    render json: {
      data: paginadas,
      meta: { total: total, pagina: page, limite: PER_PAGE, por_grupo: grupos },
    }
  end

  # POST /papelera/restaurar { tipo, id } — restaura un registro borrado.
  # Simples → des-borra. Complejas → Restorer dedicado (valida conflictos y re-aplica efectos);
  # si choca con el estado actual, bloquea (422) y devuelve los motivos.
  def restaurar
    entry = Restore::Catalog.find(params[:tipo])
    return render json: { error: 'Tipo no restaurable' }, status: :unprocessable_entity unless entry

    if entry.complex? && entry.restorer_class.nil?
      return render json: {
        error: 'Esta entidad todavía no tiene restauración con validación disponible.',
      }, status: :unprocessable_entity
    end

    ActsAsTenant.without_tenant do
      record = entry.model.find_soft_deleted(params[:id])
      return render json: { error: 'No pertenece a tu organización' }, status: :forbidden unless del_club?(record)

      if entry.restorer_class
        res = entry.restorer_class.call(record, usuario: current_user)
        unless res.ok?
          return render json: {
            error:      'No se puede restaurar por conflictos con el estado actual.',
            conflictos: res.conflicts.map { |c| { codigo: c.codigo, mensaje: c.mensaje } },
          }, status: :unprocessable_entity
        end
      else
        record.restore_record!
      end
    end

    render json: { ok: true, mensaje: "#{entry.label} restaurado." }
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Registro no encontrado en la papelera' }, status: :not_found
  end

  private

  def restorable_entries
    Restore::Catalog.top_level # agregados restaurables; los dependientes vuelven con su padre
  end

  # Relación de borrados de un modelo, scopeada a la organización y al rango de fechas. nil si no aplica.
  def scope_para(model, desde:, hasta:)
    rel = model.soft_deleted_records
    rel = rel.where(club_id: @club.id) if model.column_names.include?('club_id')
    rel = rel.where('deleted_at >= ?', desde) if desde
    rel = rel.where('deleted_at <= ?', hasta) if hasta
    rel.order(deleted_at: :desc)
  end

  def del_club?(record)
    return true unless record.class.column_names.include?('club_id')
    record.club_id == @club.id
  end

  def nombre_deleter(record)
    u = record.respond_to?(:deleted_by) ? record.deleted_by : nil
    return nil unless u
    [u.first_name, u.last_name].compact.join(' ').presence || u.email
  end

  def parse_fecha(str)
    return nil if str.blank?
    Date.parse(str)
  rescue ArgumentError
    nil
  end

  def set_club
    @club = current_user.club || Club.find_by(id: params[:club_id])
    render json: { error: 'Falta club_id' }, status: :bad_request if @club.nil?
  end

  def require_admin_o_super!
    return if current_user&.admin? || current_user&.super_admin?
    render json: { error: 'No autorizado' }, status: :forbidden
  end
end
