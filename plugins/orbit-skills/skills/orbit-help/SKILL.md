---
name: orbit-help
description: Explain the installed Orbit Skills version and route a user's Organoid Database research request to the appropriate Orbit skill. Use this skill whenever the user asks what Orbit Skills can do, which skill to use, how the skills relate, or which version is installed. Do not use it to perform research retrieval or API analysis.
---

# Orbit Help

Read `<plugin-root>/.claude-plugin/plugin.json` for the installed plugin version and `<plugin-root>/references/researcher-response-contract.md` for language and response behavior. Do not call the Orbit API, use an endpoint, or perform research retrieval.

## Output

When the user asks for general help, begin with the exact version from the plugin manifest:

```text
Orbit Skills version: <version>
```

Then give a concise routing guide in the user's explicitly requested output language, or otherwise in the user's task language:

| Skill | Use it when the user wants |
|---|---|
| `orbit-search` | Cross-sample discovery of protocols, biomarkers, pathways, trends, or genes |
| `orbit-browse` | One sample's profile, culture plan, phenotype, applications, or reference annotation |
| `orbit-chat` | Multi-sample retrieval, comparison, and sample-level evidence synthesis |
| `orbit-reason` | Cross-layer evidence chains involving pathways, genes, biomarkers, factors, phenotypes, or annotations |
| `orbit-protocol` | A database-backed organoid culture-protocol candidate synthesized from compatible records |
| `orbit-design` | Experimental design with groups, controls, replicates, batches, QC, readouts, or omics planning |
| `orbit-omics` | Sample- or dataset-specific RNA-seq, scRNA-seq, GSEA, GSVA, trajectory, or interaction results |
| `orbit-analysis` | Quick biomarker condition lookup, gene-list or expression-matrix jobs, results by `jobId`, and bounded gene-annotation plus KOBAS reports |
| `orbit-help` | This version and skill-routing guide |

Explain handoffs only when useful: search/browse/chat provide evidence context; protocol narrows compatible culture routes; design turns a selected route into an experimental plan; omics supplies analysis-scoped results; reason evaluates cross-layer evidence chains; analysis manages quick biomarker prioritization and adds bounded general gene and KOBAS context to completed rankings.

If the user asks only for the version, return the version line and no full routing guide. Do not expose endpoint paths, HTTP details, JSON paths, internal enums, or wrapper logs. Do not claim that this skill validates protocols, interprets biological results, or replaces the other skills.
