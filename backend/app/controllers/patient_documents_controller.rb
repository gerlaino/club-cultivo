class PatientDocumentsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_socio
  before_action :set_document, only: [:show, :update, :destroy, :firmar, :archivar]

  # GET /socios/:socio_id/documents
  def index
    docs = @socio.patient_documents
                 .includes(:created_by, :template)
                 .order(created_at: :desc)
    render json: docs.map { |d| serialize_doc(d) }
  end

  # GET /socios/:socio_id/documents/:id
  def show
    render json: serialize_doc_detail(@doc)
  end

  # POST /socios/:socio_id/documents
  def create
    # Obtener template si se pasa
    template = nil
    if params[:document][:template_id].present?
      template = current_user.club.document_templates.find(params[:document][:template_id])
    end

    # Interpolar variables en el contenido
    contenido = params[:document][:contenido_html]
    if contenido.present?
      contenido = PatientDocument.interpolar(
        contenido,
        socio:  @socio,
        club:   current_user.club,
        medico: current_user
      )
    end

    doc = @socio.patient_documents.build(doc_params)
    doc.club        = current_user.club
    doc.created_by  = current_user
    doc.template    = template
    doc.contenido_html = contenido if contenido.present?
    doc.tipo        = template&.tipo || doc.tipo || 'otro'

    if doc.save
      render json: serialize_doc(doc), status: :created
    else
      render json: { errors: doc.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PATCH /socios/:socio_id/documents/:id
  def update
    if @doc.update(doc_params)
      render json: serialize_doc_detail(@doc)
    else
      render json: { errors: @doc.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /socios/:socio_id/documents/:id
  def destroy
    @doc.destroy
    head :no_content
  end

  # POST /socios/:socio_id/documents/:id/firmar
  def firmar
    firmante = params[:firmante] # 'paciente' | 'medico'
    firma_data = params[:firma_data]

    unless %w[paciente medico].include?(firmante)
      return render json: { error: 'Firmante inválido' }, status: :bad_request
    end

    if firmante == 'paciente'
      @doc.firma_paciente_nombre = "#{@socio.nombre} #{@socio.apellido}"
      @doc.firma_paciente_dni    = @socio.dni
      @doc.firma_paciente_data   = firma_data
      @doc.firmado_paciente_at   = Time.current
    else
      @doc.firma_medico_nombre = "#{current_user.first_name} #{current_user.last_name}"
      @doc.firma_medico_dni    = current_user.dni
      @doc.firma_medico_data   = firma_data
      @doc.firmado_medico_at   = Time.current
    end

    # Si ambas firmas están, marcar como firmado
    if @doc.firmado_paciente_at.present? && @doc.firmado_medico_at.present?
      @doc.estado = 'firmado'
    elsif @doc.estado == 'borrador'
      @doc.estado = 'pendiente_firma'
    end

    if @doc.save
      render json: serialize_doc_detail(@doc)
    else
      render json: { errors: @doc.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PATCH /socios/:socio_id/documents/:id/archivar
  def archivar
    @doc.update(estado: 'archivado', archivado_at: Time.current)
    render json: serialize_doc(@doc)
  end

  private

  def set_socio
    @socio = Socio.for_club(current_user.club_id).find(params[:socio_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Paciente no encontrado' }, status: :not_found
  end

  def set_document
    @doc = @socio.patient_documents.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Documento no encontrado' }, status: :not_found
  end

  def doc_params
    params.require(:document).permit(
      :nombre, :tipo, :estado, :contenido_html,
      datos: {}
    )
  end

  def serialize_doc(d)
    {
      id:             d.id,
      nombre:         d.nombre,
      tipo:           d.tipo,
      estado:         d.estado,
      estado_label:   d.estado_label,
      hash_documento: d.hash_documento,
      firmado_paciente_at: d.firmado_paciente_at,
      firmado_medico_at:   d.firmado_medico_at,
      created_by: {
        id:     d.created_by.id,
        nombre: "#{d.created_by.first_name} #{d.created_by.last_name}".strip,
      },
      template: d.template ? { id: d.template.id, nombre: d.template.nombre } : nil,
      created_at: d.created_at,
      updated_at: d.updated_at,
    }
  end

  def serialize_doc_detail(d)
    serialize_doc(d).merge(
      contenido_html:         d.contenido_html,
      datos:                  d.datos,
      firma_paciente_nombre:  d.firma_paciente_nombre,
      firma_paciente_data:    d.firma_paciente_data,
      firma_medico_nombre:    d.firma_medico_nombre,
      firma_medico_data:      d.firma_medico_data,
      )
  end
end
