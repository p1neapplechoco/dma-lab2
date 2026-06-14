# Design: Realign deliverable to FPmax as the chosen algorithm

Date: 2026-06-14
Topic: fpmax-realign
Status: awaiting user review

## Problem

The assignment (CSC14004 Đồ Án 2) grades the project against the group's **one chosen
algorithm**. The group's chosen algorithm is **FPmax** (maximal frequent itemset mining,
Grahne & Zhu 2003). The implementation contains a working FPmax (`src/algorithm/fp_max.jl`,
`get_maximal_itemsets`), but the rest of the deliverable is built around FP-Growth:

- `introduction.tex:6` declares "nhóm lựa chọn họ thuật toán FP-Growth và mở rộng thêm phần FP-Max".
- `README.md` is titled FP-Growth; FPmax is 1 of 3 branches.
- `01_theory.tex`: idea, FP-tree, pseudocode, **entire complexity analysis** are FP-Growth.
  FPmax = one subsection (150–177) that self-admits "thực nghiệm chính tập trung vào FP-Growth".
- `02_example.tex`: **both** hand examples mine all frequent itemsets via FP-Growth; "maximal"
  is one sentence (line 73).
- `03_code.tex`: FPmax = one short subsection (111–115).
- `04_evaluation.tex`: `base/opt/spmf` are **all FP-Growth**; correctness vs SPMF
  `FPGrowth_itemsets`. Zero FPmax measurement.
- `experiments/run_experiments.jl`: calls `get_frequent_itemsets` + `FPGrowth`/`FPGrowthOpt`;
  never `get_maximal_itemsets`. `spmf_runner.jl:10` runs `FPGrowth_itemsets`.

Grade exposure if FPmax is the chosen algorithm: Ch2 hand examples (30%), Ch3 correctness
(10%), Ch4 experiments (20%) are all measured on the wrong algorithm.

## Goal

Make **FPmax the protagonist** of every graded deliverable, with real reproducible numbers.
FP-Growth / FP-tree is retained only where it legitimately serves FPmax:
1. prerequisite background (FPmax is built on an FP-tree), and
2. the engine reused by the **naive-maximal baseline** and by the Ch5 rule-mining application.

## Decisions (confirmed with user)

1. **Chosen algorithm = FPmax.** SPMF reference switches `FPGrowth_itemsets` → `FPMax`.
2. **base-vs-opt pair for "optimization with measurement" (Ch3) and Ch4 curves =
   naive-maximal vs FPMax-prune:**
   - `base` = mine ALL frequent itemsets with `FPGrowthOpt`, then post-filter to maximal
     (`maximal_from_frequent`). Feasible wherever FP-Growth runs; blows up on dense/low-minsup
     exactly like the current FP-Growth base, so reuse the existing skip logic.
   - `opt` = `get_maximal_itemsets` (direct FPMax with MFI superset pruning; never materializes
     all frequent). On dense data #frequent ≫ #maximal, so opt should win clearly.
3. **Ch2 Ex2 special case = superset pruning** (FPmax-distinctive), not plain single-path.
4. **Ch5 keeps FP-Growth association rules** — association rules need full support of every
   itemset, which maximal sets cannot provide; add one sentence justifying the engine choice.
5. User reviews this spec before any implementation.

## Verified facts (already checked against code/tools, do not re-derive)

- Julia 1.12.6, Java (OpenJDK 26), `experiments/spmf/spmf.jar` (15.6M), all 5 benchmark datasets
  (incl. accidents 33.9M) and toy data are present.
- SPMF FPMax invocation: `java -jar spmf.jar run FPMax <in> <out> <minsup>`. Stats line:
  `Maximal frequent itemset count : <N>`. Output rows: `item ... #SUP: count` (same format as
  FPGrowth_itemsets). **SPMF requires integer item labels** (non-integer items produce no output).
- Our `get_maximal_itemsets` == SPMF FPMax:
  - toy_1 (minsup 0.6) → `{1,3}:3`, `{2,3,5}:3` (both tools identical; matches existing unit test).
  - chess (minsup 0.9) → **34 maximal**, identical to SPMF's 34. Mining is fast (SPMF 52 ms;
    ours fast after JIT warmup).
- Ex2 design DB (`{a,b,c}×3, {a,b,d}×3`, minsup 0.5) → our FPMax `{a,b,c}:3`, `{a,b,d}:3`.

## Hand-example designs (Ch2)

### Ex1 — base FPMax trace (toy DB, reused so it matches the Ch1 FP-tree figure + unit test)

DB: T1={1,3,4}, T2={2,3,5}, T3={1,2,3,5}, T4={2,5}, T5={1,2,3,5}; minsup_abs = 3.

- Counts: 1:3, 2:4, 3:4, 4:1, 5:4 → drop 4. Tree-build order (support desc, tie by item): 2,3,5,1.
  Build the same FP-tree shown in `fig:fptree-toy`.
- FPMax processes the header **support-ascending** (least frequent first): order 1, 2, 3, 5.
  Trace the MFI list:
  - item 1: cond base {(3):1, (2,3,5):2}; tail {3} (sup 3); candidate {1,3} → MFI = [{1,3}].
  - item 2: empty base; candidate {2} → MFI = [{1,3}, {2}].
  - item 3: base {(2):3}; tail {2}; candidate {2,3} → {2} is a strict subset, dropped →
    MFI = [{1,3}, {2,3}].
  - item 5: base {(2,3):3, (2):1}; tail {2,3}; conditional tree is single path → candidate
    {2,3,5} → {2,3} dropped → MFI = [{1,3}, {2,3,5}].
- Result: **{1,3}:3, {2,3,5}:3** (recount support over D). Cross-check: list all 9 frequent
  itemsets, then keep only those with no frequent superset → exactly these 2.
- Teaching point: the MFI list with strict-subset subsumption ({2}→{2,3}→ dropped by {2,3,5}).

### Ex2 — special case: superset pruning

DB: T1=T2=T3={a,b,c}, T4=T5=T6={a,b,d}; minsup_abs = 3 (relative 0.5).

- Counts a:6, b:6, c:3, d:3. Tree-build order desc: a,b,c,d. Tree:
  root→a:6→b:6→{c:3, d:3} (b has two children ⇒ NOT single path, so per-item recursion runs).
- Header support-ascending: c, d, a, b.
  - item c: base {(a,b):3}; tail {a,b}; candidate {a,b,c} → MFI = [{a,b,c}].
  - item d: base {(a,b):3}; tail {a,b}; candidate {a,b,d} → MFI = [{a,b,c}, {a,b,d}].
  - item a: empty base; head∪tail = {a} ⊆ {a,b,c} ⇒ **pruned** (trivial).
  - item b: base {(a):6}; tail {a}; head∪tail = {a,b} ⊆ {a,b,c} ⇒ **branch pruned, conditional
    tree NOT built** — the non-trivial prune to highlight.
- Result: **{a,b,c}:3, {a,b,d}:3** (verified). Analysis: superset pruning is FPmax's defining
  optimization — it skips entire subtrees that cannot yield a new maximal set, which FP-Growth
  cannot do because it must emit every frequent subset. Pair with the contrast that on a length-k
  single path FP-Growth emits 2^k−1 itemsets while FPMax emits 1.
- Note: report Ex2 may use letters a–d (pure by-hand cross-check); SPMF cross-check optional and
  would need integer relabeling.

## Per-file change plan

### `report/content/introduction.tex`
Reframe: chosen algorithm = FPmax (cite Grahne2003FPMax as the implemented paper); FP-Growth/FP-tree
described as the structure FPmax builds on. Update the chapter roadmap sentence.

### `report/content/01_theory.tex`
- Keep: FIM definitions, Apriori/anti-monotone property, closed/maximal definitions, FP-tree
  structure + figure.
- Compress the FP-Growth "idea/pseudocode" into a short **engine background** subsection.
- Promote FPmax: core idea, distinctive structures (MFI list + subset subsumption, superset
  pruning, single-path shortcut), expanded + annotated FPmax pseudocode (already present),
  **new FPmax complexity analysis** (build phase shared with FP-Growth; mining bounded by #maximal
  with pruning; worst case still exponential when every frequent set is maximal; space = FP-tree +
  conditional trees + MFI list), history Apriori → FP-Growth → FPmax*.
- Tie complexity back to the new Ch4 numbers (count-of-maximal, txnlen jump).

### `report/content/02_example.tex`
Full rewrite to the two FPMax traces above (Ex1 base trace, Ex2 superset pruning). Keep the toy DB
table and reference the Ch1 FP-tree figure.

### `report/content/03_code.tex`
- Promote the FPMax implementation subsection: `FPMax` struct, `get_maximal_itemsets`, `insert_mfi!`
  (subset subsumption), superset-pruning check, single-path shortcut, final support recount.
- Retain FP-Growth base/opt as "the FP-tree engine" (integer encoding, typed header, `@inbounds`,
  type-stability evidence) — still valid because the naive-maximal baseline and Ch5 use it.
- Replace the FP-Growth base/opt alloc table framing with the **naive-maximal vs FPMax** measured
  optimization (numbers from the re-run).
- Update the unit-test description to foreground the FPMax correctness test.

### `report/content/04_evaluation.tex`
Rewrite around FPmax. Algorithms compared: `base` (naive-maximal via FPGrowthOpt + filter),
`opt` (FPMax), `spmf` (SPMF FPMax). Sections: correctness vs SPMF FPMax; runtime vs minsup;
**count of maximal itemsets vs minsup** (replaces frequent-count); memory base/opt (+ peak RSS);
scalability (retail/accidents prefixes); txn-length effect. All numbers + all figures regenerated
from the re-run.

### `report/content/05_application.tex`
Keep market-basket association rules on Groceries via the FP-Growth engine. Add one sentence: rule
mining needs full support of all itemsets, which maximal sets do not retain, so the full-frequent
engine is used here. Numbers unchanged (re-verify they still reproduce).

### `experiments/spmf_runner.jl`
Add `run_spmf_fpmax(input, minsup)` that runs `FPMax` and parses
`Maximal frequent itemset count : (\d+)` (+ time/mem regexes as today). Keep the existing
FPGrowth runner for Ch5 if needed.

### `experiments/run_experiments.jl`
- Add helper `maximal_from_frequent(model)`: from `get_frequent_itemsets`, drop any itemset that
  has a frequent strict superset → maximal set (the `base`).
- `exp_correctness`, `exp_timing`, `exp_scalability`, `exp_txnlen`: measure `opt` =
  `get_maximal_itemsets`, `base` = `maximal_from_frequent(FPGrowthOpt)`, ref = `run_spmf_fpmax`.
  Metric column becomes #maximal. Keep skip logic for base on dense/low-minsup.
- `make_figures.jl` / `measure_memory.jl`: update labels/series to FPmax; regenerate.

### `README.md`
Retitle to FPmax; describe FP-Growth as the engine; update the run example to `fp-max`; refresh
the test-output block after re-running tests.

## Validation / execution order

1. Land code changes (spmf_runner, run_experiments helpers) on a branch.
2. Validate FPMax-vs-SPMF correctness on chess + mushrooms at a mid minsup before full grid.
3. Run full experiment grid (skip blow-up configs as today; accidents is the slow one).
4. Regenerate figures + CSVs; fill report numbers from the produced CSVs.
5. Rewrite report chapters; rebuild PDF; re-run unit tests; update README test block.

## Risks / open items

- `get_maximal_itemsets` is built on the String-keyed base `FPGrowth`; on dense low-minsup configs
  it may be slow. Mitigation: same minsup grids + skip logic as the current report; if too slow,
  raise the lowest minsup points rather than fabricate numbers.
- The naive-maximal `base` inherits FP-Growth blow-up; keep `BASE_MIN` thresholds.
- Report length must stay ≥ 15 pages (excl. refs/appendix) — rewrite should not shrink below that.
- Numbers in the report MUST come from the actual re-run (reproducibility is graded); no carry-over
  of old FP-Growth figures.

## Out of scope

- New optimized Int-encoded FPMax variant (rejected option "FP-tree String vs Int").
- Changing the chosen application (market basket stays).
- Refactoring unrelated code.
