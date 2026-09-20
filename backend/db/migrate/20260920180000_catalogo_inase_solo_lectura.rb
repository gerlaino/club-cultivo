# Las genéticas del catálogo INASE son filas globales compartidas por todas las organizaciones.
# Cualquier admin podía marcarlas «disponible» (o apagarlas) desde su pantalla, y eso se lo
# cambiaba a todos: un uso personal recién creado aparecía con «una genética de otro usuario»
# (20-sep-2026). Desde ahora son de sólo lectura para una organización; acá se las devuelve a
# su estado de catálogo: no disponibles (cada organización carga la suya y la declara) y activas.
class CatalogoInaseSoloLectura < ActiveRecord::Migration[7.2]
  def up
    execute "UPDATE geneticas SET disponible = false, activa = true WHERE global = true AND club_id IS NULL"
  end

  def down
    # Datos: no se puede saber quién había tocado qué.
  end
end
