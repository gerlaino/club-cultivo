# Qué propuso el asistente por voz y qué confirmó la persona.
#
# Existe para poder contestar, con un número y no con una impresión, qué tan bien interpreta el
# dictado — y para poder enseñarle el vocabulario de cada organización, que es lo que lo vuelve
# una herramienta de la casa y no un formulario con micrófono.
#
# Se escribe al parsear y se completa al ejecutar. NUNCA rompe el dictado: registrar mal una
# corrección es molesto, no dejar registrar es grave.
class AsistenteCorreccion < ApplicationRecord
  self.table_name = 'asistente_correcciones' # el inflector EN no pluraliza "correccion"

  belongs_to :club
  acts_as_tenant(:club)
  belongs_to :user

  validates :texto, presence: true

  scope :del_mes,     ->(fecha = Time.zone.today) { where(created_at: fecha.all_month) }
  scope :ejecutadas,  -> { where.not(ejecutado_en: nil) }
  scope :corregidas,  -> { where(hubo_correccion: true) }
  scope :recientes,   -> { order(created_at: :desc) }

  # Qué proporción de lo dictado salió tal como lo propuso el modelo.
  #
  # Se calcula SOLO sobre las ejecutadas: un dictado que nadie guardó no dice si la
  # interpretación fue buena o mala, dice que la persona cambió de idea. Meterlo en el promedio
  # ensuciaría justo la métrica que queremos mirar.
  def self.precision_del_mes(club, fecha = Time.zone.today)
    base  = where(club_id: club.id).del_mes(fecha).ejecutadas
    total = base.count
    return nil if total.zero? # sin datos no se inventa un número

    {
      dictados:  total,
      sin_tocar: total - base.corregidas.count,
      precision: ((total - base.corregidas.count) * 100.0 / total).round(1),
    }
  end

  # Marca qué se guardó finalmente. `hubo_correccion` se calcula acá y no en el cliente: es la
  # métrica, y no puede depender de que la pantalla la mande bien.
  def confirmar!(acciones_ejecutadas)
    update!(
      confirmado:      { 'acciones' => acciones_ejecutadas },
      hubo_correccion: self.class.difiere?(propuesto['acciones'], acciones_ejecutadas),
      ejecutado_en:    Time.current
    )
  end

  # Difieren si cambió la cantidad de acciones, el tipo de alguna, o los datos de cualquiera.
  # Comparación floja a propósito: interesa "¿tuvo que meter mano?", no un diff exacto.
  def self.difiere?(propuestas, ejecutadas)
    p = Array(propuestas).map { |a| normalizar(a) }
    e = Array(ejecutadas).map { |a| normalizar(a) }
    p != e
  end

  # Se saca lo que la pantalla agrega y no es decisión de la persona (`_expandido`), y las claves
  # se comparan como texto para que no importe si vinieron como símbolo o como string.
  def self.normalizar(accion)
    datos = (accion['datos'] || accion[:datos] || {}).reject { |k, _| k.to_s.start_with?('_') }
    {
      'tipo'  => (accion['tipo'] || accion[:tipo]).to_s,
      'datos' => datos.transform_keys(&:to_s).sort.to_h,
    }
  end
end
