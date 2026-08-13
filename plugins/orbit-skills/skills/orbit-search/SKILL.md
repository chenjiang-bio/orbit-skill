---
name: orbit-search
description: Search the Organoid Database API for culture-protocol evidence, identified or potential biomarkers, cross-sample pathway results, and General sample-discovery fallbacks. Use this skill whenever a user asks to find, compare, filter, or summarize one resource family such as protocols, biomarkers, genes, pathways, trends, or dataset-labelled records. It produces traceable candidates and handoffs; multi-hop questions linking two or more entity layers belong to `orbit-reason`, tailored protocols to `orbit-protocol`, and experimental designs to `orbit-design`. This skill is API-only.
---

# Organoid Search

Read `<plugin-root>/references/api-reference.md` for exact endpoint calls, `<plugin-root>/references/organoid-api-contract.md` for shared request safety, `<plugin-root>/references/researcher-response-contract.md` for response modes and researcher-first presentation, and `<plugin-root>/references/sample-discovery-and-detail-handoff.md` before sample discovery, bounded details, or handoff.

## HTTP transport

For every Orbit HTTP attempt, invoke the wrapper at `<plugin-root>/scripts/orbit-request.sh ...` on Linux/macOS, or `<plugin-root>/scripts/orbit-request.ps1 ...` on Windows PowerShell. Resolve `<plugin-root>` from the installed plugin resources, not the user's current working directory. Use only the documented relative `/api/...` path and a body file or stdin for a documented JSON POST. Do not generate ad-hoc Python, `urllib`, `curl`, or other request scripts, and do not use browser/WebFetch transport. Preserve the exact request and wrapper stderr status line as provenance; inspect stdout JSON `code` under the shared contract.

Use this skill for cross-sample discovery within one resource family. For a multi-hop question that links condition/model, pathway, gene, biomarker, factor, phenotype, detection method, or annotation across two or more relations, produce a provenance-complete handoff to `orbit-reason`; do not build the chain here. For one sample's full record, use `orbit-browse`; for sample-specific omics, use `orbit-omics`; for quick biomarker prioritization from user-supplied genes or expression data, use `orbit-analysis`.

## Select the endpoint family

| User goal | Endpoint |
|---|---|
| Find organoid culture protocols | `GET /api/search/protocol/organoid` |
| Discover related General samples when protocol search is empty | `POST /api/browse/general/semantic/search` |
| Find co-culture protocols | `GET /api/search/protocol/coCulture` |
| Compare protocol trends | `GET /api/search/protocol/trends` |
| Find identified biomarkers | `GET /api/search/biomarker/identified` |
| Inspect biomarker culture timing | `GET /api/search/biomarker/culture-plan` with `sampleId` |
| Find potential biomarkers by tissue | `GET /api/search/biomarker/potential` |
| Find potential biomarkers by gene | `GET /api/search/biomarker/gene` |
| Compare biomarker trends | `GET /api/search/biomarker/trends` |
| Find GSEA or GSVA pathway results across samples | `GET /api/search/pathways` |
| Resolve a gene symbol or Entrez ID | `GET /api/common/gene/suggest` |

### Protocol search, lossy normalization, and semantic discovery

Keep `/api/search/protocol/organoid` as the authoritative route for protocol filtering and comparison. Its required `organ` query parameter accepts a case-insensitive documented value from the supported-organ list in `<plugin-root>/references/api-reference.md`—for example `Brain`, `Lung`, or `Mammary Gland`—not a free-text organoid name or underscore identifier. Map cerebral organoid/cerebral/brain organoid requests to `organ=Brain`. When the requested anatomy does not map unambiguously to a listed value, ask the user to choose; do not send a guessed free-text value.

Preserve the user's original wording before normalization. Decide whether mapping the anatomy to `organ` is **lossy**: it is lossy when meaningful requested constraints would not be represented by documented protocol-query fields actually sent. Those constraints can include finer anatomical specificity and biological/model qualifiers such as vascularization, cell composition, disease state, maturation, treatment, or timing. A synonym that adds no scientific constraint is not lossy. Do not call a request lossy merely because the same constraint can also be sent through a documented protocol field.

- **Fully represented request:** run the authoritative protocol search first. Only when it succeeds with `code == 0` but returns `total == 0` or an empty `list`, use General semantic search as a discovery fallback. Do not start that fallback after a non-zero protocol business code; report the error and corrective action instead.
- **Lossy normalized request:** run the authoritative protocol search with the normalized `organ` and every compatible documented structured filter, then independently run General semantic discovery with the unchanged original wording and safe documented structured filters. Run both lanes even when the protocol response is nonempty. A failure or empty result in either lane does not erase the other's observed state.

For either semantic request:

1. Send `POST /api/browse/general/semantic/search` with `page`, `pageSize`, the original query, and any documented structured `search` filters. Preserve the user's requested species in the query and in a structured filter when supported; if the service rejects that filter, retry only with the documented query and filter returned records locally.
2. Treat semantic results as sample discovery, not protocol evidence. Preserve `sampleId`, `organism`, `semanticScore` when returned, and all native fields used to explain the match. A zero or absent `semanticScore` is not evidence of a meaningful ranking.
3. Filter semantic candidates by the returned `organism` field. Keep only records matching the requested organism after exact, case-insensitive comparison; exclude missing or non-matching values rather than guessing synonyms.
4. Keep protocol and semantic records in separate evidence lanes with their own request provenance, pagination, returned/retained counts, and service order. Do not create a blended ranking or use `semanticScore` to rank protocol records.
5. If the same returned `sampleId` appears in both lanes, retain both provenance records. Deduplicate only downstream detail retrieval by exact `sampleId`. When details are requested, apply every explicit user constraint that can be checked against returned native fields, then prioritize exact-ID overlap candidates, followed by qualifying semantic candidates in semantic service order, then qualifying protocol candidates in protocol service order. Skip only an ID already selected for details; never select a broad protocol-category hit merely because its `organ` value matched when its returned native fields contradict an explicit user constraint.
6. Report protocol-empty, semantic-empty, API-error, and organism-filtered counts separately. A successful empty response is not a failed request and does not prove that no related research exists. Keep both the requested `page`/`pageSize` and the service-returned pagination fields visible; if a successful empty response returns an unusual value such as `page: 0` or `pageSize: 0`, report it as returned and do not silently replace it with the default pagination.

## Gather inputs progressively

Start with what the user provided. Ask only for filters that materially narrow an overly broad search.

- **Protocol:** `organ` is required and must be a supported organ value listed in `<plugin-root>/references/api-reference.md` (for example `Brain`, `Lung`, or `Mammary Gland`), not an underscore identifier or free-text organoid term. Map user language to that value when unambiguous; otherwise ask for a choice. Refine with `organism`, `source`, `coCulture`, `cultureMethod`, `complexity`, `keywords`, and sorting.
- **Identified biomarkers:** `organism`, `source`, and `organoid` are required. Optionally add classification, detection method, co-culture, disease modeling, or drug-test filters.
- **Potential biomarkers:** `organism` and `tissue` are required. Optionally add `researchPurpose` and `platform`. Without `platform`, preserve each platform-specific paginated group exactly as returned instead of flattening them. The documentation describes an RNA-seq/scRNA-seq split; deployments may label those groups differently (for example, `bulkRNA_seq` and `scRNA_seq`).
- **Gene biomarkers:** `organism`, `geneSymbol`, and `entrezId` are required. Use gene suggestion first when an ID is missing. Gene suggestion accepts only exact `Homo sapiens` or `Mus musculus`; do not send `hsa|mmu` or silently fall back to human. If the endpoint reports a missing or unsupported organism, preserve the error and ask the user to choose one of those two values before retrying the read-only suggestion call. A successful empty suggestion list is an unrecorded identity result, not an organism error or biological negative.
- **Pathways:** refine with organism, biological model, tissue, conditions, comparison groups, cell type, day, platform, and `onlyPeerReviewed`.

Do not guess an organism, an Entrez ID, a tissue, or a protocol parameter.

### Recurrent pathway boundary

When summarizing recurrent pathways, count distinct supporting `sampleId` values and distinct dataset-like `data` values separately. Deduplicate repeated rows from the same sample/data/comparison, preserve group, platform, analysis type, direction, and adjusted significance, and keep GSEA separate from GSVA. Direction conflicts must be reported; they cannot be called recurrent activation. A pathway label or `size` does not expose member genes. Hand off pathway→gene or other multi-hop requests to `orbit-reason`.

Identified biomarker nested records may vary in shape. Preserve their native structure. A request filter such as `detectionMethod` does not prove that every returned record explicitly contains that method; report only returned fields.

## Bounded sample-detail evidence

When a discovery request also asks for sample-level basic information, culture plan, phenotype, application, or reference evidence:

1. Complete the requested discovery page or explicitly requested pagination, then apply the user's explicit constraints to returned native fields before selecting samples.
2. Treat the discovery list only as candidate evidence. It does not establish any requested detail family, and `semanticScore` is not protocol or evidence quality.
3. Apply the shared detail budget and service-order rules in `<plugin-root>/references/sample-discovery-and-detail-handoff.md`. Use only returned `sampleId` values and retrieve only the requested documented detail families.
4. Keep every returned field, reference, missing state, and failed request grouped by its originating `sampleId`.
5. Report discovery coverage separately from detail coverage: returned and retained counts, selected/inspected IDs, uninspected count, and failed IDs or detail families. If no candidates remain after filtering, report successful filtered emptiness and stop before detail calls; do not reinterpret it as API failure or biological absence.

This remains a search workflow: return traceable per-sample evidence and a provenance-complete handoff. Do not turn it into open-ended comparative synthesis, merge sample details, or construct a tailored protocol; use `orbit-chat` for broader comparison and `orbit-protocol` for protocol-family convergence and final synthesis.

## Biomarker evidence roles

When the user asks for key biomarkers, do not flatten all returned markers into one undifferentiated list. Classify only when native fields or returned context support the role:

- identity, lineage, disease-associated, proliferation, functional
- treatment-response, QC, perturbation/infection-specific, or predicted

Separate endogenous disease evidence from perturbation or infection readouts. Rank relevance by fit to the user's goal, cross-sample support, and returned detection context—not occurrence count alone. Keep predicted markers distinct from identified markers, and never label a marker clinically validated unless the API explicitly provides that evidence.

## Protocol candidate handoff

When the user requests a complete, tailored, staged, or practical culture protocol, this skill performs only authoritative retrieval, filtering, candidate comparison, and handoff. Do not synthesize the final protocol here.

1. State that the records are database-backed research evidence, not a validated protocol or reproducibility guarantee.
2. Search `/api/search/protocol/organoid` with the documented organ mapping. When normalization loses a material user constraint, also run the documented General semantic discovery lane with the original wording; otherwise use semantic discovery only after a successful empty protocol response.
3. Collect only decision-critical missing filters when the result set is too broad. Explain exclusions and preserve `sampleId`, provenance, pagination, DOI/reference, missing states, and fallback evidence labels.
4. Produce the shared research context from `<plugin-root>/references/organoid-api-contract.md` with `recommendedNextSkill: orbit-protocol`. If the user requests a full experimental design after protocol selection, recommend `orbit-design`.
5. Never include a merged timeline or details that were not returned. `orbit-protocol` retrieves culture-plan details, resolves incompatible protocol families, and performs final synthesis.

### Dataset and GSE boundary

Potential-biomarker, gene-biomarker, or pathway results may return a native `data` value that resembles a GSE accession. Preserve it as a search-result dataset label. It is not automatically a valid omics `dataSet` input.

- If the same result returns a `sampleId`, hand off that API-returned ID to `orbit-omics`; it must call the modality-specific control-group endpoint to obtain valid `dataSet` and group values.
- If only a GSE-like `data` value is available and the user asks for a KM mapping, call `GET /api/browse/sample/reference/gds?gseId=...`. Preserve every returned mapping row's `gseId`, raw semicolon-delimited `sampleId`, and `platform`; hand off only returned IDs to `orbit-browse` or `orbit-omics`.
- The GDS result is a mapping record, not a control-group context. Never substitute its GSE value for `dataSet`, invent a group/comparison, or claim a mapping proves a particular analysis result belongs to an individual sample.
- If GDS is empty or fails, report that distinct state and stop at search evidence; do not infer a KM sample from titles, DOI, display names, or ID prefixes.

## Response modes and output

Follow the shared response contract. Explicit output-language instructions override task language; otherwise use the user's task language. Choose the mode from the workflow and user intent: use operational mode for missing filters, successful empty searches, semantic/protocol branch failures, incomplete pagination, or handoff; use audit mode only when technical trace, native fields, endpoint/filter details, or complete evidence inspection is requested; use machine mode for explicit structured output; otherwise use researcher mode for interpretable findings. In researcher mode, lead with the biological answer and hide endpoint paths, HTTP/envelope status, request syntax, JSON paths, wrapper logs, and internal enums by default. When joint retrieval is used, explain succinctly that the protocol lane is authoritative protocol evidence and the semantic lane preserves the richer original wording as related sample discovery; do not blend their rankings or evidence labels. Translate evidence and missing states into natural language, retain all endpoint/pagination/identifier/provenance and branch distinctions internally and in audit output, and do not call repeated records independent unless independence is established. A complete scientific-results request remains researcher-facing: provide all requested results with total/displayed/remaining coverage and pagination context, not an audit trace. Offer conditional next steps only when requested or when a material evidence gap affects selection or experiment; never force a fixed heading set or length. Preserve the protocol/semantic lane boundary, dataset/GSE boundary, biomarker roles, and `orbit-protocol`/`orbit-reason` handoffs.

Use the following templates as optional shapes, adapting headings and detail to the selected mode and language; simple lookups should remain simple.

### Search results

```markdown
## Scientific question and scope
- Question or selection goal: ...
- Biological context and constraints: ...

## Relevant findings
| Candidate or record | Scientific relevance | Evidence and limitation |
|---|---|---|
| ... | ... | ... |

## Coverage and provenance
- Returned total, displayed count, and remaining coverage: ...
- Sample/dataset identifiers, comparisons, and references grouped with their records: ...
- Material conflict, missing information, or fallback limitation: ...
```

### Protocol handoff

```markdown
# Protocol candidate handoff

## Scientific fit
- Research goal and explicit constraints: ...
- Evidence type: authoritative protocol search / semantic sample discovery fallback

## Candidate records
| Candidate | Fit to the research goal | Missing or conflicting information | Source / DOI |
|---|---|---|---|

## Exclusions and limitations
- Candidate and scientific constraint responsible for exclusion: ...

## Research context
- Selected sample IDs and references grouped by sample: ...
- Recommended next skill: `orbit-protocol`
```

Do not convert missing protocol details into fabricated instructions. Do not retrieve or summarize publication full text from a DOI.
