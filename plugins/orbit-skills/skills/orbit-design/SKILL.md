---
name: orbit-design
description: Turn Orbit KM evidence, a selected culture-protocol family, or an existing organoid plan into a traceable experimental-design draft. Use this skill whenever the user asks for hypotheses, experimental/control groups, biological and technical replicates, donor or cell-line structure, batch balancing, time points, QC, readouts, omics sampling, conflict review, risks, or stop criteria—even if they call it a study plan rather than an experimental design. It separates KM/API evidence, user decisions, and Agent suggestions and never fabricates sample sizes, thresholds, or database facts.
---

# Orbit Design

Read `<plugin-root>/references/api-reference.md` for exact endpoint calls, `<plugin-root>/references/organoid-api-contract.md` for shared request safety, and `<plugin-root>/references/researcher-response-contract.md` for response modes and researcher-first presentation before using an Orbit research context or making any API request.

## HTTP transport

For every Orbit HTTP attempt, invoke the wrapper at `<plugin-root>/scripts/orbit-request.sh ...` on Linux/macOS, or `<plugin-root>/scripts/orbit-request.ps1 ...` on Windows PowerShell. Resolve `<plugin-root>` from the installed plugin resources, not the user's current working directory. Use only the documented relative `/api/...` path and a body file or stdin for a documented JSON POST. Do not generate ad-hoc Python, `urllib`, `curl`, or other request scripts, and do not use browser/WebFetch transport. Preserve the exact request and wrapper stderr status line as provenance; inspect stdout JSON `code` under the shared contract.

This skill designs a study; it is not a new retrieval endpoint, statistical power calculator, protocol validator, or analysis submitter. Prefer a converged `orbit-protocol` context. Accept evidence from `orbit-chat`, `orbit-search`, `orbit-browse`, and `orbit-omics`, while preserving provenance and missing states.

## 1. Establish scope and provenance

Extract:

- research question, organism, organoid/model, selected protocol family, and application
- user-provided resources, constraints, exclusions, timeline, and intended decisions
- API-returned KM samples/details/references and omics contexts
- unresolved assumptions, conflicts, missing-information states, and user-choice history

Label every input as one of:

- **KM/API direct evidence**
- **user-provided decision or constraint**
- **Agent suggestion**
- **missing/conflicting information**

When input comes from `orbit-reason`, only a `DIRECT_EDGE` is direct relationship evidence. Treat `SAME_SAMPLE_CO_OCCURRENCE` as hypothesis-generating context, `FREE_TEXT_LINK` as an unverified textual association, and `UNRESOLVED_EDGE` as a design gap requiring validation. Never turn these weaker classes into a mechanistic premise.

Do not upgrade an assumption or suggestion into evidence. Bind references and details to their originating `sampleId`; bind omics results to `sampleId`, modality, API-returned `dataSet`, and group.

If the protocol family is unresolved or incompatible families are being combined, stop and route to `orbit-protocol`. If the user only needs sample retrieval, route to the appropriate search/browse/chat skill.

## 2. Define a testable hypothesis

Record:

- primary research question and testable hypothesis
- primary comparison and expected directional or non-directional readout
- alternative explanation or falsifying observation
- secondary questions, clearly separated

If the biological objective or primary comparison is ambiguous, use `AskUserQuestion` in the user's language. Ask only decision-critical questions; use at most four clickable options per question and additional rounds when required. Do not invent a disease mechanism or expected result.

## 3. Build groups and controls

For every group record:

| Field | Required interpretation |
|---|---|
| Group ID/label | Stable label; do not reuse it for different conditions |
| Role | experimental, control, baseline, vehicle, reference, rescue, or other returned/user role |
| Biological condition | disease, healthy, perturbation, treatment, genotype, etc. |
| Starting source | donor, line, PDO/PDX/primary source, as available |
| Intervention | treatment and vehicle/context |
| Protocol family | selected compatible family |
| Time point | collection/readout time |
| Pairing | paired/unpaired/this information was not mentioned |
| Dataset membership | sampleId, modality, dataSet, group when applicable |
| Provenance | KM/API, user, Agent suggestion, or missing state |

Check whether the main comparison has an interpretable control. Consider healthy donor, isogenic, vehicle, untreated, baseline, rescue, and time-matched controls only as context-appropriate **Agent suggestions** unless returned by KM or explicitly chosen by the user.

**STOP** when the primary comparison cannot be defined or lacks any interpretable control and the user has not resolved it. Do not prescribe a generic control as if universally correct.

## 4. Separate replication units and batches

Track independently:

- biological replicates: donor, cell line, independent organoid derivation, or independent differentiation/culture batch
- technical replicates: wells, organoids from one derivation, library/assay repeats
- culture/differentiation batch
- matrix/media lot where returned or user-provided
- sequencing/library-preparation batch
- operator, instrument, plate, or acquisition batch
- randomization, blinding, blocking, batch balancing, and batch-specific controls

Never invent `n=3`, a power target, donor count, or replicate number. Explain that multiple organoids/wells from one derivation may be technical or nested units rather than independent biological replicates. When information is absent, use the localized “this information was not mentioned” display and preserve its machine state.

Warn when batches are not balanced across biological conditions, all controls occupy one batch, donor/line is confounded with condition, or the independent experimental unit is unclear.

## 5. Align the timeline

Build a time map connecting:

- protocol stage and maturation target
- perturbation/intervention
- QC checkpoints
- sample collection
- phenotype/functional readouts
- omics acquisition and analysis contrast
- stopping or exclusion assessment

Retain every source-specific time and sample ID. Do not average incompatible days or silently align stages with different biological maturity. Put unresolved timing differences into the conflict matrix and ask the user when they affect execution or interpretation.

## 6. Separate QC and readout provenance

### KM direct QC evidence

Include only API-returned markers, morphology, measurements, methods, endpoints, thresholds, or acceptance criteria. Bind each row to `sampleId`, endpoint/reference, stage, and timing. Distinguish a method returned explicitly from one interpreted from narrative text.

### User-required QC/readouts

Keep user-specified endpoints separate, even if KM records do not mention them.

### Agent-suggested additions

May suggest checks for identity, morphology, viability, contamination/mycoplasma, lineage composition, off-target lineage, maturity/function, batch consistency, and assay suitability. Mark each as **Agent suggestion—not KM direct evidence**. Never fabricate a quantitative threshold or acceptance range.

For every readout, state which hypothesis/comparison it informs, group(s), time point, modality, and what information is needed for interpretation.

## 7. Integrate omics safely

Use only a valid `orbit-omics` context:

```text
API-returned sampleId → control-group endpoint → returned dataSet → returned group
```

A GSE-like search `data` value is provenance, not a documented shortcut to a control-group `dataSet`. If only GSE is known, a validated `/api/browse/sample/reference/gds` lookup may return mapping rows containing raw `sampleId` strings and platform. Preserve the mapping row, use only returned IDs for the next control-group call, and do not treat the GSE as `dataSet` or infer a group/comparison. If mapping is empty or fails, mark the sample-specific omics design dependency unresolved and stop it.

Do not combine quantitative results across datasets by default. Descriptive side-by-side plans are allowed with dataset labels and warnings. Joint inference requires comparable contrasts, normalization, batch correction, covariate handling, and valid experimental units; if these are unavailable, record a STOP for quantitative merging.

## 8. Produce compatibility and conflict matrices

### Group/design matrix

```markdown
| Group | Role | Source/condition | Intervention | Biological unit | Technical unit | Batch/block | Time point | Readout | Provenance |
|---|---|---|---|---|---|---|---|---|---|
```

Keep every matrix element provenance-atomic. One element may contain only API-returned evidence, only user-given content, only an Agent suggestion, or only a missing/conflicting state. If a value combines content from different sources—for example, a returned marker/time point plus a suggested matched assay—split it into separate elements before assigning provenance. Never choose a single provenance class based on the dominant clause while acknowledging a different source in the provenance note. Before finalizing the matrix, verify that the complete value of every element is supported by its one assigned provenance class.

### Conflict matrix

```markdown
| Dimension | Group/sample A | Group/sample B | Status | Interpretive impact | Resolution |
|---|---|---|---|---|---|
```

Use only these statuses:

- `COMPATIBLE`
- `CONFLICT`
- `MISSING`
- `NOT_APPLICABLE`
- `NEEDS_USER_DECISION`

Cover source, protocol family, disease/control comparability, vehicle, independent replicate unit, donor/line, batch, time/maturity, dataset/contrast, QC/readout, and missing provenance. Missing is not automatically a conflict.

## 9. Apply STOP/WARN/INFO gates

### Researcher-facing gate meanings

Use researcher-facing labels by default:

- **Cannot proceed yet:** the affected design step is uninterpretable or unsafe without a decision or missing evidence.
- **Important limitation:** planning may continue, but the limitation must remain visible and its consequence stated.
- **Context note:** a non-blocking provenance detail or optional improvement.

Retain the internal `STOP`, `WARN`, and `INFO` enums in audit, machine output, and internal risk records.

### STOP

Stop the affected design step when continuing would be uninterpretable or unsafe, including:

- organism/model or primary comparison remains ambiguous
- incompatible protocol families are being merged without a user decision
- no interpretable control for the primary comparison
- condition is completely confounded with donor/line or batch and no resolution exists
- different datasets are about to be treated as one quantitative comparison without comparability requirements
- a GSE-like value is being substituted for an unverified KM/dataSet mapping
- a sequence workflow has a STOP-level validation error
- an uncertain non-idempotent submit is about to be automatically repeated

### WARN

Proceed only with the limitation visible, including:

- replicate number/unit, donor diversity, batch balancing, blinding, or randomization was not mentioned
- QC comes only from Agent suggestions
- a protocol or checkpoint has single-KM support
- vendor/catalogue, threshold, maturity criterion, or annotation provenance is missing
- cross-dataset evidence is shown descriptively rather than merged

### INFO

Use for non-blocking provenance notes and optional design improvements.

A STOP applies only to the affected step. The skill may still report the evidence, unresolved matrix, and concrete decisions needed to continue.

## 10. Response modes and output

Follow the shared response contract. Use operational mode for missing hypothesis/comparison input, required user decisions, STOP gates, incomplete context, and handoffs; use audit mode only when technical trace, native fields, endpoint/filter details, JSON paths, or complete evidence inspection is requested; use machine mode for explicit structured output; otherwise use researcher mode. Researcher output begins with the hypothesis, primary comparison, minimum interpretable design, and principal confound, then presents only the design detail needed for the decision. Clearly separate KM/API evidence, user decisions, Agent suggestions, and missing/conflicting information; explain STOP/WARN/INFO gates scientifically; do not call returned records independent unless independence is established and do not merge datasets. Hide endpoint paths, HTTP status, request syntax, wrapper logs, JSON paths, and internal enums by default while retaining identifiers, dataset/group ownership, batches, replicates, conflicts, missing states, and provenance internally and in audit output. Offer conditional design suggestions only as allowed by the task and shared contract; do not force fixed headings or length. Use the following structure as an optional complex draft and adapt it to the selected mode and user's language.

### Optional output structure

Use an explicitly requested output language when provided; otherwise use the user's task language for every visible heading, option, table label, status explanation, and output file. Native fields may appear beside localized explanations for traceability.

```markdown
# Experimental-design draft

## What the evidence supports and what remains uncertain
## Testable hypothesis and primary comparison
## Selected protocol family and rationale
## Experimental and control groups
## Biological/technical replicates and experimental unit
## Batch, blocking, randomization, and blinding plan
## Timeline and collection plan
## Quality-control findings from the returned records
## User-required quality control and readouts
## Possible additional quality-control checks
## Omics sampling and dataset context
## Group/design matrix
## Conflicting design information
## Design considerations and decisions needed
- Issues that prevent interpretation until resolved
- Limitations that must be carried forward
- Non-blocking context and optional improvements
## Missing information
## Evidence sources and next steps
```

End with a clear boundary: this is a research-design draft requiring qualified scientific, statistical, ethical, and biosafety review. Do not use webpages or browser automation, retrieve DOI full text, invent API data, calculate unsupported power/sample sizes, expose secrets, or submit analysis jobs/files.
