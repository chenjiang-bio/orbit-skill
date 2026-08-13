# Orbit Reason 能力表：跨层关联推荐

本文用于说明 `orbit-reason` 当前能够安全建立哪些跨层关联，以及哪些关系仍然存在数据或接口断点。

## 判定说明

- ✅️：当前可以建立可追溯关联，但仍需遵守对应的接口、样本、数据集和比较组边界。
- ❌️：当前不建议建立直接关联。表中说明断点、不能作出的生物学判断，以及补齐关联所需的接口或字段。
- “直接接口关联”：API 返回字段明确表达了 A 与 B 的关系。
- “同样本/同分析上下文”：A 与 B 属于同一个样本或分析范围，但 API 没有明确表达二者的生物学关系。
- “文本关联”：关系只出现在 API 返回的描述文字中，不能升级为结构化关系。

| A | B | 能否关联（✅️/❌️） | 关联说明 | 关联上的生物学意义 |
|---|---|---:|---|---|
| `sampleId` | 样本基础信息 | ✅️ | 使用 `/api/browse/sample/general-basic-info?sampleId=...`，以 API 返回的 `sampleId` 作为稳定键。 | 确定样本的物种、类器官类型、来源、疾病模型和实验背景。 |
| `sampleId` | 培养方案 | ✅️ | 使用 `/api/browse/sample/culture-plan?sampleId=...`，保留返回的阶段、时间、培养因子和材料。 | 描述该样本对应的培养和分化过程；不能单独说明某因素导致某表型。 |
| `sampleId` | biomarker 培养时间计划 | ✅️ | 使用 `/api/search/biomarker/culture-plan?sampleId=...`。KM-00004 当前返回成功但 `timePoints=[]`，只能记录为空。 | 如果有时间点，可描述 biomarker 在培养过程中的检测时间；空结果不代表 biomarker 不存在。 |
| `sampleId` | 组学 `dataSet` | ✅️ | 先调用对应的 RNA-seq 或 scRNA-seq control-group 接口，使用 API 返回的 `dataSet`，不能从 GSE、标题或名称推导。 | 将样本连接到具体组学数据集，是进入差异基因和通路分析的必要上下文。 |
| `dataSet` | `group` | ✅️ | 使用同一个 control-group 返回对象中的 `dataSet` 和 `groups[]`，由用户选择或明确使用 API 返回的 group。 | 定义组学比较范围，例如 `DMD1_SMO_vs_WT`；group 本身不等于因果干预。 |
| `dataSet + group` | 差异基因结果 | ✅️ | 调用有效的 differential-gene search 接口，使用 `search[key="data"]` 传入 `dataSet` 值，并同时传入 `search[key="group"]`。 | 得到该数据集和比较组下的差异表达结果，包括 symbol、log2fc、p 值和调整后 p 值。 |
| 差异基因 `symbol` | Entrez ID | ✅️ | 调用 `/api/common/gene/suggest`，使用 API 返回的基因 symbol 或明确的基因名称解析，并保留 Entrez ID。 | 将差异基因连接到稳定的基因标识，便于后续注释和跨接口关联。 |
| 基因 Symbol/Entrez ID | 基因注释 | ✅️ | 调用 `/api/browse/sample/gene-annotation?geneName=...&organism=...`。数字按 Entrez ID 查询，非数字按对应物种 Symbol 查询。 | 获得基因名称、蛋白、功能、序列特征、互作、疾病和药物列表等数据库注释。 |
| 基因注释 | `referenceSample` / KM `sampleId` | ✅️ | 基因注释返回的 `referenceSample[]` 已直接包含 `sampleId`、`reference`、`doi`、`index` 和 `source`。真实验证 `geneName=MYOG` 返回 `KM-00004`，来源包含 `Biomarker` 和 `OmicsDEGs`。 | 支持“该基因在这些 KM 样本的已入库证据中被关联记录”的描述；不能仅凭该关联推断样本中的因果作用、表达变化或临床意义。 |
| 基因注释中的 `function` | GO/KEGG 功能条目 | ✅️ | 使用 `GeneAnnotation.function[]` 中明确返回的 `item`、`id`、`description`、`database` 和 `link`。 | 支持“该基因被数据库注释到某 GO/KEGG 功能”的描述；不自动证明该基因在本实验中驱动该功能。 |
| 基因注释 | 蛋白结构或蛋白位点 | ✅️ | 使用 `proteinStructure`、`proteinSite` 及其中的结合位点、活性位点和其他位点字段。 | 描述蛋白结构、结合位点或活性位点，为机制假设和实验验证提供注释依据；不能直接等同于药物结合或药效。 |
| 基因注释 | 蛋白互作基因 | ✅️ | 使用 `proteinInteraction[]` 中明确返回的 `geneIDX/geneIDY`、Symbol 和 `combinedScore`。 | 支持数据库蛋白互作网络中的关联；`combinedScore` 是数据库评分，不等于当前类器官中已验证的互作。 |
| 基因注释 | 蛋白—疾病信息 | ✅️ | 使用 `proteinDisease` 中明确返回的 `involvementInDisease` 等结构化字段。 | 支持数据库层面的蛋白—疾病关联；不能直接推断 KM-00004 中的疾病表型机制。 |
| 基因注释 | `drugList` | ✅️ | 使用接口返回的 `drugList`，并保留基因身份和接口来源。 | 只能说明数据库记录了该基因相关药物名称；不等于临床有效性、靶点验证或可成药性证明。 |
| 基因注释中的 `externalLinks` | 外部数据库实体 | ✅️ | 使用返回的 `databaseName`、`label`、`title`、`url` 作为交叉引用；不抓取 DOI 全文或外部网页内容。 | 提供 DrugBank、Open Targets、ClinGen 等外部数据库的引用关系；不能自动升级为 Orbit 内部证据。 |
| GSE-like `data` | GDS 平台元数据 | ✅️ | 调用 `/api/browse/sample/reference/gds?gseId=...`，保留 API 返回的 `gseId`、分号分隔原始 `sampleId` 字符串和 `platform`。 | 确认该 GSE-like 数据对应的 API 映射记录及平台；不能据此确认 omics control-group 的 `dataSet`、group 或 comparison。 |
| GSE-like `data` | KM `sampleId` | ✅️（有条件） | 只有 GDS 响应同一条记录明确返回查询的 `gseId` 和 `sampleId` 时才能建立映射；逐个样本详情/组学调用仅可使用该 API 返回的 ID，并保留原始映射行和 `platform`。 | 支持“该 GSE 映射记录关联这些 KM sample ID”的描述；不能把 GSE 当作 `dataSet`，也不能仅凭映射确认某个样本的特定组学比较。 |
| biomarker | 基因 | ✅️ | 使用 biomarker 结果中明确返回的 gene Symbol、Entrez ID 或基因字段；若只有文本名称，先通过 gene suggest 解析并保留原始值。 | 支持“该记录将某基因作为 biomarker”的数据库关系；不等于临床验证或因果 biomarker。 |
| biomarker | 检测方法 | ✅️ | 只有 biomarker 返回记录明确绑定 `detectionMethod` 或等价字段时才建立直接关联；请求过滤条件本身不能作为证据。 | 表示该 biomarker 使用某种方法被记录或检测；不能把文本中提到的方法自动归属于 biomarker。 |
| biomarker | pathway | ❌️ | 当前通常只能通过同一 sample、dataset 或结果上下文建立同样本共现，缺少明确 biomarker→pathway 字段。需要 biomarker 记录中显式 pathway ID，或正式 biomarker-pathway 接口。 | 在补齐接口前只能说二者出现在同一研究上下文，不能说 biomarker 参与、激活或调控该通路。 |
| 差异基因 | 富集通路 | ✅️（有条件） | 仅当 `/api/browse/sample/reference/gsea-enriched-genes` 同一返回行含有该 `pathwayId` 及原始 `enrichGene`，并且该基因经文档化解析接口与 `enrichGene` 中的成员一致时，才能建立 analysis-scoped core-enrichment 关联。必须保留该行的 `data`、`group`、原始 `enrichGene`、分页和 `sampleId`；空 `sampleId` 不支持样本特异性说法。 | 支持“该差异基因与该 API 返回的分析范围 core-enrichment 列表相符”的描述；不代表通路的通用成员、因果驱动基因，或该基因在该样本中必然差异表达。 |
| pathway | pathway 成员基因 | ✅️（有条件） | `/api/browse/sample/reference/gsea-enriched-genes` 返回的同一行 `pathwayId` 与 `enrichGene` 可以支持通路到 core-enrichment 字符串的直接关联。`enrichGene` 当前为 `/` 分隔的原始字符串，需先通过已文档化基因解析接口规范化。 | 仅表示该 `data + group` 分析记录中的 core-enrichment；不是全局 pathway membership，也不说明该通路被激活或由这些基因驱动。 |
| pathway | phenotype | ❌️ | 同 sample 或同 dataset 出现只表示共同出现，缺少通路—表型结构化绑定。需要明确 pathway、比较、时间和 phenotype 字段之间的关系。 | 不能说某通路导致或解释了某个类器官表型。 |
| 培养因子 | pathway | ❌️ | 培养方案中的 factor 与组学 pathway 如果没有干预、对照、时间和分析结果绑定，只是研究上下文共现。需要结构化干预比较或实验设计字段。 | 不能把添加、撤除、洗脱和抑制混为一谈，也不能直接宣称某因子调控该通路。 |
| perturbation | phenotype | ❌️ | 需要 API 明确绑定 perturbation、对照、时间和测量表型；仅同 sample 或文本描述不足。 | 在缺少绑定前不能写成“处理导致表型变化”。 |
| 基因注释 | druggability | ❌️ | gene-annotation 的 `drugList` 和外部链接仍不能支持可成药性结论。`/api/browse/sample/reference/drug` 只在 `targets` JSON 字符串中明确返回稳定 target identity、source/evidence 与该药物记录时，支持 drug→target 数据库注释；这仍不是 tractability、临床有效性或样本适用性证据。 | 可报告返回的 drug-target 注释及来源；不能报告该基因已被验证为可成药靶点。 |
| Entrez ID | KOBAS 通路/功能注释 | ✅️（有条件） | 按物种调用 `/api/browse/sample/reference/kobas-human` 或 `kobas-mouse`；同一行返回 `query`、`item`、`id`、`description`、`database` 时建立注释关联。 | 支持该 Entrez ID 的外部数据库功能/通路注释；不能说明该通路在 Orbit 样本中活跃、富集或有表达。 |
| 药物记录 | 靶点注释 | ✅️（有条件） | `/api/browse/sample/reference/drug` 的 `keyword` 必填；其 `targets` 是 JSON 字符串，只有成功解析且目标对象明确返回 symbol/Ensembl 等身份字段时，才可保留 drug→target 直接数据库关联；null 字段必须保留。 | 支持返回的作用机制/作用类型注释；不能推断疗效、临床可行动性、可成药性或类器官样本相关性。 |
| 材料关键词 | 标准化材料元数据 | ✅️（有条件） | `/api/browse/sample/reference/material` 的 `keyword` 必填；同一返回行的 `materialType`、`standardName`、`similarNames`、`application` 和 `pathway` 仅构成描述性材料元数据。 | 支持将查询词归一到返回的材料记录；不能将 `pathway` 文本作为标准化通路 ID、材料→机制关系或样本特异性证据。 |
| 基因注释 | 临床验证 | ❌️ | `civicSummary`、疾病注释、ClinGen 等外部链接不是当前类器官中的临床验证结果。需要明确临床证据字段或正式临床验证接口。 | 不能把数据库注释或预测结果写成临床有效性。 |
| `sampleId` | 基因注释 | ❌️ | `gene-annotation` 的 DTO 接受可选 `sampleId`，但当前 service 只使用 `geneName` 和 `organism`；`sampleId` 不参与查询过滤。虽然基因注释返回的 `referenceSample[]` 可以反向提供 KM `sampleId`，但不能用请求参数把结果限定到单一样本。若要实现该方向，需要让 `sampleId` 进入查询或新增样本特异性基因注释接口。 | 当前只能建立“基因注释 → referenceSample → KM sampleId”的反向关联，不能声称“KM-00004 的样本特异性基因注释”。 |
| sample | biomarker | ✅️（有条件） | 若 biomarker 接口返回明确 `sampleId`，可用该字段建立直接关联；若只是 sample 与 biomarker 结果来自同一研究上下文，则降级为同样本共现。 | 支持样本中记录了某 biomarker；不能自动说明 biomarker 在该样本中具有因果、诊断或临床价值。 |
| sample | pathway result | ✅️（有条件） | 通过 `sampleId → control-group → dataSet/group → result-list` 建立分析上下文关联。若结果行没有 sampleId，必须保留完整 `dataSet + group + analysis type` provenance。 | 表示该样本对应的组学分析返回了某 pathway 结果，不等于样本表型由该通路造成。 |
| pseudobulk `resolution` | enriched pathway result | ✅️ | 使用 JSON numeric `resolution`；当前后端将 `equal` 转换为 ±0.0001 的范围查询。KM-00004 的 `resolution=0.2` 已验证返回 `total=85`。 | 将富集结果限定到具体 pseudobulk 分析分辨率，避免混入其他 resolution 的分析结果。 |
| pseudobulk enriched pathway | 差异基因 | ❌️ | 即使 `resolution=0.2` 已能返回结果，仍需 pathway member/core gene 字段或 gene-pathway 接口才能连接。当前只能共享 `dataSet + group + resolution + type` 分析上下文。 | 可说明二者来自同一 pseudobulk 分析范围，但不能直接说明差异基因属于该通路。 |

## 最推荐的可执行关联链

当前最稳妥的链是：

```text
sampleId
  → control-group.dataSet + group
  → 差异基因结果
  → symbol
  → Entrez ID
  → gene-annotation
  → function / protein / interaction / disease / drugList
```

这条链可以支持：

- 某样本对应哪个组学数据集和比较组；
- 哪些基因在该比较中出现差异；
- 差异基因的稳定身份；
- 该基因的数据库注释；
- 该基因相关的功能、蛋白、互作、疾病和药物记录。

## 当前必须停止的断点

以下关系不能自动补全：

```text
GSE-like data ──✅️（GDS 映射记录）──→ sampleId
pathway ──✅️（analysis-scoped core-enrichment）──→ member gene
biomarker ──❌️──→ pathway
gene annotation ──✅️──→ referenceSample ──✅️──→ KM sampleId
gene annotation ──❌️──→ druggability
```

仍需要补齐的能力分别是：

1. biomarker-pathway 显式关系字段；
2. tractability 或临床相关的可成药性证据；
3. 绑定具体样本、比较与表型的结构化干预关系。

即使多个节点来自同一个样本，也不能把“共同出现”改写成激活、调控、介导、响应、验证或因果关系。该能力表描述的是 API 返回证据和当前接口边界，不是独立的生物学因果推断或临床结论。
