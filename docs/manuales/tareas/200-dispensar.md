---
titulo: Registrar una dispensación
roles: [admin, dispensador, supervisor]
modulo: Dispensaciones
orden: 10
---

Se dispensa desde la ficha del paciente, no desde una pantalla aparte: así siempre queda claro a
quién se le entrega.

1. Buscá al paciente y abrí su ficha.
2. Tocá **Nueva dispensación**. Se abre el carrito.
3. Agregá una línea por producto: elegí el **stock**, la **cantidad** y confirmá el **precio**.
   Podés poner varias líneas en la misma entrega.
4. Elegí el **medio de pago**: efectivo, transferencia, cuenta corriente, no abona o
   contra-entrega.
5. Si corresponde, aplicá un **descuento** sobre el total.
6. Confirmá.

Al confirmar pasan tres cosas a la vez: **baja el stock** de cada línea, queda el **movimiento
contable**, y si fue por cuenta corriente se le **debita al paciente**.

> **No hay límite mensual de gramos.** Lo que sí frena es el crédito: si el paciente no tiene
> saldo ni crédito disponible, la cuenta corriente no lo deja pasar.

### Con envío
Si la entrega va a domicilio, marcalo al confirmar: se genera un **despacho** para que delivery lo
lleve.

### Si te equivocaste
El administrador puede **editar** la dispensación —cantidad y precio de cada línea— y el sistema
reacomoda solo el stock y la cuenta corriente.
