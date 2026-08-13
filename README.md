# Orbit Skills

Orbit Skills are nine specialized skills for working with the Organoid Database. They route a request to the appropriate documented API capability, preserve API provenance, and keep database evidence separate from biological interpretation.

The repository exposes one self-contained plugin at [`plugins/orbit-skills/`](plugins/orbit-skills/). Claude Code, Codex, and Cursor each load their own manifest from that package while sharing its single `skills/`, `references/`, and `scripts/` directories.

## What the nine skills do

| Skill | What it does | Use it when the user asks to... |
|---|---|---|
| `orbit-search` | Searches protocols, biomarkers, pathways, trends, and genes across samples. It can hand off returned sample IDs to detail or analysis workflows. | Find organoid culture protocols, biomarkers, pathways, trends, or resolve a gene symbol/Entrez ID. |
| `orbit-browse` | Searches and inspects organoid sample records. It supports General, Immune-Oncology, and Host-Microbe collections, semantic search, sample details, culture plans, phenotypes, applications, gene annotations, and `referenceSample` links. | Find a sample, inspect a known `sampleId`, compare sample metadata, or look up gene annotation and related KM samples. |
| `orbit-chat` | Discovers multiple KM samples, applies the user's explicit constraints to returned native fields, retrieves selected sample details, and synthesizes results grouped by `sampleId`. | Ask for a multi-sample comparison, such as finding human kidney organoid candidates and comparing their returned culture or phenotype details. |
| `orbit-reason` | Builds a traceable multi-hop evidence graph across samples, datasets, pathways, genes, biomarkers, culture factors, perturbations, phenotypes, methods, and annotations. It classifies edges as direct, same-sample co-occurrence, free-text, or unresolved. | Connect a condition to pathways and genes, relate a biomarker to a disease model, or audit whether a proposed cross-layer biological chain is actually supported. |
| `orbit-protocol` | Converts returned protocol evidence and user choices into candidate culture plans. It separates protocol families, collects decision-critical constraints, exposes conflicts, and distinguishes KM-returned QC from agent suggestions. | Choose or adapt a protocol for a specific organoid goal, starting material, duration, complexity, co-culture requirement, or disease model. |
| `orbit-design` | Designs an experiment around a hypothesis: groups, controls, replicates, batches, timeline, perturbations, readouts, QC, omics context, conflicts, and STOP/WARN/INFO gates. | Plan an experiment, compare controls, define biological and technical replicates, integrate omics into a design, or identify missing design information. |
| `orbit-omics` | Retrieves analysis results for a known sample context, including RNA-seq, scRNA-seq, pseudobulk, GSEA, GSVA, trajectories, and interactions. It requires the API-returned `dataSet` and `group` context and preserves dataset boundaries. | Ask for differential genes, enriched pathways, cell types, pseudobulk results, trajectory data, or interaction results for a known sample. |
| `orbit-analysis` | Manages quick biomarker prioritization: enumerates valid organoid conditions, validates user-supplied gene symbols or expression matrix/group files, submits only with explicit consent, retrieves results by exact job ID, and adds bounded ORBIT gene annotations and KOBAS context for researcher interpretation. | Rank candidate biomarkers from a gene list or expression data, inspect a quick biomarker job, or explain completed ranked genes. |
| `orbit-help` | Reports the installed Orbit Skills version and explains which skill to use for each research task. It does not call the API or perform research retrieval. | Ask what Orbit Skills can do, which skill to use, how skills hand off to one another, or which version is installed. |

## Choosing the right skill

Use the narrowest skill that matches the request:

```text
Need a protocol, biomarker, pathway, trend, or gene lookup?
  → orbit-search

Need one sample or a gene annotation?
  → orbit-browse

Need several samples compared by explicit constraints?
  → orbit-chat

Need a custom culture plan based on evidence and choices?
  → orbit-protocol

Need an experimental plan with controls, replicates, QC, and readouts?
  → orbit-design

Need results from a known sample's RNA/scRNA/pseudobulk analysis?
  → orbit-omics

Need to connect multiple evidence layers or test a biological chain?
  → orbit-reason

Need biomarker prioritization from gene symbols or an expression matrix?
  → orbit-analysis

Need help choosing a skill or checking the installed version?
  → orbit-help
```

Typical handoffs are:

- `orbit-search` → `orbit-browse` when a search returns sample IDs that need detail inspection.
- `orbit-search` → `orbit-protocol` when search results must be adapted into a user-specific culture plan.
- `orbit-browse` → `orbit-omics` when a returned sample has a valid control-group context.
- `orbit-browse` or `orbit-omics` → `orbit-reason` when the user asks for a multi-hop relationship rather than a single result list.
- `orbit-chat` → `orbit-reason` when a cross-sample synthesis needs explicit edge classification.
- `orbit-analysis` remains separate because it manages asynchronous quick biomarker jobs and user-supplied analysis inputs rather than database browsing or biological validation.

## Important boundaries

### API evidence is not causality

A returned field can support only the relation expressed by that field. A shared `sampleId`, `dataSet`, or comparison establishes context or co-occurrence; it does not by itself prove activation, regulation, mediation, response, mechanism, clinical validity, or causality.

`orbit-reason` uses four evidence classes:

- `DIRECT_EDGE`: the API structure explicitly relates two entities.
- `SAME_SAMPLE_CO_OCCURRENCE`: entities share a sample or analysis context without an explicit biological relation.
- `FREE_TEXT_LINK`: a relation appears only in returned text.
- `UNRESOLVED_EDGE`: the required relation or identifier is missing or not documented.

### Preserve identifiers and provenance

- Use only API-returned `sampleId`, pathway IDs, Entrez IDs, `dataSet`, and groups.
- For omics list endpoints, the control-group response field `dataSet` is passed as the result-query key `data`; these names are not interchangeable.
- Do not infer a KM `sampleId` from a GSE-like value, title, display name, DOI, or prefix.
- Keep the endpoint, request filters, native response fields, references, status, and missing values with each claim.
- Do not merge effects, p-values, enrichment scores, or expression values across different datasets as if they were one analysis.

### Sample-specific gene annotation

`gene-annotation` returns general gene annotation plus `referenceSample` records when available. `referenceSample` can directly connect a gene annotation to returned KM sample IDs and includes fields such as reference, DOI, index, and source. The optional request `sampleId` is not currently a sample-level filter, so this should not be described as a sample-specific annotation query.

### Quick biomarker analysis safety

`orbit-analysis` does not invent condition values, candidate genes, or analysis files, and it never submits or uploads without explicit user intent. Conditions must come from the API enumeration, gene mode accepts at most 20 supplied symbols, expression files are checked against the documented combined size limit, and status/results require the exact API-returned job ID. An ambiguous submission is never replayed automatically. For completed rankings, it resolves and annotates at most five distinct returned genes by default and retrieves bounded species-specific KOBAS records for those resolved genes; identity, annotation, and KOBAS failures remain explicit. General gene and pathway database metadata is interpretive context, not biomarker validation, sample-specific evidence, or proof of pathway enrichment/activity.

## Shared HTTP behavior

For every Orbit request, the skills use the repository wrapper:

- Linux/macOS: `<plugin-root>/scripts/orbit-request.sh ...`
- Windows PowerShell: `<plugin-root>/scripts/orbit-request.ps1 ...`

The default base URL is `https://db-orbit.com`. Before using an Orbit skill, set `ORBIT_REQUEST_API_KEY` in the Agent host process; every wrapper request sends it as `Authorization: Bearer <value>`. The key is never read from `<plugin-root>/scripts/orbit-request.local.env`. Developers can override the base URL with a process-level `ORBIT_BASE_URL` or that ignored local file. Windows PowerShell JSON POST requests must use a UTF-8-without-BOM body file because native pipeline stdin can corrupt non-ASCII text. Do not commit internal URLs, tokens, or passwords. Requests use documented relative `/api/...` paths, preserve the native response, and check both HTTP status and JSON `code`.

Read [organoid-api-contract.md](plugins/orbit-skills/references/organoid-api-contract.md) before changing request behavior. Read [api-reference.md](plugins/orbit-skills/references/api-reference.md) before selecting an endpoint. Do not replace the wrapper with ad-hoc Python, urllib, browser automation, WebFetch, or undocumented endpoints.

## Output expectations

A good Orbit skill response should make clear:

1. Which endpoint or workflow was used.
2. Which user constraints were applied.
3. Which identifiers and fields came directly from the API.
4. What is missing, empty, conflicting, or failed.
5. What the returned evidence supports and what it does not support.

The skills provide database-backed research evidence and workflow support. They do not replace qualified experimental review, independent statistical reanalysis, clinical evaluation, or causal inference.

## Install, upgrade, and remove

### Claude Code

Inside Claude Code, add the Git marketplace and install the plugin:

```text
/plugin marketplace add https://github.com/chenjiang-bio/orbit-skill
/plugin install orbit-skills@orbit-skills-marketplace
/reload-plugins
```

Verify with `/plugin list`, or from a terminal with `claude plugin list`. For project scope, use `claude plugin install orbit-skills@orbit-skills-marketplace --scope project` after adding the marketplace.

### Codex

A Git clone only copies this repository; it does **not** register a plugin in Codex. Register the marketplace and then install through the current Codex CLI:

```bash
codex plugin marketplace add https://github.com/chenjiang-bio/orbit-skill --ref main
```

```bash
codex plugin add orbit-skills@orbit-skills-marketplace
```

```bash
codex plugin list
```

The final command must list `orbit-skills@orbit-skills-marketplace` as installed and enabled. In Codex App, the plugin can also be installed and enabled through `/plugins` after the marketplace is registered. Restart the app or open a new task; all nine skills should then be discoverable.

### Cursor

Cursor does not document a general Git-URL plugin-install CLI. Public users install through Cursor Marketplace / Customize after publication. For local testing, place or link [`plugins/orbit-skills/`](plugins/orbit-skills/) at `~/.cursor/plugins/local/orbit-skills`, then restart Cursor or run `Developer: Reload Window`. Teams and Enterprise can import the repository through the private marketplace controls.

A manifest describes a plugin's contents; cloning the repository alone does not register or enable that plugin in Claude Code, Codex, or Cursor. A public Git URL needs no repository-stored credential. Private Git services use their normal Git/client authentication; never commit tokens, passwords, or internal URLs.

Before the first Orbit request, configure `ORBIT_REQUEST_API_KEY` in the Claude Code, Codex, or Cursor host process and restart or open a new process so the plugin inherits it. The key must not be placed in `orbit-request.local.env`. Internal deployments may additionally set `ORBIT_BASE_URL` in the host process or create `<plugin-root>/scripts/orbit-request.local.env` beside the wrappers. Never commit that file or any credentials.


```text
.claude-plugin/marketplace.json          Claude Code marketplace
.agents/plugins/marketplace.json         Codex marketplace
.cursor-plugin/marketplace.json          Cursor marketplace catalog
plugins/orbit-skills/                    Single self-contained plugin
  .claude-plugin/plugin.json             Claude Code manifest
  .codex-plugin/plugin.json              Codex manifest
  .cursor-plugin/plugin.json             Cursor manifest
  skills/orbit-*/SKILL.md                Nine canonical skill entries
  references/                            Shared API and evidence references
  scripts/                               Cross-platform HTTP wrappers
README.md / README_zh.md                 Installation and usage guides
```
## License
This project is released under the MIT License.