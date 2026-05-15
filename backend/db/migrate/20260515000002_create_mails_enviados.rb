class CreateMailsEnviados < ActiveRecord::Migration[7.2]
  def change
    create_table :mails_enviados do |t|
      t.references :paciente, null: false, foreign_key: true
      t.references :user,     null: false, foreign_key: true
      t.references :club,     null: false, foreign_key: true
      t.string  :asunto,      null: false
      t.text    :cuerpo,      null: false
      t.string  :tipo,        null: false, default: 'personalizado'
      t.string  :email_destino, null: false
      t.datetime :enviado_at, null: false

      t.timestamps
    end

    add_index :mails_enviados, [:paciente_id, :enviado_at]
  end
end
