# Lo que se le hace al suelo de una cama (ver `CamaRegistro`): alimentarla (top dress), un té al
# suelo, cobertura, mulch, inoculación, medirla, anotar. El riego va por `camas#regar` (a los lotes
# si tiene plantas). Los que usan insumos los descuentan y cuestan (`Camas::Registrar`).
class CamaRegistrosController < ApplicationController
  before_action :authenticate_user!
  before_action -> { require_feature!(:cultivo) }
  before_action :autorizar!
  before_action :set_cama

  def index
    registros = @cama.registros.includes(:user, :cama_ciclo)
    registros = registros.where(cama_ciclo_id: params[:ciclo_id]) if params[:ciclo_id].present?
    registros = registros.where(tipo: params[:tipo]) if params[:tipo].present?
    render json: registros.limit((params[:limit] || 200).to_i.clamp(1, 500)).map { |r| CamaSerializer.registro(r, con_costo: con_costo?) }
  end

  # POST /camas/:cama_id/registros { registro: {...}, nutricion: { receta_id, base, items } }
  def create
    attrs = registro_params.to_h
    if attrs['tipo'] == 'riego'
      return render json: { error: 'El riego se carga con «Regar la cama»' }, status: :unprocessable_entity
    end
    attrs['registrado_en'] = attrs['registrado_en'].present? ? Time.zone.parse(attrs['registrado_en'].to_s) : Time.current
    res = Camas::Registrar.call(cama: @cama, usuario: current_user, attrs: attrs, nutricion: params[:nutricion])
    return render json: { error: res.error }, status: :unprocessable_entity unless res.ok?

    render json: CamaSerializer.registro(res.registro, con_costo: con_costo?).merge(faltantes: res.faltantes), status: :created
  end

  # Borrar un registro devuelve al depósito lo que descontó (como el riego). Sólo administración:
  # es la historia del suelo.
  def destroy
    return render json: { error: 'Solo un administrador puede borrar registros' }, status: :forbidden unless current_user.admin?
    registro = @cama.registros.find(params[:id])
    if registro.tipo == 'armado' && @cama.lotes.exists?
      return render json: { error: 'El armado es el origen de la cama y ya hubo lotes en ella: no se borra' },
                    status: :unprocessable_entity
    end
    registro.destroy
    head :no_content
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Registro no encontrado' }, status: :not_found
  end

  private

  # La plata es de administración (admin, supervisor; en uso personal la persona es admin).
  def con_costo? = current_user.admin? || current_user.supervisor?

  def autorizar!
    return if %w[admin supervisor cultivador].include?(current_user.role)
    render json: { error: 'No autorizado' }, status: :forbidden
  end

  def set_cama
    @cama = current_user.club.camas.al_alcance_de(current_user).find(params[:cama_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Cama no encontrada' }, status: :not_found
  end

  def registro_params
    params.require(:registro).permit(:tipo, :registrado_en, :detalle, :cantidad, :unidad, :litros, :agua,
                                     :humedad_suelo, :temperatura_suelo, :recarga, :observaciones)
  end
end
