<p align="center">
  <img src="https://raw.githubusercontent.com/Aboudjem/aws-cost-audit-skill/main/assets/hero.svg" alt="AWS Cost Audit: an executable, evidence-first AWS cost auditor for Claude Code" width="100%">
</p>

<h1 align="center">AWS Cost Audit Skill</h1>

<p align="center">
  <strong>Pide a Claude que audite tu factura de AWS. Obtén un plan de ahorro claro donde cada cifra se verifica contra los precios de AWS en vivo, y donde nada se elimina sin tu autorización.</strong>
</p>

<p align="center">
  <a href="../LICENSE"><img src="https://img.shields.io/badge/license-MIT-green.svg" alt="MIT license"></a>
  <img src="https://img.shields.io/badge/Claude%20Code-skill-d97757" alt="Claude Code skill">
  <img src="https://img.shields.io/badge/AWS-cost%20optimization-ff9900" alt="AWS cost optimization">
  <a href="../CONTRIBUTING.md"><img src="https://img.shields.io/badge/PRs-welcome-brightgreen.svg" alt="PRs welcome"></a>
  <a href="https://github.com/Aboudjem/10x"><img src="https://img.shields.io/badge/part%20of-10x%20marketplace-f59e0b" alt="Part of the 10x marketplace"></a>
</p>

<p align="center">
  Forma parte del <a href="https://github.com/Aboudjem/10x">marketplace <b>10x</b></a>, un conjunto cuidado de herramientas de Claude Code que entregan calidad.
</p>

<p align="center">
  <a href="../README.md">English</a> · <a href="zh-CN.md">简体中文</a> · <a href="ja.md">日本語</a> · <b>Español</b> · <a href="fr.md">Français</a>
</p>

---

![aws-cost-audit demo](https://raw.githubusercontent.com/Aboudjem/aws-cost-audit-skill/main/assets/demo.gif)

<p align="center"><sub>Pide a Claude que audite tu factura, obtén un plan de ahorro basado en evidencia. Todas las cifras mostradas son <b>ilustrativas</b> (datos sintéticos, ninguna cuenta real).</sub></p>

---

## ¿Qué es esto?

Es una skill de [Claude Code](https://www.claude.com/product/claude-code) que audita tu cuenta de AWS por ti.

Le pides a Claude algo como *"audita mi factura de AWS"*. La skill lee tu cuenta en vivo, calcula cuánto cuesta cada cosa y por qué, encuentra el desperdicio, y te entrega un informe en lenguaje claro: lo que pagas hoy, lo que puedes recortar sin riesgo, y cuán segura está de cada punto. Es de solo lectura por defecto. Nunca adivina un precio, y nunca elimina nada por su cuenta.

Piénsalo como un ingeniero FinOps cuidadoso que muestra su trabajo.

**¿Qué es una auditoría de costes de AWS?** Es una revisión estructurada de una cuenta de AWS que encuentra por qué estás pagando, qué recursos están desperdiciados o sobredimensionados, y qué puedes retirar sin riesgo. Esta skill ejecuta esa auditoría por ti y sigue el [pilar de optimización de costes del AWS Well-Architected Framework](https://docs.aws.amazon.com/wellarchitected/latest/cost-optimization-pillar/welcome.html) y el marco de la [FinOps Foundation](https://www.finops.org/framework/), de modo que el método no es algo inventado.

## Instalación

Elige la que prefieras. Las tres instalan la misma skill.

**Desde el [marketplace 10x](https://github.com/Aboudjem/10x)** (recomendado, está cuidado allí junto a otras herramientas de Claude Code):

```text
/plugin marketplace add Aboudjem/10x
/plugin install aws-cost-audit@10x
```

**Directamente desde este repositorio:**

```text
/plugin marketplace add Aboudjem/aws-cost-audit-skill
/plugin install aws-cost-audit@aws-cost-audit-skill
```

**Como skill autónoma** (sin sistema de plugins):

```bash
git clone https://github.com/Aboudjem/aws-cost-audit-skill
cp -r aws-cost-audit-skill/skills/aws-cost-audit ~/.claude/skills/aws-cost-audit
```

También necesitas el [AWS CLI](https://aws.amazon.com/cli/) configurado con acceso de lectura a la cuenta que quieres auditar. `ReadOnlyAccess` es suficiente para la auditoría en sí.

### Otras CLI de IA (en una línea)

Es un plugin solo de skill (sin servidor MCP). El instalador crea un enlace simbólico de la skill `aws-cost-audit` en el directorio de skills de otra CLI:

```bash
curl -fsSL https://raw.githubusercontent.com/Aboudjem/aws-cost-audit-skill/main/install.sh | bash -s <platform>
```

| Plataforma | Directorio de skills | Estilo de enlace |
|:--|:--|:--|
| gemini, codex, opencode, pi | `~/.agents/skills` | por skill |
| vscode, copilot | `~/.copilot/skills` | por skill |
| trae | `~/.trae/skills` | por skill |
| vibe | `~/.vibe/skills` | por skill |
| openclaw | `~/.openclaw/skills` | carpeta |
| antigravity | `~/.gemini/antigravity/skills` | carpeta |
| hermes, cline, kimi | `~/.<cli>/skills` | carpeta |

Pasa `all` para enlazar en todas las plataformas anteriores. Usa `--update` para reenlazar la última versión, `--uninstall` para quitar los enlaces.

<details>
<summary>Codex, Gemini, OpenCode, pi</summary>

```bash
curl -fsSL https://raw.githubusercontent.com/Aboudjem/aws-cost-audit-skill/main/install.sh | bash -s codex
```
</details>

<details>
<summary>VS Code (Copilot)</summary>

```bash
curl -fsSL https://raw.githubusercontent.com/Aboudjem/aws-cost-audit-skill/main/install.sh | bash -s copilot
```
</details>

<details>
<summary>Windows (PowerShell)</summary>

```powershell
git clone https://github.com/Aboudjem/aws-cost-audit-skill
./aws-cost-audit-skill/install.ps1 copilot
```
</details>

<details>
<summary>Otros editores (manual)</summary>

La skill es Markdown simple más scripts de shell. Copia `skills/aws-cost-audit/SKILL.md` y la carpeta `references/` en un directorio de contexto que tu editor lea, luego ejecuta directamente los scripts de ayuda en `skills/aws-cost-audit/scripts/`. Solo dependen del AWS CLI.
</details>

## Úsala en 3 pasos

1. **Instálala** (arriba).
2. **Pide a Claude** que *"audite mi factura de AWS"* o que *"encuentre mis recursos de AWS sin usar"*. La skill se activa sola.
3. **Lee el plan.** Obtienes un informe, y un panel HTML opcional, que muestran el coste, la causa, y un nivel de confianza para cada ahorro.

Eso es todo. Nada se cambia en tu cuenta a menos que lo pidas, e incluso entonces solo tras una comprobación de seguridad y tu confirmación.

<p align="center">
  <img src="https://raw.githubusercontent.com/Aboudjem/aws-cost-audit-skill/main/assets/how-it-works.svg" alt="How it works: 1 re-baseline live, 2 hunt waste across every region, 3 evidence-backed savings plan" width="100%">
</p>

## Lo que obtienes

<p align="center">
  <img src="https://raw.githubusercontent.com/Aboudjem/aws-cost-audit-skill/main/assets/dashboard-preview.png" alt="Sample AWS cost audit dashboard: monthly run-rate, save-now-safely vs maximum-theoretical-save, with synthetic data" width="100%">
  <br><sub>El panel opcional (ejemplo mostrado, datos sintéticos). Abre <a href="../examples/sample-dashboard.html"><code>examples/sample-dashboard.html</code></a> para verlo en vivo.</sub>
</p>

- **Un desglose del gasto.** Lo que pagas hoy, por servicio y por región, extraído en vivo de Cost Explorer.
- **Una vista por recurso.** Para cada recurso: lo que cuesta, lo que hace en palabras sencillas, quién lo creó, cuándo, y cuándo se usó por última vez. Si un hecho no puede verificarse, lo dice en lugar de adivinar.
- **Un plan de ahorro en dos partes.** "Ahorrar ahora sin riesgo" (alta confianza, reversible, bajo riesgo) mantenido aparte de "ahorro teórico máximo" (los recortes mayores que necesitan tu visto bueno).
- **Un panel opcional.** Una única página HTML autónoma que una persona no técnica puede leer. Mira [`examples/sample-dashboard.html`](../examples/sample-dashboard.html) y un [informe de ejemplo](../examples/sample-report.md).
- **Salvaguardas.** Comprueba si tienes presupuestos y alertas de anomalías de coste, y te ayuda a configurarlos.

## Cómo se ve una ejecución

La grabación de arriba (`assets/demo.gif`) es ilustrativa: usa datos sintéticos, no una cuenta real, porque las llamadas a AWS requieren credenciales en vivo (mira la nota sobre elementos aplazados en [CONTRIBUTING.md](../CONTRIBUTING.md)). Esto es lo que pasa paso a paso, reflejado en el [informe de ejemplo](../examples/sample-report.md) y el [panel de ejemplo](../examples/sample-dashboard.html) (ambos usan datos sintéticos, claramente etiquetados):

1. **Comprobación de identidad.** `aws sts get-caller-identity` confirma la cuenta y la región antes de que se ejecute cualquier otra cosa.
2. **Línea base de gasto.** Cost Explorer (`aws ce get-cost-and-usage`) extrae el gasto de los últimos 30 y 90 días, desglosado por servicio y por región. Ves una tabla: servicio → $/mes → cuota del total.
3. **Inventario de recursos.** La skill se despliega por cada región habilitada, listando instancias EC2, volúmenes EBS, instancias RDS, NAT Gateways, balanceadores de carga, buckets S3, funciones Lambda, grupos de logs de CloudWatch, snapshots, AMI, Elastic IP, y más. Nada se modifica.
4. **Detección de desperdicio.** Cada recurso se compara con la lista de caza (`skills/aws-cost-audit/references/hunt-list.md`): CPU inactiva, volúmenes no adjuntos, snapshots antiguos, volúmenes gp2, logs sobre-retenidos, falta de cobertura de Savings Plan, etc.
5. **Verificación de precios en vivo.** Para cada ahorro candidato, la skill obtiene el precio unitario en vivo, específico de la región, desde el AWS Price List Query API, sin tarifas memorizadas. Muestra `unit price → math → source` para cada cifra en dólares.
6. **Informe basado en evidencia.** Los hallazgos se escriben como `current $/mo → after $/mo → $ saved · confidence · evidence · reversibility`, divididos en "ahorrar ahora sin riesgo" (alta confianza, reversible, probado) y "ahorro teórico máximo". Mira [`examples/sample-report.md`](../examples/sample-report.md) para la forma exacta.
7. **Panel opcional.** Se genera un archivo HTML a partir de los hallazgos, ábrelo en cualquier navegador. Mira [`examples/sample-dashboard.html`](../examples/sample-dashboard.html).

Una ejecución real en una cuenta de AWS de tamaño medio normalmente saca hallazgos a la luz en unos pocos minutos tras la primera llamada a Cost Explorer. La fase de solo lectura termina antes de hacer cualquier sugerencia de remediación.

## Por qué puedes confiar en las cifras

La mayoría de los consejos para "reducir tu factura de AWS" son genéricos, o bien es una herramienta que cita un precio de memoria. Esta skill está construida en torno a cinco reglas que no romperá:

1. **Ningún precio inventado.** Cada dólar proviene del precio de AWS en vivo para *tu* región más tu uso *real*. Muestra el precio unitario, el cálculo, y la fuente. No codifica ningún precio en ninguna parte.
2. **Atribuir cada dólar, o decir "desconocido".** Nunca inventa un propietario, una fecha, o un "último uso".
3. **Nada destructivo sin prueba.** Un cambio se ejecuta solo si el recurso está probado como sin usar, la acción es reversible, pasó una prueba en seco, y el resultado es seguro. De lo contrario sigue siendo una recomendación.
4. **Una muestra nunca es toda la flota.** Una pasada escéptica aparte vuelve a derivar las cifras principales desde la fuente antes de publicarlas.
5. **Cada hallazgo muestra su evidencia.** Coste actual, coste después, dólares ahorrados, un nivel de confianza, la prueba, y cómo deshacerlo.

Estas reglas existen porque vimos a agentes *sin* la skill romperlas. La línea base registrada está en [`docs/research/RED-baseline-findings.md`](../docs/research/RED-baseline-findings.md): al preguntarles por la misma cifra de ahorro, dos modelos devolvieron con aplomo dos cifras erróneas distintas, de memoria. La skill arregla eso.

## Cómo se compara

| | Esta skill | Una auditoría manual | Un panel SaaS de costes |
|---|---|---|---|
| Se ejecuta contra tu cuenta en vivo | Sí | Sí | Sí |
| Puedes ejecutarla ahora mismo, gratis | Sí | Sí | Normalmente de pago / por asiento |
| Verifica cada precio en vivo (sin tarifas memorizadas) | Sí | Depende de la persona | Muestra sus propias cifras |
| Atribuye coste, propietario, y último uso por recurso | Sí | Lento, a mano | Parcial |
| Puede actuar sobre los hallazgos sin riesgo (con control + reversible) | Sí | Manual | Solo lectura |
| Genera un informe + panel compartibles | Sí | Manual | Sí |
| Envía tus datos a un tercero | No | No | A menudo |
| Bloqueo | Ninguno (MIT, tu cuenta) | Ninguno | Proveedor |

## FAQ

**¿Cómo audito mi factura de AWS con Claude?**
Instala esta skill, luego pide a Claude Code que "audite mi factura de AWS". Lee tu cuenta con el AWS CLI y produce un informe de costes y un plan de ahorro basados en evidencia.

**¿Es seguro? ¿Eliminará algo?**
Es de solo lectura por defecto. No eliminará, detendrá, ni cambiará nada por su cuenta. Toda acción tiene control: el recurso debe estar probado como sin usar, el cambio debe ser reversible, debe pasar una prueba en seco, y debes confirmar. Las acciones irreversibles siempre se dejan como recomendaciones.

**¿Necesita mis claves de AWS?**
No. Usa tus credenciales existentes del AWS CLI en tu propia máquina. Nada se sube a ningún sitio. `ReadOnlyAccess` es suficiente para la auditoría.

**¿Funciona en mi cuenta?**
Sí. Es genérica. Lee la cuenta a la que apunta tu CLI, a través de todas las regiones, y se entrega sin ningún ID de cuenta, ARN, ni precio codificado en duro.

**¿Codifica los precios de AWS?**
No, a propósito. Los precios cambian y varían según la región, así que siempre obtiene el precio en vivo para tu región y lo combina con tu uso real.

**¿Qué cubre?**
Recursos inactivos y no adjuntos, gp2→gp3, snapshots y AMI antiguos, costes de NAT y de transferencia de datos, balanceadores de carga inactivos, rightsizing, cobertura de Savings Plans e Instancias Reservadas, ciclo de vida de S3, retención de logs de CloudWatch, sobras entre regiones, y presupuestos/alertas faltantes. La lista completa está en [la lista de caza](../skills/aws-cost-audit/references/hunt-list.md).

**¿Puedo usarla sin el sistema de plugins?**
Sí. Copia `skills/aws-cost-audit/` en `~/.claude/skills/aws-cost-audit/` y funciona de la misma manera.

## Cómo funciona por dentro

La skill está en [`skills/aws-cost-audit/SKILL.md`](../skills/aws-cost-audit/SKILL.md). El detalle más pesado se carga solo cuando hace falta, desde `references/`:

- [`hunt-list.md`](../skills/aws-cost-audit/references/hunt-list.md): cada comprobación de alto ROI, con el comando de solo lectura para detectarla.
- [`pricing-verification.md`](../skills/aws-cost-audit/references/pricing-verification.md): cómo obtiene un precio en vivo, correcto para la región, y lo vuelve a comprobar.
- [`safety-and-gating.md`](../skills/aws-cost-audit/references/safety-and-gating.md): el control executor → verifier → rollback, y lo que nunca puede ejecutarse por sí solo.
- [`output-and-reporting.md`](../skills/aws-cost-audit/references/output-and-reporting.md): la forma del informe y el contrato por hallazgo.

Los scripts de ayuda en [`scripts/`](../skills/aws-cost-audit/scripts) están en prueba en seco por defecto. Mira el [inicio rápido](../docs/quickstart.md) para una primera ejecución guiada.

## Soporte de editores

Esta skill está diseñada para **Claude Code**. Funciona cargando `SKILL.md` en el contexto de Claude Code y llamando al AWS CLI, así que requiere Claude Code como runtime.

Otros editores de IA (Cursor, VS Code con Copilot, Windsurf, Codex, Gemini CLI) no usan de forma nativa el formato de plugin o skill de Claude Code. Si usas uno de esos editores, la vía más práctica es:

1. Instala el AWS CLI y configura tus credenciales como de costumbre.
2. Copia `skills/aws-cost-audit/SKILL.md` y la carpeta `references/` en tu proyecto (o un directorio de contexto personal que tu editor lea).
3. Apunta tu editor al contenido de SKILL.md como prompt de sistema o instrucción personalizada.
4. Ejecuta directamente los scripts de ayuda en `skills/aws-cost-audit/scripts/`. Son scripts de shell simples que solo dependen del AWS CLI, no de Claude Code.

La lógica de la skill (Iron Laws, workflow, salvaguardas de seguridad) es totalmente portable. Solo el *mecanismo de instalación* (sistema de plugins, autodescubrimiento `/skill`) es específico de Claude Code.

## Contribuir

Las issues y las PR son bienvenidas. La única regla firme: esta skill se construye test-first, así que un cambio que añade comportamiento necesita la línea base en fallo que arregla. Mira [CONTRIBUTING.md](../CONTRIBUTING.md) y el [Código de conducta](../CODE_OF_CONDUCT.md).

## Star History

<a href="https://star-history.com/#Aboudjem/aws-cost-audit-skill&Date">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/svg?repos=Aboudjem/aws-cost-audit-skill&type=Date&theme=dark">
    <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/svg?repos=Aboudjem/aws-cost-audit-skill&type=Date">
    <img alt="Star history of Aboudjem/aws-cost-audit-skill" src="https://api.star-history.com/svg?repos=Aboudjem/aws-cost-audit-skill&type=Date">
  </picture>
</a>

## Licencia

[MIT](../LICENSE). Úsala, bifúrcala, publícala.

---

<sub>Creada y mantenida por <a href="https://github.com/Aboudjem">Adam Boudjemaa</a>. Comandos verificados contra el AWS CLI v2 y la documentación de AWS en 2026. ¿Detectas un comando obsoleto o una carencia? <a href="https://github.com/Aboudjem/aws-cost-audit-skill/issues">Abre una issue</a>.</sub>

---

<sub>Traducción asistida por máquina. Una corrección de un hablante nativo es bienvenida: <a href="https://github.com/Aboudjem/aws-cost-audit-skill/issues">abre una issue</a> o una PR.</sub>
