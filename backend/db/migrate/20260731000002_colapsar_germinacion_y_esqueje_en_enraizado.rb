# germinación y esqueje eran DOS ESTADOS para UNA sola etapa: la planta sin raíz funcional. La
# diferencia real entre ellas no es la etapa sino el ORIGEN (de dónde viene la planta), que ya vive
# en su propia columna. Tenerlos como estados obligaba a duplicar setpoints, reglas de alerta y
# líneas de informe para algo idéntico, y era la razón de que un admin cargara los clonadores como
# "esqueje" cuando en realidad estaban enraizando.
#
# OJO con la ambigüedad histórica: `esqueje` se usó con dos sentidos distintos según quién cargó —
# "está en el clonador" y "esqueje ya prendido en vaso". Los dos caen acá en 'enraizado'; los que ya
# habían prendido hay que promoverlos a vegetativo a mano (se ven por sus días en fase).
class ColapsarGerminacionYEsquejeEnEnraizado < ActiveRecord::Migration[7.2]
  def up
    execute "UPDATE lotes  SET estado = 'enraizado' WHERE estado IN ('germinacion', 'esqueje')"
    execute "UPDATE plants SET state  = 'enraizado' WHERE state  IN ('germinacion', 'esqueje')"
    # El historial del lote guarda los estados como texto: si no se migra, la timeline queda
    # mostrando fases que ya no existen.
    execute "UPDATE lote_eventos SET estado_anterior = 'enraizado' WHERE estado_anterior IN ('germinacion', 'esqueje')"
    execute "UPDATE lote_eventos SET estado_nuevo    = 'enraizado' WHERE estado_nuevo    IN ('germinacion', 'esqueje')"
  end

  # Irreversible por diseño: al colapsar se pierde cuál de los dos era, y reconstruirlo desde
  # `origen` inventaría datos (un lote de semilla pudo haber estado en 'esqueje'). Se baja a
  # 'germinacion', que es el arranque por defecto.
  def down
    execute "UPDATE lotes  SET estado = 'germinacion' WHERE estado = 'enraizado'"
    execute "UPDATE plants SET state  = 'germinacion' WHERE state  = 'enraizado'"
    execute "UPDATE lote_eventos SET estado_anterior = 'germinacion' WHERE estado_anterior = 'enraizado'"
    execute "UPDATE lote_eventos SET estado_nuevo    = 'germinacion' WHERE estado_nuevo    = 'enraizado'"
  end
end
