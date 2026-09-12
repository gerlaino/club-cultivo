// QUÉ PASÓ EN UN CIERRE, EN ORACIONES. El producto por su NOMBRE y la cuenta a la vista: sin el
// esperado, «faltan 23 g» es una conclusión que no se puede comprobar.
//
// Vive acá porque lo leen DOS pantallas —la ficha del cierre (`CorregirConteo`) y el panel del
// día del calendario (`MostradorTurnos`)— y la misma oración escrita dos veces es cómo un día
// dicen distinto del mismo cierre.
const fmt = (n) => Number(n ?? 0).toLocaleString('es-AR', { maximumFractionDigits: 1 })

// Los motivos que no son la mercadería van como oración: un chip con «+2 más» esconde justo lo
// que hay que leer.
export const MOTIVO_FRASE = {
  corregido:   'Al abrir corrigió lo que había sobre la mesa.',
  mesa_movida: 'Mientras la caja estuvo abierta, administración movió lo que había sobre la mesa.',
}

// Devuelve [{ tono: 'warn' | 'ok' | '', texto: <html> }]. El texto lleva <b> y <small>: se
// renderiza con v-html, y viene de números y etiquetas del backend, nunca de texto libre.
export function hechosDelCierre (t) {
  const out = []
  const n = fmt

  for (const f of (t.faltaron?.items || [])) {
    out.push({ tono: 'warn', texto:
      `Faltan <b>${n(f.cantidad)} ${f.unidad}</b> de <b>${f.etiqueta}</b>. ` +
      `<small>Sobre la mesa tenía que haber ${n(f.esperado)} ${f.unidad} y al contar aparecieron ` +
      `${n(f.contado)}. Producir esos ${n(f.cantidad)} ${f.unidad} costó $${n(f.ars)}.</small>` })
  }
  const restanF = (t.faltaron?.total || 0) - (t.faltaron?.items?.length || 0)
  if (restanF > 0) out.push({ tono: 'warn', texto: `Y en ${restanF} producto${restanF === 1 ? '' : 's'} más.` })

  for (const f of (t.sobraron?.items || [])) {
    out.push({ tono: 'warn', texto:
      `Contó <b>${n(f.cantidad)} ${f.unidad}</b> de más de <b>${f.etiqueta}</b>. ` +
      '<small>No se sumaron al inventario: el mostrador descuenta producto, nunca lo carga. Si de ' +
      'verdad hay de más, los sube administración desde el depósito.</small>' })
  }

  if (!(t.faltaron?.total) && !(t.sobraron?.total)) {
    out.push({ tono: 'ok', texto:
      `Contó ${t.productos} producto${t.productos === 1 ? '' : 's'} y estaba todo.` +
      (t.dispensado_ars > 0 ? ` Entregó <b>$${n(t.dispensado_ars)}</b>.` : '') })
  }

  if (t.caja) {
    const d = Number(t.caja.diferencia_ars) || 0
    out.push({ tono: d ? 'warn' : 'ok', texto:
      `En la caja había <b>$${n(t.caja.contado_ars)}</b>` +
      (d ? ` — <b>$${n(Math.abs(d))} ${d < 0 ? 'menos' : 'más'}</b> de lo que tenía que haber` : ', lo que tenía que haber') +
      '.' + (t.caja.fondo_ars != null ? ` <small>Empezó con $${n(t.caja.fondo_ars)} de fondo.</small>` : '') })
  }

  for (const m of (t.motivos_revision || [])) {
    if (MOTIVO_FRASE[m]) out.push({ tono: '', texto: MOTIVO_FRASE[m] })
  }
  return out
}
