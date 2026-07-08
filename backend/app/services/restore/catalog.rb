module Restore
  # Catálogo único de entidades restaurables que consume la papelera. Cada entrada describe
  # un agregado TOP-LEVEL (lo que un admin restaura como unidad). Los dependientes (cobros,
  # movimientos, eventos, actividades) NO se listan: vuelven con su padre.
  #
  # `complex: true` = la restauración re-aplica efectos colaterales y necesita un Restorer con
  # validación de conflictos (Fase 3). Hasta entonces la papelera no las restaura.
  module Catalog
    Entry = Struct.new(:key, :model_name, :label, :group, :complex, :restorer, :top_level, :descriptor, :search, keyword_init: true) do
      def model = model_name.constantize
      def complex? = complex

      # Los dependientes (cobros, movimientos, etc.) NO se listan en la papelera: vuelven con su
      # agregado padre (Dispensación/Stock). top_level: false los excluye del listado.
      def top_level? = top_level.nil? ? true : top_level

      # Clase Restorer dedicada (validación + re-aplicación de efectos), si la entidad la tiene.
      def restorer_class = restorer&.constantize

      # ¿Se puede restaurar hoy desde la papelera? Las simples siempre; las complejas, solo si
      # ya tienen su Restorer implementado.
      def restaurable_ahora? = !complex? || restorer.present?

      # Texto humano para identificar el registro en la lista.
      def describe(record)
        return descriptor.call(record) if descriptor
        %i[nombre titulo codigo name descripcion].each do |f|
          v = record.respond_to?(f) ? record.public_send(f) : nil
          return v if v.present?
        end
        "##{record.id}"
      end

      # Columnas de texto sobre las que filtra el buscador.
      def search_columns = search || %i[nombre titulo codigo descripcion]
    end

    NOMBRE_PACIENTE = ->(r) { [r.try(:nombre), r.try(:apellido)].compact.join(' ').presence || "Paciente ##{r.id}" }

    ENTRIES = [
      # --- Cultivo -------------------------------------------------------------
      { key: 'genetica',            model_name: 'Genetica',           label: 'Genética',            group: 'Cultivo' },
      { key: 'lote',                model_name: 'Lote',               label: 'Lote',                group: 'Cultivo', descriptor: ->(r) { r.try(:codigo).presence || "Lote ##{r.id}" } },
      { key: 'plant',               model_name: 'Plant',              label: 'Planta',              group: 'Cultivo', descriptor: ->(r) { r.try(:codigo).presence || r.try(:qr_token).presence || "Planta ##{r.id}" } },
      { key: 'sala',                model_name: 'Sala',               label: 'Sala',                group: 'Cultivo' },
      { key: 'plan_trabajo',        model_name: 'PlanTrabajo',        label: 'Plan de trabajo',     group: 'Cultivo' },
      { key: 'tarea',               model_name: 'Tarea',              label: 'Tarea',               group: 'Cultivo' },
      { key: 'analisis_laboratorio',model_name: 'AnalisisLaboratorio',label: 'Análisis de laboratorio', group: 'Cultivo' },
      { key: 'analisis_ia',         model_name: 'AnalisisIa',         label: 'Análisis IA',         group: 'Cultivo' },

      # --- Socios / Pacientes --------------------------------------------------
      { key: 'paciente',            model_name: 'Paciente',           label: 'Socio / Paciente',    group: 'Socios', descriptor: NOMBRE_PACIENTE, search: %i[nombre apellido dni email] },
      { key: 'reprocann_renovacion',model_name: 'ReprocannRenovacion',label: 'Renovación REPROCANN',group: 'Socios' },
      { key: 'patient_document',    model_name: 'PatientDocument',    label: 'Documento de paciente', group: 'Socios' },
      { key: 'documento',           model_name: 'Documento',          label: 'Documento',           group: 'Socios' },
      { key: 'evento',              model_name: 'Evento',             label: 'Evento',              group: 'Socios' },
      { key: 'mail_enviado',        model_name: 'MailEnviado',        label: 'Correo enviado',      group: 'Socios', descriptor: ->(r) { r.try(:asunto).presence || "Correo ##{r.id}" } },
      { key: 'cuenta_corriente',    model_name: 'CuentaCorriente',    label: 'Cuenta corriente',    group: 'Socios' },

      # --- Médico --------------------------------------------------------------
      { key: 'turno',               model_name: 'Turno',              label: 'Turno',               group: 'Médico' },
      { key: 'indicacion_medica',   model_name: 'IndicacionMedica',   label: 'Indicación médica',   group: 'Médico' },
      { key: 'check_in',            model_name: 'CheckIn',            label: 'Check-in',            group: 'Médico' },
      { key: 'disponibilidad_medico',model_name: 'DisponibilidadMedico',label: 'Disponibilidad médica', group: 'Médico' },

      # --- Delivery ------------------------------------------------------------
      { key: 'ruta_entrega',        model_name: 'RutaEntrega',        label: 'Ruta de entrega',     group: 'Delivery' },

      # --- IoT / Ambiente ------------------------------------------------------
      { key: 'dispositivo',         model_name: 'Dispositivo',        label: 'Dispositivo',         group: 'Ambiente' },
      { key: 'regla_ambiental',     model_name: 'ReglaAmbiental',     label: 'Regla ambiental',     group: 'Ambiente' },
      { key: 'setpoint_fase',       model_name: 'SetpointFase',       label: 'Setpoint por fase',   group: 'Ambiente' },
      { key: 'alerta',              model_name: 'Alerta',             label: 'Alerta',              group: 'Ambiente' },

      # --- Operación / Configuración ------------------------------------------
      { key: 'jornada_laboral',     model_name: 'JornadaLaboral',     label: 'Jornada laboral',     group: 'Operación' },
      { key: 'noticia',             model_name: 'Noticia',            label: 'Noticia',             group: 'Configuración' },
      { key: 'document_template',   model_name: 'DocumentTemplate',   label: 'Plantilla de documento', group: 'Configuración' },
      { key: 'sede',                model_name: 'Sede',               label: 'Sede',                group: 'Configuración' },
      { key: 'user',                model_name: 'User',               label: 'Usuario',             group: 'Configuración', descriptor: ->(r) { [r.try(:first_name), r.try(:last_name)].compact.join(' ').presence || r.try(:email) || "Usuario ##{r.id}" }, search: %i[first_name last_name email] },

      # --- Complejas (necesitan Restorer con validación — Fase 3) --------------
      # Restaura tanto medio único (legacy) como cobros partidos (mixto/contra-entrega).
      { key: 'dispensacion',        model_name: 'Dispensacion',       label: 'Dispensación',        group: 'Dispensación', complex: true, restorer: 'Restore::Restorers::Dispensacion', descriptor: ->(r) { "Dispensación ##{r.id}" } },
      { key: 'stock',               model_name: 'Stock',              label: 'Stock',               group: 'Stock', complex: true, restorer: 'Restore::Restorers::Stock' },
      # Dependientes: vuelven con su agregado padre (Dispensación/Stock), no se listan sueltos.
      { key: 'stock_movimiento',    model_name: 'StockMovimiento',    label: 'Movimiento de stock', group: 'Stock', complex: true, top_level: false, descriptor: ->(r) { "Movimiento ##{r.id}" } },
      { key: 'cobro',               model_name: 'Cobro',              label: 'Cobro',               group: 'Dispensación', complex: true, top_level: false, descriptor: ->(r) { "Cobro ##{r.id}" } },
      { key: 'dispensacion_item',   model_name: 'DispensacionItem',   label: 'Línea de dispensación', group: 'Dispensación', complex: true, top_level: false, descriptor: ->(r) { "Línea ##{r.id}" } },
      { key: 'cuenta_corriente_movimiento', model_name: 'CuentaCorrienteMovimiento', label: 'Movimiento de cuenta corriente', group: 'Socios', complex: true, top_level: false, descriptor: ->(r) { "Movimiento ##{r.id}" } },
      { key: 'movimiento_contable', model_name: 'MovimientoContable', label: 'Movimiento contable', group: 'Contabilidad', complex: true, top_level: false, descriptor: ->(r) { "Asiento ##{r.id}" } },
      { key: 'costo_lote',          model_name: 'CostoLote',          label: 'Costo de lote',       group: 'Contabilidad', complex: true, restorer: 'Restore::Restorers::CostoLote', descriptor: ->(r) { "Costo ##{r.id}" } },
      # Pesada/PesajeManicura: el stock que crearon NO se borra con ellas, así que restaurar es
      # solo des-borrar (con su detalle). Sin efectos a re-aplicar → restore simple.
      { key: 'pesada',              model_name: 'Pesada',             label: 'Pesada',              group: 'Cultivo', descriptor: ->(r) { "Pesada ##{r.id}" } },
      { key: 'pesaje_manicura',     model_name: 'PesajeManicura',     label: 'Pesaje de manicura',  group: 'Cultivo', descriptor: ->(r) { "Pesaje ##{r.id}" } },
      { key: 'reserva',             model_name: 'Reserva',            label: 'Reserva',             group: 'Stock', complex: true, restorer: 'Restore::Restorers::Reserva', descriptor: ->(r) { "Reserva ##{r.id}" } },
      { key: 'ariccame_registro',   model_name: 'AriccameRegistro',   label: 'Registro ARICCAME',   group: 'Regulatorio', complex: true, restorer: 'Restore::Restorers::AriccameRegistro', descriptor: ->(r) { "Registro ##{r.id}" } },

      # --- Bar -----------------------------------------------------------------
      { key: 'bar',                 model_name: 'Bar',                label: 'Bar',                 group: 'Bar' },
      { key: 'bar_producto',        model_name: 'BarProducto',        label: 'Producto de bar',     group: 'Bar' },
      # La venta re-descuenta stock y re-crea el ingreso al restaurar → compleja con restorer.
      { key: 'bar_venta',           model_name: 'BarVenta',           label: 'Venta de bar',        group: 'Bar', complex: true, restorer: 'Restore::Restorers::BarVenta', descriptor: ->(r) { "Venta ##{r.id}" } },
      { key: 'bar_venta_item',      model_name: 'BarVentaItem',       label: 'Línea de venta de bar', group: 'Bar', complex: true, top_level: false, descriptor: ->(r) { "Línea ##{r.id}" } },

      # --- Eventos de bar ------------------------------------------------------
      # El evento vuelve con sus costos/tareas y re-crea los egresos de los costos pagados.
      { key: 'evento_bar',          model_name: 'EventoBar',          label: 'Evento de bar',       group: 'Bar', complex: true, restorer: 'Restore::Restorers::EventoBar', descriptor: ->(r) { r.try(:nombre).presence || "Evento ##{r.id}" } },
      # El costo re-aplica su egreso si estaba pagado.
      { key: 'evento_bar_costo',    model_name: 'EventoBarCosto',     label: 'Costo de evento',     group: 'Bar', complex: true, restorer: 'Restore::Restorers::EventoBarCosto', descriptor: ->(r) { r.try(:concepto).presence || "Costo ##{r.id}" } },
      { key: 'evento_bar_tarea',    model_name: 'EventoBarTarea',     label: 'Tarea de evento',     group: 'Bar', descriptor: ->(r) { r.try(:titulo).presence || "Tarea ##{r.id}" } },
      { key: 'evento_bar_tipo_entrada', model_name: 'EventoBarTipoEntrada', label: 'Tipo de entrada', group: 'Bar', complex: true, restorer: 'Restore::Restorers::EventoBarTipoEntrada', descriptor: ->(r) { r.try(:nombre).presence || "Tipo ##{r.id}" } },
      { key: 'evento_bar_entrada',  model_name: 'EventoBarEntrada',    label: 'Entrada',             group: 'Bar', complex: true, top_level: false, descriptor: ->(r) { "Entrada #{r.try(:codigo)}" } },
    ].map { |h| Entry.new(**h) }.freeze

    BY_KEY = ENTRIES.index_by(&:key).freeze

    def self.all = ENTRIES
    def self.top_level = ENTRIES.select(&:top_level?) # lo que se lista en la papelera
    def self.simple = ENTRIES.reject(&:complex?)
    def self.find(key) = BY_KEY[key.to_s]
  end
end
