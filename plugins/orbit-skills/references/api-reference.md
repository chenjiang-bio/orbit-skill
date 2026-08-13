# Organoid Database API Reference

Base URL: `https://db-orbit.com`

Successful JSON endpoints use the envelope:

```json
{"code": 0, "message": "", "data": {}}
```

`code == 0` is business success. Error handlers can return non-2xx HTTP statuses; callers must check both HTTP status and the envelope when present. File-download endpoints return an attachment stream instead of this envelope.

## Invocation wrapper

For every Orbit HTTP attempt, use the OS-appropriate wrapper documented in [`scripts/README.md`](../scripts/README.md): `<plugin-root>/scripts/orbit-request.sh` on Linux/macOS or `<plugin-root>/scripts/orbit-request.ps1` on Windows PowerShell. The wrapper accepts only relative `/api/...` paths, writes native response bytes to stdout, and emits HTTP/transport metadata to stderr. It performs one transport attempt; inspect JSON `code` and apply the retry policy in [`organoid-api-contract.md`](organoid-api-contract.md).

## Shared request and response types

### Pagination

| Field | Location | Type | Required | Notes |
|---|---|---:|---|---|
| `page` | query or JSON | integer | no | Default is service-defined; callers should send it. |
| `pageSize` | query or JSON | integer | no | Callers should send it. |
| `sortField` | query or JSON | string | no | Supported fields are endpoint-specific. |
| `sortOrder` | query or JSON | string | no | `asc` or `desc`. |

`PageList<T>` data shape:

```json
{"page": 1, "pageSize": 10, "total": 0, "list": []}
```

### GeneralSearchReq

Used by documented `POST .../search` endpoints.

```json
{
  "page": 1,
  "pageSize": 10,
  "sortField": "",
  "sortOrder": "asc",
  "keywords": "",
  "search": [{"option": "equal", "key": "field", "value": "value"}]
}
```

`search[]` item fields `option`, `key`, and `value` are required when the item is supplied. Ordinary-field operators implemented by the generic builder are `equal`, `notEqual`, `like`, `in`, `notEmpty`, `gt`, `gte`, `lt`, `lte`, and `fuzzyMatch`. `include` and `exist` are not implemented for ordinary fields.

### Common request types

| Type | Fields |
|---|---|
| `SampleIdReq` | query `sampleId:string` required; several endpoints add `max=50`. |
| `OmicsCommonGraphDataReq` | query `group:string` required, `dataSet:string` required; `sampleId`, `platform`, `organism` optional. |
| `OmicsCategoryGraphDataReq` | `OmicsCommonGraphDataReq` plus `category:string`; histogram category is `GO`, `KEGG`, or `ssGSEA`. |
| `ScRnaSeqPseudobulkGraphDataReq` | query `group:string`, `dataSet:string`, `resolution:number`, `type:string` required; `sampleId`, `platform`, `organism`, `cellType` optional. |
| `ScRnaSeqPseudobulkCategoryGraphDataReq` | pseudobulk graph fields plus `category:string` when the endpoint requires it. |

## Common

### GET /api/common/enum/group

- Request: query `enum:string[]` required.
- Response `data`: `code -> group -> []{label:string,value:string}`.
- Evidence: `app/common/routes.go:16-40`; `app/common/dto.go:4-83`; `app/common/handler.go:35-234`; `app/common/service.go:105-121`.

### GET /api/common/enum/index

- Request: query `enum:string[]` required.
- Response `data`: `code -> []{label,value}`.
- Evidence: same as above.

### GET /api/common/gene/suggest

- Request: query `keyword:string` required, `organism:string` required with exact supported values `Homo sapiens|Mus musculus`, `limit:integer` optional. Abbreviations such as `hsa|mmu` are not accepted by this endpoint.
- Response `data`: `{list:[{geneName,entrezId,symbol}]}`. A supported organism with no matching records currently returns HTTP 200, numeric `code == 0`, and `data.list: []`; treat this as an unrecorded/empty identity result, not an organism error or biological negative.
- Missing `organism` currently returns HTTP 200 with non-zero business code `400100`; an unsupported or non-matching value returns HTTP 400 with code `400100` and a message offering `Homo sapiens` and `Mus musculus`. Both are request errors despite their different HTTP status/envelope casing.
- Evidence: `app/common/dto.go:20-31`; `app/common/handler.go:70-91`.

### POST /api/common/file/upload

- Request: `multipart/form-data`; `file` required. The handler does not read `module`.
- Response `data`: uploaded path string.
- Side effect: upload.
- Evidence: `app/common/handler.go:93-132`; `app/common/service.go:123-155`.

### GET /api/common/file/download

- Request: query `path:string` required.
- Response: file attachment stream.
- Evidence: `app/common/dto.go:48-52`; `app/common/handler.go:134-158`.

### POST /api/common/file/export

- Request: JSON `exportType:string` required, `businessType:string` required, plus pagination and `GeneralSearchReq` fields.
- Response `data`: `{filePath:string}`.
- Side effect: export generation.
- Evidence: `app/common/dto.go:54-65`; `app/common/handler.go:160-190`.

### GET /api/common/file/omics/download

- Request: query `path:string` required.
- Response: file attachment stream.
- Evidence: `app/common/dto.go:67-71`; `app/common/handler.go:192-215`.

### GET /api/download/datasets

- Request: none.
- Response `data`: `{list:[{category,datasets:[{name,releasedOn,version,description,size,format,downloadUrl}]}]}`.
- Evidence: `app/common/routes.go:39`; `app/common/dto.go:73-83`; `app/common/handler.go:217-234`.

## Home

### GET /api/home/summary/organic-trends

- Request: none.
- Response `data`: `{list:[{organoid,trends:[{year,number}]}]}`.
- Evidence: `app/home/routes.go:18-23`; `app/home/dto.go:4-43`; `app/home/handler.go:29-59`.

### GET /api/home/clickable-icons

- Request: none.
- Response `data`: grouped icon arrays: `overview`, `immune`, `hostMicrobe`, `source`, `organoid`.
- Evidence: same as above.

### GET /api/home/search/suggest

- Request: query `q:string` optional, `limit:integer` optional, `category:string` optional.
- Response `data`: suggest-item list; item key is `text`.
- Evidence: `app/home/routes.go:22`; `app/home/dto.go:27-43`; `app/home/handler.go:51-59`.

## Protocol, biomarker, and pathway search

### GET /api/search/protocol/organoid

- Request query: `organ:string` required; send the case-insensitive value from the supported-organ list below, not a Python enum member name. Examples: `Brain`, `Lung`, `Mammary Gland`; do not send underscore enum names such as `Mammary_Gland`. `page`, `pageSize`, `keywords`, `organism`, `source`, `coCulture`, `cultureMethod`, `complexity`, `sortField`, `sortOrder` are optional.
- User-language-to-organ mapping: map cerebral organoid/cerebral/brain organoid requests to `organ=Brain`; preserve a more specific user request only when it maps exactly to a value in the supported-organ list. If no unambiguous value applies, ask the user to choose rather than sending free text as `organ`. This mapping can be broader than the full request and does not itself preserve qualifiers such as vascularization, cell composition, disease state, maturation, treatment, or timing. When such a qualifier is not represented by a documented protocol field sent in the request, `orbit-search` may pair this protocol request with a separate General semantic discovery request that keeps the original wording; semantic discoveries are not protocol-search evidence.
- Supported `organ` values: `Mouth`, `Pharynx`, `Esophagus`, `Stomach`, `Mesentery`, `Small Intestine`, `Large Intestine`, `Intestine`, `Liver`, `Biliary Tract`, `Gall Bladder`, `Pancreas`, `Anus`, `Colon`, `Tooth`, `Rectum`, `Caecum`, `Ampulla`, `Vermiform Appendix`, `Peritoneum`, `Respiratory Airway`, `Nose`, `Larynx`, `Trachea`, `Bronchi`, `Lung`, `Pleura`, `Heart`, `Artery`, `Vein`, `Capillary`, `Blood Vessel`, `Brain`, `Brainstem`, `Spinal Cord`, `Nerve`, `Hypothalamus`, `Cerebellum`, `Pineal Gland`, `Pituitary Gland`, `Hippocampus`, `Thyroid`, `Adrenal Gland`, `Parathyroid Gland`, `Thymus Gland`, `Kidney`, `Ureter`, `Bladder`, `Urethra`, `Testis`, `Ovary`, `Uterus`, `Penis`, `Vagina`, `Prostate`, `Seminal Vesicle`, `Fallopian Tube`, `Genital`, `Vulva`, `Clitoris`, `Cervix`, `Skeletal Muscle`, `Ligament`, `Tendon`, `Diaphragm`, `Muscle`, `Bone`, `Bone Marrow`, `Joint`, `Interstitium`, `Skin`, `Hair Follicle`, `Nails`, `Subcutaneous Tissue`, `Adipose Tissue`, `Connective Tissue`, `Spleen`, `Lymph Node`, `Tonsil`, `Lymphatic Vessel`, `Eye`, `Ear`, `Tongue`, `Salivary Gland`, `Mammary Gland`, `Placenta`, `Others`.
- Response `data`: `PageList<OrganoidListRes>`.
- Evidence: backend organ-value contract supplied 2026-07-29; endpoint example `GET /api/search/protocol/organoid?page=1&pageSize=10&organ=Brain`.

### GET /api/search/protocol/coCulture

- Request: same as organoid protocol; `organoid` remains required.
- Response `data`: `PageList<CoCultureListRes>`.
- Evidence: `app/search/dto.go:4-39`; `app/search/handler.go:64-92`.

### GET /api/search/protocol/trends

- Request query: `category:string` required; enum `organoid`, `culture-method`, `co-culture`, `source`.
- Response `data`: `{list:[{year,trends:[{termName,number}]}]}`.
- Evidence: `app/search/dto.go:41-49`; `app/search/handler.go:94-118`.

### GET /api/search/protocol/filter

- Request query: `organism`, `source`, `organoid`, `coCulture`, `cultureMethod` optional.
- Response `data`: map of field names to `[{label,value,children?}]`.
- Evidence: `app/search/dto.go:51-60`; `app/search/handler.go:120-143`.

### GET /api/search/biomarker/identified

- Request query: `organism:string`, `source:string`, `organoid:string` required; `page`, `pageSize`, `keywords`, `biomarkerType`, `biomarkerApplication`, `detectionMethod`, `coCulture`, `diseaseModeling`, `drugTest` optional.
- Response `data`: `PageList<IdentifyBiomarkerListRes>`.
- Evidence: `app/search/dto.go:62-88`; `app/search/handler.go:145-170`.

### GET /api/search/biomarker/potential-old — retired

- This legacy route is registered but retired for public Skill use. Do not call it.
- Historical request shape: `organism:string`, `tissue:string` required; `researchPurpose`, `platform`, and pagination optional.
- Historical response shape: legacy potential-biomarker result.
- Evidence: `app/search/routes.go:29`; `app/search/dto.go:29-41`; `app/search/handler.go:95-114`.

### GET /api/search/biomarker/trends

- Request query: `category:string` required; enum `organoid`, `potential`, `co-culture`, `disease`, `application`.
- Response `data`: `{list:[{year,trends:[{termName,number}]}]}`.
- Evidence: `app/search/dto.go:90-98`; `app/search/handler.go:199-222`.

### GET /api/search/biomarker/culture-plan

- Request query: `sampleId:string` required.
- Response `data`: `{sampleId,timePoints:[{day,items:[{name,type}]}]}`.
- Evidence: `app/search/dto.go:100-113`; `app/search/handler.go:224-248`.

### GET /api/search/biomarker/potential

- Request query: `organism:string`, `tissue:string` required; `researchPurpose`, `platform`, pagination optional.
- Response `data`: map with deployment-native keys `bulkRNA_seq` and `scRNA_seq`; each value is a biomarker result object.
- Evidence: `app/search/dto.go:115-134`; `app/search/handler.go:250-273`; `app/search/service.go:824-945`.

### GET /api/search/biomarker/gene

- Request query: `organism:string`, `geneSymbol:string`, `entrezId:integer` required; `tissue`, `researchPurpose`, `platform`, pagination optional.
- Response `data`: map with `bulkRNA_seq` and `scRNA_seq` result objects.
- Evidence: `app/search/dto.go:136-153`; `app/search/handler.go:275-298`.

### GET /api/search/biomarker/filter

- Request query: optional `organism`, `source`, `organoid`, `coCulture`, `diseaseModeling`, `biomarkerType`, `biomarkerApplication`, `detectionMethod`, `drugTest`.
- Response `data`: filter option map.
- Evidence: `app/search/dto.go:240-251`; `app/search/handler.go:300-316`.

### GET /api/search/pathways

- Request query: pagination plus optional `organism`, `biologicalModel`, `tissue`, `conditionCategory`, `condition`, `additionalConditionFactor`, `additionalCondition`, `comparisonControl`, `comparisonCondition`, `cellType`, `day`, `platform`, `onlyPeerReviewed`.
- Response `data`: `{gsea:{go:PageList,kegg:PageList},gsva:PageList}`.
- Limitation: `platform` is accepted by the DTO but not added by the current service query.
- Evidence: `app/search/dto.go:155-209`; `app/search/handler.go:318-338`; `app/search/service.go:1000-1015`.

### POST /api/search/pathways/filter

- Request JSON: `targetField:string[]` required; optional `organism`, `dataType`, `category`, `condition`, `factor`, `additionalCondition`, `model`, `organ`, `organSystem`, `cellType`, `day`, `source`, `comparisonControl`, `comparisonCondition`.
- Response `data`: `targetField -> []FieldItem`.
- Evidence: `app/search/dto.go:211-262`; `app/search/handler.go:340-347`.

## Sample protocol detail

### GET /api/sample/protocol/detail

- Request query: `sampleId:string` required, maximum length 50.
- Response `data`: `{stage:[{stageName,start,end,description}],medium:[{name,start,end}],material:[{name,description}],keyNode:[{name,day}]}`.
- Evidence: `app/sample/routes.go:16-21`; `app/sample/dto.go:2-35`; `app/sample/handler.go:25-44`.

## Browse catalog and sample metadata

### POST /api/browse/immune-oncology/search

- Request: `GeneralSearchReq` JSON.
- Response `data`: `PageList<ImmuneOncologyListResp>`.
- Evidence: `app/browse/routes.go:20`; `app/browse/dto.go:8-23`; `app/browse/handler.go:203-218`.

### POST /api/browse/host-microbe/search

- Request: `GeneralSearchReq` JSON.
- Response `data`: `PageList<HostMicrobeResp>`.
- Evidence: `app/browse/routes.go:22`; `app/browse/dto.go:8-23`; `app/browse/handler.go:220-233`.

### POST /api/browse/immune-oncology/semantic/search

- Request JSON: `SemanticSearchReq`: pagination, `query:string`, plus optional `CommonSearch` fields.
- Response `data`: `PageList`; list items include native record fields and `semanticScore` when mapped.
- Evidence: `app/browse/routes.go:21`; `app/browse/dto.go:8-23`; `app/browse/semantic_handler.go:6-55`; `app/browse/semantic_service.go:680-1297`.

### POST /api/browse/host-microbe/semantic/search

- Request JSON: `SemanticSearchReq`: pagination, `query:string`, plus optional `CommonSearch` fields.
- Response `data`: `PageList`; list items include native record fields and `semanticScore` when mapped.
- Evidence: `app/browse/routes.go:23`; `app/browse/dto.go:8-23`; `app/browse/semantic_handler.go:6-55`; `app/browse/semantic_service.go:680-1297`.

### POST /api/browse/general/semantic/search

- Request JSON: `SemanticSearchReq`: pagination, `query:string`, plus optional `CommonSearch` fields.
- Response `data`: `PageList`; list items include native record fields and `semanticScore` when mapped.
- Evidence: `app/browse/routes.go:30`; `app/browse/dto.go:8-23`; `app/browse/semantic_handler.go:6-55`; `app/browse/semantic_service.go:680-1297`.

### GET /api/browse/general/list

- Request query: pagination, `keywords`, `organoid`, `origin`, `species`, `cultureTechnique`, `biomarker`, `applications`, `test`, `cultureConditions`, `endpoints`, `characteristics`, `functions`, `diseaseModeling` optional.
- Response `data`: `PageList<GeneralListRes>`.
- Evidence: `app/browse/routes.go:26`; `app/browse/dto.go:25-45`; `app/browse/handler.go:28-52`.

### POST /api/browse/general/search

- Request: `GeneralSearchReq` JSON.
- Response `data`: `PageList<GeneralListRes>`.
- Evidence: `app/browse/routes.go:28`; `app/browse/handler.go:54-75`.

### GET /api/browse/sample/culture-plan

- Request query: `sampleId:string` required.
- Response `data`: `ProtocolCulturePlanResp`.
- Evidence: `app/browse/routes.go:35`; `app/browse/dto.go:349-552`; `app/browse/handler.go:77-95`.

### GET /api/browse/sample/co-culture-plan

- Request query: `sampleId:string` required.
- Response `data`: `ProtocolCoCulturePlanResp`.
- Evidence: `app/browse/routes.go:36`; `app/browse/dto.go:349-552`; `app/browse/handler.go:97-114`.

### GET /api/browse/sample/phenotype

- Request query: `sampleId:string` required.
- Response `data`: `{list:[SamplePhenotypeResp]}`.
- Evidence: `app/browse/routes.go:40`; `app/browse/dto.go:349-552`; `app/browse/handler.go:135-150`.

### GET /api/browse/sample/application

- Request query: `sampleId:string` required.
- Response `data`: `{list:[SampleApplicationResp]}`.
- Evidence: `app/browse/routes.go:41`; `app/browse/dto.go:349-552`; `app/browse/handler.go:152-166`.

### GET /api/browse/sample/general-basic-info

- Request query: `sampleId:string` required.
- Response `data`: General sample basic-information object.
- Evidence: `app/browse/routes.go:42`; `app/browse/dto.go:349-552`; `app/browse/handler.go:168-185`.

### GET /api/browse/sample/immune-oncology-basic-info

- Request query: `sampleId:string` required.
- Response `data`: immune-oncology sample basic-information object.
- Evidence: `app/browse/routes.go:43`; `app/browse/dto.go:349-552`; `app/browse/handler.go:235-249`.

### GET /api/browse/sample/host-microbe-basic-info

- Request query: `sampleId:string` required.
- Response `data`: host-microbe sample basic-information object.
- Evidence: `app/browse/routes.go:44`; `app/browse/dto.go:349-552`; `app/browse/handler.go:251-265`.

### GET /api/browse/sample/filter

- Request query: `menu:string` required; enum `general`, `immune-oncology`, `host-microbe`.
- Response `data`: `SampleFilterResp`.
- Evidence: `app/browse/routes.go:39`; `app/browse/dto.go:47-53`; `app/browse/handler.go:116-133`.

### GET /api/browse/sample/gene-annotation

- Request query: `geneName:string` required; accepts a gene Symbol or Entrez ID. `organism:string` optional (`human` default; `mouse` supported); `sampleId:string` is accepted as an optional compatibility parameter by the request DTO but is not used by the current service query.
- Resolution behavior: numeric `geneName` is parsed as Entrez ID; otherwise it is resolved by Symbol within the selected organism. Unknown genes return HTTP 404 with business code `240814002`; unsupported/missing organism falls back to human selection in the service.
- Response `data`: `GeneAnnotation`, including `entrezId`, `symbol`, `geneName`, `synonyms`, `location`, `protein`, summaries, `externalLinks`, `function`, `sequenceFeature`, `sgRNA`, `subcellularLocation`, `ptms`, `proteinInteraction`, `proteinSite`, `proteinDisease`, `sequence`, `referenceSample`, and `drugList`. Nested optional objects may be null and arrays may be empty.
- Read-only verification: `A1BG`/human → `code:0`, `entrezId:"1"`; `5156`/human → `code:0`, `symbol:"PDGFRA"`; `Trp53`/mouse → `code:0`, `entrezId:"22059"`; `22059`/mouse → `code:0`, `symbol:"Trp53"`; wrong-species `5156`/mouse → HTTP 404, `code:240814002`; unknown human gene → HTTP 404, `code:240814002`.
- Evidence: `app/browse/routes.go:92`; `app/browse/dto.go:615-621`; `app/browse/handler.go:380-394`; `app/browse/service.go:2045-2047`; `domain/sample/service/gene_annotation.go:22-48,312-343,516-530`.

## Reference data

All endpoints in this section are read-only `GET` requests. Send pagination explicitly when bounded output is needed. A successful empty lookup can return `{"page":0,"pageSize":0,"total":0,"list":[]}` rather than echoing the requested pagination.

### GET /api/browse/sample/reference/gds

- Request query: `gseId:string` required.
- Response `data`: array of `{gseId:string,sampleId:string,platform:string}`. One returned GSE can have multiple platform records; observed `sampleId` is a semicolon-delimited native string and must be preserved before any individual-ID handoff.
- Evidence boundary: a returned row explicitly maps its `gseId` to its native sample-ID string and platform. It does not make the GSE value an omics control-group `dataSet`, group, or comparison.
- Read-only verification: `gseId=GSE106245` → HTTP 200, `code:0`, two platform rows (`RNA-seq`, `scRNA-seq`) with the same semicolon-delimited sample-ID value. Omitting `gseId` → HTTP 400, `code:240710001`.

### GET /api/browse/sample/reference/gsea-enriched-genes

- Request query: `pathwayId:string` required; `data:string`, `group:string`, `page:integer`, `pageSize:integer` optional.
- Response `data`: `PageList<{sampleId:string,data:string,group:string,pathwayId:string,enrichGene:string}>`. `enrichGene` is an observed slash-delimited native string; `sampleId` may be an empty string.
- Evidence boundary: a returned row directly links its `pathwayId` to its core-enrichment string only within that row's `data`, `group`, and returned sample scope. It is not a universal canonical pathway-membership list, and an empty `sampleId` cannot support a sample-specific claim.
- Read-only verification: `pathwayId=GO:0002376&page=1&pageSize=3` → HTTP 200, `code:0`, `total:1323`; adding `data=GSE252570-2&group=inner_ear_org_d11_vs_inner_ear_org_d8` → `total:3`. Omitting `pathwayId` → HTTP 400, `code:240710001`.

### GET /api/browse/sample/reference/kobas-human

- Request query: `query:integer` required; `page:integer`, `pageSize:integer` optional.
- Response `data`: `PageList<{query:integer,item:string,description:string,id:string,database:string}>`.
- Evidence boundary: each record is a route-specific external reference annotation for the queried Entrez ID, not proof of activity, enrichment, expression, or sample-specific biology.
- Read-only verification: `query=5156&page=1&pageSize=3` → HTTP 200, `code:0`, `total:162`. Omitting `query` → HTTP 400, `code:240710001`.

### GET /api/browse/sample/reference/kobas-mouse

- Request query and response shape: same as `kobas-human`; preserve the mouse-route provenance.
- Read-only verification: `query=22059&page=1&pageSize=3` → HTTP 200, `code:0`, `total:323`. Omitting `query` → HTTP 400, `code:240710001`.

### GET /api/browse/sample/reference/drug

- Request query: `keyword:string` required; `page:integer`, `pageSize:integer` optional.
- Response `data`: `PageList<{drugbankId:string,preferredName:string,maxPhase:string,firstApproval:integer,nTargets:integer,description:string,drugbankUrl:string,targets:string}>`. `targets` is a JSON-encoded string. Observed target objects can include `name`, `symbol`, `source`, `evidence`, `organism`, `mechanism`, `ensembl_id`, `action_type`, `uniprot_ids`, and `chembl_target_id`; fields may be null or absent.
- Evidence boundary: a parsed target object supports only the returned drug-to-target annotation. `maxPhase`, approval history, and a target annotation do not establish efficacy, suitability for an Orbit sample, clinical actionability, or gene tractability.
- Read-only verification: `keyword=DB00001&page=1&pageSize=2` and `keyword=Aspirin&page=1&pageSize=1` → HTTP 200, `code:0`; unmatched keyword → successful empty `PageList`.

### GET /api/browse/sample/reference/material

- Request query: `keyword:string` required; `page:integer`, `pageSize:integer` optional.
- Response `data`: `PageList<{materialType:string,standardName:string,similarNames:string,application:string,pathway:string}>`. `similarNames`, `application`, and `pathway` are native descriptive strings and can be long.
- Evidence boundary: the endpoint normalizes returned descriptive material metadata only. Do not treat its `pathway` text as a normalized pathway identifier, an intervention effect, or a sample-specific mechanistic relation.
- Read-only verification: `keyword=EGF&page=1&pageSize=2` → HTTP 200, `code:0`, one EGF record; unmatched keyword → successful empty `PageList`.

## Omics result lists

### Shared list result shape

All listed endpoints accept `GeneralSearchReq` JSON and return `PageList<T>`. `dataSet` from a control-group response is not a list search key; use `search[key=data]` with that value. `group` and `data` are result-range fields. `sampleId`, `platform`, and `organism` are removed by `removeSampleSearchKey` for general result-table queries unless an endpoint service uses them before that removal.

| Endpoint | Status | List item fields | Endpoint-specific request behavior | Evidence |
|---|---|---|---|---|
| `POST /api/browse/sample/rna-seq-gsea/differ-genes/search` | VERIFIED | `sampleId,group,symbol,controlExpression,caseExpression,log2fc,pValue,adjustedPValue,regulation,plot` | `group`, `data` | `app/browse/routes.go:49`; `app/browse/dto.go`; `app/browse/service.go` |
| `POST /api/browse/sample/rna-seq-gsea/differ-cell-type/search` | VERIFIED | `sampleId,group,cellType,source,regulation,geneRatio,bgRatio,pValue,adjustedPValue,markerGene,plot` | `group`, `data` | `app/browse/routes.go:50` |
| `POST /api/browse/sample/rna-seq-gsva/differ-pathways/search` | VERIFIED | `sampleId,group,term,controlExpression,caseExpression,log2fc,pValue,adjustedPValue,regulation,boxplot` | `group`, `data` | `app/browse/routes.go:51` |
| `POST /api/browse/sample/rna-seq-gsea/enriched-pathways/search` | CONDITIONAL | `sampleId,group,pathwayId,terms,size,es,nes,pValue,adjustedPValue,plot` | `group`, `data`; additionally `sampleId` or both `platform` and `organism` required for admission; identity fields removed before final SQL | `app/browse/routes.go:52`; `app/browse/service.go:1355-1494` |
| `POST /api/browse/sample/scrna-seq-cluster/marker-genes/search` | VERIFIED | cluster-marker result DTO | `group`, `data` | `app/browse/routes.go:86` |
| `POST /api/browse/sample/scrna-seq-cluster/differ-genes/search` | IMPLEMENTATION_LIMITATION | cluster-differential result DTO | `group`, `data`; current mapper assigns `pctCase` from `pctControl` | `app/browse/routes.go:87`; `app/browse/service.go` |
| `POST /api/browse/sample/scrna-seq-gsea/pseudobulk/differ-genes/search` | CONDITIONAL | RNA GSEA differential-gene DTO | `group`, `data`; shared general handler | `app/browse/routes.go:99` |
| `POST /api/browse/sample/scrna-seq-gsea/pseudobulk/differ-cell-type/search` | CONDITIONAL | RNA GSEA differential-cell-type DTO | `group`, `data`; shared general handler | `app/browse/routes.go:100` |
| `POST /api/browse/sample/scrna-seq-gsva/pseudobulk/differ-pathways/search` | CONDITIONAL | RNA GSVA differential-pathway DTO | `group`, `data`; shared general handler | `app/browse/routes.go:101` |
| `POST /api/browse/sample/scrna-seq-gsea/pseudobulk/enriched-pathways/search` | CONDITIONAL | `sampleId,group,pathwayId,terms,size,es,nes,pValue,adjustedPValue,plot` | `group`, `data`; admission requires `sampleId` or `platform` + `organism`; `resolution:number` with `equal` becomes `gte(value-0.0001)` and `lte(value+0.0001)`; `type` converts `cellCluster→cluster`, `scType→celltype_scType`, `GPTCelltype`/`SingleRType→celltype_SingleR`; `cellType` key becomes `pseudobulk_cell_type`. Response does not return `data,resolution,type,cellType`. | `app/browse/routes.go:102`; `app/browse/service.go:1355-1494`; `app/browse/omics_data_service.go:1445-1458`; `domain/sample/service/genomics.go:48-54` |

### Retired scRNA overall result lists

The following paths are registered in code but are `REGISTERED_BUT_RETIRED`; clients must not call them:

- `POST /api/browse/sample/scrna-seq-overall-gsea/differ-genes/search`
- `POST /api/browse/sample/scrna-seq-overall-gsea/differ-cell-type/search`
- `POST /api/browse/sample/scrna-seq-overall-gsea/enriched-pathways/search`
- `POST /api/browse/sample/scrna-seq-overall-gsva/differ-pathways/search`

Evidence: `app/browse/routes.go:65-68`.

## Omics control-group, chart, trajectory, and interaction data

### Control-group

| Endpoint | Request | Response `data` | Evidence |
|---|---|---|---|
| `GET /api/browse/sample/rna-seq/control-group` | `sampleId` required | `{dataSet:string,groups:string[]}` | `app/browse/routes.go:55`; `app/browse/omics_data_handler.go` |
| `GET /api/browse/sample/scrna-seq/control-group` | `sampleId` required | `{dataSet:string,groups:string[]}` | `app/browse/routes.go:79`; `app/browse/omics_data_handler.go` |

### Bulk and scRNA chart endpoints

Each endpoint below uses its documented request DTO. Response `data` retains the native graph array or object returned by its service; it is not uniformly wrapped as `{list:...}`.

- `GET /api/browse/sample/rna-seq-gsea/volcano-plot-data`
- `GET /api/browse/sample/rna-seq-gsea/heatmap-data`
- `GET /api/browse/sample/rna-seq-gsea/enriched-function-go-data`
- `GET /api/browse/sample/rna-seq-gsea/enriched-function-kegg-data`
- `GET /api/browse/sample/rna-seq-gsva/volcano-plot-data`
- `GET /api/browse/sample/rna-seq-gsva/heatmap-data`
- `GET /api/browse/sample/rna-seq-gsva/gsva-histogram-data` — Category request; `category` required, enum `GO|KEGG|ssGSEA`.
- `GET /api/browse/sample/scrna-seq-gsea/volcano-plot-data`
- `GET /api/browse/sample/scrna-seq-gsea/heatmap-data`
- `GET /api/browse/sample/scrna-seq-gsea/enriched-function-go-data`
- `GET /api/browse/sample/scrna-seq-gsea/enriched-function-kegg-data`
- `GET /api/browse/sample/scrna-seq-gsva/volcano-plot-data`
- `GET /api/browse/sample/scrna-seq-gsva/heatmap-data`
- `GET /api/browse/sample/scrna-seq-gsva/gsva-histogram-data` — Category request; `category` required, enum `GO|KEGG|ssGSEA`.

Evidence: `app/browse/routes.go:55-77`; `app/browse/dto.go:132-347`; `app/browse/omics_data_handler.go:4-305`.

### scRNA clustered endpoints

| Endpoint | Required query fields | Response `data` |
|---|---|---|
| `GET /api/browse/sample/scrna-seq-clustered/cell-feature` | `group,dataSet,coordinates,type,resolution,gene,showGroupName` | native cell coordinate graph data |
| `GET /api/browse/sample/scrna-seq-clustered/cell-ratio` | `group,dataSet,type,resolution` | `{list:[{x,case,control}]}` |
| `GET /api/browse/sample/scrna-seq-clustered/cell-trajectory-root-cluster` | `group,dataSet,coordinates` | native root-cluster data |
| `GET /api/browse/sample/scrna-seq-clustered/cell-trajectory` | `group,dataSet,coordinates,rootCluster,is3D` | native trajectory array/object |
| `GET /api/browse/sample/scrna-seq-clustered/gene-trajectory-gene` | `group,dataSet,resolution,gene,coordinates,rootCluster` | native gene trajectory data |
| `GET /api/browse/sample/scrna-seq-clustered/gene-trajectory` | `group,dataSet,resolution,gene,coordinates,rootCluster` | native trajectory array/object |

`sampleId`, `platform`, and `organism` are optional common graph fields. Evidence: `app/browse/routes.go:80-85`; `app/browse/dto.go:132-347`; `app/browse/omics_data_handler.go:150-305`.

### Gene interaction

- `GET /api/browse/sample/gene-interaction/pathway-relation`
- `GET /api/browse/sample/gene-interaction/gene-pathway`

Request: common graph fields plus `category:string` required, enum `GO|KEGG`. Response `data`: native interaction list. Evidence: `app/browse/routes.go:95-96`; `app/browse/dto.go:553-716`.

### Pseudobulk chart and interaction endpoints

All chart endpoints use `ScRnaSeqPseudobulkGraphDataReq`; response `data` retains the native graph array or object returned by its service:

- `GET /api/browse/sample/scrna-seq-gsea/pseudobulk/volcano-plot-data`
- `GET /api/browse/sample/scrna-seq-gsea/pseudobulk/heatmap-data`
- `GET /api/browse/sample/scrna-seq-gsea/pseudobulk/enriched-function-go-data`
- `GET /api/browse/sample/scrna-seq-gsea/pseudobulk/enriched-function-kegg-data`
- `GET /api/browse/sample/scrna-seq-gsva/pseudobulk/volcano-plot-data`
- `GET /api/browse/sample/scrna-seq-gsva/pseudobulk/heatmap-data`
- `GET /api/browse/sample/scrna-seq-gsva/pseudobulk/gsva-histogram-data`
- `GET /api/browse/sample/scrna-seq-gsea/pseudobulk/cell-type-list`

Pseudobulk interaction endpoints use `ScRnaSeqPseudobulkGeneInteractionReq`, adding `category:string` required (`GO|KEGG`):

- `GET /api/browse/sample/scrna-seq-gsva/pseudobulk/gene-interaction/pathway-relation`
- `GET /api/browse/sample/scrna-seq-gsva/pseudobulk/gene-interaction/gene-pathway`

Evidence: `app/browse/routes.go:105-117`; `app/browse/dto.go:553-716`; `app/browse/omics_data_handler.go:4-305`.

## Analysis

### GET /api/analysis/quick/biomarker/conditions

- Purpose: enumerate exact B_terms values accepted by quick biomarker analysis.
- Request query: `species:string` required (`hsa|mmu`); `field:string` required (`condition|organCondition`); `q:string` optional case-insensitive substring search.
- Response payload fields: `{species,field,values,count}`.
- Use returned strings exactly for `condition` and `organCondition`; do not construct, translate, or normalize values.

### POST /api/analysis/quick/biomarker/predict

- Purpose: submit one asynchronous quick biomarker prioritization job. This request is side-effecting and must not be automatically replayed after an ambiguous outcome.
- Genes mode uses `application/json`:

```json
{
  "mode": "genes",
  "species": "hsa",
  "condition": "Colorectal Cancer",
  "genes": ["LEF1", "CD44", "LGR5"],
  "organCondition": "optional exact enumerated value"
}
```

- Genes constraints: `species` is `hsa|mmu`; `condition` is required; `genes` is a non-empty array of at most 20 gene symbols; `organCondition` is optional. The public API document does not promise Entrez or Ensembl normalization.
- Expression mode uses `multipart/form-data` with required scalar parts `mode=expression`, `species`, `condition`; required file parts `matrix` and `groups` containing TSV files; optional `organCondition`; optional `dataType=microarray|rnaseq`. Send `dataType` only when the user explicitly supplies one of those values; otherwise omit the multipart field and do not infer a default.
- Expression file limit: `matrix + groups` combined size must not exceed 10 MB.
- Submission response payload: `{jobId,status,query}`. Preserve the returned `jobId` as the job identifier.
- Documented HTTP 400 error codes: `invalidSpecies`, `invalidCondition` (may include `suggestions`), `invalidOrgan`, `missingGenes`, `invalidParams` for more than 20 genes, and `invalidMode` when expression mode is sent as JSON.

### GET /api/analysis/quick/biomarker/jobs/{jobId}

- Purpose: retrieve both current status and, when complete, inline results for one exact quick-analysis `jobId`.
- `queued` and `running` responses report status only. For `ok`, the same response must contain `summary` and a `results` field for an interpretable completed result; there is no separate quick-analysis progress or result endpoint and no documented progress percentage. If `status=ok` lacks `results`, treat the response as incomplete or a possible input mismatch, stop biological interpretation and downstream gene annotation, and report the missing field. An explicit `results: []` is a successful empty result, not a biological negative.
- Completed summary fields: `{nInput,nScored,nEnriched}`.
- Common result fields: `{rank,gene,verdict,confidence,primaryP}`. Documented verdicts are `enriched|not_sig|depleted`; documented confidence values are `HIGH|MEDIUM|N/A`.
- Expression results may additionally return `{log2fc,padj,deRank}`.
- Preserve native fields and unknown values. Do not recompute or remap rankings, confidence, verdicts, or statistics.
- A missing job returns HTTP 404. Results are retained for at most one day, but 404 alone does not establish whether a job expired or never existed.

### Quick biomarker contract limitations

The supplied public API document has unresolved discrepancies that callers must not repair by assumption:

- It states a common `{code,message,data}` envelope while endpoint success examples show bare payload objects. For these endpoints, accept an enveloped success only with numeric `code == 0`; also accept a bare object only when it matches the documented endpoint success fields. Preserve which shape was returned. A bare string error `code`, malformed JSON, or unrecognized shape is an API/contract error, not successful emptiness.
- Only `queued`, `running`, and `ok` are documented. No failed, cancelled, expired, or timeout status contract is supplied; preserve any other returned status verbatim and stop rather than inventing terminal semantics.
- The standalone OCSP tool documentation discusses broader identifier classes, auxiliary methods, consensus scores, and low confidence, while this API contract documents gene symbols, `methods: primary`, `primaryP`, and `HIGH|MEDIUM|N/A`. Do not expose the standalone tool's additional behavior as API behavior unless the API returns it.
- The API does not define deeper matrix/group validation, group labels, differential-expression method selection, replicate checks, summary accounting rules, or numeric nullability. Do not claim these validations or interpretations occurred.

### Quick biomarker result → gene annotation handoff

For researcher-facing interpretation of completed quick biomarker results, preserve the Analysis response as one evidence layer and use this documented read-only identity/annotation chain as separate evidence:

```text
result.gene symbol + Analysis species
  → GET /api/common/gene/suggest
  → exact returned symbol + Entrez ID
  → GET /api/browse/sample/gene-annotation by Entrez ID
```

- Species vocabularies differ by endpoint and must be mapped explicitly:

| Quick Analysis `species` | Gene suggest `organism` | Gene annotation `organism` |
|---|---|---|
| `hsa` | `Homo sapiens` | `human` |
| `mmu` | `Mus musculus` | `mouse` |

- Call gene suggest with `keyword` equal to the native returned `gene`, `organism` mapped to the exact full species name in the table, and a bounded `limit`. Accept an identity automatically only when exactly one returned record has an exact case-sensitive symbol match and a usable `entrezId`. Do not select fuzzy, substring, case-conflicting, or multiply exact candidates automatically.
- If gene suggest reports missing or unsupported `organism`, do not fall back to human or retry automatically. Preserve the error and ask the user to choose `Homo sapiens` or `Mus musculus`; after selection, retry only this read-only suggestion request with the exact supported value. This choice must not rewrite the already completed Analysis species or authorize a new Analysis submission. If it conflicts with the Analysis species, stop the join instead of crossing species.
- Call gene annotation with `geneName` equal to the resolved Entrez ID and the mapped `human|mouse` organism. Verify the returned Entrez identity before joining the annotation to the Analysis record.
- Do not send `sampleId`: the current annotation service ignores it. Gene annotation is general reference metadata, not sample-specific evidence.
- Keep unresolved, ambiguous, empty, 404, and failed identities as per-gene annotation states. They do not change the completed Analysis result or imply biological absence.
- Gene annotation fields can add descriptive context, but they do not validate the biomarker ranking, explain `primaryP`, prove disease causality or context-specific interaction, or establish druggability, efficacy, or clinical actionability.
- After a successful gene-annotation lookup, call the matching KOBAS reference endpoint for the same resolved Entrez ID: `kobas-human` for `hsa→human`, or `kobas-mouse` for `mmu→mouse`. Send explicit bounded `page` and `pageSize`, preserve returned pagination/total, and report uninspected coverage.
- KOBAS records form a fourth, separate evidence layer. They provide route-specific pathway/function database annotations, not evidence that a pathway is enriched, active, causal, expressed, or sample-specific in this Analysis.

Source: existing gene suggestion and gene annotation contracts in this reference; this handoff adds no new endpoint.

Source: quick biomarker integration contract reviewed for this plugin release. The standalone OCSP overview is explanatory background only, not an extension of this HTTP contract.

## Implementation anchors

- Root `/api/` mount: `app/routes.go:152-182`.
- JSON envelope: `pkg/response/gin_response.go:17-24,151-166`.
- Pagination: `pkg/valueobject/pagination.go:62-83`.
- Common search binding: `pkg/valueobject/search.go:6-23`.
- Generic query operator implementation: `infrastructure/db/gormclient/common_search.go:93-228`.
- Page list shape: `infrastructure/db/gormclient/model.go:21-39`.
