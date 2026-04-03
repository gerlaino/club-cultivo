class DocumentTemplatesController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin!, except: [:index, :show]
  before_action :set_template, only: [:show, :update, :destroy]

  # GET /document_templates
  def index
    templates = current_user.club.document_templates.activos.order(:tipo, :nombre)
    render json: templates.map { |t| serialize_template(t) }
  end

  # GET /document_templates/:id
  def show
    render json: serialize_template_detail(@template)
  end

  # POST /document_templates
  def create
    template = current_user.club.document_templates.build(template_params)
    template.created_by = current_user
    if template.save
      render json: serialize_template(template), status: :created
    else
      render json: { errors: template.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PATCH /document_templates/:id
  def update
    if @template.update(template_params)
      render json: serialize_template_detail(@template)
    else
      render json: { errors: @template.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /document_templates/:id
  def destroy
    @template.update(activo: false)
    head :no_content
  end

  private

  def set_template
    @template = current_user.club.document_templates.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Template no encontrado' }, status: :not_found
  end

  def require_admin!
    unless current_user.admin?
      render json: { error: 'No autorizado' }, status: :forbidden
    end
  end

  def template_params
    params.require(:document_template).permit(
      :nombre, :tipo, :descripcion, :contenido_html, :activo,
      :requiere_firma_paciente, :requiere_firma_medico,
      campos: []
    )
  end

  def serialize_template(t)
    {
      id:                      t.id,
      nombre:                  t.nombre,
      tipo:                    t.tipo,
      tipo_label:              t.tipo_label,
      descripcion:             t.descripcion,
      activo:                  t.activo,
      requiere_firma_paciente: t.requiere_firma_paciente,
      requiere_firma_medico:   t.requiere_firma_medico,
      created_at:              t.created_at,
    }
  end

  def serialize_template_detail(t)
    serialize_template(t).merge(
      contenido_html:         t.contenido_html,
      campos:                 t.campos,
      variables_disponibles:  DocumentTemplate::VARIABLES_DISPONIBLES,
      )
  end
end
