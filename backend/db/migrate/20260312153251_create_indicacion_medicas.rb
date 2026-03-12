class CreateIndicacionMedicas < ActiveRecord::Migration[7.2]
  def change
    create_table :indicacion_medicas do |t|
      t.references :socio, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true, comment: 'Médico que emite'
      t.string :patologia, null: false
      t.text :dosificacion, null: false
      t.string :via_administracion, null: false
      t.integer :duracion_dias
      t.date :fecha_emision, null: false
      t.date :fecha_vencimiento
      t.boolean :activa, default: true, null: false
      t.text :observaciones

      t.timestamps
    end

    add_index :indicacion_medicas, :activa
    add_index :indicacion_medicas, :fecha_vencimiento
  end
end