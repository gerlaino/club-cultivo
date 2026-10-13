# Un cobro mensual de una suscripción, tal como lo informó Mercado Pago (`authorized_payment`). El
# `mp_id` es único: el mismo aviso que llega dos veces no se cuenta dos veces.
class SuscripcionCobro < ApplicationRecord
  self.table_name = 'suscripcion_cobros'

  belongs_to :suscripcion

  def aprobado? = estado == 'aprobado'
end
