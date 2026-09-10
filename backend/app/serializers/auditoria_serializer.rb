# Presenta una fila del rastro (`auditorias`) para que la lea un ADMIN, no un DBA.
#
# Nace de tres cosas que la pantalla mostraba mal y que eran todas la misma causa —la fila
# describía la operación de la BASE en vez del hecho:
#   · "Editó" cuando la persona en realidad ENTREGÓ un paquete (`update` es el verbo de Rails,
#     no el de nadie más);
#   · `[object Object]` porque `historial_envio` es un array jsonb y el front hacía `String(v)`;
#   · cinco renglones por entrega de los cuales cuatro repetían la acción en jerga
#     (`estado_envio: en_viaje → entregado`, `entregado at: → 2026-09-09T15:49:50.752-03:00`).
#
# Regla que lo ordena: CUANDO EL CAMBIO SE PUEDE NOMBRAR, LOS CAMPOS QUE LO COMPONEN NO SE
# REPITEN EN EL DETALLE. Si la fila dice "Entregó", `estado_envio` y `entregado_at` sobran.
#
# Vive acá y no en el front porque son dos consumidores (el panel del usuario y el historial del
# super admin) y la misma regla escrita dos veces es de donde salen las divergencias.
class AuditoriaSerializer
  # Los 13 modelos auditados, con nombre de persona. Faltaban cinco y la pantalla mostraba el
  # de la clase —"RendicionCaja", "TurnoMostradorItem"—, que es el mismo error de fondo que
  # "Editó" en vez de "Entregó": jerga de la base delante de quien no la escribió.
  TIPOS = {
    'Lote' => 'Lote', 'Plant' => 'Planta', 'Stock' => 'Stock', 'Dispensacion' => 'Dispensación',
    'Paciente' => 'Paciente', 'User' => 'Usuario', 'Reserva' => 'Reserva', 'Club' => 'Organización',
    'CajaTurno' => 'Caja', 'RendicionCaja' => 'Rendición', 'MovimientoContable' => 'Movimiento contable',
    'TurnoMostrador' => 'Cierre de caja', 'TurnoMostradorItem' => 'Conteo de un producto',
  }.freeze

  # Campos internos que no significan nada para quien lee, y los jsonb/blob de registros VIEJOS
  # (anteriores al `auditar_solo` de Dispensacion) que ya no se guardan pero siguen en la tabla.
  CAMPOS_OCULTOS = %w[
    id created_at updated_at deleted_at deleted_by_id club_id
    historial_envio producto_snapshot token
  ].freeze

  # Qué pasó, deducido del cambio. `campos` son los que COMPONEN esa acción y por eso salen del
  # detalle: decirlos otra vez es decir dos veces lo mismo, una de ellas en idioma de base.
  ACCIONES_POR_ESTADO = {
    'entregado' => { label: 'Entregó',            tono: 'ok',      campos: %w[estado_envio entregado_at] },
    'fallido'   => { label: 'No pudo entregar',   tono: 'alerta',  campos: %w[estado_envio fallido_at] },
    'en_viaje'  => { label: 'Salió a repartir',   tono: 'editar',  campos: %w[estado_envio] },
    'cancelada' => { label: 'Canceló el envío',   tono: 'alerta',  campos: %w[estado_envio] },
    'pendiente' => { label: 'Reprogramó',         tono: 'editar',  campos: %w[estado_envio motivo_fallo] },
  }.freeze

  ACCIONES_BASE = {
    'crear'      => { label: 'Creó',    tono: 'crear' },
    'actualizar' => { label: 'Editó',   tono: 'editar' },
    'eliminar'   => { label: 'Eliminó', tono: 'eliminar' },
  }.freeze

  CAMPO_LABEL = {
    'tamano_maceta' => 'tamaño de maceta', 'precio_sugerido_ars' => 'precio sugerido',
    'costo_unitario_ars' => 'costo unitario', 'precio_unitario_ars' => 'precio unitario',
    'sala_id' => 'sala', 'sede_id' => 'sede', 'genetica_id' => 'genética',
    'stock_id' => 'producto', 'paciente_id' => 'paciente', 'delivery_id' => 'repartidor',
    'ruta_entrega_id' => 'ruta', 'indicacion_medica_id' => 'indicación médica',
    'codigo' => 'código', 'descripcion' => 'descripción', 'categoria' => 'categoría',
    'medio_pago' => 'medio de pago', 'aporte_socio_ars' => 'aporte', 'monto_credito_ars' => 'a crédito',
    'descuento_dispensa_pct' => 'descuento', 'descuento_paciente_pct' => 'descuento del paciente',
    'fecha_dispensacion' => 'fecha', 'estado_envio' => 'estado del envío',
    'notas_entrega' => 'notas de entrega', 'motivo_fallo' => 'motivo del fallo',
    'codigo_paquete' => 'paquete', 'direccion_envio' => 'dirección de envío',
    'cobrar_en_entrega' => 'cobra al entregar', 'orden_entrega' => 'orden en la ruta',
    'es_regalo' => 'regalo', 'con_envio' => 'con envío',
    'fecha_nacimiento' => 'fecha de nacimiento', 'reprocann_vencimiento' => 'venc. REPROCANN',
    'reprocann_estado' => 'estado REPROCANN', 'role' => 'rol',
    'first_name' => 'nombre', 'last_name' => 'apellido', 'email_personal' => 'email personal',
    'fecha_entrega_estimada' => 'fecha de entrega', 'sena_ars' => 'seña',
    'aporte_estimado_ars' => 'aporte estimado', 'contacto_nombre' => 'contacto',
    'contacto_telefono' => 'tel. de contacto',
  }.freeze

  VALOR_LABEL = {
    'estado_envio' => {
      'pendiente' => 'pendiente', 'en_viaje' => 'en viaje', 'entregado' => 'entregado',
      'fallido' => 'fallido', 'cancelada' => 'cancelada',
    },
    'medio_pago' => {
      'efectivo' => 'efectivo', 'transferencia' => 'transferencia',
      'cuenta_corriente' => 'cuenta corriente', 'no_abona' => 'no abona',
      'credito_gramos' => 'crédito en gramos', 'mixto' => 'mixto', 'regalo' => 'regalo',
    },
  }.freeze

  def self.serialize(a)
    new(a).to_h
  end

  def initialize(auditoria)
    @a       = auditoria
    @cambios = auditoria.cambios.is_a?(Hash) ? auditoria.cambios : {}
  end

  def to_h
    accion = resolver_accion
    {
      id:           @a.id,
      accion:       @a.accion, # crear | actualizar | eliminar (el verbo de la base, para filtrar)
      accion_label: accion[:label],
      accion_tono:  accion[:tono],
      tipo:         TIPOS[@a.auditable_type] || @a.auditable_type,
      registro_id:  @a.auditable_id,
      fecha:        @a.created_at,
      # El antes→después sólo tiene sentido en un update: un alta o una baja se explican solas.
      cambios:      @a.accion == 'actualizar' ? diffs(accion[:campos] || []) : [],
      notas:        notas,
    }
  end

  private

  # Nombra el hecho. Sin regla que aplique, cae al verbo genérico.
  def resolver_accion
    base = ACCIONES_BASE[@a.accion] || { label: @a.accion, tono: 'editar' }
    return base unless @a.accion == 'actualizar'

    destino = par('estado_envio')&.last
    ACCIONES_POR_ESTADO[destino] || base
  end

  # [{campo, de, a}] ya humanizados, sin lo interno, sin lo que ya dijo la acción, y sin los
  # cambios que no cambiaron nada a la vista (típico: nil → "", que se lee "— → —").
  def diffs(campos_de_la_accion)
    ocultos = CAMPOS_OCULTOS + campos_de_la_accion + %w[firma_entrega_data]
    @cambios.except(*ocultos).filter_map do |campo, valores|
      next unless valores.is_a?(Array) && valores.size == 2

      de = formato(campo, valores[0])
      a  = formato(campo, valores[1])
      next if de.blank? && a.blank?
      next if de == a

      { campo: CAMPO_LABEL[campo] || campo.tr('_', ' '), de: de, a: a }
    end
  end

  # Hechos que no son un "antes → después": no se muestran con flecha porque no hay nada que
  # comparar. Lo que importa de una firma es que se capturó, no su base64 de 40 KB.
  #
  # ES DE TRANSICIÓN, a propósito: desde `Dispensacion.auditar_solo` la firma ya NO entra al
  # rastro, así que esto sólo aplica a las filas viejas, y deja de aplicar del todo cuando corra
  # `rake auditorias:limpiar_blobs`. No es una pérdida: que hubo firma vive en `historial_envio`
  # de la dispensa —donde el job de retención escribe también que la borró— que es su lugar.
  # Mientras tanto, mostrarlo es mejor que tragárselo en silencio.
  def notas
    firma = par('firma_entrega_data')
    return [] unless firma && firma[1].present?

    ['Firma capturada']
  end

  def par(campo)
    v = @cambios[campo]
    v.is_a?(Array) && v.size == 2 ? v : nil
  end

  # Un valor que un admin pueda leer. Nunca `to_s` a ciegas: un jsonb sale "[object Object]"
  # del otro lado, que fue el bug que originó todo esto.
  def formato(campo, valor)
    return nil if valor.nil? || valor == ''
    return (valor ? 'Sí' : 'No') if [true, false].include?(valor)
    return nil if valor.is_a?(Hash) || valor.is_a?(Array)

    if (mapa = VALOR_LABEL[campo])
      return mapa[valor.to_s] || valor.to_s
    end

    return formato_numero(campo, valor) if numerico?(valor)

    formato_texto(campo, valor.to_s)
  end

  # Los decimales viajan en el jsonb como STRING ("212500.0"): ActiveSupport serializa BigDecimal
  # así para no perder precisión. Sin esto, un aporte se mostraba crudo con el .0 colgando.
  def numerico?(valor)
    valor.is_a?(Numeric) || (valor.is_a?(String) && valor.match?(/\A-?\d+(\.\d+)?\z/))
  end

  def formato_numero(campo, valor)
    v = valor.to_d
    return "$#{ActiveSupport::NumberHelper.number_to_delimited(v.to_i, delimiter: '.')}" if campo.end_with?('_ars')
    return v.to_i.to_s if v == v.to_i

    ActiveSupport::NumberHelper.number_to_delimited(v, delimiter: '.', separator: ',')
  end

  # Las fechas llegan como string ISO desde el jsonb. Crudas son ilegibles y, encima, la hora ya
  # está en la columna Fecha de la fila.
  def formato_texto(_campo, texto)
    if texto.match?(/\A\d{4}-\d{2}-\d{2}(T| |\z)/)
      begin
        t = Time.zone.parse(texto)
        return texto.length <= 10 ? I18n.l(t.to_date, format: '%-d %b %Y') : I18n.l(t, format: '%-d %b %Y, %H:%M')
      rescue ArgumentError, I18n::ArgumentError
        return texto
      end
    end
    texto
  end
end
