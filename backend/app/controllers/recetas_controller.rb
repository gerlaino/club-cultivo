# Recetas de nutrientes: armar, editar, archivar, y dónde se usó cada una. Las aplica el registro
# de riego (`registros_ambientales#create`, `salas#registrar_sala`) con `nutricion: {...}`.
#
# Quién: quien cultiva (admin, supervisor, cultivador). En uso personal, la persona.
class RecetasController < ApplicationController
  before_action :authenticate_user!
  before_action -> { require_feature!(:cultivo) }
  before_action :autorizar!
  before_action :set_receta, only: [:show, :update, :destroy]

  def index
    recetas = current_user.club.recetas.includes(receta_items: :insumo).order(activa: :desc, nombre: :asc)
    # `?uso=top_dress`: el formulario de la cama pide sólo las que le sirven.
    recetas = recetas.de_uso(params[:uso]) if Receta::USOS.include?(params[:uso].to_s)
    render json: recetas.map { |r| serialize(r) }
  end

  def show
    render json: serialize(@receta, con_uso: true)
  end

  def create
    receta = current_user.club.recetas.new(receta_params.merge(created_by: current_user))
    if receta.save
      render json: serialize(receta), status: :created
    else
      render json: { errors: receta.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    if @receta.update(receta_params)
      render json: serialize(@receta)
    else
      render json: { errors: @receta.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # Borrar es archivar: los registros que la usaron guardan su copia, así que no se pierde nada.
  def destroy
    @receta.destroy
    head :no_content
  end

  private

  def autorizar!
    return if %w[admin supervisor cultivador].include?(current_user.role)
    render json: { error: 'No autorizado' }, status: :forbidden
  end

  def set_receta
    @receta = current_user.club.recetas.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Receta no encontrada' }, status: :not_found
  end

  def receta_params
    params.require(:receta).permit(:nombre, :uso, :fase, :ph_objetivo, :ec_objetivo, :notas, :activa,
                                   receta_items_attributes: [:id, :insumo_id, :dosis, :unidad, :orden, :_destroy])
  end

  def serialize(r, con_uso: false)
    base = {
      id: r.id, nombre: r.nombre, fase: r.fase, fase_label: Receta::FASE_LABELS[r.fase],
      uso: r.uso, uso_label: Receta::USO_LABELS[r.uso], base_unidad: Receta::BASE_UNIDAD[r.uso],
      ph_objetivo: r.ph_objetivo, ec_objetivo: r.ec_objetivo, notas: r.notas, activa: r.activa,
      items: r.receta_items.map { |it|
        { id: it.id, insumo_id: it.insumo_id, nombre: it.insumo.nombre, dosis: it.dosis, unidad: it.unidad,
          unidad_label: RecetaItem::UNIDAD_LABELS[it.unidad], unidad_insumo: it.insumo.unidad_medida,
          stock_actual: it.insumo.stock_actual, orden: it.orden,
          # Cuánto de la unidad del insumo es una unidad de la dosis (g → kg: 0,001). La pantalla
          # multiplica por esto; la regla vive acá (`RecetaItem#factor_a_insumo`).
          factor: it.factor_a_insumo.to_f }
      },
      # Para 1 unidad de base (litro, m² o litro de suelo), ya en la unidad del insumo: con esto
      # la pantalla calcula cualquier cantidad sin volver a pedir.
      por_litro: r.receta_items.map { |it| { insumo_id: it.insumo_id, dosis: it.dosis, factor: it.factor_a_insumo.to_f } },
    }
    con_uso ? base.merge(uso: uso_de(r)) : base
  end

  # Dónde se usó: lotes, aplicaciones y plata. Para comparar «con qué receta rindió más».
  def uso_de(r)
    registros = r.registros_ambientales.includes(:lote)
    lotes = registros.map(&:lote).compact.uniq
    # En suelo vivo la receta también se aplica a camas (top dress, mezcla, té al suelo).
    de_camas = CamaRegistro.where(receta_id: r.id).includes(:cama)
    {
      aplicaciones: registros.size + de_camas.size,
      camas: de_camas.group_by(&:cama).map { |cama, regs|
        { id: cama.id, nombre: cama.nombre, aplicaciones: regs.size,
          costo_ars: regs.sum(&:costo_ars).round(2) }
      },
      lotes: lotes.map { |l|
        regs = registros.select { |x| x.lote_id == l.id }
        { id: l.id, codigo: l.codigo, estado: l.estado, aplicaciones: regs.size,
          litros: regs.sum { |x| x.litros.to_f }.round(1),
          costo_ars: regs.sum { |x| x.nutricion.to_h['costo_ars'].to_f }.round(2),
          plantas: l.plants_count }
      },
      costo_total_ars: (registros.sum { |x| x.nutricion.to_h['costo_ars'].to_f } + de_camas.sum(&:costo_ars)).round(2),
    }
  end
end
