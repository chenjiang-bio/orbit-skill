---
name: orbit-protocol
description: Synthesize a tailored organoid culture-protocol candidate from multiple KM sample records. Use this skill whenever a user asks for a complete staged culture plan, wants database protocols narrowed by experimental purpose, cell source, culture system, or maturity, or needs incompatible KM routes separated before synthesis. It uses fit-first candidate selection, clickable convergence decisions, protocol-family isolation, conflict reporting, and sample-level provenance. It is API-only and never treats semantic discovery as protocol validation.
---

# Orbit Protocol

Read `<plugin-root>/references/api-reference.md` for exact endpoint calls, `<plugin-root>/references/organoid-api-contract.md` for shared request safety, and `<plugin-root>/references/researcher-response-contract.md` for response modes and researcher-first presentation, plus `<plugin-root>/references/sample-discovery-and-detail-handoff.md` before discovery, detail retrieval, or handoff.

## HTTP transport

For every Orbit HTTP attempt, invoke the wrapper at `<plugin-root>/scripts/orbit-request.sh ...` on Linux/macOS, or `<plugin-root>/scripts/orbit-request.ps1 ...` on Windows PowerShell. Resolve `<plugin-root>` from the installed plugin resources, not the user's current working directory. Use only the documented relative `/api/...` path and a body file or stdin for a documented JSON POST. Do not generate ad-hoc Python, `urllib`, `curl`, or other request scripts, and do not use browser/WebFetch transport. Preserve the exact request and wrapper stderr status line as provenance; inspect stdout JSON `code` under the shared contract.

Build a database-backed protocol candidate. Use `orbit-search` for authoritative retrieval, `orbit-chat` for comparative evidence, `orbit-browse` for one sample, `orbit-reason` for factor/pathway/phenotype or other cross-layer chains, and `orbit-design` after protocol selection when the user needs controls, replicates, batches, readouts, or a full experimental design. This skill reports returned factors and stage timing as protocol provenance; it does not infer factor→pathway or perturbation→phenotype relationships.

## 1. Establish the target

Extract only user-provided constraints:

- organism and organoid type (required)
- organ, starting-cell source, disease/application, experimental purpose
- culture system, complexity, target duration/maturity
- co-culture/perturbation requirements, equipment/material constraints, intended readouts

Keep unresolved values unresolved. Do not guess organism, organoid, sample IDs, protocol parameters, or equipment availability. Preserve the user's language in the research context.

## 2. Reuse or discover candidates

Accept a provenance-complete handoff from `orbit-search` or `orbit-chat`. Validate its explicit constraints, API-returned `sampleId` values, references grouped by sample, evidence labels, API status, and missing states. Reuse successful details rather than repeating requests. Repeat discovery only when constraints changed, required context is incomplete, or provenance cannot be verified; record the reason.

When discovery is needed, call:

```text
POST /api/browse/general/semantic/search
```

Send documented fields only. Preserve exact query/filters, requested and returned pagination, total, service order, `sampleId`, organism, native matching fields, and `semanticScore`. Label this `sample discovery`, not protocol search or validation. Never derive a sample ID.

Apply explicit constraints before detail retrieval. Organism requires exact case-insensitive equality. A missing field is unresolved—not a match or conflict. Deduplicate identical `sampleId` values only.

## 3. Retrieve protocol details

For every retained API-returned ID, retrieve:

```text
GET /api/browse/sample/culture-plan?sampleId={sampleId}
GET /api/browse/sample/general-basic-info?sampleId={sampleId}
```

Apply the shared read-only retry policy and isolate errors per sample. Preserve `sample_id`, `composition`, `time_anchors`, `time_axis`, `material_source`, and `protocol`, plus basic metadata and references. Keep null, omitted, empty, source-placeholder, business-error, and transport-error states distinct.

Do not shortlist by culture-plan richness before retrieving the details needed to measure it. If there are too many discovery matches, first use explicit fit fields and service order to choose a bounded detail-retrieval set; explain that this is a retrieval bound, not a quality ranking.

## 4. Build protocol families

Classify each candidate using returned fields only. Use a conceptual family key with these compatibility dimensions:

1. purpose: base generation, disease modeling, drug/toxicity, immune research, biomarker/omics, regenerative/transplantation
2. cell source: PSC, iPSC, ESC, PDO, primary cells, fetal-tissue-derived, PDX, or unclassified
3. operational approach: scaffold, suspension/low-attachment, bioreactor/spinner, interface/Transwell, bioprinting/assembly, or unclassified
4. formation strategy: self-assembly, directed differentiation, or unclassified
5. scaffold class/species
6. co-culture mode, including immune, microbial, or viral components
7. disease/application context
8. target duration/maturity and timeline compatibility
9. critical material, concentration, and stage compatibility
10. base-construction versus downstream-application boundary

Treat placeholder strings such as `not specified`, `unknown`, `none`, `N/A`, and `-` as `SOURCE_NOT_SPECIFIED`, never as a biological classification signal. User-visible wording must say the formal equivalent of “this information was not mentioned” in the user's language; retain the machine state in provenance.

A missing dimension is `UNCLASSIFIED`; it is not automatically compatible or conflicting. Purpose and operational approach alone are insufficient to establish convergence.

Present a localized family table before synthesis:

```markdown
| Sample ID | Purpose | Cell source | Operational route | Maturity/timeline | Compatibility flags | Detail status |
|---|---|---|---|---|---|---|
```

## 5. Rank fit before completeness

Never equate “most detailed” with “best”. Use this order:

### Fit tier

1. satisfy explicit organism and organoid constraints;
2. prefer candidates matching explicit purpose, source, disease/application, culture system, maturity/duration, co-culture, equipment, and readout constraints;
3. rank an explicit conflict below an unresolved/missing field;
4. keep incompatible families separate.

### Evidence-completeness tier

Only among candidates with equal or comparable fit, compare returned coverage of:

- protocol stages and timing
- materials, vendors/catalogue data, factors and concentrations
- time anchors, QC/readouts, references
- metadata needed to assess compatibility

Preserve service order as the stable final tie-breaker unless the user requested another documented ranking. Explain fit evidence, conflicts, missing information, completeness, and final selection reason.

## 6. Run a dynamic clickable convergence gate

Ask only when returned information is too broad or candidate routes genuinely diverge. Do not ask upfront for every possible preference.

At each gate:

1. compute unresolved decision-critical dimensions and current family count;
2. use `AskUserQuestion` with clickable options in the user's language;
3. ask the smallest set of questions with the greatest narrowing value;
4. apply the answer, preserve choice history and exclusion reasons;
5. rebuild family keys, fit ranking, and conflict state;
6. repeat this gate if incompatible families remain.

Use single-select for purpose, source, route, or primary family; multi-select for exclusions. Each question may have at most four options. If there are more than four values, ask hierarchically or over multiple rounds—never merge scientifically distinct choices merely to fit the UI. Never ask the user to type A/B/C/D.

Terminal states:

- **One compatible family:** proceed.
- **Multiple families and user requests parallel alternatives:** output each family independently; never cross-merge.
- **Zero candidates:** stop and offer a clickable choice to relax a specific constraint or end.
- **User declines/dismisses a required decision:** stop synthesis and show the unresolved comparison; do not substitute a default.
- **Single candidate:** proceed with a single-source warning.

Flag non-human scaffolds, fetal tissue, microbial/viral components, API errors, and application-only records as explicit exclusion choices when relevant.

## 7. Build the staged protocol

Synthesize only within one converged family. If parallel families were selected, create separate protocol sections.

Every material statement, stage, duration, concentration, material, and KM-derived checkpoint must cite its supporting `sampleId`. Do not average times or concentrations, take medians, or invent a compromise. When records conflict, retain alternatives in a conflict matrix and require a choice if the conflict prevents execution.

### Stage rules

- Merge only genuinely compatible conceptual stages.
- Preserve source-specific timing and concentrations.
- A stage supported by one sample remains single-source evidence.
- Drug exposure, infection, irradiation, toxicity testing, and other downstream operations belong in separate application modules.
- Do not splice cell-source transitions, culture systems, or maturation endpoints across incompatible records.

### Materials rules

Group materials without erasing identity. Merge only when name, vendor, and catalogue identity are compatible. Same-name materials with different vendor/catalogue values remain separate or are marked conflicting. List supporting sample IDs and do not call a single-sample material universally required.

### Protocol conflict matrix

```markdown
| Parameter/stage | Sample A | Sample B | Status | Consequence | Required resolution |
|---|---|---|---|---|---|
```

Include conflicts in source, route, matrix, medium transition, density/format, concentration, timing, maturation endpoint, materials, and QC. Missing information is not a conflict. Never resolve conflicts by averaging.

## 8. Separate QC provenance

Use two visibly separate sections.

### KM direct QC evidence

Include only API-returned time anchors, markers, measurement endpoints, methods, thresholds, or acceptance criteria. Bind every row to `sampleId`, endpoint, and reference when available. Distinguish direct returned methods from a method interpreted from a description.

### Agent-suggested QC additions

May identify scientifically useful checks that the KM records did not provide, such as identity, morphology, viability, contamination, lineage, maturity/function, or batch consistency. Label every item **Agent suggestion—not KM direct evidence**. Do not invent numeric thresholds, acceptance ranges, or failure criteria. Put absent thresholds into validation questions.

## 9. Report design-relevant gaps

Transfer—but do not fabricate—information about controls, biological versus technical replicates, donor/cell-line count, differentiation/culture batches, randomization/blinding, batch balancing, time points, and readouts. When KM records do not mention these, say “this information was not mentioned” with the correct machine state. Recommend `orbit-design` to resolve them into an experimental-design draft.

## 10. Response modes and output

Follow the shared response contract and choose the response mode from the user's intent and workflow state.

- **Researcher mode (default):** Begin with a fit-first conclusion: the best-matching protocol family for the user's purpose and constraints, the major alternative or conflict, and the decision-critical missing information. Present only stages actually supported by returned evidence or explicitly needed for the plan; do not invent stages, parameters, or a compromise between incompatible routes. At each stage, separate in natural language what the records returned, what must be adapted to this user, and what remains unresolved. Keep source-specific values and sample ownership visible in researcher-relevant provenance, without exposing internal field names by default. There are no fixed headings or response length requirements.
- **Operational mode:** Use for missing organism or other required input, a required family/route choice, successful empty retrieval, API or transport failure, incomplete handoff/context, or a stopped synthesis. State the current status plainly, what is missing or happened, available choices or identifiers, and the next decision or workflow step. Do not force a protocol recommendation before a compatible family is established.
- **Audit mode:** Use only when the user requests technical trace, endpoint/filter details, native fields, JSON paths, claim-level evidence, internal edge or missing-state classification, complete pagination, or status. Start with a concise fit conclusion when possible, then show the technical evidence and full provenance. A request for all scientific protocol results alone remains researcher-facing.
- **Machine mode:** Use for explicit JSON, structured output, or programmatic consumption. Return only the requested structure, preserving native keys, stable identifiers, and machine states, with no Markdown or unsolicited suggestions. Use this skill's defined structure; do not imply a cross-skill schema.

Hide endpoint paths, HTTP/API status, wrapper messages, request syntax, JSON paths, internal error codes, and internal enums by default. Retain exact sample IDs, source-specific protocol values, conflicts, missing states, pagination, user-choice history, exclusion reasons, and handoff context internally and in audit or machine output. Keep returned evidence, user-specific adaptation, Agent suggestions, and unresolved values separate; an agent-combined plan is not a published or validated protocol. Offer suggestions only when requested or when a direct evidence gap materially affects protocol or experiment selection, and label them as evidence-informed rather than database conclusions. Use the user's language for all visible content.

### Optional output structure

```markdown
# [Organoid] culture-protocol candidate for [organism]

## Evidence from returned records
## User-specific adaptation and decisions
## Unresolved parameters and validation questions
## Candidate families and fit-first selection
## Contributing KM samples
## Staged protocol (one section per selected family)
## Materials checklist
## Protocol conflict matrix
## Quality-control evidence from returned records
## Additional quality-control suggestions
## Application modules
## Controls, replication, batch, and readout information gaps
## Evidence boundary and handoff to orbit-design
```

All user-visible content and output files must use an explicitly requested output language when provided; otherwise use the user's task language. Native API keys/values may be retained beside localized explanations for traceability. Never use informal wording, webpages, browser automation, DOI full-text retrieval, secrets, sequence-job submission, or file upload.
