class AddTipoToSalas < ActiveRecord::Migration[7.2]
  TIPOS_VALIDOS = %w[cultivo vegetativo floracion secado curado madre clones].freeze

  KIND_TO_TIPO = {
    'vegetativo' => 'vegetativo',
    'floracion'  => 'floracion',
    'secado'     => 'secado',
    'madre'      => 'madre',
    'clon'       => 'clones',
    'mixta'      => 'cultivo',
    'manicura'   => 'cultivo',
  }.freeze

  def up
    add_column :salas, :tipo, :string, null: false, default: 'cultivo'
    add_index  :salas, [:sede_id, :tipo]

    KIND_TO_TIPO.each do |kind, tipo|
      execute "UPDATE salas SET tipo = '#{tipo}' WHERE kind = '#{kind}'"
    end
  end

  def down
    remove_index  :salas, [:sede_id, :tipo]
    remove_column :salas, :tipo
  end
end
