# CRUD de categorías contables editables por club. Lectura: admin/auditor. Escritura: admin.
# Las categorías de sistema (es_sistema) no se pueden borrar; sí renombrar/recolorear/reasignar.
class CategoriasContablesController < ApplicationController
  before_action :authenticate_user!
  before_action :require_lectura,   only: [:index]
  before_action :require_escritura, only: [:create, :update, :destroy]
  before_action :asegurar_catalogo, only: [:index]
  before_action :set_categoria,     only: [:update, :destroy]

  # GET /categorias_contables — árbol: madres con sus subcategorías anidadas.
  def index
    scope = current_user.club.categorias_contables.includes(:unidad_negocio, subcategorias: :unidad_negocio)
    scope = scope.where(tipo: params[:tipo]) if params[:tipo].present?
    scope = scope.activas                    if params[:activas] == 'true'
    madres = scope.madres.ordenadas
    render json: madres.map { |m| serialize(m, con_subcategorias: true) }
  end

  # POST /categorias_contables
  #
  # Un solo nivel: SECTOR → CATEGORÍA. Las subcategorías agregaban un tercer escalón que había que
  # entender antes de poder anotar un gasto, y la mitad de la app las trataba como categorías.
  # Las que ya existen se siguen usando y editando; nuevas no se crean.
  def create
    if params.dig(:categoria_contable, :parent_id).present?
      return render json: { error: 'Las categorías no tienen subcategorías: creá una categoría del sector que corresponda.' },
                    status: :unprocessable_entity
    end

    categoria = current_user.club.categorias_contables.build(categoria_params)
    aplicar_va_a_deposito(categoria)
    if categoria.save
      render json: serialize(categoria), status: :created
    else
      render json: { errors: categoria.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PATCH /categorias_contables/:id
  def update
    @categoria.assign_attributes(categoria_params)
    aplicar_va_a_deposito(@categoria)
    if @categoria.save
      render json: serialize(@categoria)
    else
      render json: { errors: @categoria.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /categorias_contables/:id
  def destroy
    if @categoria.es_sistema?
      return render json: { error: 'Esta categoría es del sistema y no puede eliminarse. Podés desactivarla.' }, status: :unprocessable_entity
    end
    if @categoria.subcategorias.exists?
      return render json: { error: 'Esta categoría tiene subcategorías. Borralas o movelas primero.' }, status: :unprocessable_entity
    end
    if @categoria.movimientos_contables.exists?
      return render json: { error: 'La categoría tiene movimientos. Desactivala en vez de borrarla para conservar el histórico.' }, status: :unprocessable_entity
    end
    if @categoria.insumos.exists?
      return render json: { error: 'La categoría está asignada a insumos del depósito. Reasignalos o desactivala en vez de borrarla.' }, status: :unprocessable_entity
    end

    @categoria.destroy
    head :no_content
  end

  private

  def set_categoria
    @categoria = current_user.club.categorias_contables.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Categoría no encontrada' }, status: :not_found
  end

  # Siembra el catálogo la primera vez y, si el club quedó con categorías planas (siembra vieja),
  # las reorganiza en el árbol. La siembra es idempotente: correrla de nuevo no duplica.
  # También auto-repara clubes ya sembrados a los que les falta una familia agregada DESPUÉS
  # de su siembra original (p.ej. "Insumos generales", jul-2026): esos clubes ya tienen hojas,
  # así que el guard viejo (solo por hojas) nunca los actualizaba.
  def asegurar_catalogo
    return if catalogo_al_dia?(current_user.club)

    Finanzas::SembrarCatalogo.new(current_user.club).call
  end

  # El catálogo está al día si ya tiene hojas Y las familias que hoy espera la app.
  # Solo garantizamos las ÁREAS (unidades de negocio). El árbol de categorías NO se auto-siembra:
  # el club arranca en limpio y el usuario crea las suyas.
  def catalogo_al_dia?(club)
    club.unidades_negocio.exists?
  end

  # El formulario pregunta "¿va a depósito?" (sí/no) y el SECTOR decide a cuál. Se traduce a
  # `comportamiento`, que sigue siendo la única columna que lo guarda. Si el cliente no manda el
  # switch (una edición que sólo cambia el nombre), no se toca nada.
  def aplicar_va_a_deposito(categoria)
    # Se acepta suelto o dentro del objeto: el cliente manda todo el formulario anidado bajo
    # `categoria_contable`, y no es un campo del modelo como para meterlo en el permit.
    crudo = params[:va_a_deposito]
    crudo = params.dig(:categoria_contable, :va_a_deposito) if crudo.nil?
    return if crudo.nil?

    va = ActiveModel::Type::Boolean.new.cast(crudo)
    categoria.comportamiento = CategoriaContable.comportamiento_para(categoria.unidad_efectiva, va)
  end

  def categoria_params
    params.require(:categoria_contable).permit(
      # `sede_id` nulo = la categoría vale para toda la organización (como venían todas).
      :nombre, :tipo, :color, :unidad_negocio_id, :sede_id, :orden, :activa, :parent_id, :comportamiento
    )
  end

  def require_lectura
    unless current_user.admin? || current_user.auditor?
      render json: { error: 'No autorizado' }, status: :forbidden
    end
  end

  def require_escritura
    unless current_user.admin?
      render json: { error: 'Solo administradores pueden gestionar categorías' }, status: :forbidden
    end
  end

  def serialize(c, con_subcategorias: false)
    base = {
      id:                c.id,
      nombre:            c.nombre,
      tipo:              c.tipo,
      color:             c.color,
      parent_id:         c.parent_id,
      comportamiento:    c.comportamiento,
      comportamiento_efectivo: c.comportamiento_efectivo,
      clave_efectiva:    c.clave_efectiva,
      es_sistema:        c.es_sistema,
      activa:            c.activa,
      orden:             c.orden,
      unidad_negocio_id: c.unidad_negocio_id,
      unidad_negocio:    c.unidad_efectiva ? { id: c.unidad_efectiva.id, nombre: c.unidad_efectiva.nombre, tipo: c.unidad_efectiva.tipo } : nil,
      sede_id:           c.sede_id_efectiva,
      sede:              c.sede_efectiva ? { id: c.sede_efectiva.id, nombre: c.sede_efectiva.nombre } : nil,
      # Si una compra con esta categoría entra a un inventario, y a cuál. No es una columna
      # aparte: lo dice `comportamiento` (ver CategoriaContable::FAMILIA_DEPOSITO).
      va_a_deposito:     c.va_a_deposito?,
      familia_deposito:  c.familia_deposito,
    }
    base[:subcategorias] = c.subcategorias.ordenadas.map { |s| serialize(s) } if con_subcategorias
    base
  end
end
