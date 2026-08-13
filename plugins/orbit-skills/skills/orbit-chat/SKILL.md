---
name: orbit-chat
description: Retrieve and synthesize traceable Organoid Database evidence through a RAG-like workflow. Use this skill whenever a user asks to compare two or more supplied KM sample IDs, semantically find related KM organoid samples, keep samples consistent with explicit biological constraints, inspect each selected sample's detailed metadata or culture plan, and integrate the records into a comparative research summary. This skill is API-only and uses documented Orbit endpoints; it never treats semantic discovery as a protocol or retrieves publication full text.
---

# Orbit Chat

Read `<plugin-root>/references/api-reference.md` for exact endpoint calls, `<plugin-root>/references/organoid-api-contract.md` for shared request safety, and `<plugin-root>/references/researcher-response-contract.md` for response modes and researcher-first presentation before making any API request. Read `<plugin-root>/references/sample-discovery-and-detail-handoff.md` before multi-sample discovery or handoff.

## HTTP transport

For every Orbit HTTP attempt, invoke the wrapper at `<plugin-root>/scripts/orbit-request.sh ...` on Linux/macOS, or `<plugin-root>/scripts/orbit-request.ps1 ...` on Windows PowerShell. Resolve `<plugin-root>` from the installed plugin resources, not the user's current working directory. Use only the documented relative `/api/...` path and a body file or stdin for a documented JSON POST. Do not generate ad-hoc Python, `urllib`, `curl`, or other request scripts, and do not use browser/WebFetch transport. Preserve the exact request and wrapper stderr status line as provenance; inspect stdout JSON `code` under the shared contract.

Use this skill for multi-sample evidence retrieval and comparative synthesis centered on `sampleId`. Use `orbit-search` for one protocol/biomarker/pathway/gene resource family; use `orbit-reason` when the user requests a multi-hop chain across entity layers; use `orbit-browse` for a single sample profile; use `orbit-protocol` for tailored protocol synthesis; use `orbit-design` for complete experimental design; use `orbit-omics` for a known sample's omics analysis; use `orbit-analysis` for sequence-driven asynchronous jobs.

## Core workflow

Select the retrieval mode before running the numbered stages. In both modes, keep every sample's details and failures isolated.

### Fixed-ID comparison mode

Use this mode when the user explicitly supplies two or more KM `sampleId` values to compare, or when a provenance-valid incoming context supplies the exact comparison set. For one supplied sample without a comparative request, use `orbit-browse`. When the incoming IDs were selected by an upstream discovery, preserve that discovery's provenance and inherited coverage; fixed-ID mode means only that this skill does not repeat discovery.

- Skip semantic discovery, semantic ranking, and discovery filtering.
- Deduplicate only identical supplied IDs; never infer or rewrite an ID.
- Reuse requested detail families that are already successful and provenance-complete. Retrieve only missing, failed, or newly requested families for each supplied or inherited ID.
- Compare only those records. Report unresolved or failed IDs separately.
- Do not imply that directly user-supplied IDs are exhaustive ORBIT search results, and do not invent discovery pagination or coverage. For IDs inherited from discovery, retain the upstream pagination and complete/partial/unknown coverage without presenting it as newly performed discovery.

### Discovery comparison mode

Use this mode when the user supplies a research concept but no usable sample IDs. Follow stages 1–5: semantic discovery, explicit native-field filtering, the shared bounded detail budget, per-sample synthesis, and separate discovery/detail coverage.

A valid incoming context is reused. Repeat discovery only when constraints changed, required evidence is incomplete, or provenance cannot be verified, and record that reason.

### 1. Parse the research request

Extract only constraints the user explicitly provided, such as:

- organism or species
- organoid and organ
- starting-cell source or origin
- disease or application
- culture approach or complexity
- target duration or maturity
- requested detail sections

Keep the natural-language research question as the semantic `query`. Do not infer species synonyms, sample IDs, protocol parameters, or experimental constraints.

### 2. Discover related KM samples (discovery mode only)

Call:

```text
POST /api/browse/general/semantic/search
```

Send JSON with `page`, `pageSize`, `query`, and only documented `search` filters. Preserve:

- the exact query and requested pagination
- service-returned `page`, `pageSize`, and `total`
- every selected record's native fields
- `sampleId`
- `organism`
- `semanticScore` when present

This is General sample discovery. It is not a protocol search and must be labeled `sample discovery` in the output. A zero or absent `semanticScore` is not evidence of meaningful ranking.

### 3. Keep association-consistent candidates (discovery mode only)

Apply explicit constraints to returned native fields before requesting details:

1. For `organism`, require exact case-insensitive equality with the user's requested value. Exclude missing, null, and non-matching values; do not guess synonyms.
2. For organoid, organ, source, disease, application, and culture properties, retain a candidate only when the returned native fields support the requested constraint. State when a field is unavailable rather than treating semantic similarity as proof.
3. Keep the original semantic result and explain each exclusion reason.
4. Deduplicate only identical returned `sampleId` values; never merge records by display name.
5. Preserve the service order unless the user asks for ranking. If ranking is requested, use `semanticScore` only when it is present and meaningful; keep ties and missing scores explicit.

Report counts separately: returned, constraint-matching, excluded by organism, excluded by other explicit constraints, missing required fields, and duplicate IDs.

If no candidates remain, report an empty filtered state and stop. Do not invent IDs or broaden the query without user direction.

### 4. Retrieve selected samples' details

In discovery mode, do not make any detail request until native-field filtering, deduplication, and the retained/excluded decision are complete for the returned page. Use only the retained `sampleId` values for detail retrieval. In fixed-ID mode, use only the exact user-supplied or provenance-valid upstream IDs. Never derive IDs from names, titles, prefixes, or DOI values.

Fetch only sections needed for the user's request:

| Requested detail | Endpoint |
|---|---|
| Basic metadata | `GET /api/browse/sample/general-basic-info` |
| Culture plan | `GET /api/browse/sample/culture-plan` |
| Phenotype | `GET /api/browse/sample/phenotype` |
| Applications | `GET /api/browse/sample/application` |

For multiple discovery candidates or a comparison set inherited from discovery without complete details, apply the shared sample limit in `<plugin-root>/references/sample-discovery-and-detail-handoff.md`. For IDs supplied directly by the user, retrieve the requested families for every supplied ID unless the user gives a smaller sample limit. In either mode, a sample limit never drops a detail family explicitly requested for a selected sample. Limit concurrency and keep the result associated with its originating `sampleId`. Do not use unbounded parallel requests. Apply the shared read-only retry policy: up to 5 attempts for transport-level failures with a 10-second wait, never for HTTP 4xx or non-zero business codes.

For each detail request, check both HTTP and business status:

- HTTP 2xx with `code == 0` and a non-empty payload: returned details.
- HTTP 2xx with `code == 0` and empty, null, or empty-list data: empty successful detail; preserve it as empty.
- Non-zero business code: record endpoint, `sampleId`, code, message, and stop that detail request.
- Non-2xx, transport/timeout failure, or invalid JSON: `API_ERROR`; record the observable symptom and stop that detail request.

A documented successful empty, null, or not-found payload for one supplied ID is retained as that sample's observable status; it is not a request failure and does not erase other supplied IDs. Fields not produced by that valid state remain not applicable. A transport, HTTP, business, or parse failure affects only that request and leaves its dependent fields unavailable while other samples and detail families continue.

Preserve native response keys. In particular, culture-plan fields remain `sample_id`, `time_anchors`, `time_axis`, `material_source`, and `protocol`. Keep null, omitted, and empty fields distinct.

### 5. Integrate and report

Group output by `sampleId`. In discovery mode, every material statement must be traceable to a semantic record or a detail endpoint. In fixed-ID mode, every material statement must be traceable to the supplied or inherited ID and its detail endpoint; do not create semantic matching evidence. Preserve inherited discovery provenance and coverage when present, but do not invent either for directly user-supplied IDs. Separate as applicable:

- semantic matching evidence (discovery mode only)
- fixed-ID comparison scope (fixed-ID mode only)
- basic metadata
- culture-plan evidence
- phenotype evidence
- application evidence
- missing, conflicting, or failed sections

Cross-sample synthesis may describe shared returned attributes, differences, conflicts, and evidence coverage. Preserve incompatible values as `CONFLICTING_EVIDENCE`; never overwrite one sample with another. Sample-centric aggregation does not create a biological relationship between fields: unless an API response explicitly binds them, two entities in one sample are at most `SAME_SAMPLE_CO_OCCURRENCE`. Preserve endpoint and field-path provenance so `orbit-reason` can classify later edges. It must not claim that association proves causality, validation, clinical utility, or reproducibility.

If the user requests a tailored culture protocol, provide the comparative evidence and shared research context, then hand off to `orbit-protocol`; do not perform protocol-family convergence here. If the user requests a complete experimental design, recommend `orbit-design` after protocol selection.

Use an explicitly requested output language when provided; otherwise use the user's task language for every user-visible heading, status explanation, choice, and output file. Translate raw placeholders through the shared missing-information display rule while retaining native values and machine states in provenance.

At the end, include a compact cross-skill research context: explicit and unresolved constraints, selected/excluded sample IDs, references grouped by sample, per-endpoint status, conflicts, missing states, and the recommended next skill. Reuse a valid incoming context; repeat discovery only when constraints changed, required context is incomplete, or provenance cannot be verified, and record that reason.

## Response modes and output

Follow the shared response contract and select the mode from the user's request and workflow state before composing the answer.

- **Researcher mode (default for interpretable findings):** Lead with the comparative conclusion: which samples satisfy all explicit constraints, the most important shared feature, and the consequential difference for the stated selection purpose. Keep partial matches and exclusion reasons separate. Use natural scientific language and only the structure needed; there is no fixed heading set, result count, or response length. Full scientific results remain researcher-facing, not an audit trace: state returned, displayed, and remaining coverage and preserve pagination when relevant.
- **Operational mode:** Use plain language for missing input or a required choice, successful empty retrieval, missing returned information, API/transport failure, incomplete pagination, or an unfinished handoff. State the current status, what happened or is missing, relevant choices or identifiers, and the next user/workflow step. Do not force a comparison or biological interpretation before interpretable evidence exists, and never turn empty or failed retrieval into a biological negative.
- **Audit mode:** Use when the user asks for a complete API/evidence trace, endpoint or filters, native records/fields, JSON paths, claim support, internal evidence classes, missing states, status, or pagination details. Begin with a concise scientific conclusion when one exists, then expose the technical trace and full provenance needed to inspect it. A request for all scientific results alone does not imply audit intent.
- **Machine mode:** Use for explicit JSON, structured output, or programmatic consumption. Return only the requested structure, preserve native keys, stable identifiers, and machine states, and add no Markdown or unsolicited suggestions. Keep internal states and provenance available in the active skill's defined structure; do not claim a cross-skill schema.

By default, hide endpoint paths, HTTP/API status, wrapper messages, request syntax, JSON paths, internal error codes, and internal evidence or missing-state enums. Retain complete sample ownership, exclusion reasons, endpoint/field provenance, conflicts, missing states, and handoff context internally and in audit or machine output. Keep returned evidence, record-supported synthesis, user-specific adaptation, research suggestions, and unresolved questions distinct. Offer conditional suggestions only when requested or when a material evidence gap directly affects sample or experiment selection; label them evidence-informed rather than ORBIT-validated conclusions.

## Output template

```markdown
# Sample comparison for the research goal

## Selection conclusion
- Samples satisfying all explicit constraints: ...
- Most important shared feature: ...
- Consequential difference for selection: ...

## Candidate sample evidence
| Sample | Scientific fit and matching features | Important limitation |
|---|---|---|

## Per-sample evidence
### [sampleId]
- Model and culture features: ...
- Phenotype and applications: ...
- Missing, conflicting, or failed sections: ...

## Integrated observations and evidence boundary
- Shared returned attributes, differences, conflicts, and coverage: ...
- These records are sample-discovery evidence, not independently validated protocols or clinical conclusions.
```

Never use webpages or browser automation, retrieve publication full text from a DOI, expose secrets, submit analysis jobs, or upload files.
