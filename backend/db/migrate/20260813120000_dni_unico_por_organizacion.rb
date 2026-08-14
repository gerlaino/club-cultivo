# El DNI deja de ser único en TODA la plataforma y pasa a serlo dentro de cada organización.
#
# El índice global venía de leer el requisito del REPROCANN —una persona se registra con UN
# cultivador a la vez— como si fuera una restricción de nuestra base. No lo es, y traía tres
# problemas:
#
# 1. Una persona que se va de una organización y entra a otra no se podía cargar hasta que la
#    primera la borrara. Hacer depender el alta de un cliente de que otro cliente haga algo es
#    inaceptable: nadie tiene forma de pedírselo, ni de saber a quién.
# 2. Es una fuga entre tenants: el error de alta confirmaba que ese DNI ya existe en OTRA
#    organización. Es un dato de salud de una persona que no es paciente de quien lo ve.
# 3. Con `acts_as_paranoid`, el registro borrado sigue en la tabla ocupando el índice: ni
#    siquiera borrándolo se liberaba el DNI. Por eso el índice nuevo es PARCIAL.
#
# La regla del REPROCANN sigue existiendo donde corresponde —es un requisito del trámite, y lo
# controla el organismo, que es el único que ve el padrón completo—, no como constraint nuestro.
class DniUnicoPorOrganizacion < ActiveRecord::Migration[7.2]
  def up
    remove_index :pacientes, name: 'index_pacientes_on_dni_normalizado'
    add_index :pacientes, %i[club_id dni_normalizado],
              unique: true,
              where:  'deleted_at IS NULL',
              name:   'index_pacientes_on_club_id_and_dni_normalizado'
  end

  def down
    remove_index :pacientes, name: 'index_pacientes_on_club_id_and_dni_normalizado'
    add_index :pacientes, :dni_normalizado, unique: true, name: 'index_pacientes_on_dni_normalizado'
  end
end
