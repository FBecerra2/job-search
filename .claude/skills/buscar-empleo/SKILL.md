---
name: buscar-empleo
description: Busca ofertas de customer service / atención al cliente en España, ayuda a postular (siempre con confirmación del usuario), descarta ofertas por criterio de la usuaria (modo `descartar`) y genera el reporte de lo aplicado. Usar cuando el usuario diga /buscar-empleo, "buscar ofertas", "aplicar a ofertas", "descartar ofertas" o "reporte de postulaciones".
---

# Buscar empleo (customer service, España)

Skill a pedido: solo actúa cuando el usuario la invoca, mientras está presente. No hay ejecución automática.

## Regla absoluta sobre los archivos de la carpeta del proyecto
**Nunca, bajo ninguna circunstancia, uses para aplicar a un trabajo ninguna imagen ni documento que esté en la carpeta del proyecto** (`CV_latest.jpg`, `CV_latestES.jpg` y cualquier otro JPG, PNG, PDF, DOC u otro archivo que el usuario deje aquí). No los subas, no los adjuntes, no los copies a otra carpeta para subirlos, no los conviertas a otro formato ni los envíes por ningún canal. Son solo material de lectura: puedes abrirlos para leer lo que dicen y usar esa información escrita (por ejemplo, para redactar mensajes o sugerir mejoras al CV) solo cuando haga falta. Cuando un formulario pida adjuntar el CV, usa el archivo que indique el usuario por otra vía (el PDF de `perfil.md` desde su carpeta original, o lo sube él a mano). Si no puedes adjuntarlo sin usar un archivo de esta carpeta, detente y pídeselo al usuario.

## Archivos del proyecto
- `perfil.md`: ciudad, radio, palabras clave, exclusiones, idiomas, datos y CV. **Léelo siempre primero.** Si tiene campos vacíos, pregunta al usuario antes de buscar.
- `registro.md`: todas las ofertas vistas, ordenadas en secciones por estado: 🟢 Para aplicar, 🟡 Con dudas, ⚪ Sin verificar, ✅ Aplicadas, 💬 Respuestas, ❌ Descartadas. Cada oferta vive en una sola sección y conserva su número (#). Léelo para no repetir ofertas. Tras cada acción mueve la fila a la sección que corresponda y actualiza el resumen de cantidades de arriba. Una oferta solo va a 🟢 si la leíste completa en la web ("verificada"); si solo viste el resumen de un buscador, va a ⚪.
- `registro.html`: vista bonita de `registro.md` (tarjetas por oferta, secciones por estado, buscador). **No se edita a mano**: se genera con `powershell -NoProfile -ExecutionPolicy Bypass -File generar-registro.ps1` (en la carpeta del proyecto). Se ejecuta en el "Cierre de cada ejecución" (arriba), que además guarda una versión con fecha y hora en `historial/` y `historial.md`. `registro.md` es la única fuente de datos; mantén su formato (secciones `##` y tablas con cabecera) para que el script lo lea bien.

## Modos (según el argumento)
- `buscar` (por defecto): busca y presenta ofertas nuevas.
- `aplicar <n|url>`: ayuda a postular a una oferta concreta.
- `reporte`: resumen del día.
- `descartar <n [n …]> [motivo]`: descarta ofertas por criterio de la usuaria, esté la oferta en la sección que esté (ver sección "descartar" más abajo).

## Aplicaciones marcadas a mano en registro.html
`registro.html` se abre desde un servidor local (`servidor-registro.ps1`, http://localhost:8765/, solo localhost), que `generar-registro.ps1 -Open` arranca solo en segundo plano si no está activo. Con él, el usuario puede en la página:
- Marcar la casilla **"Apliqué"** de una oferta: el servidor mueve la fila a ✅ Aplicadas de `registro.md` (fecha y hora, CV "(manual, por la usuaria)", sin mensaje, y guarda la fila original en un comentario `<!--orig:...-->` para poder deshacerlo), actualiza los contadores y regenera la página, que se recarga sola. Desmarcarla devuelve la fila a su sección.
- Marcar la casilla **"Descartar"** de una oferta en 🟢, 🟡 o ⚪ (pedido por la usuaria el 2026-11-10): la página pregunta el motivo (opcional), el servidor mueve la fila a ❌ Descartadas con el motivo "Descartada por la usuaria: …. Origen: <sección>" y guarda la fila original en un comentario `<!--orig:...-->`, actualiza los contadores (incluida la línea de ❌) y regenera la página. En ❌, las descartadas desde la web tienen la casilla **"Descartada"** marcada: desmarcarla (con confirmación) devuelve la oferta a su sección. Las descartadas por la skill o por filtro no tienen esa casilla; para recuperarlas, pídelo en el chat ("vuelve a poner la 11").
- Pulsar el botón **"Nota"** de cualquier oferta: se abre una barra lateral; al guardar, la nota queda en la sección `Notas de la usuaria` de `registro.md` (tabla `# | Oferta | Fecha y hora | Nota`, saltos de línea como `<br>`) y la página se regenera.

Reglas para ti:
- **Lee la sección `Notas de la usuaria` de `registro.md` al empezar cada ejecución** y tenla en cuenta (por ejemplo, si una nota dice que descarte algo o que llame a alguien). No borres ni reescribas esas notas.
- Si una oferta aparece ya en ✅ Aplicadas, no vuelvas a proponerla ni a aplicar.
- Cuando aplicas tú con la skill, mueve la fila a ✅ Aplicadas con todos los datos reales (fecha y hora, CV usado, mensaje enviado) y regenera la página: el servidor detecta el cambio y la página abierta se recarga sola.
- Las filas descartadas desde la web empiezan por "Descartada por la usuaria", igual que las de la opción `descartar` de la skill: **no las vuelvas a sugerir nunca** (ver la sección "descartar"). Si al recuperar una descartada ves el comentario `<!--orig:...-->`, usa esa fila original (está codificada en base64 UTF-8) y la sección que indica.
- **Estos guardados desde la web (marcar aplicada, descartar o recuperar, notas) NO crean versión en el historial.** Solo esta skill (`/buscar-empleo`) crea versiones, en su cierre de ejecución. Los scripts `servidor-registro.ps1` y `generar-registro.ps1` sin `-Note` nunca las crean.
- Si la página se abre como archivo (`file://`) es solo lectura. Para parar el servidor: `detener-servidor.ps1`. Si falla algo, mira `servidor-registro.log`.

## Las aplicadas son permanentes
- Las secciones ✅ Aplicadas y 💬 Respuestas y la sección `Notas de la usuaria` **no se borran, no se renumeran y no se reescriben nunca**, ni cuando se rehace el registro ni cuando se limpian ofertas viejas. Las demás secciones (🟢, 🟡, ⚪, ❌) sí se pueden regenerar o limpiar. Si reescribes `registro.md`, copia esas secciones tal cual.
- Salvaguarda automática: `generar-registro.ps1` guarda una copia en `registro-aplicadas.bak` y, si falta alguna fila de Aplicadas o de Notas, la restaura sola e imprime `RESTAURADO: ...`. Si lo ves en la salida, díselo al usuario. Para quitar una aplicada se usa la casilla en la web, y para borrar una nota el botón "Borrar nota"; no se editan a mano.
- **Numeración**: nunca reutilices un número. Las ofertas nuevas siguen desde el mayor `#` de todo el registro (incluidas aplicadas y descartadas).
- **Ofertas parecidas a una aplicada**: al buscar, compara cada oferta nueva con las aplicadas (misma empresa o puesto parecido, aunque venga de otra fuente o con otro título). Si coincide, **avísale en el chat** con "⚠ Parecida a la aplicada #N (empresa, puesto)", no la presentes como si fuera nueva sin ese aviso, y añade a su fila de `registro.md`, en la columna `Notas`, "⚠ Parecida a la aplicada #N". Además la página lo muestra sola con un aviso naranja y un enlace al número.

## Cierre de cada ejecución (obligatorio, en cualquier modo y aunque no haya cambios)
Cada vez que se invoque esta skill, al terminar:
1. Actualiza la línea "Última actualización" de `registro.md` con fecha y hora (`yyyy-MM-dd HH:mm`) y qué se hizo.
2. Ejecuta, desde la carpeta del proyecto: `powershell -NoProfile -ExecutionPolicy Bypass -File generar-registro.ps1 -Run <buscar|aplicar|reporte|descartar> -Note "<resumen corto de lo que cambió: ofertas nuevas, movidas de sección, aplicadas, descartadas>" -Open`. Esto hace cuatro cosas: regenera `registro.html`, guarda una copia de `registro.md` en `historial/registro_<fecha>_<hora>.md`, añade una fila (versión, fecha y hora, modo, cambios) a `historial.md` y abre `registro.html` en el navegador. Si no hubo cambios, pon "Sin cambios" en `-Note`: se guarda la versión igualmente.
3. Dile al usuario en una línea la versión y la hora (por ejemplo "Guardé la v5, 2026-11-04 10:15; ya tienes el registro abierto").
No pases a otra cosa sin haber hecho este cierre. Si el script falla, díselo al usuario con el error. **Este cierre es lo único que crea una versión en el historial**: no uses `-Note` fuera de una ejecución de esta skill (ni para ajustes manuales ni para cambios hechos desde la web).

## buscar
**Regla (pedida por la usuaria el 2026-11-03): en cada ejecución de la skill, revisa TODAS las webs que ella te pase** (en el mensaje o en la invocación), además de todas las fuentes listadas abajo (InfoJobs, Indeed ES, LinkedIn, Glassdoor). No te quedes en una sola fuente ni des la búsqueda por terminada tras la primera web. Si alguna no se puede revisar (bloqueo, captcha, dominio no permitido), dilo en el resumen final indicando cuál y por qué.
1. Fuentes, en este orden:
   - **InfoJobs e Indeed ES**: WebSearch/WebFetch con la ciudad y las palabras clave del perfil. Si una página bloquea el fetch (suele pasar con Indeed e InfoJobs), usa el navegador (skill `anthropic-skills:chrome-browser` o `built-in-browser`; léela antes de usar sus herramientas). Usa siempre las variantes de búsqueda de abajo, no solo una palabra.
     - **InfoJobs**: `https://www.infojobs.net/ofertas-trabajo/barcelona/<palabra-clave-con-guiones>` (p. ej. `customer-service-ingles`, `atencion-al-cliente`). La lista carga por tramos: haz scroll hasta abajo antes de leer el texto de la página. Se puede filtrar por "Solo teletrabajo", fecha y jornada con las casillas de la izquierda.
     - **Indeed ES**: `https://es.indeed.com/jobs?q=<palabras+con+signo+más>&l=Barcelona&fromage=14` (`fromage=14` = últimos 14 días). Al cargar, `get_page_text` devuelve la lista y además el texto completo de la primera oferta. Para leer otra, ábrela desde la lista. Puede mostrar la verificación de Cloudflare (pasó una vez); si aparece, sigue la regla de verificación humana de abajo.
     - **Nombres de puesto a buscar** (siempre en inglés y en español, porque las ofertas vienen en ambos idiomas). Busca por familias, no por una sola palabra:
       - **Customer care / customer service / customer support / customer experience / client service(s) / client care** → en español: "atención al cliente", "servicio al cliente", "soporte al cliente", "asistencia al cliente", "atención al usuario", "SAC" (servicio de atención al cliente).
       - **Operational service / service operations / operations support / service delivery / back office / order management** → en español: "servicio operativo", "operaciones de servicio", "soporte operativo", "soporte de operaciones", "back office", "gestión de pedidos", "administración de operaciones".
       - **Localization / localisation /  LQA / localisation quality** → en español: "localización".
       - **Cargos que acompañan a lo anterior** (combínalos con cada familia): agent, advisor, specialist, representative, associate, executive, officer, coordinator, analyst → agente, asesor/a, especialista, técnico/a, gestor/a, auxiliar, coordinador/a, analista. Ejemplos: "Customer Care Specialist", "Customer Service Representative", "Operations Support Specialist", "Agente de atención al cliente", "Especialista de soporte operativo".
       - **Idioma** (el perfil es español nativo + inglés C1): añade o combina "español e inglés", "bilingüe", "bilingual", "English speaking", "inglés alto". Al leer cada oferta, confirma que los idiomas pedidos sean solo español e inglés (descarta si exigen catalán, francés, alemán, italiano u otro).
     - **Comodines y operadores**: no todas las webs aceptan `*`, así que no lo asumas. Orden de preferencia:
       1. En **Indeed, LinkedIn y Glassdoor** prueba primero una búsqueda combinada con comillas, paréntesis y OR, por ejemplo: `("customer care" OR "customer service" OR "customer support" OR "operations support" OR "service operations" OR "atención al cliente" OR "servicio al cliente" OR "soporte al cliente" OR "soporte operativo")`, y si quieres acotar idioma, añade `AND (inglés OR english OR bilingüe OR bilingual)`. Indeed y LinkedIn aceptan estos operadores; en Glassdoor no está garantizado.
       2. Para raíces de palabra usa `*` solo si el sitio lo admite (p. ej. `asesor*`, `especialista*`, `agent*`). Si con el comodín salen 0 resultados o resultados raros, no insistas: expande a mano ("asesor", "asesora", "asesores").
       3. En **InfoJobs** la palabra clave va en la URL: haz una búsqueda por variante (`customer-service`, `customer-care`, `customer-support`, `atencion-al-cliente`, `servicio-al-cliente`, `soporte-al-cliente`, `operations-support`, `soporte-operativo`).
       4. Si una búsqueda combinada falla o el sitio la ignora, usa una búsqueda por familia y junta los resultados, quitando duplicados con `registro.md`.
   - **LinkedIn y Glassdoor**: solo lectura en el navegador del usuario con su sesión ya iniciada, o leyendo sus alertas por Gmail si el conector está autorizado. Si Chrome responde "Navigation to this domain is not allowed", el dominio no está permitido en la extensión: avisa al usuario y espera, no lo rodees.
     - **Glassdoor** (probado y funcionando el 2026-11-03 con la sesión del usuario): no construyas URLs de búsqueda con códigos de ciudad (`IL.0,9_IC...`): un código inventado lleva a otra ciudad (salió "Ban Rai Rang", Tailandia, con 0 resultados). Tampoco uses `/Empleo/` como página de entrada (da 404). Entra a `https://www.glassdoor.es/Job/index.htm`, haz clic en el cuadro "Encuentra tu empleo ideal" y escribe el puesto, haz clic en "Ciudad, provincia o teletrabajo" y escribe "Barcelona", elige **"Barcelona (España)"** en el desplegable (la primera sugerencia) y pulsa Enter. Comprueba que el título de la página diga "en Barcelona" antes de leer los resultados.
     - **LinkedIn** (probado y funcionando el 2026-11-03 con la sesión del usuario): `https://www.linkedin.com/jobs/` muestra "Jobs based on your preferences" con ofertas ya filtradas; léelas con `get_page_text`. Para buscar, usa el buscador de la página, un solo tipo de búsqueda a la vez, sin paginar de forma masiva. Nunca inicies sesión por el usuario y no hagas búsquedas masivas: sus términos prohíben la automatización y pueden bloquear la cuenta.
   - **Verificación humana (captcha, Cloudflare, "no soy un robot") en cualquier sitio**: nunca la resuelvas tú. Detente, avisa al usuario en el chat de qué página la pide y pídele que la complete él en la pestaña de Chrome. Espera su respuesta (por ejemplo "listo"), haz una captura o lee la página para confirmar que ya cargó la oferta y entonces continúa donde lo dejaste. Si tras la verificación la página sigue bloqueada, dilo y pasa a otra fuente en lugar de reintentar.
2. Filtra según `perfil.md` (ubicación, idioma, exclusiones) y descarta lo que ya esté en `registro.md`.
3. Presenta una lista numerada y corta: puesto, empresa, **qué hace la empresa (1 frase)**, ubicación, salario si aparece, fuente y enlace. Para las ofertas verificadas (las que van a 🟢 o 🟡) añade también **Mejoras al CV** (0 a 5 cambios ya redactados para pegar, basados en su CV real; ver la sección "Ajustes sugeridos al CV" más abajo). Añade las nuevas a `registro.md` en la sección que corresponda (🟢, 🟡 o ⚪) y las descartadas con su motivo en ❌.
   - **Qué hace la empresa**: sácalo del texto de la oferta, de la sección "About the company" o de la página de la empresa. No inventes: si no hay datos, escribe "Sin datos; revisar al verificar la oferta". Si lo escribes de memoria o por el nombre, di "(confirmar al verificar)".
   - **Columnas en `registro.md`**: las tablas de 🟢 y 🟡 llevan al final las columnas `Qué hace la empresa` y `Mejoras al CV`; la tabla de ⚪ lleva `Qué hace la empresa`; ❌ no las lleva. Una oferta que pasa de ⚪ a 🟢/🟡 al verificarla debe recibir también sus `Mejoras al CV`. El script `generar-registro.ps1` muestra esas dos columnas como bloques destacados en `registro.html`.
4. Pregunta a cuáles quiere aplicar. No apliques a nada por iniciativa propia.

## aplicar
1. Abre la oferta en el navegador y rellena lo que se pueda con los datos de `perfil.md`.
2. **Antes de enviar, muestra al usuario un resumen (puesto, empresa, qué se enviará, mensaje de presentación) y espera un "sí" explícito para esa oferta.** Un "sí" no vale para las siguientes.
3. Si hay login, pregunta no cubierta por el perfil o cualquier duda, detente y pregunta al usuario. Si hay captcha o verificación humana, detente, pídele al usuario que la complete en Chrome, espera a que confirme y continúa con el formulario desde ese punto. Nunca resuelvas la verificación tú.
4. Redacta el mensaje a partir de "Mensaje de presentación base" de `perfil.md`, respetando "Tono de los mensajes", y pásalo por el **filtro humanizer** (abajo).
5. Junto al resumen, incluye **Ajustes sugeridos al CV** (abajo): redactados para pegar, basados en la lectura del CV real y con el filtro humanizer. Si la oferta ya tiene `Mejoras al CV` en `registro.md`, revísalas contra el CV real (las escritas antes del 2026-11-04 se hicieron sin leerlo y pueden repetir lo que ya dice) y afínalas con lo que veas en el formulario.
   - **Reglas de formulario (aprendidas el 2026-11-03)**:
     - Usa referencias (`find`/`read_page` + `form_input`) en vez de clics por coordenadas, y haz una captura nueva antes de cada clic por coordenadas: si la página se desplazó, el clic cae en otro campo. Tras rellenar, verifica con captura o texto que cada campo tiene su valor.
     - **No rellenes campos opcionales de diversidad** (género, etnia, etc.) ni casillas de "contactarme para futuras ofertas". Déjalos en blanco. Si por error quedan marcados, corrígelo y díselo al usuario.
     - Aceptar la política de privacidad o términos es una confirmación: marca esa casilla solo cuando el usuario haya dado su "sí" al resumen final.
     - Banners de cookies: rechaza las no esenciales.
     - Preguntas que el perfil no cubre (turno, trabajo remoto, paquete salarial, disponibilidad, etc.): no las respondas tú; pregúntaselas al usuario con el texto exacto de la pregunta.
     - Subida de CV: `file_upload` solo acepta carpetas autorizadas para la sesión. Si el PDF de `perfil.md` (en `C:\Users\anto\Documents\CVs\...`) no está autorizado, pídele al usuario que autorice esa carpeta con `/add-dir` o que suba él el CV a mano en ese campo. **No copies el CV a la carpeta del proyecto** y no uses los JPG de la carpeta del proyecto (ver la regla absoluta de arriba).
     - Teléfono: si el campo pide prefijo, usa +34 delante del número de `perfil.md`.
6. Tras enviar, mueve la fila a la sección ✅ Aplicadas de `registro.md` con fecha y hora, CV usado y mensaje enviado.

## Filtro humanizer (obligatorio en cada mensaje)
Antes de mostrar el mensaje, revísalo y corrige:
- Elimina muletillas de IA: "apasionada por", "dinámica", "proactiva" sin prueba, "me complace", "sinergias", "no dudo que", "excelente oportunidad", listas de tres adjetivos.
- Usa al menos un dato concreto de la oferta (herramienta, idioma, tipo de cliente, sector) y un dato real del perfil (empresa, herramienta, años). No inventes experiencia ni logros que no estén en `perfil.md` o en el CV.
- Frases cortas y variadas, voz natural, educado pero sin florituras. Sin "vosotros". Sin teléfono en el texto.
- Varía el saludo y el cierre entre postulaciones para que no queden idénticos.
- Máximo 100 palabras. Si la oferta pide carta larga o preguntas concretas, responde a eso en lugar del texto base.

## Ajustes sugeridos al CV (en cada postulación)
**Regla (pedida por la usuaria el 2026-11-04): las mejoras se basan en su CV real, vienen ya curadas y redactadas para que ella las copie al CV, y pasan por el filtro humanizer.** Antes ella recibía comentarios del tipo "sube tal punto" sobre frases que ya estaban en su CV; eso no sirve.

Se escriben **dos veces**: en `registro.md` (columna `Mejoras al CV`) en cuanto una oferta verificada entra en 🟢 o 🟡, y de nuevo en el resumen previo a cada postulación (partiendo de lo ya escrito, afinado con lo que se vea en el formulario).

**Paso 1: lee el CV real, siempre, antes de escribir nada.** Abre `CV_latest.jpg` (versión en inglés) o `CV_latestES.jpg` (versión en español, si la oferta está en español) con la herramienta de lectura de imágenes, **solo para leerlo, nunca para adjuntarlo ni copiarlo** (ver la regla absoluta de arriba). No escribas mejoras de memoria ni a partir del resumen de `perfil.md`: ese resumen no es el CV. Si el JPG que toca no está, dilo al usuario y no escribas mejoras hasta tenerlo. Si el CV cambia, ella actualiza los JPG.

**Paso 2: compara la oferta con el CV, frase por frase.** Anota qué pide la oferta (herramientas, canales, tipo de cliente, sector, idiomas, palabras clave) y qué dice ya el CV. **No propongas nada que el CV ya diga con las mismas palabras o con un sentido equivalente.** Tampoco "subir", "destacar" o "reordenar" una frase si ya está bien situada. Solo valen estos cambios:
- Una frase **nueva o reescrita** que reformule algo que ya es cierto con las palabras clave de la oferta (p. ej. el CV dice "Processed customer returns and refunds" y la oferta habla de devoluciones de e-commerce).
- Una herramienta o competencia que hoy solo aparece en Skills y conviene llevar a un puesto concreto (p. ej. Freshdesk), **solo si ella confirma dónde la usó**.
- Algo que el CV no dice y es probablemente cierto (p. ej. atención por chat): no lo asumas; **hazle la pregunta** y deja el cambio pendiente de su confirmación.
- Un cambio de orden entre puestos, solo si realmente cambia el efecto (no si el puesto ya está arriba).

**Paso 3: redáctalo listo para pegar.** Cada mejora indica **dónde va** (Resumen, un puesto concreto o Skills), **qué frase sustituye o se añade** (cita la frase actual del CV si se reemplaza) y **el texto nuevo, completo y listo para copiar**, en el idioma del CV que corresponde a la oferta. Usa el estilo del CV (viñetas con verbo en pasado en inglés, frases cortas). Formato en el registro: una sola celda, numerada "1) ... 2) ...", sin el carácter `|`. Ejemplo: `1) Klarna, 2.º punto. Sustituir "Processed customer returns and refunds with accuracy" por "Processed customer returns and refunds for online purchases with accuracy" (solo si eran compras en tiendas online).`

**Paso 4: pásalo por el filtro humanizer** (el de arriba, adaptado a un CV): sin muletillas de IA ("proactive", "dynamic", "passionate", "results-driven", "synergies", "ensuring" repetido), sin listas de tres adjetivos, verbos concretos, un dato real por viñeta (herramienta, volumen, tipo de cliente, mercado), frases cortas y variadas, nada inflado y sin repetir la misma estructura en todas las viñetas. No inventes cifras, herramientas ni logros que no estén en el CV o que ella no haya confirmado.

**Cantidad y casos sin cambios.** Entre 0 y 5 mejoras: las que realmente aporten. Si el CV ya encaja con la oferta, escribe "El CV ya encaja con la oferta; sin cambios necesarios" (y, si procede, qué CV usar, inglés o español). No rellenes hasta llegar a 3. Nunca propongas añadir lo que Antonella no ha hecho. Si una mejora depende de algo que no sabes, redáctala igualmente marcada "(confirmar: …)" y pregúntaselo en el chat con el texto exacto de la pregunta.

## descartar (pedido por la usuaria el 2026-11-04)
Sirve para que la usuaria quite ofertas por **su propio criterio**, aunque estén en 🟢 Para aplicar (o en 🟡 o ⚪), y así mantener limpia la sección "Para aplicar". Se invoca, por ejemplo, con `/buscar-empleo descartar 11`, `/buscar-empleo descartar 11 19 28 no me convence el turno` o en lenguaje natural ("descarta la 20, el sueldo es bajo"). No hace falta que la oferta cumpla ninguna regla de filtro: manda lo que ella decida, no el perfil.
1. **Lee `registro.md`** (y sus notas de la usuaria) y localiza cada número indicado. Si un número no existe, dilo y sigue con los demás.
2. **Motivo**: usa el que ella diga, con sus palabras (resumido, sin inventar). Si no da motivo, escribe "Descartada por la usuaria" y no se lo preguntes (no la frenes). Si en las notas de la usuaria hay una nota de esa oferta que explique por qué, puedes añadirla al motivo citándola como "(nota de la usuaria)", sin copiarla entera.
3. **Mueve la fila** a la sección ❌ Descartadas con el formato de esa tabla (`# | Puesto | Empresa | Lugar | Motivo`): conserva el número (#), el puesto, la empresa y el lugar (quita el enlace en markdown solo si estorba; si lo conservas, déjalo en el puesto) y escribe el motivo precedido de "Descartada por la usuaria:". **No pierdas los datos útiles** de la fila original (sueldo, contrato, pega): resúmelos al final del motivo, por si luego quiere recuperarla.
4. **Quita la fila de su sección original** (🟢, 🟡 o ⚪) y actualiza el resumen de cantidades de arriba. Una oferta vive en una sola sección.
5. **Límites**: si la oferta está en ✅ Aplicadas o en 💬 Respuestas, **no la muevas** (esas secciones son permanentes): avísale y deja la fila donde está. No toques la sección `Notas de la usuaria`.
6. **Deshacer**: si pide recuperar una descartada ("vuelve a poner la 11"), mueve la fila a la sección donde estaba (según lo que anotaste en el motivo; si no consta, a ⚪, o a 🟢 si fue verificada y las mejoras al CV siguen en la fila) y reconstruye las columnas de esa tabla. Avísale de lo que no se pudo recuperar.
7. **No vuelvas a sugerir nunca una oferta que ella descartó, ni al día siguiente ni en ninguna búsqueda posterior** (misma empresa y puesto parecido, aunque venga de otra fuente, con otro título o republicada). Antes de presentar ofertas nuevas en `buscar`, compara cada una con la sección ❌ Descartadas, igual que se compara con las aplicadas. Si coincide, no la incluyas en la lista ni en ⚪/🟢/🟡 ni la cuentes como nueva (como mucho, una línea en el resumen: "N ofertas ya descartadas por ti, omitidas"). Excepción única: si reaparece con un cambio importante (otro sueldo, otro turno, otro idioma pedido), menciónalo en una línea y que ella decida; no la presentes como nueva. Esto vale solo para las que **ella** descartó (las que empiezan por "Descartada por la usuaria"); las que descarté yo por filtro sí se pueden reevaluar si cambia el perfil.
8. **Confirmación**: no hace falta pedir permiso, es reversible y lo pide ella. Pero **muestra al final qué moviste**: número, puesto, empresa, motivo y de qué sección salió. Si indicó muchas ofertas de golpe (más de 5), enséñale la lista antes de aplicar el cambio.
9. **Cierre obligatorio** como en cualquier ejecución: actualiza "Última actualización" y ejecuta `generar-registro.ps1 -Run descartar -Note "<resumen: ofertas descartadas y motivo>" -Open`, y dile la versión y la hora.

## reporte
1. Lee `registro.md` y resume: aplicadas hoy, pendientes (secciones 🟢, 🟡 y ⚪), descartadas y respuestas recibidas.
2. Muéstralo en el chat.
3. Si el usuario quiere el reporte por email y el conector de Gmail está autorizado, prepáralo como **borrador** o envíalo solo a antopaoloni@gmail.com tras confirmar. Si el conector no está autorizado, dile que debe autorizarlo desde la configuración de conectores de claude.ai.
4. Si ve respuestas de empresas (en Gmail o en el navegador), pasa esa fila a la sección 💬 Respuestas y avísale.
