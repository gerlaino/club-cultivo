class CreateJornadasLaborales < ActiveRecord::Migration[7.2]
  # Planilla de horas trabajadas: un registro por día y usuario, con hora de entrada
  # y salida. Las horas se calculan de entrada/salida. Pensado para manicura/cultivador,
  # editable por el propio usuario y corregible por el admin.
  def change
    create_table :jornadas_laborales do |t|
      t.references :user, null: false, foreign_key: true
      t.references :club, null: false, foreign_key: true
      t.date   :fecha,        null: false
      t.string :hora_entrada, null: false   # "HH:MM"
      t.string :hora_salida,  null: false   # "HH:MM"
      t.text   :nota
      t.timestamps
    end
    add_index :jornadas_laborales, [:user_id, :fecha], unique: true
    add_index :jornadas_laborales, [:club_id, :fecha]
  end
end
