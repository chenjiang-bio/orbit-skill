---
name: orbit-browse
description: Browse Organoid Database API sample records, perform General, Immune-Oncology, or Host-Microbe keyword/structured/semantic searches, retrieve a sample's culture, phenotype, application, and basic details, or query gene and validated reference data. Use this skill whenever a user asks to locate particular organoid samples, inspect a sample ID, compare sample metadata, use semantic sample search, look up a gene annotation or its related samples, map a GSE to returned KM IDs, or perform an exact drug/material reference lookup. Use only documented `/api/browse/*` endpoints; never derive results from webpages or browser tools.
---

# Organoid Browse

Read `<plugin-root>/references/api-reference.md` for exact endpoint calls, `<plugin-root>/references/organoid-api-contract.md` for shared request safety, and `<plugin-root>/references/researcher-response-contract.md` for response modes and researcher-first presentation before making any API request.

## HTTP transport

For every Orbit HTTP attempt, invoke the wrapper at `<plugin-root>/scripts/orbit-request.sh ...` on Linux/macOS, or `<plugin-root>/scripts/orbit-request.ps1 ...` on Windows PowerShell. Resolve `<plugin-root>` from the installed plugin resources, not the user's current working directory. Use only the documented relative `/api/...` path and a body file or stdin for a documented JSON POST. Do not generate ad-hoc Python, `urllib`, `curl`, or other request scripts, and do not use browser/WebFetch transport. Preserve the exact request and wrapper stderr status line as provenance; inspect stdout JSON `code` under the shared contract.

Use this skill for sample discovery and record inspection. For cross-sample evidence comparison, use `orbit-chat`; for multi-hop relationships across genes, pathways, biomarkers, factors, phenotypes, or annotations, use `orbit-reason`; for protocol/biomarker/pathway discovery, use `orbit-search`; for tailored protocol synthesis, use `orbit-protocol`; for complete experimental design, use `orbit-design`; for omics attached to a known sample, use `orbit-omics`.

Use the shared missing-information states and the user's input language in every visible response. Bind every detail endpoint, source field path, native value, reference, status, and missing field to its originating `sampleId`. When handing off, provide a minimal research context containing collection, search mode, explicit constraints, API-returned sample IDs, field-level provenance, references, missing/conflicting states, and recommended next skill. Details from one sample support co-occurrence unless the response explicitly states a relation. Do not add design advice inside this browse workflow.

## Select a sample collection

- **General**: ordinary organoid samples and broad metadata.
- **Immune-Oncology**: samples involving immune-cell co-culture or oncology context.
- **Host-Microbe**: samples involving microbial components.

Ask the user to choose only if the request does not imply a collection. Explain the chosen collection in the response.

## Search routes

| Search type | General | Immune-Oncology | Host-Microbe |
|---|---|---|---|
| Keyword/list search | `GET /api/browse/general/list` | use structured search | use structured search |
| Structured search | `POST /api/browse/general/search` | `POST /api/browse/immune-oncology/search` | `POST /api/browse/host-microbe/search` |
| Semantic search | `POST /api/browse/general/semantic/search` | `POST /api/browse/immune-oncology/semantic/search` | `POST /api/browse/host-microbe/semantic/search` |

Use a JSON search body with pagination, optional sorting, optional `keywords`, and `search` objects. Use semantic search only when the user asks for meaning-based, similarity-based, or natural-language matching. Include `query`; order and label returned records by `semanticScore` when it exists. When this endpoint is used after an empty protocol search, label the records as General sample-discovery candidates, not culture protocols. Preserve the returned `organism` and `semanticScore` values, and do not treat a zero or missing score as reliable semantic ranking. Treat the selected collection as an endpoint-level scope; do not infer collection membership from a `sampleId` prefix or display name.

## Relevant fields

- General list filtering supports keywords plus organoid, origin, species, culture technique, biomarker, applications, tests, culture conditions, endpoints, characteristics, functions, and disease modeling.
- General records can include `composition`, `cultureTechnique`, `cultureDays`, `biomarker`, `references`, `drugScreening`, `cultureCondition`, `sgRna`, and `multiOmics`. Preserve structured fields as returned.
- Immune-Oncology records can include immune-cell type, disease model, co-culture days, organoid/immune biomarkers, medium, factors, readout, endpoints, and tests.
- Host-Microbe records additionally expose microbial and microbial-biomarker fields.

## Inspect a sample

Use the user-provided `sampleId`; never infer it from a display name.

| Detail requested | Endpoint |
|---|---|
| General basic information | `GET /api/browse/sample/general-basic-info` |
| Immune-Oncology basic information | `GET /api/browse/sample/immune-oncology-basic-info` |
| Host-Microbe basic information | `GET /api/browse/sample/host-microbe-basic-info` |
| Culture protocol | `GET /api/browse/sample/culture-plan` |
| Co-culture protocol | `GET /api/browse/sample/co-culture-plan` |
| Phenotype | `GET /api/browse/sample/phenotype` |
| Applications | `GET /api/browse/sample/application` |

Fetch only the detail sections the user asked for. For an explicit "full sample profile," retrieve base information plus culture plan, phenotype, and application; include co-culture only when relevant.

Culture-plan responses use `sample_id`, `time_anchors`, `time_axis`, `material_source`, and `protocol`. Preserve these snake_case names. Do not flatten nested records into claims that the API did not make.

## Gene annotation

Gene annotation is both a standalone workflow and a supporting action during sample browsing.

Use `GET /api/browse/sample/gene-annotation` with required `geneName`, plus optional `organism` and `sampleId`. Return a focused overview from fields actually present: symbol, Entrez ID, synonyms, functional annotations, external links, sequence features, disease information, interactions, and `referenceSample`.

Interpret `referenceSample` with its data-version semantics. Current v1 records populate it only when a gene publication DOI—resolved through PubMed metadata—matches a KM DOI; `null` means no DOI match was stored, not that the KM lacks the gene. The v2 pipeline, once its data are fully processed and loaded, also adds KM IDs whose records directly contain the gene. State the returned version when available; otherwise say that version is not returned and do not infer gene absence from `null`.

Treat `geneName` as either a gene name or Entrez ID as documented. Do not use a gene annotation to imply expression or causal relevance in a sample unless the API explicitly supplies evidence.

## Reference-data lookups

Use these read-only GET workflows only for the narrow lookup the user requested. They normalize or annotate records; they do not create sample-specific biological evidence.

| User request | Endpoint | Required input and output boundary |
|---|---|---|
| Map an API-returned or user-provided GSE ID to internal sample records | `GET /api/browse/sample/reference/gds` | Require `gseId`. Preserve every returned `{gseId,sampleId,platform}` row and the raw semicolon-delimited `sampleId` string. Only hand returned individual IDs to sample detail or omics workflows; the mapping does not provide `dataSet`, group, or comparison. |
| Look up one gene's human/mouse KOBAS annotation | `GET /api/browse/sample/reference/kobas-human` / `kobas-mouse` | Require Entrez ID and an explicit organism/route. Preserve `query,item,id,description,database`. This is external annotation, not Orbit-sample pathway activity or enrichment. |
| Look up a specific drug record | `GET /api/browse/sample/reference/drug` | `keyword` is required; require a user-provided DrugBank ID or drug name. Preserve raw `targets`; parse its JSON only when valid, preserving nulls and `source`/`evidence`. A returned drug target is not efficacy, sample relevance, clinical actionability, or gene druggability. |
| Normalize a specific material name | `GET /api/browse/sample/reference/material` | `keyword` is required; require a user-provided material name. Preserve `materialType,standardName,similarNames,application,pathway` as descriptive metadata. Do not use its pathway text as a normalized pathway ID or mechanistic claim. |

For successful empty `PageList` results, preserve the returned `page`, `pageSize`, `total`, and empty list exactly; do not treat the lookup as an API error. Use `orbit-omics` for core-enrichment lookup within a known analysis context and `orbit-reason` when any reference result must be connected to another evidence layer.

## Response modes and output

Follow the shared response contract. Explicit output-language instructions override task language; otherwise use the user's task language. Use operational mode for missing collection/sample input, choices, empty or failed retrievals, missing details, incomplete pagination, and handoffs; use audit mode only for requested endpoint/filter/native-field/JSON-path or complete trace output; use machine mode for explicit structured output; otherwise use researcher mode for findings. Researcher answers lead with why the selected sample, annotation, or returned match matters to the question, prioritize model identity, culture, phenotype, application, biomarker, and omics availability, and hide endpoint paths, HTTP/API status, request syntax, wrapper logs, JSON paths, and internal enums by default. Keep general gene annotation separate from `referenceSample` evidence, do not describe the optional gene-annotation `sampleId` as a sample-level filter, and translate missing/null/empty/failure states without turning them into biological negatives. Preserve sample ownership, returned IDs, pagination, detail/source fields, conflict and handoff provenance internally and in audit output; do not call repeated records independent unless established. Complete lists remain researcher-facing with total/displayed/remaining coverage. Offer conditional suggestions only when requested or materially decision-relevant; do not force fixed headings or length. Use the templates below as optional shapes, adapting them to the selected mode and language.

## Output templates

### Sample search

```markdown
## Research goal and scope
- Collection and biological selection goal: ...

## Relevant sample matches
| Sample | Organoid/model and identity | Key scientific features | Evidence and limitation |
|---|---|---|---|

## Coverage and next step
- Returned total, displayed count, remaining coverage: ...
- Sample identifiers available for deeper inspection: ...
```

### Sample profile

```markdown
# Sample profile: [sampleId]

## Model identity and relevance
...

## Culture features
...

## Phenotype and applications
...

## Evidence sources and limitations
- Returned references and material missing or null information: ...
```

### Gene annotation

```markdown
# Gene annotation: [symbol or geneName]

## Gene identity and relevance
...

## Functional and structural evidence
...

## Related sample evidence
...

## Limitations
- Describe unavailable or null sections without filling them in.
```
