# Shared Sample Discovery and Detail Handoff

Use the bounded discovery/detail rules from `orbit-search` when a search request requires sample-level evidence, and use the full sample-comparison workflow from `orbit-chat`; `orbit-protocol` consumes provenance-complete candidates for protocol-family convergence. This is a behavior reference, not a runtime skill-to-skill call or an API object. `orbit-search` stops at traceable per-sample evidence and handoff; it does not perform `orbit-chat`'s open-ended comparative synthesis.

## Discovery record

For every discovery request preserve:

- exact query, documented filters, endpoint/method, and requested pagination
- returned pagination, total, service order, and API status
- each returned `sampleId`, `organism`, native matching fields, and `semanticScore` when present
- local exclusions, duplicate IDs, and reasons

Semantic search is sample-discovery evidence, not protocol evidence. A missing or zero score is not a reliable ranking signal.

## Constraint filtering

Apply only explicit user constraints. Require exact case-insensitive equality for organism. Treat missing fields as unresolved rather than matches or conflicts. Deduplicate only identical API-returned `sampleId` values; never derive IDs from names, prefixes, titles, or DOI values.

## Detail retrieval

Use only exact `sampleId` values explicitly supplied by the user or returned by a documented API request. A discovery workflow may use only IDs returned by that discovery or inherited through provenance-valid context. Never derive IDs from names, titles, prefixes, DOI values, or GSE-like labels. Keep every response, error, missing state, and reference associated with its originating sample. Apply the read-only retry policy in `../organoid-api-contract.md`; one sample's failure must not contaminate another.

When sample-level details follow discovery, apply one shared sample-detail retrieval budget:

1. If the user specifies a maximum number of retained samples to inspect, use that sample limit. It does not reduce the detail families explicitly requested for each selected sample.
2. Otherwise retrieve only the requested detail families for at most the first three retained samples in service order.
3. Treat the default of three as a request budget, never as evidence ranking, protocol quality, or biological importance.
4. Preserve retained, selected/inspected, uninspected, and failed sample IDs and counts. Keep discovery coverage separate from detail coverage.
5. If the user explicitly requests all results, complete the required pagination and details when feasible. If the result set or request budget makes that impractical, ask for a narrower scope or report the bounded coverage transparently; never imply exhaustiveness.

Preserve native culture-plan keys: `sample_id`, `composition`, `time_anchors`, `time_axis`, `material_source`, and `protocol`.

## Handoff

Return the shared research context defined in `../organoid-api-contract.md`, including discovery and detail coverage. A receiving workflow must reuse successful, complete context rather than repeating discovery, unless constraints changed, context is incomplete, or provenance cannot be verified. Record the reason for any repeat request. Inherited partial or unknown discovery coverage remains partial or unknown even when downstream detail requests succeed.
