---
name: orbit-omics
description: Query Organoid Database API omics results for a known sample or dataset, including RNA-seq, scRNA-seq, pseudobulk differential genes/cell types/pathways, chart-ready data, trajectories, and gene-interaction data. Use this skill whenever a user asks for sample-specific RNA-seq, scRNA-seq, GSEA, GSVA, pseudobulk, volcano, heatmap, GO, KEGG, cell trajectory, cluster, or gene-pathway results. This skill returns documented API data only and does not use webpages, browser tools, or unsupported statistical or medical interpretation.
---

# Organoid Omics

Read `<plugin-root>/references/api-reference.md` for exact endpoint calls, `<plugin-root>/references/organoid-api-contract.md` for shared request safety, and `<plugin-root>/references/researcher-response-contract.md` for response modes and researcher-first presentation before making any API request.

## HTTP transport

For every Orbit HTTP attempt, invoke the wrapper at `<plugin-root>/scripts/orbit-request.sh ...` on Linux/macOS, or `<plugin-root>/scripts/orbit-request.ps1 ...` on Windows PowerShell. Resolve `<plugin-root>` from the installed plugin resources, not the user's current working directory. Use only the documented relative `/api/...` path and a body file or stdin for a documented JSON POST. Do not generate ad-hoc Python, `urllib`, `curl`, or other request scripts, and do not use browser/WebFetch transport. Preserve the exact request and wrapper stderr status line as provenance; inspect stdout JSON `code` under the shared contract.

Use this skill only after the user identifies a sample, dataset, or analysis context. For cross-sample pathway search, use `orbit-search`; for a multi-hop evidence chain involving omics pathways, genes, biomarkers, or phenotypes, use `orbit-reason`; for sample metadata or sample selection, use `orbit-browse`; for integrating omics into controls, replicates, batches, and readouts, use `orbit-design`.

Use an explicitly requested output language when provided; otherwise use the user's task language for visible output and the shared missing-information states. Preserve whether each design field came from the API, the user, or remains unavailable. Any reasoning handoff must retain the GSE/`dataSet`, contrast, platform, and cross-dataset boundaries below.

## Begin with analysis context

Before selecting a detailed omics endpoint that depends on a dataset/group comparison, obtain the available control-group context:

- RNA-seq: `GET /api/browse/sample/rna-seq/control-group`
- scRNA-seq: `GET /api/browse/sample/scrna-seq/control-group`

Both require an API-returned `sampleId` and return dataset IDs with available groups. The valid detail path is always:

```text
sampleId → modality-specific control-group endpoint → returned dataSet → returned group → detail endpoint
```

Do not fabricate `group` or `dataSet` values. Ask the user to choose with `AskUserQuestion` when multiple API-returned options exist, using at most four clickable options per question and additional rounds when needed. If the response succeeds with `code == 0` but `data.list` is empty, report `EMPTY_OMICS_CONTEXT` and stop before dependent detail endpoints. If the context request fails, keep that request outcome separate and stop only the dependent result path; do not describe it as an empty context or biological absence.

### GSE boundary

Search endpoints may return a native `data` field whose value resembles a GSE accession. Search `data` is not automatically the `dataSet` required here.

- If only GSE is known and the user needs a KM mapping, call `GET /api/browse/sample/reference/gds?gseId=...`; preserve the returned mapping row (`gseId`, raw semicolon-delimited `sampleId`, `platform`) and use only its returned IDs for the next step.
- A GDS mapping never replaces the required modality-specific control-group request. For every mapped `sampleId`, obtain a newly returned `dataSet` and group before detail retrieval; do not use the GSE value as `dataSet`.
- If a search result returns both GSE-like `data` and `sampleId`, use only the returned `sampleId` to call control-group. Use the newly returned `dataSet` and groups for details.
- Preserve the GSE-like value and mapping row as search provenance only. If GDS is empty or fails, report that state and stop rather than inferring a mapping.

## Result-list queries

Use the documented `GeneralSearchReq` shape for result-list endpoints: page, pageSize, optional sortField/sortOrder/keywords, and documented `search` filters. By default, omit `sortField` and `sortOrder` and preserve service order. Add a documented sort only when the user explicitly requests it; do not impose ascending adjusted p-value or another ranking as an unstated default. The active endpoint families include:

- RNA-seq GSEA differential genes and cell types; enriched pathways.
- RNA-seq GSVA differential pathways.
- scRNA-seq cluster marker and differential genes.
- pseudobulk GSEA differential genes/cell types and enriched pathways.
- pseudobulk GSVA differential pathways.

The following scRNA-seq overall result-list endpoints are retired and must never be called, even when they appear in historical run artifacts:

- `/api/browse/sample/scrna-seq-overall-gsea/differ-genes/search`
- `/api/browse/sample/scrna-seq-overall-gsea/differ-cell-type/search`
- `/api/browse/sample/scrna-seq-overall-gsea/enriched-pathways/search`
- `/api/browse/sample/scrna-seq-overall-gsva/differ-pathways/search`

For current result-list requests, first obtain `dataSet` and groups from the modality-specific control-group endpoint. Most active list endpoints no longer use `sampleId` as a filter even though the response field is retained. Build the default `GeneralSearchReq.search[]` with:

- `key: group`, using the selected API-returned group;
- `key: data`, using the selected control-group `dataSet` value.

### Critical `dataSet` → `data` translation

The control-group response key and list-query key are intentionally different and must never be interchanged:

```text
control-group response: dataSet = "GSE277637"
result-list request:   search[key="data", value="GSE277637"]
```

There is no backend `dataSet → data` alias. Sending `search[key=dataSet]` is converted to the database name `data_set` and can cause an internal error. Keep both names in provenance so this translation remains visible during handoff and debugging.

The list key is `data`, not `dataSet`. Always send both `group` and `data`: a group may appear globally unique today but can be duplicated across datasets. Do not send `sampleId` for differential genes, differential cell types, GSVA differential pathways, cluster results, or pseudobulk differential results.

Two enriched-pathway lists have an additional identity requirement:

- `/api/browse/sample/rna-seq-gsea/enriched-pathways/search`
- `/api/browse/sample/scrna-seq-gsea/pseudobulk/enriched-pathways/search`

For the RNA-seq endpoint, send `group` + `data` and also either the API-returned `sampleId`, or both `platform` and `organism`.

The pseudobulk enriched-pathways endpoint intentionally shares the general RNA-seq enriched-pathways implementation and table. It is a **conditional result source**, not a route mismatch. For it, send `group` + `data`, and also either the API-returned `sampleId`, or both `platform` and `organism` for identity admission. To define a pseudobulk analysis scope, also send a JSON-numeric `resolution`, a defined `type`, and `cellType` when applicable. The service normalizes `type`, maps `cellType` to `pseudobulk_cell_type`, and converts numeric equal `resolution` into a narrow ±0.0001 range.

`sampleId`, `platform`, and `organism` are removed before final SQL and must not be described as row-level filters. The response does not return `data`, `resolution`, `type`, or `cellType`; preserve the exact request as analysis provenance, including the `dataSet → data` translation. If a required scope dimension is absent, do not interpret the result as a unique pseudobulk pathway context or link it to genes/biomarkers as a sample-specific pathway relation: return `UNRESOLVED_EDGE: INCOMPLETE_ANALYSIS_SCOPE`. The existing KM-00004 resolution-empty observations remain request outcomes, not evidence that the shared endpoint is incorrectly routed. The project audit is recorded at `docs/pseudobulk-enriched-pathways-implementation-doc-gap-report.md`.

A returned row may retain `sampleId` with an empty value. Preserve the native empty value and bind provenance to the exact request context: `data`, `group`, and, for enriched pathways, the identity constraint used. Do not rewrite the response field.

Select the exact active documented result family that matches the requested modality and result type. Keep the exact endpoint and request-key translation in internal provenance; show the endpoint only in audit, machine output, or when the user explicitly requests technical trace or when it is necessary to disambiguate the scientific result.

### Stage-scoped failures and diagnostics

Track context retrieval, result-list retrieval, and optional chart/advanced retrieval as separate workflow stages.

- A failed context stage stops only requests that require that missing dataset/group context.
- A result-list, chart, or advanced-data failure preserves the validated context and every other successful stage. Report the affected stage, request context, and observable request outcome without replacing it with historical data or model knowledge.
- A transport timeout, HTTP/business error, or invalid JSON is not a successful empty result and cannot support “no differential genes,” “no pathway,” or another biological negative.
- A diagnostic `pageSize=1` request may be used when the user asks for endpoint diagnostics or an evaluation protocol requires it. It is not a universal prerequisite for normal omics retrieval and must not silently replace the requested result page.

A workflow may therefore have valid context with unavailable downstream results; retain both facts rather than collapsing them into one global success or failure.

## Core-enrichment genes

When the user requests core-enrichment genes for an exact API-returned pathway ID, use `GET /api/browse/sample/reference/gsea-enriched-genes`. Send `pathwayId`; send `data` and `group` only when they are already API-returned values from the requested analysis context. Use explicit pagination.

Preserve every returned `sampleId`, `data`, `group`, `pathwayId`, raw slash-delimited `enrichGene`, page, pageSize, and total. A returned empty `sampleId` prevents a sample-specific claim. Resolve individual gene symbols through a documented gene-resolution route before cross-endpoint identity joins. This endpoint supplies analysis-scoped core-enrichment evidence only: it is not a universal pathway member list, does not prove a gene is differentially expressed, and does not establish causality, phenotype explanation, or pathway activation.

## Interpret response shapes conservatively

| Result type | Key fields to report |
|---|---|
| Differential genes | sampleId, group, symbol, control/case expression or percentage, log2fc, pValue, adjustedPValue, regulation, available plot path |
| Differential cell types | sampleId, group, cellType, source, regulation, geneRatio, bgRatio, pValue, adjustedPValue, markerGene |
| GSEA enriched pathways | sampleId, group, pathwayId, terms, size, es, nes, pValue, adjustedPValue, plot |
| GSVA pathways | sampleId, group, term, control/case expression, log2fc, pValue, adjustedPValue, regulation, boxplot |
| Cluster-specific records | the relevant result fields plus cluster and violinplot when returned |

Report numerical values as API data, not causal conclusions. Flag missing values and distinguish adjusted from unadjusted p-values. For cluster results, the current backend may serialize p-values below approximately `1e-45` as numeric `0`; report them as **below the backend representation limit (approximately <1e-45)** rather than as an exact mathematical zero. Do not apply this reinterpretation to arbitrary zero values from other result families without the same documented backend behavior.

## Experimental-design completeness

Before interpreting results, report the availability and provenance of:

- sampleId, modality, `dataSet`, group/comparison, control label, and case label
- biological meaning of the contrast and available time point
- donor/cell-line identity, biological and technical replicates
- culture/differentiation, library-preparation, operator, instrument, or other batches
- paired/unpaired structure, covariates, normalization/statistical method, thresholds
- cell-annotation provenance and, for pseudobulk, aggregation unit

Do not require unavailable metadata to display existing API results, but mark it as a limitation with the shared machine state. If the missing field prevents defining the requested comparison, stop and ask for a valid API-returned context.

## Cross-dataset boundary

Do not merge expression values, fold changes, p-values, enrichment scores, or cell ratios across different `dataSet` values. Do not rank cross-dataset effects numerically unless the API explicitly documents a unified comparable analysis context.

Descriptive side-by-side comparison is allowed when every result retains its dataset and contrast, with a warning about platform, normalization, annotation, threshold, covariate, and batch differences. A request for joint quantitative inference must stop unless comparable contrasts, normalization, batch correction, and covariate handling are established; these endpoints return precomputed results and do not imply access to raw data for reanalysis.

## Chart-ready and advanced data

Use only the matching documented endpoint after you have the required context:

- Common chart inputs are `group` and `dataSet`; may also require sampleId, platform, organism, and category (`GO`, `KEGG`, or `ssGSEA`).
- Pseudobulk chart inputs also require `resolution` and `type`, with optional cellType.
- Trajectory and interaction endpoints may require coordinates, type, resolution, gene, rootCluster, is3D, and category.

Preserve raw structures and explain compact field names:

| Data | Shape |
|---|---|
| Volcano | `s` symbol, `l` log2 fold change, `p` adjusted p-value, `r` regulation |
| Heatmap | `x` horizontal label, `y` vertical label, `v` value, `r` group/regulation |
| GO | `c` category, `d` description, `v` p-value |
| KEGG | `d` description, `v` p-value |
| GSVA bars | `x` term, `t` statistic |
| Coordinates | cell IDs plus `x`, `y`, optional `z`, and `v` |
| Cell ratio | `x` cluster, `case`, `control` |

Do not draw a chart unless the user specifically asks. If asked to visualize returned data, follow the available visualization guidance and retain the underlying endpoint and analysis context.

## Response modes and output

Follow the shared response contract. Use operational mode for missing sample/context, required group or dataset choice, successful empty analysis context, API failure, incomplete pagination, and handoff; use audit mode only when technical trace, endpoint/filter/native-field details, JSON paths, or complete evidence inspection is requested; use machine mode for explicit structured output; otherwise use researcher mode for completed interpretable results. In researcher mode, lead with the main biological result of the requested comparison, tying every statistic to its returned dataset, exact groups, analysis type, and direction. Prioritize dominant changes, robust or repeated candidates, agreement/disagreement, and unanswered questions; never merge datasets or call repetition independent unless established. Hide endpoint paths, HTTP/API status, request syntax, wrapper logs, JSON paths, and internal enums by default while retaining the exact `dataSet` response to `data` request-key translation, analysis scope, identifiers, pagination, missing values, conflicts, and provenance internally and in audit output. Full result requests retain all records and coverage/pagination without becoming audit output. Do not add recommendations unless requested or materially useful. Do not force fixed headings or length; the template below is optional and adapts to the selected mode and user's language.

## Output template

```markdown
# [Modality] results for the selected sample or comparison

## Main biological result
- Dominant returned pattern and its direction: ...

## Analysis context
- Dataset, exact groups/comparison, analysis type, and time point: ...

## Returned findings
| Gene, cell type, or pathway | Biological change | Statistical support | Dataset and comparison |
|---|---|---|---|

## Interpretation boundary and coverage
- Agreement/disagreement across returned contexts: ...
- Returned total, displayed count, remaining coverage, and material limitations: ...
- These are API-returned results, not independently reanalyzed statistics or clinical conclusions.
```

For raw chart, trajectory, or interaction outputs, provide a compact schema summary followed by the requested records or a clearly paginated subset. Never invent coordinates, clusters, or analysis parameters.
