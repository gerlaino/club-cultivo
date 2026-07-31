# La fase de setpoints 'clon' pasa a llamarse 'enraizado'. Es el mismo momento del ciclo —planta
# sin raíz funcional— pero 'clon' dejaba afuera a las plántulas de semilla, que están en la misma
# etapa fisiológica. La fase existía desde siempre y nunca llegó a usarse: el detector de alertas
# desviaba el enraizado a los setpoints de vegetativo antes de consultarla.
class RenombrarFaseClonAEnraizado < ActiveRecord::Migration[7.2]
  def up
    execute "UPDATE setpoints_fase SET fase = 'enraizado' WHERE fase = 'clon'"
  end

  def down
    execute "UPDATE setpoints_fase SET fase = 'clon' WHERE fase = 'enraizado'"
  end
end
