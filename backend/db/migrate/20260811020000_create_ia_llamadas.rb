# Cada llamada a la API de IA, con lo que costó.
#
# Hasta acá el uso era invisible: el rate limit vivía en Redis con TTL de una hora, así que no
# había forma de responder "cuánto consumió esta organización en julio" — que es exactamente el
# dato que hace falta para ponerle precio al add-on. De los cinco lugares que llaman a la API,
# uno solo guardaba tokens (`analisis_lotes.tokens_usados`), y sólo los suyos.
#
# Sólo se inserta: es un registro de consumo, no un estado que se edita.
class CreateIaLlamadas < ActiveRecord::Migration[7.2]
  def change
    create_table :ia_llamadas do |t|
      t.references :club, null: false, foreign_key: true
      # Nullable: hay llamadas sin persona detrás (importaciones, jobs).
      t.references :user, null: true, foreign_key: true

      t.string  :funcion, null: false
      t.string  :modelo,  null: false

      t.integer :input_tokens,  null: false, default: 0
      t.integer :output_tokens, null: false, default: 0
      # Se congela el costo al momento de la llamada: los precios por millón cambian, y un
      # informe de julio tiene que seguir diciendo lo que costó julio. 6 decimales porque una
      # llamada barata son fracciones de centavo.
      t.decimal :costo_usd, null: false, default: 0, precision: 12, scale: 6

      t.boolean :ok, null: false, default: true
      t.string  :error_clase

      t.timestamps
    end

    # El corte natural es "organización + período": el panel, la factura y el tope mensual.
    add_index :ia_llamadas, [:club_id, :created_at]
    add_index :ia_llamadas, [:club_id, :funcion]
  end
end
