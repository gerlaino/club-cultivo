# Arma el ZIP de «Exportar mis datos» (`Autocultivo::ExportarDatos`) en segundo plano y lo deja
# listo para bajar 48 horas. Sin tabla nueva: el estado vive en Redis por cuenta (el mismo de
# Sidekiq, no `Rails.cache`: en desarrollo la caché es nula y vive en otro proceso) y el archivo es
# un blob suelto de Active Storage que se purga solo. Se baja por un endpoint con sesión
# (`MisDatosController#descargar`), nunca por una URL pública: son datos de salud.
class ExportarDatosJob < ApplicationJob
  queue_as :default

  VIGENCIA = 48.hours

  def self.store
    @store ||= ActiveSupport::Cache::RedisCacheStore.new(url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0'))
  end
  def self.clave(club_id) = "exportar_datos:#{club_id}"
  def self.estado(club_id) = store.read(clave(club_id)) || { 'estado' => 'nada' }
  def self.guardar(club_id, valor, expires_in:) = store.write(clave(club_id), valor, expires_in: expires_in)

  def perform(club_id, user_id)
    club = Club.find(club_id)
    usuario = User.find(user_id)
    ruta = Autocultivo::ExportarDatos.new(club: club, usuario: usuario).call
    blob = File.open(ruta, 'rb') do |io|
      ActiveStorage::Blob.create_and_upload!(io: io, filename: "mis-datos-#{Time.zone.today.strftime('%Y%m%d')}.zip",
                                             content_type: 'application/zip')
    end
    File.delete(ruta) if File.exist?(ruta)
    ActiveStorage::PurgeJob.set(wait: VIGENCIA).perform_later(blob)
    self.class.guardar(club_id, { 'estado' => 'listo', 'blob_id' => blob.id, 'bytes' => blob.byte_size,
                                  'listo_at' => Time.current.iso8601, 'vence_at' => (Time.current + VIGENCIA).iso8601 },
                       expires_in: VIGENCIA)
  rescue StandardError => e
    Rails.logger.error "[ExportarDatos] club #{club_id}: #{e.class} #{e.message}"
    self.class.guardar(club_id, { 'estado' => 'error' }, expires_in: 1.hour)
    raise
  end
end
