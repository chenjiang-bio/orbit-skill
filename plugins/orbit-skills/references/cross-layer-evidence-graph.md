# Cross-Layer Evidence Graph

Use this reference when a research question links two or more entity layers, such as condition → pathway → gene → annotation or factor → pathway → phenotype. It defines an auditable graph, not an inference license.

## 1. Parse the target chain

Write the requested nodes and required edges before retrieval. For each edge, state what API evidence would be sufficient. A missing required edge remains visible in the final answer.

Common nodes include sample, disease/model, factor, perturbation, phenotype, biomarker, gene, pathway, detection method, dataset/comparison, drug, and druggability annotation.

## 2. Normalize without guessing

Use stable API-returned identifiers: `sampleId`, Entrez ID, pathway/term ID plus database when returned, and API-returned dataset/group. Keep synonyms and labels, but never merge nodes by label alone. A GSE-like search `data` value is not automatically a KM `sampleId` or omics `dataSet`; only a returned `/api/browse/sample/reference/gds` record can map its own `gseId` to its native `sampleId` string and platform, and it still does not supply a control-group `dataSet` or group.

## 3. Classify every edge

Use the shared contract's four classes:

- `DIRECT_EDGE`: the response explicitly represents the stated relation.
- `SAME_SAMPLE_CO_OCCURRENCE`: both nodes belong to one API-returned sample but have no explicit relation.
- `FREE_TEXT_LINK`: the relation exists only in returned text; keep a minimal quote and field path.
- `UNRESOLVED_EDGE`: no documented or returned relation can support the requested edge.

One JSON object or one sample is not enough for a direct edge. A direct association is not automatically causal.

## 4. Preserve provenance

Each node/edge must retain endpoint, query/filter, `sampleId`, source field path, dataset/group/comparison, reference, native value, and status. Never move a field or reference between samples. For a core-enrichment record, retain `pathwayId`, `data`, `group`, the raw `enrichGene` string, pagination, and its possibly empty `sampleId`; do not upgrade it to universal pathway membership or a sample-specific relation when `sampleId` is empty. For a parsed drug target, retain the raw `targets` string and the target object's source, evidence, identity fields, and nulls.

## 5. Recurrent pathway rules

Count independent support by distinct `sampleId` and dataset-like `data`; report both. Deduplicate repeated rows from the same sample/data/comparison. Preserve platform, analysis type, group, direction, adjusted significance, and peer-review filter when returned.

Do not pool GSEA with GSVA effects, combine p-values, compare effect magnitudes across datasets, or call a pathway recurrently active when returned directions conflict. When pathway IDs/databases are missing, describe a label-level match and warn that identity is unresolved.

## 6. Reference-data relation rules

- A GDS response supplies a `DIRECT_EDGE` only from its own returned `gseId` to its native sample-ID string/platform record. It cannot replace the sample → control-group → `dataSet` → group workflow.
- A GSEA enriched-gene response supplies a `DIRECT_EDGE` from its returned `pathwayId` to the raw core-enrichment string in the same row. Normalize individual genes only through a documented gene-resolution endpoint; the edge remains scoped to its returned `data` and `group`, and is not canonical pathway membership or causal evidence.
- A KOBAS row supplies a `DIRECT_EDGE` from its returned Entrez `query` to that row's external annotation (`item`, `id`, `description`, `database`). It is not evidence that the pathway is active or enriched in an Orbit sample.
- A drug target object supplies a `DIRECT_EDGE` from its returned drug record to the target identity explicitly present in that object. It does not by itself establish druggability, clinical actionability, efficacy, or sample relevance.
- Material `application` and `pathway` fields are descriptive text. Keep them as `FREE_TEXT_LINK` unless a different API response explicitly provides a structured relation and stable target identifier.

## 7. Free-text relation rules

Match action terms in context, including negation. `no withdrawal`, `not inhibited`, or hypothetical statements must not become positive links. Distinguish addition, withdrawal, washout, inhibition, knockout, and knockdown. Keep the original wording and do not rewrite withdrawal as inhibition.

## 8. Chain gate

For each requested edge report:

- resolved class and supporting evidence;
- whether causal wording is allowed by the returned relation semantics;
- unresolved reason and what endpoint/field would be required.

Stop only the unsupported chain segment. Return earlier supported nodes and edges. Never fill a missing edge from model knowledge, publication full text, or an undocumented endpoint.

## 9. Output skeleton

```markdown
# Cross-layer evidence synthesis

## Target chain and scope
## Query provenance and normalization
## Nodes
## Direct API edges
## Same-sample co-occurrences
## Free-text links
## Unresolved required edges
## Cross-study recurrence summary
## Chain coverage matrix
## Claims that cannot be made
## API/data gaps and next steps
```

Use the user's language for visible output. Keep native keys, IDs, evidence classes, and minimal source excerpts for traceability.
