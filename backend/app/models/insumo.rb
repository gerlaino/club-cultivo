# Insumo de cultivo en depósito (fertilizante, sustrato, macetas…). Se compra a granel y
# se consume a lo largo del tiempo imputando el costo al lote/sala donde se usó.
# Costeo: promedio ponderado móvil — `costo_promedio_ars` se recalcula en cada compra.
class Insumo < ApplicationRecord
  acts_as_paranoid
  acts_as_tenant(:club)

  belongs_to :club
  belongs_to :sede, optional: true # nil = pool del club (mismo criterio que Stock)
  belongs_to :categoria_contable, optional: true
  belongs_to :deposito, optional: true # dónde vive (reemplaza al enum `tipo`; se backfillea)
  has_many :insumo_compras,  dependent: :destroy
  has_many :insumo_consumos, dependent: :destroy

  # Se levanta al querer revertir una compra que ya fue consumida/distribuida.
  Consumido = Class.new(StandardError)

  UNIDADES = %w[unidad litro mililitro kilogramo gramo bolsa metro otro].freeze
  # Familia hardcodeada → define el depósito de la sede. El bar es aparte (BarProducto).
  TIPOS = %w[cultivo general].freeze

  validates :nombre, presence: true
  validates :unidad_medida, inclusion: { in: UNIDADES }
  validates :tipo, inclusion: { in: TIPOS }
  validates :stock_actual, :costo_promedio_ars, :stock_minimo,
            numericality: { greater_than_or_equal_to: 0 }

  scope :activos,    -> { where(activo: true) }
  scope :stock_bajo, -> { where('stock_minimo > 0 AND stock_actual <= stock_minimo') }
  scope :por_tipo,   ->(tipo) { tipo.present? ? where(tipo: tipo) : self }
  # Contexto de sede: un id filtra esa sede; 'pool' filtra el pool sin sede; nil = todas.
  scope :de_sede,    ->(sede_id) {
    if sede_id.to_s == 'pool' then where(sede_id: nil)
    elsif sede_id.present?     then where(sede_id: sede_id)
    else self
    end
  }

  def valorizado_ars
    (stock_actual.to_d * costo_promedio_ars.to_d).round(2)
  end

  def stock_bajo?
    stock_minimo.to_d.positive? && stock_actual.to_d <= stock_minimo.to_d
  end

  # Compra: suma stock y recalcula el costo promedio ponderado móvil. Opcionalmente genera
  # el egreso en el libro contable (la plata sale al comprar). Devuelve la InsumoCompra.
  def registrar_compra!(cantidad:, costo_total_ars:, created_by:, proveedor: nil,
                        fecha: Date.current, sede: nil, generar_egreso: true,
                        medio_pago: 'efectivo', pagado: true)
    cantidad    = cantidad.to_d
    costo_total = costo_total_ars.to_d
    raise ArgumentError, 'La cantidad debe ser mayor a 0' if cantidad <= 0
    raise ArgumentError, 'El costo debe ser mayor a 0'    if costo_total <= 0

    transaction do
      nuevo_stock = stock_actual.to_d + cantidad
      # Promedio ponderado móvil: (valor_previo + valor_compra) / stock_total
      self.costo_promedio_ars = ((stock_actual.to_d * costo_promedio_ars.to_d) + costo_total) / nuevo_stock
      self.stock_actual = nuevo_stock
      save!

      compra = insumo_compras.create!(
        club: club, created_by: created_by,
        cantidad: cantidad, costo_total_ars: costo_total,
        costo_unitario_ars: (costo_total / cantidad).round(4),
        proveedor: proveedor, fecha: fecha
      )

      if generar_egreso
        mov = club.movimientos_contables.create!(
          sede: sede, created_by: created_by, tipo: 'egreso',
          categoria: 'insumo', categoria_contable: categoria_contable,
          # El área la manda el depósito donde vive el insumo; la categoría queda de respaldo.
          unidad_negocio_id: deposito&.unidad_negocio_id || categoria_contable&.unidad_negocio_id,
          # "1000 unidad", no "1000.0 unidad": el `.0` de un decimal entero se lee como si el
          # número siguiera, y al lado de un monto vuelve ambiguo si el importe es por unidad
          # o total. Los decimales sólo aparecen cuando los hay (2.5 litros).
          descripcion: "Compra insumo — #{nombre} (#{cantidad_legible(cantidad)} #{unidad_medida})",
          monto_ars: costo_total, fecha: fecha, proveedor: proveedor,
          pagado: pagado, medio_pago: medio_pago
        )
        compra.update!(movimiento_contable: mov)
      end

      compra
    end
  end

  # Revierte una compra: baja el stock por la cantidad comprada y recalcula el costo promedio
  # con las compras restantes. Bloquea si ya se consumió/distribuyó parte (no queda stock sin
  # consumir para revertir entero). NO toca el movimiento contable asociado — eso lo hace el
  # caller (borrar el movimiento o la compra desde el otro lado), para no recursar.
  def revertir_compra!(compra)
    cantidad = compra.cantidad.to_d
    if stock_actual.to_d < cantidad
      restante = stock_actual.to_d
      raise Consumido, "Ya se consumió o distribuyó parte de esta compra: quedan #{restante.to_s('F')} de #{cantidad.to_s('F')} #{unidad_medida}. Desasigná el consumo o la transferencia primero."
    end
    transaction do
      compra.destroy!
      restantes = insumo_compras.reload.to_a
      self.stock_actual = (stock_actual.to_d - cantidad)
      self.costo_promedio_ars = if restantes.any? && restantes.sum { |c| c.cantidad.to_d } > 0
        (restantes.sum { |c| c.costo_total_ars.to_d } / restantes.sum { |c| c.cantidad.to_d }).round(4)
      else
        0
      end
      save!
    end
  end

  MOTIVOS_RECONTEO = %w[correccion merma].freeze

  # Reconteo de inventario: lleva el stock al valor físico contado. Dos motivos, dos efectos:
  #  - 'correccion': error humano al cargar (se tipeó mal la cantidad). Corrige el dato; puede
  #    subir o bajar el stock. SIN impacto contable (no hubo pérdida real de plata).
  #  - 'merma': pérdida real (rotura, vencimiento, robo). Descuenta el faltante y lo deja en el
  #    historial como merma. NO genera un egreso nuevo: la compra ya se imputó como gasto —
  #    duplicarlo inflaría el P&L. Solo puede bajar el stock.
  # Devuelve self. No hace nada si el conteo coincide con el stock actual.
  def reconciliar_stock!(nuevo_stock:, motivo:, created_by:, notas: nil, fecha: Date.current)
    nuevo  = nuevo_stock.to_d
    actual = stock_actual.to_d
    raise ArgumentError, 'El stock contado no puede ser negativo' if nuevo < 0
    raise ArgumentError, 'Motivo de reconteo inválido'           unless MOTIVOS_RECONTEO.include?(motivo.to_s)
    return self if nuevo == actual

    if motivo.to_s == 'merma'
      raise ArgumentError, 'La merma solo baja el stock; si contaste de más es una corrección' if nuevo > actual
      registrar_consumo!(
        cantidad: actual - nuevo, created_by: created_by, fecha: fecha,
        notas: "Merma — #{notas.presence || 'reconteo de inventario'}"
      )
    else # correccion
      transaction do
        self.stock_actual = nuevo
        save!
      end
    end
    self
  end

  # Consumo: descuenta stock e imputa el costo (al promedio actual) al lote/sala. Refleja el
  # costo en el CostoLote. Devuelve la InsumoConsumo. Lanza si no hay stock suficiente.
  def registrar_consumo!(cantidad:, created_by:, lote: nil, sala: nil,
                         fecha: Date.current, notas: nil)
    cantidad = cantidad.to_d
    raise ArgumentError, 'La cantidad debe ser mayor a 0' if cantidad <= 0
    raise ArgumentError, 'Stock insuficiente'             if cantidad > stock_actual.to_d

    consumo = transaction do
      costo_imputado   = (cantidad * costo_promedio_ars.to_d).round(2)
      self.stock_actual = stock_actual.to_d - cantidad
      save!

      c = insumo_consumos.create!(
        club: club, created_by: created_by,
        cantidad: cantidad, costo_imputado_ars: costo_imputado,
        lote: lote, sala: sala, fecha: fecha, notas: notas
      )
      # El costo del lote se recalcula para reflejar el consumo imputado.
      CostoDesdeLibroService.new(lote: lote, actualizado_por: created_by).call if lote
      c
    end

    avisar_reposicion! # best-effort, fuera de la transacción del consumo
    consumo
  end

  # Consumo repartido en partes iguales entre varios lotes (y/o una sala). Ej: "3 L a los lotes
  # OG-24 y GG-11" → 1,5 L a cada uno, cada uno con su costo imputado. Atómico.
  def registrar_consumo_repartido!(cantidad:, created_by:, lotes: [], sala: nil,
                                   fecha: Date.current, notas: nil)
    total  = cantidad.to_d
    lotes  = Array(lotes).compact
    raise ArgumentError, 'La cantidad debe ser mayor a 0' if total <= 0
    raise ArgumentError, 'Stock insuficiente'             if total > stock_actual.to_d

    transaction do
      if lotes.empty?
        [registrar_consumo!(cantidad: total, created_by: created_by, sala: sala, fecha: fecha, notas: notas)]
      else
        base = (total / lotes.size).round(3)
        lotes.each_with_index.map do |lote, i|
          # el último absorbe el redondeo para que la suma sea exacta
          cant = i == lotes.size - 1 ? (total - base * (lotes.size - 1)) : base
          registrar_consumo!(cantidad: cant, created_by: created_by, lote: lote, sala: sala, fecha: fecha, notas: notas)
        end
      end
    end
  end

  # Transfiere una cantidad de este insumo a otra sede. Réplica del criterio de Stock ("siempre
  # está en alguna sede, se puede mover una parte"), pero con el costeo propio del insumo:
  # el origen descuenta stock (su promedio no cambia) y el destino recibe la cantidad valorizada
  # al promedio del origen, recalculando SU propio promedio ponderado. Si en la sede destino no
  # existe el mismo insumo (nombre+unidad), lo crea. No genera egreso: la plata ya salió al comprar.
  # Devuelve el insumo destino.
  def transferir_a!(sede_destino:, cantidad:, created_by:)
    cantidad = cantidad.to_d
    raise ArgumentError, 'La cantidad debe ser mayor a 0' if cantidad <= 0
    raise ArgumentError, 'Stock insuficiente'             if cantidad > stock_actual.to_d
    raise ArgumentError, 'Elegí una sede destino'         if sede_destino.nil?
    raise ArgumentError, 'La sede destino es la misma'    if sede_destino.id == sede_id

    valor = (cantidad * costo_promedio_ars.to_d)

    transaction do
      destino = club.insumos.where(sede_id: sede_destino.id, nombre: nombre, unidad_medida: unidad_medida)
                    .first_or_initialize
      if destino.new_record?
        # Heredar `tipo` (cultivo/general): sin esto el destino cae al default 'cultivo' y un
        # insumo General transferido aparecía en la solapa Cultivo de la otra sede.
        destino.assign_attributes(stock_minimo: stock_minimo, categoria_contable: categoria_contable,
                                  tipo: tipo, stock_actual: 0, costo_promedio_ars: 0, activo: true)
      end
      nuevo_stock = destino.stock_actual.to_d + cantidad
      destino.costo_promedio_ars = ((destino.stock_actual.to_d * destino.costo_promedio_ars.to_d) + valor) / nuevo_stock
      destino.stock_actual = nuevo_stock
      destino.save!

      update!(stock_actual: stock_actual.to_d - cantidad) # el promedio del origen no cambia
      destino
    end
  end

  # Transferencia a OTRO depósito (mismo club). Reclasifica stock: baja del origen y sube al mismo
  # insumo (nombre+unidad) del depósito destino — lo crea si no existe, heredando su sede y tipo.
  # NO genera egreso (la plata ya salió al comprar); el costo se mueve con la mercadería. La flor y
  # el salón (familia 'mercaderia') quedan afuera: su stock se genera/opera en otro lado.
  def transferir_a_deposito!(deposito_destino:, cantidad:, created_by:)
    cantidad = cantidad.to_d
    raise ArgumentError, 'La cantidad debe ser mayor a 0'  if cantidad <= 0
    raise ArgumentError, 'Stock insuficiente'              if cantidad > stock_actual.to_d
    raise ArgumentError, 'Elegí un depósito destino'       if deposito_destino.nil?
    raise ArgumentError, 'El depósito destino es el mismo' if deposito_destino.id == deposito_id
    raise ArgumentError, 'Ese depósito no admite insumos (flor/salón se manejan en su módulo)' if deposito_destino.familia == 'mercaderia'

    valor = cantidad * costo_promedio_ars.to_d
    transaction do
      destino = club.insumos.where(deposito_id: deposito_destino.id, nombre: nombre, unidad_medida: unidad_medida).first_or_initialize
      if destino.new_record?
        destino.assign_attributes(
          sede_id: deposito_destino.sede_id, deposito: deposito_destino,
          tipo: deposito_destino.clave_sistema == 'cultivo' ? 'cultivo' : 'general',
          stock_minimo: stock_minimo, categoria_contable: categoria_contable,
          stock_actual: 0, costo_promedio_ars: 0, activo: true
        )
      end
      nuevo_stock = destino.stock_actual.to_d + cantidad
      destino.costo_promedio_ars = ((destino.stock_actual.to_d * destino.costo_promedio_ars.to_d) + valor) / nuevo_stock
      destino.stock_actual = nuevo_stock
      destino.save!

      update!(stock_actual: stock_actual.to_d - cantidad) # el promedio del origen no cambia
      destino
    end
  end

  # Baja pura de stock, sin asiento ni consumo imputado a un lote: la usa la reserva de un evento
  # (apartar del depósito) y la venta por el mostrador del salón. El costo ya se gastó al comprar.
  def descontar_stock!(cantidad:)
    cantidad = cantidad.to_d
    raise ArgumentError, 'Cantidad inválida'                 if cantidad <= 0
    raise ArgumentError, "Sin stock suficiente de #{nombre}" if cantidad > stock_actual.to_d
    update!(stock_actual: stock_actual.to_d - cantidad)
  end

  # Reposición pura: sobrante de un evento que vuelve, o venta borrada.
  def reponer_stock!(cantidad:)
    cantidad = cantidad.to_d
    return if cantidad <= 0
    update!(stock_actual: stock_actual.to_d + cantidad)
  end

  # Alias por claridad en el flujo de eventos (misma mecánica).
  alias reservar_para_evento! descontar_stock!
  alias devolver_para_evento! reponer_stock!

  # Aviso activo de reposición cuando el stock llega al mínimo. Best-effort (no bloquea el consumo)
  # y con anti-spam de 12 h por insumo. Aparece en las alertas internas del admin.
  def avisar_reposicion!
    return unless stock_bajo?
    return if AlertaInterna.where(club_id: club_id, tipo: 'stock_bajo')
                           .where("contexto ->> 'insumo_id' = ?", id.to_s)
                           .where('created_at > ?', 12.hours.ago).exists?

    club.alertas_internas.create!(
      tipo: 'stock_bajo', severidad: 'warning', destinada_a_role: 'admin',
      mensaje: "Reponer #{nombre}: quedan #{stock_actual.to_f.round(2)} #{unidad_medida} (mínimo #{stock_minimo.to_f.round(2)}).",
      contexto: { 'insumo_id' => id, 'origen' => 'insumo' }
    )
  rescue StandardError => e
    Rails.logger.error "[Insumo] aviso de reposición: #{e.message}"
  end

  # 1000 → "1000"; 2.5 → "2.5". Sin el ".0" que arrastra `to_s('F')` en los enteros.
  def cantidad_legible(valor)
    d = valor.to_d
    d == d.to_i ? d.to_i.to_s : d.to_s('F')
  end
end
