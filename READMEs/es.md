<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="../assets/hero-dark.svg">
    <source media="(prefers-color-scheme: light)" srcset="../assets/hero-light.svg">
    <img src="../assets/hero-dark.svg" alt="aws-cost-audit: recorta el desperdicio de tu factura de AWS, cada precio comprobado en vivo con AWS" width="100%">
  </picture>
</p>

<h1 align="center">aws-cost-audit</h1>

<p align="center">
  <a href="../LICENSE"><img src="https://img.shields.io/github/license/Aboudjem/aws-cost-audit-skill" alt="Licencia MIT"></a>
  <a href="https://github.com/Aboudjem/aws-cost-audit-skill/actions/workflows/validate.yml"><img src="https://img.shields.io/github/actions/workflow/status/Aboudjem/aws-cost-audit-skill/validate.yml?branch=main&label=validate" alt="estado del workflow validate"></a>
  <a href="https://github.com/Aboudjem/10x"><img src="https://img.shields.io/badge/part%20of-10x-FFB341" alt="Parte del marketplace 10x"></a>
</p>

<p align="center">
  <a href="../README.md">English</a> · <a href="zh-CN.md">简体中文</a> · <a href="ja.md">日本語</a> · <b>Español</b> · <a href="fr.md">Français</a>
</p>

<p align="center">
  <strong>Recorta el desperdicio de tu factura de AWS, con precios en vivo.</strong>
</p>

<p align="center">
  Pide a tu agente que audite tu factura de AWS: un veredicto, tres recortes para empezar y un precio en vivo detrás de cada uno.
</p>

<p align="center">
  <a href="#informe-de-muestra">Informe de muestra</a> · <a href="#por-qué-usarlo">Por qué usarlo</a> · <a href="#instalación">Instalación</a> · <a href="#cómo-funciona">Cómo funciona</a> · <a href="#pruebas">Pruebas</a> · <a href="#preguntas-frecuentes">Preguntas frecuentes</a> · <a href="#límites">Límites</a>
</p>

```bash
npx skills add Aboudjem/aws-cost-audit-skill -a claude-code
```

Cambia `claude-code` por tu agente: `codex`, `cursor`, `gemini-cli`, `github-copilot` u `opencode`.
Si omites `-a`, la CLI te pide que elijas. Si usas el plugin de Claude Code, mira [Instalación](#instalación).

Después pídele a tu agente: `audit my AWS bill`. Lo que necesitas en tu máquina está en [Instalación](#instalación).

Dale credenciales de solo lectura: el skill guía a tu agente, los scripts exigen el sí.

## Informe de muestra

Todo informe empieza así. Este es una ilustración: cuenta ficticia, cifras inventadas, sin datos reales de AWS.
Vuelve a imprimirlo desde el repositorio con `bash skills/aws-cost-audit/scripts/findings-summary.sh examples/sample-findings.json`.

<!-- sample-report:begin -->

```text
VERDICT: save $242/mo now, safely. Up to $1,777/mo with sign-offs.
11 findings to act on: 4 safe now, 7 need sign-off. 1 to keep.

Do these three first:
1. OPTIMIZE 9 log groups that never expire (Amazon CloudWatch Logs, us-east-1): saves $84/mo. High confidence, reversible.
2. SAFE-TO-DELETE 4 unattached EBS volumes (vol-EXAMPLE1 to vol-EXAMPLE4) (Amazon EBS, us-east-1): saves $72/mo. High confidence, reversible.
3. OPTIMIZE abandoned multipart uploads in <demo-bucket> (Amazon S3, us-east-1): saves $58/mo. High confidence, reversible.

Detail:
- Save now safely: 4 findings, $242/mo
- Needs sign-off: 7 findings, $1,535/mo
- No verified cost: 0 findings, in no total
- Keep: 1 finding
Every figure above comes from the findings file. Nothing in your account was changed.
```

<!-- sample-report:end -->

El informe completo sigue con lo que pagas por servicio, cada hallazgo con su evidencia y cómo deshacerlo.
Mira [`examples/sample-report.md`](../examples/sample-report.md) y el [panel HTML](../examples/sample-dashboard.html) opcional.

Es para desarrolladores y equipos pequeños que pagan la factura de AWS sin una persona de FinOps.
Cost Explorer muestra el total, no qué apagar. Este skill nombra qué recortar.
Volúmenes sin uso, logs guardados para siempre, subidas que nadie terminó: cada hallazgo lleva su evidencia y dice si se puede deshacer.
Todo ahorro que no sea a la vez de confianza alta y reversible espera la aprobación del responsable.
Cost Explorer debe estar activado, y AWS puede tardar hasta 24 horas en mostrar datos.

## Por qué usarlo

- **Sabe por dónde empezar.** Un veredicto en dólares y luego los tres recortes que hacer primero.
  Prueba: la muestra de arriba se reimprime con el comando de arriba, y `make test` compara las dos línea a línea.
- **Confía en las cifras.** Los precios vienen de AWS en tiempo de ejecución, no de la memoria ni de una tabla de un blog.
  Prueba: `make test` y un escaneo de la CI fallan si un script contiene un precio fijo.
- **Nada cambia por sorpresa.** Es dry-run por defecto: los scripts de cambio solo muestran lo que harían.
  Con `--apply` guardan un archivo de reversión y luego te piden escribir yes. `--yes` se salta la pregunta.
  Sin terminal donde preguntar y sin `--yes`, se niegan. `make test` comprueba ese orden en el script de EBS.

## Instalación

Dentro de Claude Code, desde el [marketplace 10x](https://github.com/Aboudjem/10x):

```bash
claude plugin marketplace add Aboudjem/10x
claude plugin install aws-cost-audit@10x
```

En cualquier otro agente, con la [CLI de skills](https://github.com/vercel-labs/skills):

```bash
npx skills add Aboudjem/aws-cost-audit-skill
```

También necesitas la [AWS CLI](https://aws.amazon.com/cli/) con acceso de lectura a la cuenta, y `jq`.
Basta con la política administrada de AWS `ReadOnlyAccess` más lectura de facturación (`ce:Get*`, `pricing:GetProducts`).

Después pídele a tu agente: `audit my AWS bill`. Primero revisa tu configuración y nombra lo que falte.

Una aprobación es el visto bueno del responsable del recurso antes de cambiar nada.
Todo ahorro que no sea a la vez de confianza alta y reversible necesita una.

### Funciona con

| Agente               | Comando de instalación                                           | Probado    |
| :------------------- | :--------------------------------------------------------------- | :--------- |
| Claude Code (plugin) | `claude plugin install aws-cost-audit@10x`                       | 2026-11-17 |
| Claude Code (skill)  | `npx skills add Aboudjem/aws-cost-audit-skill -a claude-code`    | 2026-11-17 |
| Codex                | `npx skills add Aboudjem/aws-cost-audit-skill -a codex`          | 2026-11-17 |
| Cursor               | `npx skills add Aboudjem/aws-cost-audit-skill -a cursor`         | 2026-11-17 |
| Gemini CLI           | `npx skills add Aboudjem/aws-cost-audit-skill -a gemini-cli`     | 2026-11-17 |
| GitHub Copilot       | `npx skills add Aboudjem/aws-cost-audit-skill -a github-copilot` | 2026-11-17 |
| OpenCode             | `npx skills add Aboudjem/aws-cost-audit-skill -a opencode`       | 2026-11-17 |

«Probado» significa que la instalación se ejecutó y que `SKILL.md` quedó donde el agente lo lee.
La CI repite la instalación para Claude Code, Codex y Cursor en cada push.

Documentados, pero no probados de extremo a extremo: Pi, Mistral Vibe, Trae, OpenClaw, Antigravity, Hermes, Cline y Kimi.
Sus códigos de agente fueron aceptados por la CLI de skills fijada el 2026-11-17. Instálalos con `install.sh`, desde un clon:

```bash
git clone https://github.com/Aboudjem/aws-cost-audit-skill && cd aws-cost-audit-skill
./install.sh pi
```

Eso instala para todo tu perfil de usuario. Añade `--project` para instalar solo en la carpeta actual.
Las rutas por editor están en [docs/editors.md](../docs/editors.md).

<details>
<summary>Copiar el skill a mano</summary>

El skill es una carpeta de Markdown y scripts de shell. Cópiala donde tu agente lee los skills:

```bash
git clone https://github.com/Aboudjem/aws-cost-audit-skill
mkdir -p ~/.claude/skills
cp -r aws-cost-audit-skill/skills/aws-cost-audit ~/.claude/skills/aws-cost-audit
```

Este repositorio no tiene manifiesto de marketplace propio. Para el plugin, usa el marketplace 10x de arriba.
</details>

## Cómo funciona

<p align="center">
  <img src="../assets/how-it-works.svg" alt="Cómo funciona: 1 recalcular la base en vivo, 2 buscar desperdicio en todas las regiones, 3 plan de ahorro respaldado por evidencia" width="100%">
</p>

1. **Comprobación previa.** `doctor.sh` revisa la AWS CLI, las credenciales, `jq`, la región y la carpeta de salida. No cambia nada.
2. **Base de referencia.** Cost Explorer da tu gasto por servicio, región y tipo de uso. Los scripts cuentan cada petición y se detienen en un tope.
3. **Búsqueda.** Recorre cada región activada en busca de recursos inactivos, sobredimensionados u olvidados. Las comprobaciones están en [la lista de búsqueda](../skills/aws-cost-audit/references/hunt-list.md).
4. **Precio.** Cada dólar es el precio unitario en vivo de tu región por tu uso real. Ningún precio sale de la memoria.
5. **Clasificación.** Cada hallazgo es KEEP, OPTIMIZE o SAFE-TO-DELETE, con un nivel de confianza y su evidencia.
6. **Informe.** `findings-validate.sh` revisa `findings.json`, y luego `findings-summary.sh` imprime el veredicto y las tres acciones. El detalle sigue.

Nada cambia en tu cuenta si no lo pides. Tres scripts pueden cambiar algo, y el código lo impone:

- Sin `--apply` solo imprimen una simulación.
- Con `--apply` guardan primero un archivo de reversión y luego te piden escribir `yes`.
- `--yes` se salta esa pregunta. Sin terminal donde preguntar y sin `--yes`, se niegan antes de cualquier cambio.

El skill también indica a tu agente que te muestre primero la prueba de no uso y la simulación, y que espere tu sí.
Le indica que mantenga las acciones irreversibles, como comprar un Savings Plan, como recomendaciones.

El skill en sí es [`SKILL.md`](../skills/aws-cost-audit/SKILL.md): cinco reglas, los pasos y archivos de referencia que carga bajo demanda.

## Pruebas

Cada número de abajo lo vuelve a imprimir el comando que tiene al lado.

| Afirmación                                 | Comando                                                      | Resultado hoy                                                                 |
| :----------------------------------------- | :----------------------------------------------------------- | :---------------------------------------------------------------------------- |
| La suite sin conexión pasa                 | `make test`                                                  | `Results: 106 passed, 0 failed`                                                |
| La muestra de arriba es la salida real de la herramienta | `make test` (el caso 39 las compara línea por línea) | `[PASS] sample: the README sample report is the script output, line for line` |
| El manifiesto del plugin es válido         | `claude plugin validate . --strict`                          | `✔ Validation passed`                                                         |
| Ningún precio unitario está escrito en un script | `make test` (caso «no-hardcoded-price»)                | `[PASS] no per-request price literal in any script`                           |

La suite simula el comando `aws`, así que no necesita credenciales ni hace llamadas a AWS.
También comprueba el orden de seguridad de `delete-unattached-ebs.sh`: ningún cambio antes de la confirmación.
La CI añade un análisis de cada script para detectar un precio unitario fijo en el código.
La CI lo ejecuta en cada push y pull request, con shellcheck y la instalación con la CLI de skills.

Lo que los scripts pueden llamar, y lo que nunca envían a ningún sitio, está en [PRIVACY.md](../PRIVACY.md).

## Preguntas frecuentes

**¿Borrará algo por su cuenta?**
No. Por defecto solo lee. Un script de cambio solo se ejecuta con `--apply`, guarda un archivo de reversión y luego te pide escribir `yes`.
`--yes` se salta la pregunta, y el skill indica a tu agente que solo lo pase después de que digas sí en el chat.
El skill indica a tu agente que muestre primero la prueba de no uso y la simulación. Las acciones irreversibles siguen siendo recomendaciones.

**¿Necesita mis claves de AWS?**
No. Usa las credenciales de la AWS CLI que ya tienes en tu equipo. Tus datos van a AWS y a tu agente, a ningún otro sitio.

**¿Cuánto cuesta ejecutar una auditoría?**
Cost Explorer cobra cada petición a su API. Los scripts cuentan cada página y paran en `AWS_COST_AUDIT_CE_BUDGET`, 50 por defecto. Las consultas a la Price List son gratis.

**¿Por qué fiarse de las cifras en dólares?**
Cada una muestra el precio unitario, el cálculo y la fuente. Una cifra que no se puede verificar se escribe «unknown» y queda fuera de todos los totales.

**¿Son reales las cifras de la muestra?**
No. El informe de muestra, el panel y la demo usan una cuenta ficticia. Nada en ellos se leyó de una factura real de AWS.

**¿Puedo comparar dos auditorías?**
Sí. Pide `findings.json`. `findings-validate.sh` lo comprueba contra un contrato fijo, así que dos ejecuciones se pueden comparar.

Hay más respuestas en [docs/faq.md](../docs/faq.md).

## Límites

- Necesita la AWS CLI v2, bash y `jq`. En Windows, los scripts necesitan un shell bash; mira [docs/editors.md](../docs/editors.md).
- La base de referencia necesita Cost Explorer activado. Tras activarlo, AWS puede tardar hasta 24 horas en mostrar datos.
- El skill guía a tu agente. Un modelo más débil aún puede saltarse un paso, así que revisa las líneas de evidencia.
- Los precios están en USD, tal como los devuelve AWS.
- «Probado» en la tabla de agentes significa que la instalación se ejecutó y los archivos quedaron en su sitio. No significa que se viera a cada agente cargar el skill.
- La prueba de no uso y la simulación antes de un cambio son pasos que el skill pide a tu agente. Los scripts imponen `--apply`, el archivo de reversión y el `yes`.

## Más información

- [Inicio rápido](../docs/quickstart.md): de las credenciales al panel, paso a paso.
- [Soporte de editores y agentes](../docs/editors.md): una línea por agente, más la copia manual.
- [Comparación](../docs/comparison.md): frente a una auditoría manual y a un panel de costes.
- [CHANGELOG](../CHANGELOG.md) · [CONTRIBUTING](../CONTRIBUTING.md) · [Privacidad](../PRIVACY.md) · [Licencia MIT](../LICENSE)

---

<sub>Creado y mantenido por <a href="https://github.com/Aboudjem">Adam Boudjemaa</a>. ¿Ves un comando desactualizado? <a href="https://github.com/Aboudjem/aws-cost-audit-skill/issues">Abre un issue</a>.</sub>

<sub>Traducción asistida por máquina. Si hay dudas, el README en inglés es el que manda.</sub>
