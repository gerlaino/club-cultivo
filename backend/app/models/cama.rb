# Una CAMA de cultivo en suelo vivo (Germán, 22/25-sep-2026; plan en `docs/PLAN_SUELO_VIVO.md`).
#
# En suelo vivo el suelo vive más que los lotes: por la misma cama pasan cosecha tras cosecha, se
# la alimenta (top dress, tés, cobertura, mulch) y descansa entre una y otra. Por eso la cama es
# una entidad con su propia historia, y el lote sólo la OCUPA durante su ciclo.
#
# Reglas que viven acá:
# - **El estado se calcula, no se guarda**: retirada → en uso (tiene lotes en cultivo) →
#   cocinando → descansando → lista. Guardarlo dejaría dos verdades.
# - **Los números de cultivo los pone el cultivador**: semanas de cocción, días de descanso y cada
#   cuántos días toca top dress. La app no trae ninguno de fábrica (Germán, 25-sep: «quizás el
#   cultivador lo hace de otra manera porque quiere probar cosas»). Sin número, no hay reloj.
# - **La cama entra en su sala**: sus m² más los de las otras camas y los de los lotes sin cama
#   no pueden pasar los de la sala (cuando la sala declaró sus metros; sin eso no hay techo).
# - **No se muda con plantas adentro**: la sala se cambia sólo con la cama vacía.
class Cama < ApplicationRecord
  include Transmite
  transmite_como 'camas'
  include Auditable
  acts_as_paranoid
  acts_as_tenant(:club)

  belongs_to :club
  belongs_to :sala
  belongs_to :created_by, class_name: 'User', optional: true
  has_many :lotes,           dependent: :restrict_with_error
  has_many :ciclos,          -> { order(:numero) }, class_name: 'CamaCiclo', dependent: :destroy
  has_many :registros,       -> { order(registrado_en: :desc) }, class_name: 'CamaRegistro', dependent: :destroy
  has_many :analisis_suelo,  -> { order(fecha: :desc) }, class_name: 'AnalisisSuelo', dependent: :destroy
  has_many :insumo_consumos, dependent: :nullify

  ESTADOS = %w[retirada en_uso cocinando descansando lista].freeze
  ESTADO_LABELS = { 'retirada' => 'Retirada', 'en_uso' => 'En uso', 'cocinando' => 'Cocinando',
                    'descansando' => 'Descansando', 'lista' => 'Lista' }.freeze

  validates :nombre, presence: true, length: { maximum: 60 },
                     uniqueness: { scope: :sala_id, conditions: -> { where(deleted_at: nil) },
                                   message: 'ya existe en este espacio' }
  validates :largo_m, :ancho_m, numericality: { greater_than: 0, less_than: 1000 }, allow_nil: true
  validates :profundidad_cm, numericality: { greater_than: 0, less_than: 1000 }, allow_nil: true
  validates :semanas_coccion, :dias_descanso, :frecuencia_top_dress_dias,
            numericality: { only_integer: true, greater_than: 0, less_than: 10_000 }, allow_nil: true
  validate  :sala_de_cultivo
  validate  :entra_en_la_sala, if: -> { m2.present? && (will_save_change_to_largo_m? || will_save_change_to_ancho_m? || will_save_change_to_sala_id? || will_save_change_to_retirada_el?) }
  validate  :no_se_muda_con_plantas, if: -> { persisted? && will_save_change_to_sala_id? }
  validate  :no_se_retira_con_plantas, if: -> { will_save_change_to_retirada_el? && retirada_el.present? }
  validate  :lotes_entran_en_la_cama, if: -> { persisted? && (will_save_change_to_largo_m? || will_save_change_to_ancho_m?) }
  validate  :fechas_coherentes

  # La fecha en que termina de cocinarse sale del armado + las semanas que dijo el cultivador.
  # Se recalcula sólo cuando cambian esos dos datos: «ya está lista» la fija a mano (hoy).
  before_save :calcular_cocina_hasta, if: -> { will_save_change_to_armada_el? || will_save_change_to_semanas_coccion? }

  scope :vigentes, -> { where(retirada_el: nil) }
  # Las camas que ve cada uno: las de las salas que ve (misma regla que `SalasController#set_sala`).
  scope :al_alcance_de, ->(user) {
    if user.cultivador? || user.manicura?
      where(sala_id: user.salas_ids_asignadas)
    elsif user.supervisor?
      where(sala_id: Sala.where(sede_id: user.sedes_ids_asignadas).select(:id))
    else
      all
    end
  }

  # ── Medidas ────────────────────────────────────────────────────────────────
  def m2
    return nil if largo_m.blank? || ancho_m.blank?
    (largo_m.to_d * ancho_m.to_d).round(2)
  end

  # Litros de suelo: lo que necesita la receta de mezcla («3 g de kelp por litro de suelo»).
  def litros_suelo
    return nil if m2.nil? || profundidad_cm.blank?
    (m2 * profundidad_cm.to_d * 10).round(0) # 1 m² × 1 cm = 10 L
  end

  # ── Estado ─────────────────────────────────────────────────────────────────
  def lotes_en_cultivo = lotes.where(estado: Lote::CULTIVO_ESTADOS)

  def estado(hoy = Time.zone.today)
    return 'retirada'    if retirada_el.present?
    return 'en_uso'      if lotes_en_cultivo.exists?
    return 'cocinando'   if cocina_hasta.present? && cocina_hasta > hoy
    return 'descansando' if descansando?(hoy)
    'lista'
  end

  def descansando?(hoy = Time.zone.today)
    descansa_desde.present? && descansa_desde <= hoy && (descansa_hasta.nil? || descansa_hasta > hoy)
  end

  def ciclo_actual = ciclos.where(hasta: nil).order(:numero).last

  # ── Ciclos ─────────────────────────────────────────────────────────────────
  # El ciclo al que entra un lote que se planta hoy: el abierto, o uno nuevo. Plantar corta el
  # descanso (avisa la pantalla; no se bloquea: decisión de Germán, 22-sep).
  def ciclo_para_plantar!(fecha = Time.zone.today)
    abierto = ciclo_actual
    return abierto if abierto

    self.descansa_hasta = fecha if descansando?(fecha)
    save!(validate: false) if changed?
    numero = (ciclos.maximum(:numero) || 0) + 1
    ciclos.create!(club: club, numero: numero, desde: fecha)
  end

  # Cuando sale el último lote en cultivo, se cierra el ciclo y la cama pasa a descansar los días
  # que el cultivador le puso a ESTA cama (sin número, descansa hasta que diga «terminar»).
  # Devuelve true si la cama arrancó el descanso ahora.
  def cerrar_ciclo_si_vacia!(fecha = Time.zone.today)
    abierto = ciclo_actual
    return false if abierto.nil? || lotes_en_cultivo.exists?

    # Un ciclo que se quedó sin lotes ni registros no existió: el lote se cargó en la cama
    # equivocada y se corrigió, o se borró. No hay cosecha que cerrar ni descanso que empezar.
    if abierto.lotes.none? && abierto.registros.none?
      Lote.unscoped.where(cama_ciclo_id: abierto.id).update_all(cama_ciclo_id: nil)
      abierto.destroy!
      return false
    end

    abierto.update!(hasta: fecha)
    iniciar_descanso!(desde: fecha)
    true
  end

  def iniciar_descanso!(desde: Time.zone.today, dias: dias_descanso)
    update!(descansa_desde: desde, descansa_hasta: dias.present? ? desde + dias.to_i.days : nil)
  end

  def terminar_descanso!(hoy = Time.zone.today)
    update!(descansa_hasta: hoy)
  end

  # «Ya está lista»: la mezcla se da por cocida hoy, aunque faltaran días.
  def terminar_coccion!(hoy = Time.zone.today)
    update_columns(cocina_hasta: hoy, updated_at: Time.current)
    transmitir_cambio
  end

  # ── Qué viene ──────────────────────────────────────────────────────────────
  # Lo calcula el backend (como `Lote#proximo_paso`) para que teléfono y escritorio digan lo mismo.
  # nil cuando no hay nada que contar.
  def proximo_paso(hoy = Time.zone.today)
    case estado(hoy)
    when 'cocinando'
      { tipo: 'lista', fecha: cocina_hasta, faltan_dias: (cocina_hasta - hoy).to_i }
    when 'descansando'
      if descansa_hasta
        { tipo: 'fin_descanso', fecha: descansa_hasta, faltan_dias: (descansa_hasta - hoy).to_i }
      else
        { tipo: 'descansando', desde: descansa_desde, lleva_dias: (hoy - descansa_desde).to_i }
      end
    when 'en_uso'
      return nil if frecuencia_top_dress_dias.blank?
      ultimo = ultimo_top_dress_el || ciclo_actual&.desde || armada_el
      return nil if ultimo.nil?
      fecha = ultimo + frecuencia_top_dress_dias.days
      { tipo: 'top_dress', fecha: fecha, faltan_dias: (fecha - hoy).to_i, ultimo: ultimo }
    end
  end

  def ultimo_top_dress_el
    registros.where(tipo: %w[top_dress armado]).maximum(:registrado_en)&.to_date
  end

  # ── Plata y rendimiento ────────────────────────────────────────────────────
  # Todo lo que se le puso a la cama (armado, recargas, top dress, tés), esté cargado a un lote o
  # no. El armado no se le carga a ningún lote (Germán, 25-sep): queda como inversión de la cama.
  def invertido_ars = insumo_consumos.sum(:costo_imputado_ars).to_d

  def gramos_cosechados = lotes.sum(:rendimiento_real_g).to_d

  # «Gastaste $X y sacaste Y gramos»: el número que baja cosecha tras cosecha. nil sin cosecha.
  def costo_por_gramo
    g = gramos_cosechados
    g.positive? ? (invertido_ars / g).round(2) : nil
  end

  def edad_dias(hoy = Time.zone.today) = armada_el ? (hoy - armada_el).to_i : nil

  private

  def calcular_cocina_hasta
    self.cocina_hasta = armada_el && semanas_coccion ? armada_el + (semanas_coccion * 7).days : nil
  end

  def sala_de_cultivo
    return if sala.nil?
    errors.add(:sala, 'tiene que ser un espacio de cultivo') if Sala::KINDS_PROCESO.include?(sala.kind)
  end

  def entra_en_la_sala
    return if sala.nil? || sala.m2.blank? || retirada_el.present?

    libres = sala.m2_libres(excepto_cama: id)
    return if m2 <= libres

    errors.add(:base, "La cama mide #{fmt(m2)} m² y en #{sala.nombre} quedan #{fmt(libres)} m² libres " \
                      "(el espacio mide #{fmt(sala.m2)} m² y ya hay #{fmt(sala.m2_ocupados(excepto_cama: id))} m² ocupados)")
  end

  def no_se_muda_con_plantas
    return unless lotes_en_cultivo.exists?
    errors.add(:sala, 'no se puede cambiar con plantas en la cama: las raíces están ahí')
  end

  def no_se_retira_con_plantas
    return unless lotes_en_cultivo.exists?
    errors.add(:base, 'La cama tiene plantas: se retira cuando esté vacía')
  end

  def lotes_entran_en_la_cama
    return if m2.nil?
    ocupados = lotes_en_cultivo.sum(:m2_ocupados).to_d
    return if ocupados <= m2
    errors.add(:base, "Los lotes de la cama ocupan #{fmt(ocupados)} m²: la cama no puede medir menos (#{fmt(m2)} m²)")
  end

  def fechas_coherentes
    if descansa_desde && descansa_hasta && descansa_hasta < descansa_desde
      errors.add(:descansa_hasta, 'no puede ser anterior al inicio del descanso')
    end
    errors.add(:armada_el, 'no puede ser futura') if armada_el && armada_el > Time.zone.today
  end

  def fmt(n) = n.to_d.round(2).to_s('F').sub(/\.0\z/, '').tr('.', ',')
end
