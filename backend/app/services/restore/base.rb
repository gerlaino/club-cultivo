module Restore
  # Conflicto que impide (o advierte sobre) una restauración. `codigo` es estable para tests/UI,
  # `mensaje` es el texto humano que ve el admin.
  Conflict = Struct.new(:codigo, :mensaje, keyword_init: true)

  Result = Struct.new(:ok, :conflicts, :mensaje, keyword_init: true) do
    def ok? = ok
    def conflicts = self[:conflicts] || []
  end

  # Base de los Restorers: restauración COMPLETA de una entidad con efectos colaterales.
  # A diferencia del restore simple (solo des-borra), un Restorer:
  #   1. valida contra el estado ACTUAL (dry-run vía #check) y bloquea con motivos si choca,
  #   2. re-aplica los efectos de la creación (#apply!) dentro de una transacción.
  # Política de conflictos (decisión del proyecto): bloquear con motivos, nunca forzar.
  class Base
    def self.check(record)   = new(record).check
    def self.call(record)    = new(record).restore!

    def initialize(record)
      @record = record
    end

    attr_reader :record

    # Dry-run: ¿se puede restaurar ahora? Devuelve Result con la lista de conflictos.
    def check
      c = conflicts
      Result.new(ok: c.empty?, conflicts: c)
    end

    def restore!
      c = conflicts
      return Result.new(ok: false, conflicts: c) if c.any?

      ActiveRecord::Base.transaction do
        apply!
        record.restore_record!(recursive: recursive_restore?)
      end
      Result.new(ok: true, mensaje: 'Restaurado')
    end

    # --- A implementar por cada subclase -----------------------------------
    # Lista de Conflict (vacía = se puede restaurar). Validar SIEMPRE contra el estado actual.
    def conflicts = []

    private

    # Re-aplica los efectos colaterales de la creación. Default: nada (solo des-borra).
    def apply!; end

    # ¿Des-borrar también los dependientes? Off cuando apply! ya crea efectos frescos
    # (evita duplicar asientos/movimientos que volverían con el recursive).
    def recursive_restore? = true

    def conflict(codigo, mensaje)
      Conflict.new(codigo: codigo, mensaje: mensaje)
    end
  end
end
