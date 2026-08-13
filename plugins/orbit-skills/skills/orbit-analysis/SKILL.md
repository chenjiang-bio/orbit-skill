---
name: orbit-analysis
description: Prioritize candidate biomarkers with the ORBIT quick biomarker analysis API from a user-supplied gene-symbol list or expression matrix, enumerate valid conditions, manage asynchronous jobs, and enrich completed rankings with bounded ORBIT gene annotations for a researcher-friendly biological report. Use this skill whenever a user asks to rank organoid-context biomarker candidates, analyze genes or an expression matrix for biomarkers, search valid analysis conditions, check a quick biomarker job, retrieve its results, or explain returned candidate genes. Use only documented Orbit endpoints through the plugin wrapper; never submit or upload without explicit user intent, and never present annotation as biomarker validation.
---

# Organoid Analysis

Read `<plugin-root>/references/api-reference.md` for exact endpoint calls, `<plugin-root>/references/organoid-api-contract.md` for shared request safety, and `<plugin-root>/references/researcher-response-contract.md` for response modes and researcher-first presentation before making any API request.

## Scope

This Skill manages biomarker prioritization through `/api/analysis/quick/biomarker`. Quick jobs use `jobId`, and their status endpoint returns completed results inline.

The analysis reprioritizes supplied candidates against an organoid-context pathway background. It does not discover all possible biomarkers, validate a biomarker, establish causality, or support clinical decisions. Only candidates that the service can score contribute to a scored ranking; an unscored candidate is not a biological negative.

## HTTP transport

For every Orbit HTTP attempt, invoke the wrapper at `<plugin-root>/scripts/orbit-request.sh ...` on Linux/macOS, or `<plugin-root>/scripts/orbit-request.ps1 ...` on Windows PowerShell. Resolve `<plugin-root>` from installed plugin resources, not the user's working directory. Use JSON body files for genes-mode submission and the wrapper's explicit multipart fields/files for expression-mode submission. Supporting interpretation uses the documented read-only gene suggestion and gene annotation endpoints through the same wrapper. Do not generate ad-hoc Python, `urllib`, direct `curl`, browser, or WebFetch transport.

Preserve the exact request metadata and wrapper stderr status line as provenance without displaying uploaded file paths or contents. Inspect HTTP status and the native JSON shape under the shared contract.

## Choose a workflow

| User goal | Endpoint | Identifier/result behavior |
|---|---|---|
| List or search valid condition values | `GET /api/analysis/quick/biomarker/conditions` | Read-only; no job created |
| Rank supplied gene symbols | `POST /api/analysis/quick/biomarker/predict` with JSON `mode: genes` | Returns `jobId` |
| Rank candidates from expression data | `POST /api/analysis/quick/biomarker/predict` with multipart `mode=expression` | Returns `jobId` |
| Check status or obtain final results | `GET /api/analysis/quick/biomarker/jobs/{jobId}` | `queued`, `running`, or inline results when `ok` |

There is no separate biomarker progress or result endpoint and no documented progress percentage. Use the exact returned `jobId` only with the documented job endpoint.

## Resolve analysis conditions first

`condition` is required and `organCondition` is optional. Both must exactly match server-returned B_terms values; never construct, translate, or normalize them from model knowledge.

Call `/conditions` with:

- `species`: exactly `hsa` or `mmu`;
- `field`: exactly `condition` or `organCondition`;
- optional `q`: the user's search text for case-insensitive substring matching.

If the user has not supplied an exact previously returned value, retrieve candidates before preparing a submission:

- one returned exact match: present it for submission confirmation;
- multiple values: ask the user to select from returned values, using additional rounds when more than four choices are relevant;
- no values: report that no valid value was returned and stop;
- request failure or unrecognized payload: report the operational failure and stop.

Preserve the exact selected value in the submission.

## Validate before submission

A prediction request creates a job. Confirm that the user explicitly wants to submit it. Never submit merely because they asked what the API can do, requested condition options, or supplied files for inspection.

### Genes mode

Require all of the following:

- `species`: `hsa` or `mmu`;
- exact server-enumerated `condition`;
- `genes`: 1–20 user-supplied gene symbols;
- optional exact server-enumerated `organCondition`.

Use the JSON request shape from the API reference. Preserve order and spelling. Do not convert Entrez or Ensembl identifiers, infer symbols, add genes, deduplicate silently, or submit more than 20 entries. If an identifier is not clearly a symbol, stop and ask the user to provide symbols or authorize a separate documented resolution workflow.

### Expression mode

Require all of the following:

- `species`: `hsa` or `mmu`;
- exact server-enumerated `condition`;
- readable user-supplied `matrix` TSV file;
- readable user-supplied `groups` TSV file;
- optional exact server-enumerated `organCondition`;
- optional `dataType`: exactly `microarray` or `rnaseq` when the user explicitly provides it; omit the multipart field when the user does not specify it.

Before submission, verify that the two files together do not exceed 10 MB. Do not upload a different file, rewrite file contents, or infer `dataType`; when it is not user-specified, omit it rather than choosing a default. Do not expose local paths in the answer. Use only the documented multipart fields. The public API contract does not define additional matrix/group validation, normalization, replicate rules, or the differential-expression implementation, so do not claim those checks or methods were performed.

### Stop conditions

Do not submit when intent is absent, a required field is missing, a condition was not returned by the enumeration endpoint, gene count/type is invalid, a file is absent or unreadable, combined upload size exceeds 10 MB, `dataType` is invalid, or the requested mode conflicts with the request format.

A validation failure is not an API result. Explain the exact missing or invalid input and the next corrective action.

## Handle the asynchronous lifecycle

### Submission safety

`POST /predict` is side-effecting and not safely replayable after an ambiguous outcome.

- Submit exactly once after validation and confirmation.
- Accept the job only when the documented response shape returns a non-empty `jobId`.
- If timeout, connection loss, HTTP 5xx, invalid JSON, or an unrecognized response occurs after the server may have accepted the request, record `SUBMISSION_OUTCOME_UNKNOWN` and do not resubmit automatically.
- Without a returned `jobId`, do not guess one or poll.
- Explain that resubmission might create a duplicate job and requires a new explicit user decision.

### Polling

Poll only when the user asks to monitor the job or the original request explicitly asks for final results. Use the exact returned or user-provided `jobId`; never derive one from inputs or filenames.

- `queued`: report that the job is queued.
- `running`: report that it is running.
- `ok`: require `summary`; require the `results` field for a complete interpretable response. If `results` is absent, report an incomplete response and possible input mismatch, stop interpretation, and do not call gene suggestion, annotation, or KOBAS. If `results` is present as an empty list, report a successful empty result without treating it as a biological negative; do not call downstream enrichment.
- any undocumented status: preserve and report it verbatim, stop polling, and do not map it to completed, failed, or expired.
- HTTP 404: report that the job was not found. Results are retained for at most one day, but the response does not prove whether this ID expired or never existed.

Read-only condition and job GET requests may use the shared bounded retry policy. Do not claim completion from HTTP 2xx alone.

## Handle response shapes conservatively

The quick API document states a `{code,message,data}` envelope, while its endpoint examples show bare payload objects. Follow the endpoint-specific rule in the API contract:

- for an envelope, require HTTP 2xx and numeric `code == 0`, then use `data`;
- for a bare object matching the documented success fields, preserve it as the endpoint payload;
- a bare string error `code`, HTTP error, malformed JSON, or unrecognized shape is an API/contract error, not an empty result;
- preserve unknown fields and native enum values.

## Present completed results

Lead with the returned coverage:

- `nInput`: input count as returned;
- `nScored`: count the service reports as scored;
- `nEnriched`: count the service reports as enriched.

Then show the returned ranked records with native fields:

- common: `rank`, `gene`, `verdict`, `confidence`, `primaryP`;
- expression-only when returned: `log2fc`, `padj`, `deRank`;
- preserve any unknown fields without inventing definitions.

Do not recompute ranking, confidence, verdicts, p-values, or enrichment. Do not import the OCSP command-line tool's broader identifier support, auxiliary scoring methods, consensus score, or `LOW` confidence semantics into the API response unless the API returns them. Keep unscored, missing, null, successful-empty, request-failed, and incomplete states distinct.

## Add biological context through gene annotation

After a job returns documented status `ok`, preserve the complete Analysis response before enrichment. Run annotation only when `results` contains usable non-empty `gene` values. Do not call annotation during condition discovery, submission, `queued`/`running`, an undocumented status, failed result retrieval, or a successful empty result.

### Select a bounded annotation set

By default, annotate at most the first five distinct returned genes in native rank order. Use returned numeric `rank` only when it is usable; otherwise retain service order. Deduplicate only the downstream resolution/annotation requests and preserve every native Analysis row unchanged.

The five-gene limit bounds enrichment calls, not display of the returned ranking. Report:

- ranking rows returned and displayed;
- distinct genes eligible for annotation;
- genes selected for annotation and KOBAS enrichment;
- successfully resolved, annotated, and KOBAS-enriched genes;
- ambiguous, unmatched, empty, and failed genes or enrichment stages;
- genes outside the annotation bound.

If the user explicitly requests more annotation, extend only across genes actually returned by Analysis, up to the returned distinct-gene set. Never add genes from model knowledge.

### Resolve identity before annotation

The endpoint vocabularies differ:

| Analysis species | Gene suggest organism | Gene annotation organism |
|---|---|---|
| `hsa` | `Homo sapiens` | `human` |
| `mmu` | `Mus musculus` | `mouse` |

For each selected native result gene:

1. Call `GET /api/common/gene/suggest` with `keyword` equal to the returned gene, `organism` mapped to the exact full species name in the table, and a bounded `limit`.
2. Preserve the raw wrapper stdout unchanged and apply the shared contract's BOM-aware decoding before parsing JSON or judging `data.list`. In particular, do not classify a PowerShell UTF-16 response as malformed or shape-incompatible from its raw text display.
3. Continue only when exactly one suggestion has an exact case-sensitive `symbol` match and a usable `entrezId`.
4. Preserve all candidates when multiple exact records are returned, and mark the identity ambiguous. Do not automatically choose fuzzy, substring, case-conflicting, or first-listed candidates.
5. If gene suggest reports that `organism` is missing, unsupported, or not matched, preserve the error and ask the user to choose exactly one of `Homo sapiens` or `Mus musculus`. Do not silently fall back to human and do not retry until they choose. Because suggestion is read-only, retry only that failed suggestion call after the choice. Do not replay the Analysis submission. If the choice conflicts with the completed Analysis species, stop the cross-species join and explain the conflict instead of changing the Analysis record.
6. A supported organism with a successful empty suggestion list means no record was returned or indexed for that keyword. Keep it distinct from an organism error, do not offer species correction solely because the list is empty, and do not treat it as a biological negative.
7. Call `GET /api/browse/sample/gene-annotation` with `geneName` equal to the resolved Entrez ID and organism `human` or `mouse` from the table.
8. Verify that the returned `entrezId` matches the resolved identity before associating annotation with the Analysis gene.
9. After a valid annotation identity, call `GET /api/browse/sample/reference/kobas-human` for `hsa→human` or `GET /api/browse/sample/reference/kobas-mouse` for `mmu→mouse`, using the same resolved Entrez ID as integer `query` and explicit bounded `page`/`pageSize`.

Do not send `sampleId`; the service does not use it for annotation selection, and these records are not sample-specific evidence.

A successful empty suggestion, ambiguous identity, missing Entrez ID, annotation 404, malformed response, KOBAS empty result, or request failure leaves the corresponding enrichment stage unresolved, empty, or failed. Continue with other genes. Partial annotation or KOBAS coverage does not change the Analysis job from completed to failed and does not imply biological absence.

### Keep evidence layers separate

Preserve four linked evidence layers:

1. **Analysis evidence:** `jobId`, mode, species, conditions, summary, ranking, and statistics.
2. **Identity-resolution evidence:** native Analysis gene, suggestion request species, returned candidates, exact-match rule, selected symbol/Entrez ID, and resolution state.
3. **Gene-annotation evidence:** queried Entrez ID, annotation organism, returned identity, fields actually returned, and null/empty/error states.
4. **KOBAS evidence:** species-specific route, queried Entrez ID, requested and returned pagination, total, returned `item`/`description`/`id`/`database` records, empty/error state, and uninspected count.

Connect gene annotation and KOBAS records to a ranked gene only through the recorded exact suggestion match and resolved Entrez ID. General annotation does not explain why a gene received its rank, verdict, confidence, or `primaryP`.

Use returned gene annotation selectively for researcher interpretation: stable identity, functional summaries, protein or subcellular information, and relevant disease, interaction, sequence-feature, or external-link metadata when present. Summarize bounded KOBAS records as pathway/function database context with database and identifier provenance. Do not dump every field or fill missing sections from general knowledge.

KOBAS is required for each successfully resolved and gene-annotated selected gene. Use the species-specific route, explicit bounded pagination, and preserve returned total and remaining coverage. A KOBAS term is not evidence that the pathway is active, enriched, expressed, causal, or sample-specific in this Analysis.

Before writing the final answer, reconcile one stage ledger for every selected gene in native rank order: selected → suggestion attempted → exact resolution state → annotation attempted → annotation identity state → KOBAS attempted → final state. Every exact-resolved gene must have an annotation attempt, and every gene with a valid annotation identity must have a KOBAS attempt or preserved evidence of that failed/empty attempt. A missing downstream attempt is a workflow gap, not an unresolved identity. Keep every otherwise eligible gene outside the bound in the same coverage record without calling its downstream stages.

## Response behavior

Follow the shared response contract and use the user's language unless they explicitly request another. Use operational mode for condition selection, validation/confirmation, submission, queued/running/unknown status, job-not-found, ambiguous submission outcome, API errors, or missing fields that block interpretation. Use researcher mode only for completed interpretable results; describe them as API-returned computational prioritization, then add bounded gene annotation as a separate descriptive context layer rather than biomarker validation.

Hide endpoint paths, wrapper syntax, HTTP details, local file paths, and internal contract enums by default. Preserve exact `jobId`, selected condition values, submitted non-sensitive parameters, native statuses, Analysis coverage, result fields, identity-resolution provenance, gene-annotation coverage, KOBAS route/pagination/coverage, and per-gene failures; expose technical details only in audit/machine mode.

A researcher-facing completed report should lead with the most informative ranked findings, then show Analysis coverage and native results, concise biological context from gene annotation and bounded KOBAS records, enrichment coverage and unresolved genes, and the interpretation boundary. Annotation disease records do not prove causality; interactions are not proven in the submitted expression context; `drugList` does not establish druggability, efficacy, actionability, or treatment suitability; KOBAS terms do not establish pathway enrichment or activity in this Analysis; and unscored, unresolved, or unannotated genes are not biological negatives.

## Output templates

### Submission

```markdown
## Quick biomarker job submitted
- Mode: genes / expression
- Job ID: `...`
- Species and condition: ...
- Submitted inputs: non-sensitive summary only
- Next step: check the job status
```

### Status

```markdown
## Quick biomarker job status
- Job ID: `...`
- Status: queued / running / exact undocumented value
- Next step: ...
```

### Completed result

```markdown
# Quick biomarker prioritization

## Coverage
- Input: ...
- Scored: ...
- Enriched: ...

## Returned ranking
| Rank | Gene | Verdict | Confidence | Primary p-value | Expression fields when returned |
|---:|---|---|---|---:|---|

## Biological context for annotated genes
### [native ranked gene]
- Resolved identity: symbol ..., Entrez ID ...
- Returned functional context: ...
- Bounded KOBAS pathway/database context: ...
- Missing or unresolved annotation/KOBAS evidence: ...

## Annotation and KOBAS coverage
- Eligible / selected / resolved / annotated / KOBAS queried / unresolved / outside bound: ...
- KOBAS pagination and remaining records: ...

## Evidence boundary
- This is an API-returned, organoid-context computational ranking, not biomarker validation or a clinical conclusion.
- Gene annotations and KOBAS records are separate descriptive reference evidence; they do not validate or explain the ranking statistics.
- Disease, interaction, drug, and pathway annotations do not establish causality, context-specific activity, pathway enrichment, druggability, efficacy, or treatment suitability.
- Candidates not scored, resolved, or annotated must not be interpreted as biologically negative.
```
