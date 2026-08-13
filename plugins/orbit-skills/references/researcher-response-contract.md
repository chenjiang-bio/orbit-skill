# Researcher Response Contract

This contract defines user-visible response presentation. Read it with [`organoid-api-contract.md`](organoid-api-contract.md), which remains authoritative for API requests, returned evidence, provenance, handoff, and safety.

## Precedence and language

Apply, in order: evidence truthfulness and documented API boundaries; explicit user output language and format; workflow state and task type; researcher-first presentation; then a skill template. Explicit language overrides task language; otherwise use the task language. Formatting may change organization, never evidence, identifier, causal, cross-dataset, or safety rules.

## Response modes

A response mode controls presentation and interaction, not the underlying request outcome, payload/field state, coverage, or workflow state. Keep those dimensions independent under the API contract. Natural-language translation may combine them into a readable sentence, but it must not collapse them into an ambiguous generic “success” or “failure.”

**Researcher mode** is the default for terminal interpretable findings. Lead with the shortest direct scientific answer, never an endpoint, status, wrapper log, filter, JSON path, raw pagination, or identifier list. Use only needed structure. A complete scientific-results request remains researcher-facing: preserve total, displayed, remaining counts and pagination without becoming an audit trace. Never manufacture a biological narrative.

**Operational mode** covers missing input, user choices, successful empty retrieval, missing information, failure, incomplete pagination or handoff, side-effect confirmation, and asynchronous submission/progress/completion/failure. State plainly the current status, what happened or is missing, relevant identifier or choices, and the next user/workflow step. Do not force interpretation before evidence exists; absence from an empty or failed retrieval is not a biological negative.

**Audit mode** applies when the user requests a complete API/evidence trace, endpoint or filters, native fields/raw records, JSON paths, claim support, edge classification, missing states, status, or pagination. Begin with a concise conclusion, then expose reproduction details, native keys, internal edge and missing-state enums, paths, and the active skill's relevant request/payload/coverage/workflow states. Audit mode governs the visible response only; by itself it neither writes files nor implies a persistent deliverable. A request to save a trace, produce named files, or hand off a machine-readable bundle is a separate output contract (below), not merely audit presentation.

**Machine mode** applies to explicit JSON, structured, or programmatic requests. Return only the requested structure; preserve native keys, stable identifiers, and the active skill's machine states; use the requested language for natural-language values; do not translate structural keys, replace missing values with prose, add recommendations, or claim a stable cross-skill schema.

## Default-off persistence

Mode selection controls presentation; it never, on its own, writes files. In every mode the default deliverable is the response itself, and the researcher default additionally keeps provenance, native keys, traces, and coverage internal. Only an explicit user instruction to persist output — save a trace, produce named files, emit a machine-readable bundle, or hand off raw captures — creates a persistent-artifact contract, and only that instruction does. Do not manufacture files, audit bundles, or trace directories because a task seems thorough or a mode exposes internals.

When the user does specify a persistent-artifact contract, its named paths, filenames, field names, ordering, encoding, raw-capture requirements, and completion rules are a binding deliverable, separate from and additional to the researcher-facing answer. Reproduce every stated requirement verbatim; never summarize, weaken, reorder, drop, or substitute a "practical" equivalent for any of it, and never rewrite a locked instruction into a shorter paraphrase before acting on it. When the contract requires raw evidence, capture it as it is produced rather than reconstructing it afterward, and treat post-completion editing, repair, or supplementation of captured evidence as prohibited unless the contract allows it. Before claiming the deliverable is complete, verify closure against the contract's own terms — every required file present, every declared-missing item reconciled with a reason — and report the actual state rather than an assumed one.

## Before-final-answer checklist

Before every final answer, verify all eleven points. Keep these checks internal in researcher mode; expose technical details only for audit or machine intent.

1. **Request ownership:** Every returned `sampleId`, gene/pathway identifier, `dataSet`, group, comparison, reference, DOI, status, missing value, conflict, and pagination field remains in provenance and attached to its originating request.
2. **Field ownership:** Every field remains attached to its originating sample, dataset, group, comparison, analysis, and request; never transfer details between records.
3. **Identifier truth:** Never infer a KM `sampleId` or another identifier from a title, GSE-like value, DOI, display name, or prefix.
4. **Five-layer separation:** Keep ORBIT facts, record-supported synthesis, biological interpretation, research suggestions, and unresolved questions distinguishable; never present one layer as another.
5. **Evidence boundaries:** Never merge effects, p-values, adjusted p-values, enrichment scores, expression values, or claims across datasets as one analysis. Retain internal `DIRECT_EDGE`, `SAME_SAMPLE_CO_OCCURRENCE`, `FREE_TEXT_LINK`, or `UNRESOLVED_EDGE` even when translating it.
6. **Relationship meaning:** A field supports only the relationship it expresses. Shared context does not prove activation, regulation, mediation, response, mechanism, causality, clinical validity, or therapeutic utility.
7. **No model repair:** General knowledge has not repaired missing identifiers, relations, experimental results, parameters, or statistical evidence.
8. **Conflict consequence:** Conflicting records remain conflicting, and the material consequence for interpretation or action is stated.
9. **Missing-state truth:** No field returned, null, successful empty, source unspecified, user input missing, conflict, request failure, and incomplete analysis scope remain distinct and are never rewritten as a biological negative.
10. **Coverage inheritance:** Requested/returned pagination, totals, selected/displayed/remaining or inspected/uninspected counts, failed items, and upstream complete/partial/unknown coverage remain visible when they affect interpretation. A successful downstream request has not silently reset inherited partial coverage.
11. **No replacement narrative:** When evidence is unsupported or insufficient, say so; do not replace the unsupported answer with a plausible biological narrative.

## Researcher-facing translation

Hide endpoint paths, HTTP/API status, request syntax, wrapper messages, JSON paths, internal error codes, edge enums, and missing-state enums by default. Translate edge meanings naturally: a direct database-supported relationship; observations in one context without an established relationship; a source-text mention without structured support; or a relationship current data cannot determine. Translate missing states without erasing distinctions. Use “supports,” “is consistent with,” “suggests,” “is associated with,” and “cannot be determined from the current data” with their calibrated meanings. Do not call annotations active pathways, core-enrichment genes drivers, predictions validated biomarkers, sequence similarity functional equivalence, or co-occurrence mechanism.

Preserve researcher-relevant provenance: sample/dataset IDs, biological groups, analysis/time point, species/model, DOI/reference, support across records, and material conflict, incompleteness, pagination, and missing evidence. Report only limitations that change interpretation or action, with consequence. Offer one to three suggestions only when requested, in protocol/design work, or when a direct evidence gap materially affects selection or experiment; label them evidence-informed, not ORBIT-validated conclusions, and do not add them to simple lookups, operational states, raw requests, machine output, or underspecified contexts.
