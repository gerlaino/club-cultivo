# «Exportar mis datos» del autocultivo: pedir el ZIP, ver si está listo y bajarlo.
# Ver `Autocultivo::ExportarDatos` y `ExportarDatosJob`.
class MisDatosController < ApplicationController
  before_action :authenticate_user!
  before_action :solo_autocultivo!
  before_action :solo_admin!

  # GET /mis_datos/exportar — en qué está (nada · armando · listo · error).
  def estado
    render json: publico(ExportarDatosJob.estado(club.id))
  end

  # POST /mis_datos/exportar — encola el armado (si ya hay uno en curso, no encola otro).
  def exportar
    actual = ExportarDatosJob.estado(club.id)
    unless actual['estado'] == 'armando'
      actual = { 'estado' => 'armando', 'pedido_at' => Time.current.iso8601 }
      ExportarDatosJob.guardar(club.id, actual, expires_in: 2.hours)
      ExportarDatosJob.perform_later(club.id, current_user.id)
    end
    render json: publico(actual), status: :accepted
  end

  # GET /mis_datos/exportar/descargar — el ZIP, con sesión.
  def descargar
    est = ExportarDatosJob.estado(club.id)
    blob = est['estado'] == 'listo' && ActiveStorage::Blob.find_by(id: est['blob_id'])
    return render json: { error: 'No hay una exportación lista. Pedila de nuevo.' }, status: :not_found unless blob

    send_data blob.download, filename: blob.filename.to_s, type: 'application/zip', disposition: 'attachment'
  end

  private

  def club = current_user.club

  def publico(est) = est.slice('estado', 'bytes', 'listo_at', 'vence_at', 'pedido_at')

  def solo_autocultivo!
    render json: { error: 'Es del autocultivo' }, status: :not_found unless club&.personal?
  end

  def solo_admin!
    render json: { error: 'Forbidden' }, status: :forbidden unless current_user.admin?
  end
end
