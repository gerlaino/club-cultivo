class DocumentosController < ApplicationController
  before_action :authenticate_user!

  def index
    docs = current_user.club.documentos.recientes
    render json: docs.map { |d| serialize(d) }
  end

  def create
    doc = current_user.club.documentos.build(doc_params)
    doc.user = current_user
    doc.archivo.attach(params[:archivo]) if params[:archivo].present?

    if doc.save
      render json: serialize(doc), status: :created
    else
      render json: { errors: doc.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    doc = current_user.club.documentos.find(params[:id])
    doc.destroy
    head :no_content
  end

  private

  def doc_params
    params.require(:documento).permit(:tipo, :titulo, :descripcion, :fecha_vencimiento, :estado)
  end

  def serialize(d)
    {
      id:               d.id,
      tipo:             d.tipo,
      titulo:           d.titulo,
      descripcion:      d.descripcion,
      fecha_vencimiento:d.fecha_vencimiento,
      estado:           d.estado,
      tiene_archivo:    d.archivo.attached?,
      archivo_url:      d.archivo.attached? ? Rails.application.routes.url_helpers.url_for(d.archivo) : nil,
      archivo_nombre:   d.archivo.attached? ? d.archivo.filename.to_s : nil,
      usuario:          d.user.nombre_completo,
      created_at:       d.created_at
    }
  end
end