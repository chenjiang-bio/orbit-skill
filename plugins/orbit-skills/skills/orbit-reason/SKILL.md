---
name: orbit-reason
description: Build traceable cross-layer evidence chains across Organoid Database pathways, genes, biomarkers, disease models, culture factors, perturbations, phenotypes, detection methods, and annotations. Use this skill whenever a user asks a multi-hop biological question such as condition→pathway→gene→druggability, factor→pathway→phenotype, or biomarker→disease model→pathway→detection method. It distinguishes direct API relations, same-sample co-occurrence, free-text links, and unresolved edges; it never turns co-occurrence into causality or fills missing relations from model knowledge.
---

# Orbit Reason

Read `<plugin-root>/references/api-reference.md` for exact endpoint calls, `<plugin-root>/references/organoid-api-contract.md` for shared request safety, `<plugin-root>/references/researcher-response-contract.md` for response modes and researcher-first presentation, and `<plugin-root>/references/cross-layer-evidence-graph.md` before retrieval or synthesis.

Read `<plugin-root>/references/orbit-reason-capability-matrix.md` when presenting the current cross-layer capability coverage or known association gaps.
For every Orbit HTTP attempt, invoke the wrapper at `<plugin-root>/scripts/orbit-request.sh ...` on Linux/macOS, or `<plugin-root>/scripts/orbit-request.ps1 ...` on Windows PowerShell. Resolve `<plugin-root>` from the installed plugin resources, not the user's current working directory. Use only the documented relative `/api/...` path and a body file or stdin for a documented JSON POST. Do not generate ad-hoc Python, `urllib`, `curl`, or other request scripts, and do not use browser/WebFetch transport. Preserve the exact request and wrapper stderr status line as provenance; inspect stdout JSON `code` under the shared contract.

This skill plans and audits cross-endpoint evidence chains. It is not a new knowledge source, a causal inference engine, or permission to call undocumented endpoints. Use `orbit-search` for single resource families, `orbit-chat` for sample-centric synthesis, `orbit-browse` for one sample's details, and `orbit-omics` for a valid sample/dataset analysis context.

## 1. Define the target chain

Parse the user's question into ordered nodes and required edges. Preserve explicit constraints including organism, organoid/model, disease/condition, factor/perturbation, comparison, time, platform, peer-review preference, and desired annotations.

Examples:

- disease/model → recurrent pathway → member gene → druggability annotation
- culture factor → pathway → withdrawal/inhibition → phenotype
- gene/biomarker → human disease model → pathway annotation → detection method

For each edge, specify what documented API field would qualify as a direct relation. Do not start by writing a biological mechanism.

## 2. Reuse and validate research context

Accept provenance-complete contexts from other Orbit skills. Validate API-returned IDs, endpoints, filters, sample association, dataset/group, references, missing states, and prior edge classes. Reuse successful evidence; repeat a request only when constraints changed, required context is incomplete, or provenance cannot be verified, and record why.

Plan retrieval through existing capabilities:

- `orbit-search`: pathways, biomarkers, protocols/factors, gene resolution
- `orbit-browse`: sample metadata, culture plan, phenotype, application, gene annotation, and narrow GDS/KOBAS/drug/material reference lookups
- `orbit-chat`: multi-sample details grouped by `sampleId`
- `orbit-omics`: sampleId → control-group → returned dataSet/group → detail results and analysis-scoped core-enrichment lookup

Never derive `sampleId`, pathway ID, Entrez ID, or dataset mappings from display text.

## 3. Build normalized nodes

Use stable API identifiers when available:

- sample: `sampleId`
- gene: Entrez ID plus returned symbol
- pathway: term/pathway ID plus database/version when returned
- dataset/comparison: API-returned `dataSet` or search `data`, group, platform, and analysis type—without treating them as interchangeable

Keep label-only nodes distinct when identity is uncertain. Do not merge same-name pathways across databases or same-symbol genes with conflicting Entrez IDs.

## 4. Classify every requested edge

Use exactly one class from the shared contract:

- `DIRECT_EDGE`
- `SAME_SAMPLE_CO_OCCURRENCE`
- `FREE_TEXT_LINK`
- `UNRESOLVED_EDGE`

A field pair in one response is direct only when the documented/returned structure states that relation. The same sample merely supports co-occurrence. A textual claim retains its field path and minimal excerpt. Missing, unstable, cross-sample, or undocumented links remain unresolved with a reason code.

Never connect a factor from sample A, a pathway from sample B, and a phenotype from sample C into one chain. Never rewrite association as activation, mediation, response, or causality unless the API relation semantics explicitly support that wording.

## 5. Handle recurrent pathways conservatively

Query cross-sample pathways with the user's condition/model filters. For each pathway retain term/ID, `sampleId`, `data`, group/comparison, platform, analysis type, direction, significance, and peer-review filter when returned.

Report recurrence by both distinct sample count and distinct dataset-like `data` count. Deduplicate repeated rows within the same sample/data/comparison. Keep GSEA and GSVA separate. Do not combine p-values/effects or rank their magnitudes across datasets.

A pathway is recurrently direction-consistent only when independent records return compatible direction. If directions conflict, report recurrence with direction conflict—not “recurrently active”. A label match without stable pathway ID/database is provisional.

`size` or a pathway name is not a member-gene list. When an exact pathway ID is available, `/api/browse/sample/reference/gsea-enriched-genes` may return an analysis-scoped core-enrichment string. Classify `pathwayId → enrichGene` as `DIRECT_EDGE` only for the same returned row; retain its `data`, `group`, raw slash-delimited value, pagination, and returned `sampleId`. An empty `sampleId` prevents a sample-specific statement. Normalize listed genes through documented resolution before identity joins. Do not describe this as universal pathway membership, proof of differential expression, or causality. Without that returned record, pathway → gene remains `UNRESOLVED_EDGE`.

## 6. Handle factors, perturbations, and phenotypes

Use protocol/culture-plan returned factors and stage timing. Distinguish:

- addition/exposure
- withdrawal/no longer added
- washout
- pharmacological inhibition
- knockdown/knockout

Do not equate withdrawal with inhibition. Parse free text with negation awareness; `no withdrawal` or `not inhibited` is not a positive relation.

A factor/pathway or perturbation/phenotype pair returned for the same `sampleId` is co-occurrence unless the API binds intervention, comparison/control, timing, and measured phenotype. Text describing a relation is `FREE_TEXT_LINK`. Without a structured binding, “withdrawal caused phenotype” remains unresolved.

## 7. Handle biomarkers and detection methods

Resolve a gene symbol/Entrez ID through documented gene endpoints. Retain only samples whose returned native fields support the organism, disease model, and biomarker constraint; semantic similarity is not biomarker evidence.

Treat identified biomarker nested data defensively because its sub-schema may vary. Preserve raw structures. A detection method is a direct edge only when the returned biomarker record explicitly binds the biomarker to that method. A method mentioned only in narrative text is a free-text link. A request filter does not prove the response returned that method.

A biomarker and pathway appearing in the same sample are co-occurrence unless the response explicitly annotates the biomarker to the pathway. Free-text descriptions do not create a normalized pathway ID.

## 8. Handle gene annotation and druggability

General gene annotation fields—function, structure, sites, diseases, interactions, summaries, and external links—are not automatically druggability evidence. `/api/browse/sample/reference/kobas-human` and `kobas-mouse` can provide route-specific Entrez-ID-to-external-annotation records; retain `query,item,id,description,database` and do not call them active or sample-specific. The reference drug endpoint can provide a direct drug→target annotation only when a successfully parsed `targets` JSON object explicitly returns target identity and provenance; retain the raw string, nulls, `source`, and `evidence`.

Neither a KOBAS annotation nor a drug target record establishes pathway activity, gene tractability, clinical efficacy, clinical actionability, or suitability for an Orbit sample. If the requested conclusion requires those semantics, return `UNRESOLVED_EDGE: ENDPOINT_NOT_AVAILABLE`. Do not answer from model memory or publication full text.

## 9. Apply chain coverage gates

For every required edge, report:

- edge class and provenance;
- whether direct or causal wording is allowed;
- unresolved reason and missing API capability.

**STOP the affected chain segment** when the user requests a complete/direct/causal chain but a required edge is only co-occurrence, text-only, cross-sample, or unresolved. Still return all supported evidence before and after the break as separate observations.

Warn about single-sample support, mixed platforms/analysis types, direction conflicts, unstable nested schemas, label-only identities, and missing dataset/comparison context.

## 10. Response modes and output

Follow the shared response contract. Use operational mode for missing chain inputs, unresolved choices, empty/failed retrievals, incomplete handoffs or pagination, and capability gaps; use audit mode when the user requests complete technical trace, endpoint/filter details, native fields, JSON paths, or edge classification; use machine mode for explicit structured output; otherwise use researcher mode. In researcher mode, begin with a plain-language chain-coverage conclusion, then explain which links are directly supported, which are same-context or source-text observations, which required link is unresolved, and whether the requested mechanistic or causal claim can be made. Translate `DIRECT_EDGE`, `SAME_SAMPLE_CO_OCCURRENCE`, `FREE_TEXT_LINK`, and `UNRESOLVED_EDGE` rather than printing enum names by default; retain exact classes, reason codes, field paths, identifiers, datasets/groups, conflicts, pagination, and provenance for audit/machine output. Never call repeated records or cross-sample associations independent unless established, and do not turn a complete result request into audit output. Offer conditional next steps only when requested or when a direct gap affects an experiment; do not force fixed headings or length. Use the following structure as an optional complex synthesis and adapt it to the selected mode and user's language.

### Optional output structure

Use an explicitly requested output language when provided; otherwise use the user's task language for every visible heading and explanation. Keep edge classes and reason codes only in audit or machine output, or in a technical comparison explicitly requested by the user.

```markdown
# Cross-layer evidence synthesis

## Research question and chain coverage
## What the returned evidence directly supports
## Observations from the same research context
## Relationships mentioned only in source descriptions
## Relationships the current data cannot determine
## Evidence summary
| Required relationship | Plain-language evidence strength | Evidence and limitation |
## Consequences for the requested mechanism or causal claim
## Data gaps and conditional next steps
## Research context handoff
```

End with an explicit boundary: the synthesis reports API-returned evidence and missing relationships; it does not establish causality, clinical actionability, druggability, or reproducibility unless the returned relation specifically supports that claim.

Never use webpages/browser automation, DOI full-text retrieval, external databases, undocumented endpoints, secrets, or sequence submission unless a separate authorized workflow explicitly requires them.
