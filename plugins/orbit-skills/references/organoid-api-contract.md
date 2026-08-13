# Organoid API Contract

Read [`api-reference.md`](api-reference.md) for endpoint method, path, request, response, status, and implementation evidence. This file remains authoritative for API requests, returned evidence, provenance, handoff, and evidence boundaries. For user-visible response organization and language, read and follow [`researcher-response-contract.md`](researcher-response-contract.md). The response contract governs presentation; it does not replace or weaken this API/evidence contract. Do not use webpages, browser automation, webpage scraping, or WebFetch for Orbit data.

## Output language

- Unless the user explicitly specifies an output language in the task, use the language of the user's task for the final answer and all other user-visible output.
- An explicit output-language request overrides the task language.
- Preserve native API field names, identifiers, enum values, endpoint paths, and necessary source excerpts in provenance and machine/audit output. In ordinary researcher-facing explanations, translate native keys, enums, and endpoint details into scientific language; expose them only when audit or machine output requires them, or in a necessary secondary note for reproduction or disambiguation.
- This rule applies to every current and future skill in this plugin.

## Success and response handling

- Preserve wrapper stdout and stderr as exact raw bytes for provenance. Before interpreting stdout as JSON, detect its byte-order mark: decode `FF FE` or `FE FF` as UTF-16, decode `EF BB BF` as UTF-8 with BOM, and otherwise decode as UTF-8. BOM-aware decoding is for interpretation only; do not transcode, overwrite, or reconstruct the captured raw file. A UTF-16 PowerShell stdout display with interleaved NUL characters is not evidence of invalid JSON or a response-shape mismatch. Only classify JSON as malformed or a documented field as absent after decoding succeeds under this rule and the decoded payload has been inspected.
- A JSON request normally succeeds only when HTTP is 2xx **and** envelope `code == 0`. The quick biomarker endpoints have a documented envelope/example discrepancy; apply their endpoint-specific bare-payload rule in [`api-reference.md`](api-reference.md) rather than assuming every bare object is success.
- Preserve native response keys and API-returned identifiers. Do not fabricate `sampleId`, `jobId`, dataset IDs, group names, pathways, or gene identifiers.
- Distinguish `NOT_RETURNED`, `RETURNED_NULL`, `RETURNED_EMPTY`, `SOURCE_NOT_SPECIFIED`, `NOT_APPLICABLE`, `USER_NOT_PROVIDED`, `CONFLICTING_EVIDENCE`, and `API_ERROR`.
- Treat a 2xx response with empty data as successful emptiness, not an API error. Do not convert absent information into a biological negative, zero, or unsupported conclusion.
- For quick biomarker job responses, `status=ok` is interpretable only when `summary` and the `results` field are both present. If `results` is absent, record an incomplete/possible input-mismatch payload, report the missing field, and stop biological interpretation and downstream gene suggestion, annotation, and KOBAS. An explicit `results: []` is successful empty output, not a biological negative, and does not trigger downstream enrichment.

### Independent state dimensions

Track these dimensions independently whenever they affect interpretation or handoff:

| Dimension | What it records | Examples |
|---|---|---|
| Request outcome | What happened to the transport, HTTP exchange, JSON parsing, and business envelope | success, transport timeout, HTTP error, invalid JSON, non-zero business code |
| Payload or field state | What the successful response returned for the requested data or field | returned value, returned empty, returned null, not returned, source not specified |
| Coverage | How much of the eligible result set or requested detail was inspected | complete, page-bounded, detail-bounded, partial API failure, unknown |
| Workflow state | Whether the research workflow can continue or reached its intended endpoint | completed, awaiting user decision, handoff incomplete, stopped at a failed stage |

No dimension implies another. HTTP 2xx with `code == 0` does not imply a non-empty payload, complete coverage, a completed workflow, or biological support. Likewise, a page or detail bound is not a request failure, and a correctly handled endpoint timeout is not by itself a workflow-fidelity failure.

These dimensions describe evidence and context; they are not one global terminal enum. An active skill may expose its own structured representation in audit or machine output, but this contract does not promise one stable cross-skill machine schema.

## Request safety

- Use only endpoints and fields documented in [`api-reference.md`](api-reference.md).
- For every Orbit HTTP attempt, use the platform-appropriate wrapper in [`scripts/README.md`](../scripts/README.md): `<plugin-root>/scripts/orbit-request.sh ...` on Linux/macOS, or `<plugin-root>/scripts/orbit-request.ps1 ...` on Windows PowerShell. Resolve `<plugin-root>` from the installed plugin resources, not the user's current working directory. Do not generate ad-hoc Python, `urllib`, `curl`, or other transport scripts.
- In an Agent environment with a network-restricted sandbox, request minimal external-execution authorization before the first Orbit wrapper attempt. The authorization may run only the installed plugin's wrapper and only documented `https://db-orbit.com/api/...` requests; it does not authorize browsers, ad-hoc transport commands, arbitrary domains, local-configuration reads, or unrelated shell actions. In an unrestricted local environment, invoke the wrapper normally without an external-execution request.
- If sandbox restriction is unknown or external execution is initially unavailable, preserve the wrapper stderr and transport result. For only GET requests or other calls already permitted to retry by this contract, after multiple TLS/Schannel transport failures, browser access to `https://db-orbit.com` supports recording a possible sandbox transport restriction and requesting that minimal external-execution authorization. Do not change TLS, proxy, certificate, curl, or wrapper settings. If authorization is unavailable or denied, report transport blockage rather than an API business failure.
- A wrapper exit of `0` means only that an HTTP 2xx exchange completed. Inspect its stderr status line and stdout JSON. For normal enveloped endpoints, require `code == 0`; for quick biomarker endpoints, apply the documented envelope-or-bare-payload rule in [`api-reference.md`](api-reference.md).
- A wrapper call is one attempt. For read-only GET requests and explicitly safe POST searches, retry only HTTP 5xx, transport/timeout errors, or invalid JSON: wait 10 seconds, make at most 5 attempts. Do not retry HTTP 4xx, non-zero business codes, or rate limits.
- Do not submit an analysis job, upload a file, or export a file unless the user explicitly asks and supplies the required data.
- If a side-effecting submission response is lost, record `SUBMISSION_OUTCOME_UNKNOWN`. Do not replay it, and do not poll without the exact returned `jobId`. Moving a request to external execution does not make an ambiguous side-effecting submission replay-safe; obtain renewed explicit user authorization before a new submission.
- Do not retrieve publication full text from DOI values. Do not expose, request, log, or echo API keys unnecessarily.

## Cross-skill research context and provenance

Preserve only user-provided or API-returned values: research question, user language, explicit constraints, endpoint, exact request, pagination, status, selected/excluded `sampleId` values and reasons, references, sample-linked details, and missing/error states.

For paginated discovery or bounded details, also preserve requested and returned pagination, total, service order, retained and selected IDs, displayed/inspected counts, remaining or uninspected counts, failed IDs or stages, and whether coverage is complete, bounded, partially failed, or unknown.

For omics, retain the API-returned `sampleId`, modality, control-group `dataSet`, selected group, analysis scope, and exact result-list request. `dataSet` from control-group context and `data` in result-list search are distinct native fields; use the mapping defined in [`api-reference.md`](api-reference.md), and preserve both in provenance.

A receiving skill must validate its own required context. It must not upgrade assumptions into API evidence, detach details from their originating sample, reintroduce excluded candidates, or infer identifiers from labels, titles, prefixes, or DOI values.

Coverage is inherited with the research context. A receiving skill must retain the upstream requested/returned pagination, totals, selection boundary, failed items or stages, and whether coverage was observed directly or inherited. It may add its own detail or downstream coverage, but it must not reset upstream partial or unknown coverage to complete. A successful downstream request does not repair incomplete upstream discovery.

## Evidence boundaries

Use these edge classes for multi-endpoint claims:

| Class | Meaning |
|---|---|
| `DIRECT_EDGE` | An API response explicitly states the relationship. |
| `SAME_SAMPLE_CO_OCCURRENCE` | Entities are independently returned for one sample without an explicit relationship. |
| `FREE_TEXT_LINK` | A relationship appears only in API-returned text. |
| `UNRESOLVED_EDGE` | The requested relationship cannot be established from returned fields. |

Do not present co-occurrence, text association, label similarity, or cross-sample joining as causality, regulation, mediation, clinical validation, druggability, or reproducibility. A predicted biomarker is not clinically validated. A pathway name or size is not a member-gene list.

For a pseudobulk result whose request does not define the required analysis scope specified in [`api-reference.md`](api-reference.md), use `UNRESOLVED_EDGE: INCOMPLETE_ANALYSIS_SCOPE`; do not infer omitted scope dimensions from response rows.

## Contract maintenance

When documentation and implementation conflict, first use a minimally scoped, read-only HTTP request where safe, then trace route → DTO → handler → service → repository/query builder. Function-body behavior overrides names, comments, and historical documentation. Record unresolved discrepancies as `CONDITIONAL` or `IMPLEMENTATION_LIMITATION` in [`api-reference.md`](api-reference.md). Never validate a contract by submitting work, uploading files, or replaying non-idempotent requests.

After editing shared contract or API reference content, keep all references within this plugin package consistent.
