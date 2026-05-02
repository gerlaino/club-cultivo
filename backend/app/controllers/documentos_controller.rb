class DocumentosController < ApplicationController
  before_action :authenticate_user!
  before_action :require_documental_role!
  before_action :set_documento, only: [:show, :update, :destroy, :subir_archivo, :descargar]

  def index
    docs = policy_scope(Documento).recientes
    render json: docs.map { |d| serialize(d) }
  end

  def show
    authorize @documento
    render json: serialize(@documento)
  end

  def create
    doc = current_user.club.documentos.build(doc_params)
    doc.user         = current_user
    doc.subido_por   = current_user

    authorize doc

    if doc.save
      render json: serialize(doc), status: :created
    else
      render json: { errors: doc.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    authorize @documento
    if @documento.update(doc_params)
      render json: serialize(@documento)
    else
      render json: { errors: @documento.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @documento
    @documento.destroy
    head :no_content
  end

  def subir_archivo
    authorize @documento, :subir_archivo?
    @documento.archivo.attach(params[:archivo])
    if @documento.archivo.attached?
      render json: serialize(@documento)
    else
      render json: { error: 'No se pudo subir el archivo' }, status: :unprocessable_entity
    end
  end

  def descargar
    authorize @documento, :descargar?
    unless @documento.archivo.attached?
      return render json: { error: 'Sin archivo' }, status: :not_found
    end
    redirect_to Rails.application.routes.url_helpers.url_for(@documento.archivo)
  end

  private

  def set_documento
    @documento = current_user.club.documentos.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Documento no encontrado' }, status: :not_found
  end

  def require_documental_role!
    allowed = %w[admin medico abogado]
    unless allowed.include?(current_user&.role)
      render json: { error: 'No autorizado' }, status: :forbidden
    end
  end

  def doc_params
    params.require(:documento).permit(:tipo, :titulo, :descripcion, :fecha_vencimiento, :estado, :paciente_id)
  end

  def serialize(d)
    {
      id:               d.id,
      tipo:             d.tipo,
      categoria:        d.categoria,
      titulo:           d.titulo,
      descripcion:      d.descripcion,
      fecha_vencimiento: d.fecha_vencimiento,
      estado:           d.estado,
      tiene_archivo:    d.archivo.attached?,
      archivo_url:      d.archivo.attached? ? Rails.application.routes.url_helpers.url_for(d.archivo) : nil,
      archivo_nombre:   d.archivo.attached? ? d.archivo.filename.to_s : nil,
      usuario:          d.user.nombre_completo,
      subido_por:       d.subido_por&.nombre_completo,
      paciente_id:      d.paciente_id,
      created_at:       d.created_at,
    }
  end
end
