# Be sure to restart your server when you modify this file.

# El inflector inglés singulariza "bares" → "bare" (le saca la 's'), no "bar". Eso hacía que las
# rutas anidadas `resources :bares do ... end` generaran el parámetro `:bare_id`, mientras que TODOS
# los controllers del bar leen `params[:bar_id]` → quedaba nil → find(nil) → 404 en todo lo anidado
# (eventos, productos, ventas, cajas, provisiones). El dashboard andaba por ser ruta member (usa :id).
#
# Con esta regla, singular de "bares" = "bar" y el parámetro anidado pasa a ser `:bar_id`, que es lo
# que esperan los controllers. (El modelo es `Barra` con table_name explícito, no se ve afectado.)
ActiveSupport::Inflector.inflections(:en) do |inflect|
  inflect.irregular "bar", "bares"
end

# Rails pluraliza en inglés: "clonador" → "clonadors", y singulariza "clonadores" → "Clonadore".
# Enseñarle la regla UNA vez arregla el nombre de tabla, las asociaciones y las rutas de una, en vez
# de parchar cada lugar con table_name/class_name/to_table.
ActiveSupport::Inflector.inflections(:en) do |inflect|
  inflect.irregular 'clonador', 'clonadores'
end
