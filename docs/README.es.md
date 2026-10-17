<p align="center">
  <img src="https://raw.githubusercontent.com/Cerynna/CorpSR/main/art/icons-coin-64.png" width="96" alt="CorpSR">
</p>

<h1 align="center">CorpSR</h1>

<p align="center">
  <b>Soft Reserve de hermandad con puntos, todo dentro del juego.</b><br>
  World of Warcraft Classic · cliente «Forever» (Interface 16001)
</p>

<p align="center">
  <a href="https://github.com/Cerynna/CorpSR/blob/main/README.md">English</a> ·
  <a href="https://github.com/Cerynna/CorpSR/blob/main/docs/README.fr.md">Français</a> ·
  <a href="https://github.com/Cerynna/CorpSR/blob/main/docs/README.de.md">Deutsch</a> ·
  <b>Español</b> ·
  <a href="https://github.com/Cerynna/CorpSR/blob/main/docs/README.pt.md">Português</a> ·
  <a href="https://github.com/Cerynna/CorpSR/blob/main/docs/README.it.md">Italiano</a> ·
  <a href="https://github.com/Cerynna/CorpSR/blob/main/docs/README.ru.md">Русский</a> ·
  <a href="https://github.com/Cerynna/CorpSR/blob/main/docs/README.zh-CN.md">简体中文</a> ·
  <a href="https://github.com/Cerynna/CorpSR/blob/main/docs/README.zh-TW.md">繁體中文</a> ·
  <a href="https://github.com/Cerynna/CorpSR/blob/main/docs/README.ko.md">한국어</a>
</p>

![Mis SR](https://raw.githubusercontent.com/Cerynna/CorpSR/main/docs/images/en/MesSR.png)

CorpSR gestiona los Soft Reserve (SR) de tu hermandad dentro del juego: cada miembro reserva los objetos que quiere, el maestro despojador reparte el botín y el addon lee las `/roll`, las clasifica y guarda el historial. Cada SR que pierdes te da puntos en ese objeto: tu próxima tirada será más fuerte.

Sin web, sin exportar, sin hojas de cálculo. Los datos solo viajan por el canal de addon de la hermandad, y cada miembro guarda una copia completa: un oficial ausente nunca hace perder nada.

## Funciones

- **SR de la semana**: 2 por semana (ajuste del GM), en cualquier objeto de cualquier banda. Doble SR permitido.
- **Puntos**: pierdes un objeto que habías reservado → +10 puntos en él. Tu tirada SR = tirada + puntos.
- **Prioridad clara**: SR > +1 > +1 ya botín > +2 > Transfiguración, según el rango de la tirada.
- **Ventana del jugador**: el objeto, tus puntos, un botón por tipo de tirada, una barra de tiempo, «Pasar».
- **Ventana de reparto** para el maestro despojador: tiradas en directo, empates, ganador a elección, restos (banco de hermandad, desencantar).
- **Anuncios en banda** al empezar y al terminar cada objeto.
- **Entrega**: intento de comercio, susurro preparado, lista de lo que falta entregar, un desencantador para la sesión.
- **`!SR` por susurro** para los PUG (jugadores de fuera de la hermandad) y cualquiera sin el addon: no hace falta instalarlo.
- **Historial completo**: todo queda escrito; correcciones y anulaciones con motivo, reversibles.
- **Ajustes del GM**: valores y permisos rango por rango, reinicio completo.
- **Modo demo** para probarlo todo sin enviar nada a la hermandad.
- **10 idiomas**: inglés, francés, alemán, español, portugués, italiano, ruso, chino simplificado y tradicional, coreano.

## Las reglas

| Tipo de tirada | Tirada | Total |
|---|---|---|
| **SR** | `/roll 110` | tirada + tus puntos en el objeto |
| **+1** (especialización principal) | `/roll 100` | tirada |
| **+1 ya botín** (especialización principal, ya ganó un objeto en +1 esta semana) | `/roll 100` | tirada |
| **+2** (segunda especialización) | `/roll 50` | tirada |
| **Transfiguración** | `/roll 20` | tirada |

- **Gana la mejor categoría**, sean cuales sean las tiradas: un SR siempre gana a un +1. Dentro de una categoría gana el total más alto. En caso de empate, los empatados vuelven a tirar.
- **Puntos**: tiras con los puntos que ya tienes (0 la primera vez). Una vez tirado el objeto, todos los que lo reservaron, estaban en la banda y no se lo llevaron ganan **+10 por SR** en él (+20 con doble SR). El ganador no gana nada y, si lo ganó con SR, vuelve a 0 en ese objeto. Quien pulsa «Pasar» tampoco gana nada.
- **Los puntos se guardan** cuando cambias de objeto: esperan en reserva hasta que lo vuelvas a reservar.
- **Un objeto ganado gasta tu SR** de la semana: si varios jefes pueden soltarlo, no vuelves a tirar SR por él hasta la semana siguiente.
- **+1 ya botín**: desde tu primera victoria en +1 de la semana (o de la sesión, ajuste del GM). Las victorias en SR, +2 o transfiguración no cuentan.
- **Solo cuenta tu primera tirada válida.** Si caen N copias, ganan los N mejores.
- **Los PUG** (jugadores de fuera de la hermandad) siguen exactamente las mismas reglas que la hermandad: SR (susurrando `!SR`), puntos y todos los tipos de tirada.
- Todos los valores (puntos, número de SR, doble SR, rangos de tirada) son ajustes del GM.

## Una sesión de banda

**Oficiales**

1. Pestaña **Sesión** → **Nueva sesión**.
2. El maestro despojador abre el botín del jefe: la **ventana de reparto** se abre sola. También puedes hacer Alt + clic izquierdo en un objeto de tus bolsas.
3. Elige el objeto y luego **Lanzar**: tu clic anuncia el objeto en el chat de banda, con los rangos y el tiempo.
4. Las tiradas llegan en directo. Cuando se acaba el tiempo, **Validar** (o **Repetir empate**): tu clic anuncia al ganador.
5. CorpSR intenta abrir un comercio con el ganador y pone el objeto en él. Si no, un susurro queda listo en un botón. La pestaña **Por entregar** recuerda a quién se le debe qué.
6. ¿Nadie lo quiere? Banco de hermandad o desencantar.

![Ventana de reparto](https://raw.githubusercontent.com/Cerynna/CorpSR/main/docs/images/en/Attribution.png)

**Jugadores**

- Pestaña **Mis SR**: haz clic en un objeto para reservarlo, otra vez para un doble SR, clic derecho para quitar uno. Los SR se bloquean con el primer objeto tirado de la semana (o cuando un oficial los bloquea).
- Cuando cae un objeto, tu **ventana de tirada** muestra lo que puedes tirar. Un clic hace la `/roll` correcta por ti.

<p align="center">
  <img src="https://raw.githubusercontent.com/Cerynna/CorpSR/main/docs/images/en/Raideur.png" width="450" alt="Ventana del jugador">
</p>

- Pestaña **Puntos**: los puntos de todos, objeto por objeto. Pestaña **Historial**: todo lo que pasó, quién y cuándo.
- ¿PUG o sin addon? Susurra a un oficial `!SR [objeto] [objeto]` (enlaces de objetos, juntos o separados, o números de objeto). `!SR` solo te devuelve tus SR de la semana.

## Permisos por rango

El GM elige, rango por rango, quién puede hacer qué (pestaña Ajustes). Poner tus propios SR no necesita ningún permiso.

| Permiso | Permite |
|---|---|
| **Sesión** | abrir, bloquear, cerrar, reabrir, renombrar o eliminar una sesión; inscribir los SR de un jugador (PUG o miembro) que susurra `!SR` |
| **Reparto** | lanzar un objeto, leer las tiradas, validar al ganador, enviarlo al banco o a desencantar |
| **Corregir** | corregir los puntos de un jugador en un objeto, con motivo obligatorio |
| **Anular** | anular una línea del historial, con motivo obligatorio |
| **Objetos** | quitar un objeto de los objetos conocidos (cualquiera puede añadir) |

## Comandos

| Comando | Efecto |
|---|---|
| `/csr` | abre o cierra la ventana de CorpSR |
| `/csr attrib` | abre o cierra la ventana de reparto (también: clic derecho en el botón del minimapa) |
| `/csr demo` | inicia o detiene el modo demo |
| `/csr minimap` | muestra u oculta el botón del minimapa |
| `/csr sync` | pide a la hermandad los últimos datos |

CorpSR también añade una pestaña a la ventana **Hermandad y comunidades**, y una página a `/corp` cuando [CorpUI](https://github.com/Cerynna/CorpUI) está instalado (opcional).

## Conviene saber

- **El juego prohíbe a los addons escribir solos en el chat o susurrar.** Por eso los anuncios y los susurros pasan por botones: tu clic envía el mensaje, como si lo hubieras escrito. Estos botones se ocultan en combate.
- **En las mazmorras y bandas**, el texto de los susurros puede ocultarse a los addons: envía tu `!SR` antes de entrar.
- Los datos se comparten **solo con tu hermandad**, por el canal de addon. Nada sale del juego.

## Instalación

- **Wago**: [addons.wago.io/addons/corpsr](https://addons.wago.io/addons/corpsr), con la aplicación de Wago o a mano.
- **A mano**: pon la carpeta `CorpSR` en `Interface\AddOns` de tu carpeta de WoW Classic y reinicia el juego.

## Capturas

| | |
|---|---|
| ![Puntos](https://raw.githubusercontent.com/Cerynna/CorpSR/main/docs/images/en/Points.png) | ![Historial](https://raw.githubusercontent.com/Cerynna/CorpSR/main/docs/images/en/Historique.png) |
| ![Sesión](https://raw.githubusercontent.com/Cerynna/CorpSR/main/docs/images/en/Session.png) | ![Por entregar](https://raw.githubusercontent.com/Cerynna/CorpSR/main/docs/images/en/Remise.png) |
| ![Ajustes](https://raw.githubusercontent.com/Cerynna/CorpSR/main/docs/images/en/Reglages.png) | ![Objetos conocidos](https://raw.githubusercontent.com/Cerynna/CorpSR/main/docs/images/en/Raids.png) |

Las capturas muestran el addon en inglés; en el juego está en español. Todas las ventanas, en inglés y en francés: [`docs/images`](https://github.com/Cerynna/CorpSR/tree/main/docs/images). Están dibujadas a partir del diseño real del addon, en modo demo.

## Desarrollo

Organización del código, reglas detalladas y pruebas (en francés): [`docs/DEVELOPMENT.md`](https://github.com/Cerynna/CorpSR/blob/main/docs/DEVELOPMENT.md).
