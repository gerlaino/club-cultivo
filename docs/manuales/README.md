# Manuales de usuario

Los manuales que se le entregan a cada organización, uno por rol.

## La regla que ordena todo

**Se escriben tareas, no manuales.** Cada archivo de `tareas/` explica *una cosa que alguien
hace*, y declara en su frontmatter qué roles la hacen. El manual de un rol es la **compilación**
de las tareas que lo mencionan.

Escribir "Registrar una dispensación" una vez y que aparezca en el manual del admin, del
supervisor y del dispensador — siempre igual, siempre actualizada — es la única forma de que
cinco manuales no sean cinco veces el trabajo. Para siempre, no sólo la primera vez.

## Cómo se escribe una tarea

```markdown
---
titulo: Registrar una dispensación
roles: [admin, dispensador, supervisor]
modulo: dispensaciones
orden: 20
---

Pasos, en la pantalla real, nombrando los botones exactos en **negrita**.

### 📱 En el teléfono
Sólo lo que CAMBIA en mobile. Si no cambia nada, no va la sección.
```

| Campo | Para qué |
|---|---|
| `titulo` | Encabezado de la sección |
| `roles` | Quiénes la ven. Un rol que no está acá no recibe esta tarea |
| `modulo` | Agrupa las tareas dentro del manual |
| `orden` | Ordena dentro del módulo. Sin esto queda alfabético, que no es el orden en que se aprende |

## Reglas de estilo

**Sin capturas de pantalla** (decisión de agosto 2026). Se nombra el botón exacto en negrita:
*"tocá **Dispensar**"* sobrevive un rediseño; una captura del sidebar viejo lo vuelve basura y
encima queda mal frente a la organización. Si algún día se agregan, hay que revisarlas en cada
release.

**Mobile no lleva manual aparte.** La PWA es la misma app con otro envoltorio; un manual mobile
separado duplica el 85% del texto para explicar el 15% que cambia, y garantiza que las dos
versiones se desincronicen. Va como bloque `### 📱 En el teléfono` dentro de cada tarea.

**Escribir para quien no conoce el módulo.** El manual lo lee alguien que recién entra, no quien
ya sabe dónde está todo.

## Generar los PDF

```bash
npm run manuales          # todos
npm run manuales -- admin # uno solo
```

Salen en `docs/manuales/dist/`. Usa **wkhtmltopdf** (pandoc no está instalado).

## Orden acordado

`admin` → `cultivador` → `manicura` → `dispensador` → `medico`.

`super_admin` **no lleva manual de usuario**: es el equipo de la plataforma, no un cliente.

## De dónde sale el contenido

De [`../GUIA_USUARIOS.md`](../GUIA_USUARIOS.md), que es la referencia interna reconciliada contra
el código. Ojo con su **sección 5** (detalle de cada informe): está marcada como no reverificada.
