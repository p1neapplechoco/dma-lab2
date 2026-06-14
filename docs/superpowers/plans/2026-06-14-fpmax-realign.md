# FPmax Realign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make FPmax the chosen/measured algorithm across every graded deliverable (theory, hand examples, implementation, experiments, README), with all report numbers coming from a real re-run.

**Architecture:** Keep FP-Growth/FP-tree only as (1) prerequisite background and (2) the engine reused by the naive-maximal baseline + Ch5 rules. Rewire experiments so `base` = naive-maximal (FPGrowthOpt mine-all + post-filter), `opt` = `get_maximal_itemsets` (FPMax with MFI superset pruning), `ref` = SPMF `FPMax`. Rewrite the 6 report `.tex` files in the existing Vietnamese academic voice.

**Tech Stack:** Julia 1.12 (`FrequentItemsetMining` package), SPMF jar (Java), LaTeX (latexmk).

**Spec:** `docs/superpowers/specs/2026-06-14-fpmax-realign-design.md`

**Style constraint (user):** preserve the existing report prose voice — tiếng Việt, English technical terms kept on first use, flowing paragraphs (not bullet-dumps), concrete numbers, evidence-first, every figure/table has `\caption` + `\label` and is referenced by `\ref`.

---

## File Structure

**Code (Julia):**
- Modify `src/algorithm/fp_max.jl` — add `maximal_from_frequent` (naive-maximal helper).
- Modify `src/FrequentItemsetMining.jl` — export `maximal_from_frequent`.
- Modify `test/test_correctness.jl` — add unit test for `maximal_from_frequent`.
- Modify `experiments/spmf_runner.jl` — add `run_spmf_fpmax`.
- Rewrite `experiments/run_experiments.jl` — FPmax base/opt/ref across all phases.
- Modify `experiments/make_figures.jl`, `experiments/measure_memory.jl` — FPmax labels/series.

**Report (LaTeX), all under `report/content/`:**
- `introduction.tex`, `01_theory.tex`, `02_example.tex`, `03_code.tex`, `04_evaluation.tex`, `05_application.tex`
- `README.md` (repo root)

**Data products (regenerated, not hand-edited):**
- `experiments/results/*.csv`, `experiments/figures/*.png`

---

## Phase A — Code rewiring (TDD)

### Task 1: `maximal_from_frequent` helper

**Files:**
- Modify: `src/algorithm/fp_max.jl` (append function)
- Modify: `src/FrequentItemsetMining.jl:14` (export list)
- Test: `test/test_correctness.jl` (append testset)

- [ ] **Step 1: Write the failing test** — append to `test/test_correctness.jl`:

```julia
@testset "maximal_from_frequent" begin
    transactions = collect(values(load_transactions("data/toy/test_1.txt")))
    g = FPGrowthOpt(0.6); fit!(g, transactions)
    @test maximal_from_frequent(get_frequent_itemsets(g)) == Dict(
        ("1", "3") => 3,
        ("2", "3", "5") => 3,
    )
end
```

- [ ] **Step 2: Run test, verify it fails**

Run: `julia --project=. test/runtests.jl`
Expected: FAIL — `UndefVarError: maximal_from_frequent not defined` (or not exported).

- [ ] **Step 3: Implement** — append to `src/algorithm/fp_max.jl`:

```julia
# Lọc maximal từ tập frequent đầy đủ: bỏ itemset nào có superset nghiêm ngặt cũng frequent.
# Dùng làm baseline "naive maximal" để đối chiếu với FPMax có tỉa.
function maximal_from_frequent(frequent::Dict{Tuple{Vararg{String}}, Int})::Dict{Tuple{Vararg{String}}, Int}
    itemsets = collect(keys(frequent))
    sets = Dict(it => Set(it) for it in itemsets)
    maximal = Dict{Tuple{Vararg{String}}, Int}()
    for it in itemsets
        s = sets[it]
        has_superset = any(
            other != it && length(sets[other]) > length(s) && issubset(s, sets[other])
            for other in itemsets
        )
        has_superset || (maximal[it] = frequent[it])
    end
    return maximal
end
```

- [ ] **Step 4: Export it** — in `src/FrequentItemsetMining.jl`, add `maximal_from_frequent,` to the export list (after `load_unique_items,`).

- [ ] **Step 5: Run test, verify it passes**

Run: `julia --project=. test/runtests.jl`
Expected: PASS, including `maximal_from_frequent` testset.

- [ ] **Step 6: Commit**

```bash
git add src/algorithm/fp_max.jl src/FrequentItemsetMining.jl test/test_correctness.jl
git commit -m "feat: add maximal_from_frequent naive-maximal helper"
```

---

### Task 2: SPMF FPMax runner

**Files:**
- Modify: `experiments/spmf_runner.jl` (add function)

- [ ] **Step 1: Implement** — append to `experiments/spmf_runner.jl` (after `run_spmf`):

```julia
# Chạy SPMF FPMax. Trả (out_path, n_maximal, time_ms, mem_mb, status). Output file dạng #SUP.
function run_spmf_fpmax(input::String, minsup::Float64; timeout_s::Int = 120)
    isfile(SPMF_JAR) || error("spmf.jar not found at $SPMF_JAR")
    out_path = tempname() * ".txt"
    log_path = tempname() * ".log"
    cmd = `java -jar $SPMF_JAR run FPMax $input $out_path $(string(minsup))`

    status = :ok
    n_itemsets = -1
    time_ms = NaN
    mem_mb = NaN
    try
        proc = run(pipeline(cmd; stdout = log_path, stderr = devnull); wait = false)
        t0 = time()
        while process_running(proc)
            if time() - t0 > timeout_s
                kill(proc)
                status = :timeout
                break
            end
            sleep(0.05)
        end
        if status == :ok
            text = read(log_path, String)
            m = match(r"Maximal frequent itemset count\s*:\s*(\d+)", text)
            m !== nothing && (n_itemsets = parse(Int, m.captures[1]))
            mt = match(r"Total time ~?\s*([\d.]+)\s*ms", text)
            mt !== nothing && (time_ms = parse(Float64, mt.captures[1]))
            mm = match(r"Max memory usage:\s*([\d.]+)\s*mb", text)
            mm !== nothing && (mem_mb = parse(Float64, mm.captures[1]))
        end
    catch
        status = :error
    end
    return (out_path, n_itemsets, time_ms, mem_mb, status)
end
```

- [ ] **Step 2: Smoke test** — run:

```bash
julia --project=. -e 'include("experiments/spmf_runner.jl"); o,n,t,m,s = run_spmf_fpmax("data/benchmark/chess.txt", 0.9); println((n,s))'
```
Expected: `(34, :ok)` (matches the verified chess@0.9 = 34 maximal).

- [ ] **Step 3: Commit**

```bash
git add experiments/spmf_runner.jl
git commit -m "feat: add SPMF FPMax runner"
```

---

### Task 3: Rewire `run_experiments.jl` to FPmax

**Files:**
- Rewrite: `experiments/run_experiments.jl`

- [ ] **Step 1: Replace the file** with the FPmax version below (full content):

```julia
using FrequentItemsetMining
using Printf

include("spmf_runner.jl")
include("datagen.jl")

const RESULTS = joinpath(@__DIR__, "results")

const ALL_DATASETS = ["chess", "mushrooms", "retail", "T10I4D100K", "accidents"]
const DATASETS = haskey(ENV, "EXP_DATASETS") ? String.(split(ENV["EXP_DATASETS"], ",")) : ALL_DATASETS

const GRIDS = Dict(
    "chess"      => [0.95, 0.9, 0.85, 0.8, 0.75, 0.7],
    "mushrooms"  => [0.5, 0.4, 0.3, 0.25, 0.2, 0.15],
    "retail"     => [0.05, 0.02, 0.01, 0.005, 0.002, 0.001],
    "T10I4D100K" => [0.05, 0.02, 0.01, 0.005, 0.002, 0.001],
    "accidents"  => [0.9, 0.8, 0.7, 0.6, 0.5],
)

# minsup tối thiểu để còn chạy base (naive-maximal = mine toàn bộ frequent rồi lọc).
# Dưới ngưỡng -> base bùng nổ ~mũ như FP-Growth all-frequent => skip. accidents=1.0 => luôn skip base.
const BASE_MIN = Dict(
    "chess" => 0.8, "mushrooms" => 0.25, "retail" => 0.01,
    "T10I4D100K" => 0.01, "accidents" => 1.0,
)

dataset_path(name) = joinpath(@__DIR__, "..", "data", "benchmark", "$(name).txt")

# opt = FPMax trực tiếp (MFI + tỉa superset).
mine_opt(transactions, s) = let m = FPMax(s); fit!(m, deepcopy(transactions)); get_maximal_itemsets(m) end
# base = naive maximal: mine toàn bộ frequent bằng FPGrowthOpt rồi lọc maximal.
mine_base(transactions, s) = let m = FPGrowthOpt(s); fit!(m, deepcopy(transactions)); maximal_from_frequent(get_frequent_itemsets(m)) end

# Đo (time_ms, alloc_bytes, n_maximal) cho 1 lần chạy, warm-up loại JIT.
function measure_ours(mine, transactions, s)
    mine(transactions, s)
    stats = @timed mine(transactions, s)
    return (stats.time * 1e3, stats.bytes, length(stats.value))
end

function write_csv(path, header, rows)
    mkpath(dirname(path))
    open(path, "w") do io
        println(io, join(header, ","))
        for r in sort(rows; by = r -> string.(r))
            println(io, join(r, ","))
        end
    end
end

function exp_correctness()
    rows = Vector{Tuple}()
    for ds in DATASETS
        path = dataset_path(ds)
        isfile(path) || (@warn "missing $path"; continue)
        transactions = collect(values(load_transactions(path)))
        grid = GRIDS[ds]
        idxs = clamp.(unique(round.(Int, length(grid) .* [0.34, 0.5, 0.67])), 1, length(grid))
        for s in unique(grid[idxs])
            out, _, _, _, st = run_spmf_fpmax(path, s)
            if st != :ok
                push!(rows, (ds, s, "spmf", -1, -1, -1, 0.0, -1))
                continue
            end
            spmf = read_itemsets_spmf(out)
            algos = Tuple{String, Function}[("opt", () -> mine_opt(transactions, s))]
            s >= BASE_MIN[ds] && push!(algos, ("base", () -> mine_base(transactions, s)))
            for (algo, runfn) in algos
                ours = to_itemset_sets(runfn())
                n_match = count(k -> haskey(ours, k), keys(spmf))
                supp_mis = count(k -> haskey(ours, k) && ours[k] != spmf[k], keys(spmf))
                ratio = isempty(spmf) ? 1.0 : n_match / length(spmf)
                push!(rows, (ds, s, algo, length(ours), length(spmf), n_match,
                             round(ratio; digits = 4), supp_mis))
            end
        end
    end
    write_csv(joinpath(RESULTS, "correctness.csv"),
        ["dataset", "minsup", "algo", "n_ours", "n_spmf", "n_match", "match_ratio", "support_mismatch"],
        rows)
    return rows
end

function exp_timing()
    rows = Vector{Tuple}()
    for ds in DATASETS
        path = dataset_path(ds)
        isfile(path) || (@warn "missing $path"; continue)
        transactions = collect(values(load_transactions(path)))
        for s in GRIDS[ds]
            t, b, n = measure_ours(mine_opt, transactions, s)
            push!(rows, (ds, s, "opt", round(t; digits = 2), b, n, "ok"))

            if s >= BASE_MIN[ds]
                tb, bb, nb = measure_ours(mine_base, transactions, s)
                push!(rows, (ds, s, "base", round(tb; digits = 2), bb, nb, "ok"))
            else
                push!(rows, (ds, s, "base", NaN, -1, -1, "skip"))
            end

            _, ns, ts, mm, stt = run_spmf_fpmax(path, s)
            push!(rows, (ds, s, "spmf", isnan(ts) ? -1.0 : round(ts; digits = 2),
                         isnan(mm) ? -1 : round(Int, mm * 1e6), ns, string(stt)))
        end
    end
    write_csv(joinpath(RESULTS, "timing.csv"),
        ["dataset", "minsup", "algo", "time_ms", "alloc_bytes", "n_maximal", "status"], rows)
    return rows
end

function exp_scalability()
    rows = Vector{Tuple}()
    configs = [("retail", 0.01), ("accidents", 0.7)]
    for (ds, s) in configs
        ds in DATASETS || continue
        path = dataset_path(ds)
        isfile(path) || (@warn "missing $path"; continue)
        for frac in [0.1, 0.25, 0.5, 0.75, 1.0]
            sub = subset_prefix(path, frac)
            transactions = collect(values(load_transactions(sub)))
            nt = length(transactions)
            algos = Tuple{String, Function}[("opt", () -> measure_ours(mine_opt, transactions, s))]
            # base (naive maximal) chỉ chạy trên retail (thưa); accidents dày -> mine-all OOM.
            ds == "retail" && push!(algos, ("base", () -> measure_ours(mine_base, transactions, s)))
            for (algo, runfn) in algos
                t, _, n = runfn()
                push!(rows, (ds, frac, nt, algo, round(t; digits = 2), n, "ok"))
            end
        end
    end
    write_csv(joinpath(RESULTS, "scalability.csv"),
        ["dataset", "fraction", "n_trans", "algo", "time_ms", "n_maximal", "status"], rows)
    return rows
end

function exp_txnlen()
    rows = Vector{Tuple}()
    s = 0.03
    # Chỉ opt (FPMax). base naive-maximal bùng nổ trên giao dịch dài-dày.
    for avg in [5, 10, 15, 20, 25]
        path = gen_synthetic(20000, 100, avg)
        transactions = collect(values(load_transactions(path)))
        t, _, n = measure_ours(mine_opt, transactions, s)
        push!(rows, (avg, "opt", round(t; digits = 2), n, "ok"))
    end
    write_csv(joinpath(RESULTS, "txnlen.csv"),
        ["avg_len", "algo", "time_ms", "n_maximal", "status"], rows)
    return rows
end

const PHASES = haskey(ENV, "EXP_PHASES") ?
    Set(String.(split(ENV["EXP_PHASES"], ","))) :
    Set(["correctness", "timing", "scalability", "txnlen"])

function main()
    mkpath(RESULTS)
    "correctness" in PHASES && (@info "Correctness..."; exp_correctness())
    "timing" in PHASES && (@info "Timing..."; exp_timing())
    "scalability" in PHASES && (@info "Scalability..."; exp_scalability())
    "txnlen" in PHASES && (@info "Txn length..."; exp_txnlen())
    @info "Done. CSV in $RESULTS"
end

main()
```

- [ ] **Step 2: Smoke test on one small config** — run:

```bash
EXP_DATASETS=chess EXP_PHASES=correctness julia --project=. experiments/run_experiments.jl && cat experiments/results/correctness.csv
```
Expected: chess rows with `match_ratio = 1.0` and `support_mismatch = 0` for both `opt` and `base` (`n_ours == n_spmf`).

- [ ] **Step 3: Commit**

```bash
git add experiments/run_experiments.jl
git commit -m "feat: rewire experiments to FPmax (base naive-maximal, opt FPMax, ref SPMF FPMax)"
```

---

### Task 4: Update figures + memory experiment labels

**Files:**
- Modify: `experiments/make_figures.jl`
- Modify: `experiments/measure_memory.jl`

- [ ] **Step 1: Read both files** to find the column name `n_itemsets` and series/title strings referencing "frequent itemset" / "FP-Growth".

Run: `grep -n "n_itemsets\|frequent\|FP-Growth\|itemset" experiments/make_figures.jl experiments/measure_memory.jl`

- [ ] **Step 2: Update `make_figures.jl`** — change the count-CSV column read from `n_itemsets` to `n_maximal`; rename the count-plot axis/title from "Số frequent itemset" to "Số maximal itemset"; keep file names (`count_<ds>.png`, `time_<ds>.png`, etc.) so report `\includegraphics` paths stay valid. If `measure_memory.jl` mines via `get_frequent_itemsets`, switch its mining to `mine_opt`/`mine_base` equivalents (FPMax for opt, naive-maximal for base) so peak-RSS reflects FPmax.

- [ ] **Step 3: Commit**

```bash
git add experiments/make_figures.jl experiments/measure_memory.jl
git commit -m "chore: figures + memory experiment use FPmax maximal counts"
```

---

## Phase B — Run experiments (produce real numbers)

### Task 5: Validate FPMax == SPMF FPMax on two datasets

- [ ] **Step 1: Run correctness on chess + mushrooms**

```bash
EXP_DATASETS=chess,mushrooms EXP_PHASES=correctness julia --project=. experiments/run_experiments.jl
cat experiments/results/correctness.csv
```
Expected: every `opt`/`base` row has `match_ratio = 1.0`, `support_mismatch = 0`, `n_ours == n_spmf`.

- [ ] **Step 2: STOP-gate.** If any mismatch, do not proceed — investigate `get_maximal_itemsets` (support recount / item ordering). Only continue when all match.

---

### Task 6: Full experiment run + figures

- [ ] **Step 1: Run all phases, all datasets** (long; accidents is slow — run in background):

```bash
julia --project=. experiments/run_experiments.jl
```
Expected: `experiments/results/{correctness,timing,scalability,txnlen}.csv` populated; correctness all `1.0`.

- [ ] **Step 2: Memory experiment**

```bash
julia --project=. experiments/measure_memory.jl
```
Expected: `experiments/results/memory.csv` (or the peak-RSS table source) populated.

- [ ] **Step 3: Generate figures**

```bash
julia --project=. experiments/make_figures.jl
```
Expected: `experiments/figures/*.png` regenerated (time_*, count_*, memory, scalability, txnlen).

- [ ] **Step 4: Produce a numbers summary for the report** — print the cells the report will cite:

```bash
column -s, -t experiments/results/correctness.csv
column -s, -t experiments/results/timing.csv
column -s, -t experiments/results/scalability.csv
column -s, -t experiments/results/txnlen.csv
```
Record (for later report tasks): per-dataset opt-vs-base speedup at the lowest base-eligible minsup; #maximal range per dataset across the grid; scalability times at 10%/100%; txnlen times + #maximal jump; memory base vs opt at the mid minsup.

- [ ] **Step 5: Commit data products**

```bash
git add experiments/results/*.csv experiments/figures/*.png
git commit -m "data: regenerate experiment CSVs + figures for FPmax"
```

---

## Phase C — Report rewrite (numbers from Phase B)

> For every report task: write in the existing Vietnamese academic voice (see Style constraint). Build after each edit:
> `cd report && latexmk -pdf -interaction=nonstopmode main.tex` — expected: completes, `main.pdf` updated, no undefined `\ref`/`\cite` warnings for touched labels. Verify cited numbers against the Phase B CSVs.

### Task 7: `introduction.tex` — reframe chosen algorithm

**Files:** Modify `report/content/introduction.tex:6,8`

- [ ] **Step 1:** Rewrite paragraph 2 (line 6) so the chosen algorithm is **FPmax** (cite `\cite{Grahne2003FPMax}` as the implemented paper), and FP-Growth/FP-tree is described as the structure FPmax builds on. State the three implemented pieces as: FP-tree engine (FP-Growth base + optimized), the naive-maximal baseline, and FPMax with superset pruning. Update the roadmap sentence (line 8): Ch2 = two FPMax hand traces (base trace + superset-pruning special case); Ch4 = correctness/timing/maximal-count/memory/scalability/txn-length of FPMax vs SPMF FPMax.

- [ ] **Step 2: Build + commit**

```bash
cd report && latexmk -pdf -interaction=nonstopmode main.tex; cd ..
git add report/content/introduction.tex && git commit -m "docs(report): reframe intro around FPmax"
```

---

### Task 8: `01_theory.tex` — FPmax as the analyzed algorithm

**Files:** Modify `report/content/01_theory.tex`

- [ ] **Step 1:** Keep §"Bài toán FIM" (defs, Apriori, closed/maximal) and §"Cấu trúc dữ liệu FP-tree" + figure. Compress §"Ý tưởng FP-Growth" + §"Giả mã FP-Growth" into one shorter **engine background** subsection (FP-Growth = how the FP-tree is mined; ~1 short pseudocode kept).

- [ ] **Step 2:** Promote the existing §"Thuật toán FP-Max" (lines 150–177) to the centerpiece, expanded: (a) core idea — mine maximal directly, never materialize all frequent; (b) distinctive structures — MFI list with strict-subset subsumption, superset pruning `head∪tail ⊆ existing MFI ⇒ prune branch`, single-path shortcut; (c) annotated FPMax pseudocode (reuse the existing algorithm block, add per-line comments). Remove the self-deprecating sentence (line 177) about FPMax being only a side branch.

- [ ] **Step 3:** Replace the FP-Growth complexity subsection with **FPmax complexity** (keep the two tables' structure, retitle to FP-Max):
  - Time: build phase `O(L log ℓ̄)` shared with FP-Growth; mining bounded by number of maximal itemsets `M` with pruning, but worst case still `O(2^m)` when every frequent set is maximal (anti-chain). Best case single-path → one maximal, `O(L log ℓ̄)`.
  - Space: FP-tree `O(N)` + conditional trees along one branch `O(ℓ̄)` + MFI list `O(M·ℓ̄)` + final support recount.
  - Tie to Ch4: maximal-count curve and txn-length jump (cite `\ref{tab:txnlen}` / count figure).

- [ ] **Step 4:** Update §"Vị trí lịch sử": Apriori → FP-Growth → FPmax* (Grahne & Zhu 2003); what FPmax improves (output compression, superset pruning), what it leaves (cannot recover subset supports without rescanning → motivates Ch5 engine choice).

- [ ] **Step 5: Build + commit**

```bash
cd report && latexmk -pdf -interaction=nonstopmode main.tex; cd ..
git add report/content/01_theory.tex && git commit -m "docs(report): make FPmax the analyzed algorithm in theory"
```

---

### Task 9: `02_example.tex` — two FPMax hand traces

**Files:** Rewrite `report/content/02_example.tex`

- [ ] **Step 1: Ex1 (base FPMax trace).** Keep the toy DB table (T1={1,3,4}…T5={1,2,3,5}, minsup_abs 3) and reference `\ref{fig:fptree-toy}`. Write the trace: item counts → drop item 4 → tree-build order (support desc) 2,3,5,1 → FPMax processes header **support-ascending** 1,2,3,5. Walk the MFI list exactly:
  - item 1: cond base `(3):1, (2,3,5):2`; tail `{3}`; candidate `{1,3}` → MFI `[{1,3}]`.
  - item 2: empty base; candidate `{2}` → MFI `[{1,3},{2}]`.
  - item 3: base `(2):3`; tail `{2}`; candidate `{2,3}` → drops `{2}` → MFI `[{1,3},{2,3}]`.
  - item 5: base `(2,3):3,(2):1`; tail `{2,3}`; conditional tree single-path → candidate `{2,3,5}` → drops `{2,3}` → MFI `[{1,3},{2,3,5}]`.
  - Result `{1,3}:3, {2,3,5}:3`. Cross-check: list all 9 frequent (reuse from old text), filter to the 2 maximal. Highlight the MFI subsumption mechanism.

- [ ] **Step 2: Ex2 (superset pruning special case).** New DB table: T1=T2=T3={a,b,c}, T4=T5=T6={a,b,d}, minsup_abs 3 (θ=0.5). Counts a:6,b:6,c:3,d:3; tree-build order a,b,c,d; tree `root→a:6→b:6→{c:3,d:3}` (b has 2 children ⇒ not single path). Header ascending c,d,a,b. Trace:
  - item c: base `(a,b):3`; tail `{a,b}`; candidate `{a,b,c}` → MFI `[{a,b,c}]`.
  - item d: base `(a,b):3`; tail `{a,b}`; candidate `{a,b,d}` → MFI `[{a,b,c},{a,b,d}]`.
  - item a: empty base; `{a} ⊆ {a,b,c}` ⇒ **pruned**.
  - item b: base `(a):6`; tail `{a}`; `head∪tail={a,b} ⊆ {a,b,c}` ⇒ **branch pruned, conditional tree not built** (the highlight).
  - Result `{a,b,c}:3, {a,b,d}:3` (verified vs code). Analysis: superset pruning is FPmax's defining optimization vs FP-Growth (which must emit every frequent subset); add the single-path contrast (length-k path → FP-Growth `2^k−1` frequent vs FPMax 1 maximal).

- [ ] **Step 3: Build + commit**

```bash
cd report && latexmk -pdf -interaction=nonstopmode main.tex; cd ..
git add report/content/02_example.tex && git commit -m "docs(report): rewrite Ch2 hand examples as FPMax traces"
```

---

### Task 10: `03_code.tex` — FPMax primary + naive-vs-prune optimization

**Files:** Modify `report/content/03_code.tex`

- [ ] **Step 1:** Promote §"Cài đặt FP-Max" (lines 111–115) to a full primary section: `FPMax` struct, `get_maximal_itemsets`, `insert_mfi!` (subset subsumption), the superset-pruning check, single-path shortcut, final `support_in_transactions` recount. Mention `maximal_from_frequent` as the naive baseline.

- [ ] **Step 2:** Keep FP-Growth base/opt as "the FP-tree engine" (integer encoding, typed header, `@inbounds`, type-stability evidence). Reframe the alloc table `\ref{tab:perf-alloc}`: change the measured optimization story to **naive-maximal (base) vs FPMax-prune (opt)** using Phase B `timing.csv` alloc numbers; update the table caption + numbers accordingly. (Pull exact base/opt MB at chess minsups from `timing.csv`.)

- [ ] **Step 3:** Update §"Kiểm thử tự động" to foreground the FPMax correctness test (`{1,3},{2,3,5}`) and add the `maximal_from_frequent` test; mention the new test count.

- [ ] **Step 4: Build + commit**

```bash
cd report && latexmk -pdf -interaction=nonstopmode main.tex; cd ..
git add report/content/03_code.tex && git commit -m "docs(report): FPMax-primary implementation chapter"
```

---

### Task 11: `04_evaluation.tex` — rewrite around FPmax numbers

**Files:** Rewrite `report/content/04_evaluation.tex`

- [ ] **Step 1:** Update the algorithms-compared list: `base` = naive-maximal (FPGrowthOpt mine-all + filter), `opt` = FPMax (direct, MFI pruning), `spmf` = SPMF FPMax. Update the intro paragraph + skip-logic note (base skipped on dense/low-minsup because naive mine-all blows up; accidents always skip base).

- [ ] **Step 2:** §Correctness — rewrite from new `correctness.csv`: `match_ratio = 1.0`, `support_mismatch = 0`; rebuild `\ref{tab:correctness-summary}` rows with the new `#maximal` (#Ours/#SPMF) per dataset.

- [ ] **Step 3:** §Timing — rewrite per-dataset paragraphs (chess/mushrooms/retail/T10I4D100K/accidents) from new `timing.csv`: opt-vs-base speedups, opt-vs-SPMF. Figures `time_<ds>.png` already regenerated.

- [ ] **Step 4:** §Count — retitle to "Số lượng maximal itemset theo minsup"; rewrite from `timing.csv` `n_maximal` column; figures `count_chess.png`, `count_retail.png`. Compare dense vs sparse maximal growth.

- [ ] **Step 5:** §Memory — rewrite base/opt alloc + peak-RSS table `\ref{tab:peak-rss}` from regenerated `memory.csv`.

- [ ] **Step 6:** §Scalability + §Txn-length — rewrite from `scalability.csv` / `txnlen.csv` (now `n_maximal`). Keep the theory tie-in.

- [ ] **Step 7:** §Nhận xét — strengths/weaknesses of FPMax vs SPMF FPMax + ≥2 concrete next optimizations (e.g. Int-encoded FPMax tree; MFI-tree superset test instead of linear MFI-list scan).

- [ ] **Step 8: Build + commit**

```bash
cd report && latexmk -pdf -interaction=nonstopmode main.tex; cd ..
git add report/content/04_evaluation.tex && git commit -m "docs(report): rewrite Ch4 around FPmax experiments"
```

---

### Task 12: `05_application.tex` — justify FP-Growth engine

**Files:** Modify `report/content/05_application.tex:22`

- [ ] **Step 1:** Add one sentence in §"Dữ liệu và thiết lập": association rules need the support of every itemset (antecedent, consequent, union), which maximal sets do not retain, so the full-frequent FP-Growth engine is used here while FPMax remains the chosen algorithm for compact maximal patterns. Verify the 333 frequent / 231 rules numbers still reproduce:

```bash
julia --project=. experiments/application.jl | tail -5
```
Expected: 333 frequent itemsets, 231 rules. If changed, update the numbers in the text + table.

- [ ] **Step 2: Build + commit**

```bash
cd report && latexmk -pdf -interaction=nonstopmode main.tex; cd ..
git add report/content/05_application.tex && git commit -m "docs(report): justify FP-Growth engine for rule mining in Ch5"
```

---

### Task 13: `README.md` — retitle + refreshed test block

**Files:** Modify `README.md`

- [ ] **Step 1:** Retitle to FPmax; describe FP-Growth as the engine; keep the `fp-max` CLI example as the headline run. Re-run tests and paste the actual final summary:

```bash
julia --project=. test/runtests.jl 2>&1 | tail -20
```
Update the test-output block (line ~100–108) with the real pass counts (now includes `maximal_from_frequent`).

- [ ] **Step 2: Commit**

```bash
git add README.md && git commit -m "docs: README retitle to FPmax + refresh test output"
```

---

### Task 14: Final verification

- [ ] **Step 1: Full test suite**

```bash
julia --project=. test/runtests.jl
```
Expected: all pass (incl. FP-Max + maximal_from_frequent).

- [ ] **Step 2: Full PDF build, check page count + refs**

```bash
cd report && latexmk -pdf -interaction=nonstopmode main.tex; cd ..
```
Expected: builds clean; `main.pdf` ≥ 15 pages excl. refs/appendix; no undefined references/citations in log.

- [ ] **Step 3: Copy PDF to docs**

```bash
cp report/main.pdf docs/Report.pdf
git add docs/Report.pdf && git commit -m "docs: rebuild Report.pdf for FPmax realign"
```

- [ ] **Step 4: Grep sanity** — confirm no stray "thực nghiệm chính tập trung vào FP-Growth" or FP-Growth-as-chosen framing remains:

```bash
grep -rn "tập trung vào FP-Growth\|lựa chọn họ thuật toán FP-Growth\|chọn.*FP-Growth" report/content README.md
```
Expected: no hits (or only engine-background mentions).

---

## Self-Review

**Spec coverage:** intro (T7), theory incl. FPmax complexity/history (T8), Ch2 both traces (T9), Ch3 FPMax-primary + naive-vs-prune optimization (T10), Ch4 all six experiments (T11), Ch5 engine justification (T12), README (T13), spmf_runner FPMax (T2), run_experiments rewire (T3), figures/memory (T4), validation (T5–6, T14). All spec sections mapped.

**Placeholder scan:** code tasks contain full code; report tasks specify exact structure + which CSV cell feeds which sentence (numbers genuinely come from Phase B, not inventable). No "TODO"/"handle edge cases".

**Type consistency:** `maximal_from_frequent(Dict{Tuple{Vararg{String}},Int}) → Dict{Tuple{Vararg{String}},Int}`; `mine_opt`/`mine_base` both `(transactions, s) → Dict`; `measure_ours(mine, transactions, s)`; `run_spmf_fpmax` returns the same 5-tuple as `run_spmf`; CSV column renamed `n_itemsets → n_maximal` consistently across run_experiments + make_figures (T4 Step 2).
