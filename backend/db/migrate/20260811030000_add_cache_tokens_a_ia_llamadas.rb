# Con caché de prompt, la API devuelve los tokens de entrada partidos en tres: los que se
# procesaron a precio lleno, los que se ESCRIBIERON en caché (1,25×) y los que se LEYERON de
# caché (0,1×). Sin estas dos columnas el costo quedaría mal contado justo cuando empezamos a
# cachear — que es cuando hay que poder medir el ahorro.
class AddCacheTokensAIaLlamadas < ActiveRecord::Migration[7.2]
  def change
    add_column :ia_llamadas, :cache_creation_tokens, :integer, null: false, default: 0
    add_column :ia_llamadas, :cache_read_tokens,     :integer, null: false, default: 0
  end
end
