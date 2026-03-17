class StandardizeSalasLotesNomenclature < ActiveRecord::Migration[7.2]
  def change
    # Salas: name -> nombre (consistente con español)
    rename_column :salas, :name, :nombre if column_exists?(:salas, :name)

    # Lotes: code -> codigo (consistente con Plant.codigo_qr)
    rename_column :lotes, :code, :codigo if column_exists?(:lotes, :code)

    # Lotes: Consolidar stage y state en un solo campo 'estado'
    # Primero migrar datos de 'stage' a 'state' si es necesario
    reversible do |dir|
      dir.up do
        # Si hay datos en stage, copiarlos a state antes de eliminar
        execute <<-SQL
          UPDATE lotes 
          SET state = COALESCE(stage, 'planificacion')
          WHERE state IS NULL OR state = ''
        SQL
      end
    end

    # Eliminar 'stage' (vegetativo/floracion/cosechado)
    remove_column :lotes, :stage, :string if column_exists?(:lotes, :stage)

    # Renombrar 'state' a 'estado'
    rename_column :lotes, :state, :estado if column_exists?(:lotes, :state)

    # Agregar índices para mejorar performance
    add_index :salas, :nombre unless index_exists?(:salas, :nombre)
    add_index :lotes, :codigo unless index_exists?(:lotes, :codigo)
    add_index :lotes, :estado unless index_exists?(:lotes, :estado)
  end
end