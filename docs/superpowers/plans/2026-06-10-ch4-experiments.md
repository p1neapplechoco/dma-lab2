# Chương 4 — Thực nghiệm & đánh giá — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Harness thực nghiệm FP-Growth (base/opt) đối chiếu SPMF, sinh CSV + đồ thị, phủ req 3.4.2 (a–f).

**Architecture:** Script `.jl` chạy compute nặng → `experiments/results/*.csv`. SPMF chạy qua Java (`spmf.jar`), parse stdout lấy count/time/mem. Script `make_figures.jl` (Plots) + `notebooks/demo.ipynb` đọc CSV vẽ đồ thị.

**Tech Stack:** Julia ≥1.9, package FrequentItemsetMining, SPMF 2.42 (Java 26), Plots.jl, IJulia.

---

## File Structure

- `experiments/spmf_runner.jl` — chạy SPMF + parse output/stats (CREATE)
- `experiments/datagen.jl` — subset + synthetic generators (CREATE)
- `experiments/run_experiments.jl` — driver → CSV (CREATE)
- `experiments/make_figures.jl` — đọc CSV → PNG (CREATE)
- `experiments/results/*.csv` — output (commit)
- `experiments/figures/*.png` — output (commit)
- `notebooks/demo.ipynb` — demo + đồ thị (CREATE)
- `Project.toml` — thêm Plots, IJulia (MODIFY)

Note môi trường: `experiments/spmf/spmf.jar` đã tải, Java 26 đã cài. Các dataset ở `data/benchmark/`.

---

## Task 1: spmf_runner.jl — chạy SPMF + parse

**Files:** Create `experiments/spmf_runner.jl`

- [ ] **Step 1: Viết file**

```julia
using FrequentItemsetMining

const SPMF_JAR = joinpath(@__DIR__, "spmf", "spmf.jar")

# Chạy SPMF FPGrowth_itemsets. Trả (out_path, n_itemsets, time_ms, mem_mb, status).
function run_spmf(input::String, minsup::Float64; timeout_s::Int = 120)
    isfile(SPMF_JAR) || error("spmf.jar not found at $SPMF_JAR")
    out_path = tempname() * ".txt"
    log_path = tempname() * ".log"
    cmd = `java -jar $SPMF_JAR run FPGrowth_itemsets $input $out_path $(string(minsup))`

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
            m = match(r"Frequent itemsets count\s*:\s*(\d+)", text)
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

# Đọc file output SPMF -> Dict{Set{String}, Int} (chuẩn hoá để so).
function read_itemsets_spmf(path::String)::Dict{Set{String}, Int}
    result = Dict{Set{String}, Int}()
    isfile(path) || return result
    for line in eachline(path)
        s = strip(line)
        isempty(s) && continue
        parts = split(s, "#SUP:")
        length(parts) != 2 && continue
        items = Set(String.(split(strip(parts[1]))))
        supp = parse(Int, strip(parts[2]))
        result[items] = supp
    end
    return result
end

# Output bản nhóm -> cùng dạng Set để so.
function to_itemset_sets(d::Dict{Tuple{Vararg{String}}, Int})::Dict{Set{String}, Int}
    out = Dict{Set{String}, Int}()
    for (k, v) in d
        out[Set(k)] = v
    end
    return out
end
```

- [ ] **Step 2: Smoke test run_spmf + so với opt**

```bash
cd "/home/lesliu/Documents/school/25_26_Semester_2/data-mining/lab2"
julia --project=. -e '
using FrequentItemsetMining
include("experiments/spmf_runner.jl")
out, n, t, mem, st = run_spmf("data/benchmark/chess.txt", 0.95)
println("spmf status=$st n=$n time=$t mem=$mem")
spmf = read_itemsets_spmf(out)
m = FPGrowthOpt(0.95); fit!(m, collect(values(load_transactions("data/benchmark/chess.txt"))))
ours = to_itemset_sets(get_frequent_itemsets(m))
println("ours=$(length(ours)) spmf=$(length(spmf)) equal=$(ours==spmf)")'
```
Expected: `status=ok n=77 ...`; `ours=77 spmf=77 equal=true`.

- [ ] **Step 3: Commit**

```bash
git add experiments/spmf_runner.jl
git commit -m "feat: SPMF runner + output parser for Ch4 experiments"
```

---

## Task 2: datagen.jl — subset + synthetic

**Files:** Create `experiments/datagen.jl`

- [ ] **Step 1: Viết file**

```julia
using Random

const TMP_DIR = joinpath(@__DIR__, "tmp")

function _ensure_tmp()
    isdir(TMP_DIR) || mkpath(TMP_DIR)
    return TMP_DIR
end

# Lấy `fraction` giao dịch đầu (deterministic prefix).
function subset_prefix(input::String, fraction::Float64)::String
    _ensure_tmp()
    lines = readlines(input)
    n = max(1, round(Int, fraction * length(lines)))
    tag = replace(string(fraction), "." => "")
    out = joinpath(TMP_DIR, "subset_$(splitext(basename(input))[1])_$(tag).txt")
    open(out, "w") do io
        for i in 1:n
            println(io, lines[i])
        end
    end
    return out
end

# CSDL tổng hợp: n_trans giao dịch, item 1..n_items, độ dài ~ avg_len (Gaussian, clamp).
function gen_synthetic(n_trans::Int, n_items::Int, avg_len::Int; seed::Int = 42)::String
    _ensure_tmp()
    rng = MersenneTwister(seed + avg_len)
    out = joinpath(TMP_DIR, "synth_n$(n_trans)_i$(n_items)_l$(avg_len).txt")
    open(out, "w") do io
        for _ in 1:n_trans
            len = round(Int, avg_len + randn(rng) * (avg_len / 4))
            len = clamp(len, 1, n_items)
            items = randperm(rng, n_items)[1:len]
            println(io, join(sort(items), " "))
        end
    end
    return out
end
```

- [ ] **Step 2: Smoke test**

```bash
cd "/home/lesliu/Documents/school/25_26_Semester_2/data-mining/lab2"
julia --project=. -e '
include("experiments/datagen.jl")
s = subset_prefix("data/benchmark/retail.txt", 0.1)
println("subset lines=", length(readlines(s)))
g = gen_synthetic(1000, 100, 10)
ls = readlines(g); avg = sum(length(split(l)) for l in ls)/length(ls)
println("synth lines=", length(ls), " avg_len≈", round(avg; digits=1))'
```
Expected: `subset lines=8817` (≈10% của 88162→ thực tế round(0.1*88162)); `synth lines=1000 avg_len≈10.x`.

- [ ] **Step 3: Commit**

```bash
git add experiments/datagen.jl
git commit -m "feat: dataset generators (prefix subset + synthetic) for Ch4"
```

---

## Task 3: run_experiments.jl — khung + correctness

**Files:** Create `experiments/run_experiments.jl`

- [ ] **Step 1: Viết khung (config, measure, write_csv) + exp_correctness + main tạm gọi correctness**

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

# minsup tối thiểu để còn chạy base (tránh blowup ~mũ). Dưới ngưỡng -> skip base.
const BASE_MIN = Dict(
    "chess" => 0.8, "mushrooms" => 0.25, "retail" => 0.001,
    "T10I4D100K" => 0.001, "accidents" => 0.7,
)

dataset_path(name) = joinpath(@__DIR__, "..", "data", "benchmark", "$(name).txt")

# Đo (time_ms, alloc_bytes, n_itemsets) cho 1 lần chạy bản nhóm, warm-up loại JIT.
function measure_ours(ctor, transactions)
    let m = ctor()
        fit!(m, deepcopy(transactions)); get_frequent_itemsets(m)
    end
    stats = @timed begin
        mm = ctor(); fit!(mm, deepcopy(transactions)); get_frequent_itemsets(mm)
    end
    return (stats.time * 1e3, stats.bytes, length(stats.value))
end

function write_csv(path, header, rows)
    mkpath(dirname(path))
    open(path, "w") do io
        println(io, join(header, ","))
        for r in sort(rows; by = r -> (string(r[1]), Float64(r[2]), string(r[3])))
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
            out, _, _, _, st = run_spmf(path, s)
            if st != :ok
                push!(rows, (ds, s, "spmf", -1, -1, -1, 0.0, -1))
                continue
            end
            spmf = read_itemsets_spmf(out)
            algos = Tuple{String, Function}[("opt", () -> FPGrowthOpt(s))]
            s >= BASE_MIN[ds] && push!(algos, ("base", () -> FPGrowth(s)))
            for (algo, ctor) in algos
                m = ctor(); fit!(m, deepcopy(transactions))
                ours = to_itemset_sets(get_frequent_itemsets(m))
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

function main()
    mkpath(RESULTS)
    @info "Correctness..."; exp_correctness()
    @info "Done. CSV in $RESULTS"
end

main()
```

- [ ] **Step 2: Chạy correctness trên subset nhanh (chess, mushrooms)**

```bash
cd "/home/lesliu/Documents/school/25_26_Semester_2/data-mining/lab2"
EXP_DATASETS=chess,mushrooms julia --project=. experiments/run_experiments.jl
echo "--- correctness.csv ---"; cat experiments/results/correctness.csv
```
Expected: mọi dòng `match_ratio=1.0` và `support_mismatch=0` (cả opt lẫn base).

- [ ] **Step 3: Commit**

```bash
git add experiments/run_experiments.jl experiments/results/correctness.csv
git commit -m "feat: experiment driver + correctness vs SPMF (ratio=1.0)"
```

---

## Task 4: run_experiments.jl — timing (b,c,d)

**Files:** Modify `experiments/run_experiments.jl`

- [ ] **Step 1: Thêm exp_timing + gọi trong main**

Thêm hàm trước `function main()`:

```julia
function exp_timing()
    rows = Vector{Tuple}()
    for ds in DATASETS
        path = dataset_path(ds)
        isfile(path) || (@warn "missing $path"; continue)
        transactions = collect(values(load_transactions(path)))
        for s in GRIDS[ds]
            t, b, n = measure_ours(() -> FPGrowthOpt(s), transactions)
            push!(rows, (ds, s, "opt", round(t; digits = 2), b, n, "ok"))

            if s >= BASE_MIN[ds]
                tb, bb, nb = measure_ours(() -> FPGrowth(s), transactions)
                push!(rows, (ds, s, "base", round(tb; digits = 2), bb, nb, "ok"))
            else
                push!(rows, (ds, s, "base", NaN, -1, -1, "skip"))
            end

            _, ns, ts, mm, stt = run_spmf(path, s)
            push!(rows, (ds, s, "spmf", isnan(ts) ? -1.0 : round(ts; digits = 2),
                         isnan(mm) ? -1 : round(Int, mm * 1e6), ns, string(stt)))
        end
    end
    write_csv(joinpath(RESULTS, "timing.csv"),
        ["dataset", "minsup", "algo", "time_ms", "alloc_bytes", "n_itemsets", "status"], rows)
    return rows
end
```

Sửa `main()` thêm dòng sau correctness:
```julia
    @info "Timing..."; exp_timing()
```

- [ ] **Step 2: Chạy timing nhanh (chess)**

```bash
cd "/home/lesliu/Documents/school/25_26_Semester_2/data-mining/lab2"
EXP_DATASETS=chess julia --project=. experiments/run_experiments.jl
echo "--- timing.csv ---"; cat experiments/results/timing.csv
```
Expected: với mỗi minsup có 3 dòng (opt/base/spmf); cột n_itemsets của opt và spmf bằng nhau ở các điểm có base; thời gian opt ≤ base.

- [ ] **Step 3: Commit**

```bash
git add experiments/run_experiments.jl experiments/results/timing.csv
git commit -m "feat: timing/itemset-count/memory experiment (b,c,d)"
```

---

## Task 5: run_experiments.jl — scalability (e) + txn-length (f)

**Files:** Modify `experiments/run_experiments.jl`

- [ ] **Step 1: Thêm exp_scalability + exp_txnlen + gọi trong main**

Thêm hai hàm trước `function main()`:

```julia
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
            for (algo, ctor) in [("opt", () -> FPGrowthOpt(s)), ("base", () -> FPGrowth(s))]
                t, _, n = measure_ours(ctor, transactions)
                push!(rows, (ds, frac, nt, algo, round(t; digits = 2), n, "ok"))
            end
        end
    end
    write_csv(joinpath(RESULTS, "scalability.csv"),
        ["dataset", "fraction", "n_trans", "algo", "time_ms", "n_itemsets", "status"], rows)
    return rows
end

function exp_txnlen()
    rows = Vector{Tuple}()
    s = 0.05
    for avg in [5, 10, 15, 20, 25]
        path = gen_synthetic(20000, 100, avg)
        transactions = collect(values(load_transactions(path)))
        for (algo, ctor) in [("opt", () -> FPGrowthOpt(s)), ("base", () -> FPGrowth(s))]
            t, _, n = measure_ours(ctor, transactions)
            push!(rows, (avg, algo, round(t; digits = 2), n, "ok"))
        end
    end
    write_csv(joinpath(RESULTS, "txnlen.csv"),
        ["avg_len", "algo", "time_ms", "n_itemsets", "status"], rows)
    return rows
end
```

Note `write_csv` sort key dùng `r[1],r[2],r[3]`: txnlen rows có `r[1]=avg_len::Int`, `r[2]=algo::String` → `Float64(r[2])` sẽ lỗi. Sửa `write_csv` cho linh hoạt: đổi dòng sort thành:
```julia
        for r in sort(rows; by = r -> string.(r))
```
(so sánh theo string của toàn tuple — ổn định, không phụ thuộc kiểu cột).

Sửa `main()` thêm sau timing:
```julia
    @info "Scalability..."; exp_scalability()
    @info "Txn length..."; exp_txnlen()
```

- [ ] **Step 2: Chạy nhanh (retail scalability + txnlen) — bỏ accidents cho nhanh**

```bash
cd "/home/lesliu/Documents/school/25_26_Semester_2/data-mining/lab2"
EXP_DATASETS=retail julia --project=. experiments/run_experiments.jl
echo "--- scalability.csv ---"; cat experiments/results/scalability.csv
echo "--- txnlen.csv ---"; cat experiments/results/txnlen.csv
```
Expected: scalability có 5 fraction × 2 algo cho retail; n_trans tăng theo fraction; time tăng. txnlen có 5 avg_len × 2 algo; n_itemsets > 0 (nếu toàn 0 → giảm minsup s trong exp_txnlen).

- [ ] **Step 3: Commit**

```bash
git add experiments/run_experiments.jl experiments/results/scalability.csv experiments/results/txnlen.csv
git commit -m "feat: scalability (e) and avg-txn-length (f) experiments"
```

---

## Task 6: Full run — sinh đủ CSV cho cả 5 dataset

**Files:** experiments/results/*.csv (regenerate)

- [ ] **Step 1: Chạy full (có thể lâu 10–30+ phút do accidents + SPMF minsup thấp)**

```bash
cd "/home/lesliu/Documents/school/25_26_Semester_2/data-mining/lab2"
julia --project=. experiments/run_experiments.jl 2>&1 | tail -20
```
Expected: log "Correctness/Timing/Scalability/Txn length/Done"; 4 CSV cập nhật đủ 5 dataset (accidents có thể vài dòng base=skip, spmf=timeout — chấp nhận, ghi status).

- [ ] **Step 2: Kiểm correctness toàn bộ = khớp**

```bash
cd "/home/lesliu/Documents/school/25_26_Semester_2/data-mining/lab2"
awk -F, 'NR>1 && $3!="spmf" {print $1,$3,$7,$8}' experiments/results/correctness.csv
```
Expected: mọi dòng cột match_ratio (cột 7) = 1.0 và support_mismatch (cột 8) = 0.

- [ ] **Step 3: Commit**

```bash
git add experiments/results/*.csv
git commit -m "data: full experiment results across 5 benchmark datasets"
```

---

## Task 7: make_figures.jl — vẽ đồ thị từ CSV

**Files:**
- Modify `Project.toml` (thêm Plots)
- Create `experiments/make_figures.jl`

- [ ] **Step 1: Thêm Plots vào project**

```bash
cd "/home/lesliu/Documents/school/25_26_Semester_2/data-mining/lab2"
julia --project=. -e 'import Pkg; Pkg.add("Plots")'
```
Expected: Plots cài + precompile xong (lần đầu vài phút).

- [ ] **Step 2: Viết `experiments/make_figures.jl`**

```julia
ENV["GKSwstype"] = "100"   # GR headless, không cần display
using Plots
gr()

const RESULTS = joinpath(@__DIR__, "results")
const FIGURES = joinpath(@__DIR__, "figures")

function read_csv(path)
    lines = readlines(path)
    header = String.(split(lines[1], ","))
    rows = [String.(split(l, ",")) for l in lines[2:end] if !isempty(strip(l))]
    return header, rows
end

col(header, rows, name) = [r[findfirst(==(name), header)] for r in rows]

fnum(x) = (v = tryparse(Float64, x); v === nothing ? NaN : v)

function fig_time_and_count()
    header, rows = read_csv(joinpath(RESULTS, "timing.csv"))
    datasets = unique(col(header, rows, "dataset"))
    for ds in datasets
        drows = [r for r in rows if r[findfirst(==("dataset"), header)] == ds]
        # time vs minsup
        p = plot(title = "Time vs minsup — $ds", xlabel = "minsup", ylabel = "time (ms)",
                 yscale = :log10, legend = :topright)
        for algo in ["base", "opt", "spmf"]
            ar = [r for r in drows if r[findfirst(==("algo"), header)] == algo &&
                  r[findfirst(==("status"), header)] in ("ok",)]
            isempty(ar) && continue
            x = fnum.(col(header, ar, "minsup"))
            y = fnum.(col(header, ar, "time_ms"))
            keep = .!isnan.(y) .& (y .> 0)
            any(keep) && plot!(p, x[keep], y[keep]; marker = :circle, label = algo)
        end
        savefig(p, joinpath(FIGURES, "time_$(ds).png"))

        # #itemsets vs minsup (dùng opt; opt==base==spmf)
        ar = [r for r in drows if r[findfirst(==("algo"), header)] == "opt"]
        x = fnum.(col(header, ar, "minsup"))
        y = fnum.(col(header, ar, "n_itemsets"))
        pc = plot(x, y; marker = :square, title = "#Frequent itemsets vs minsup — $ds",
                  xlabel = "minsup", ylabel = "#itemsets", yscale = :log10, legend = false)
        savefig(pc, joinpath(FIGURES, "count_$(ds).png"))
    end
end

function fig_memory()
    header, rows = read_csv(joinpath(RESULTS, "timing.csv"))
    # tại minsup giữa grid mỗi dataset: lấy dòng base có status ok + opt tương ứng
    datasets = unique(col(header, rows, "dataset"))
    labels = String[]; base_mb = Float64[]; opt_mb = Float64[]
    for ds in datasets
        drows = [r for r in rows if r[findfirst(==("dataset"), header)] == ds &&
                 r[findfirst(==("status"), header)] == "ok"]
        baserows = [r for r in drows if r[findfirst(==("algo"), header)] == "base"]
        isempty(baserows) && continue
        mid = baserows[cld(length(baserows), 2)]
        ms = mid[findfirst(==("minsup"), header)]
        optrow = findfirst(r -> r[findfirst(==("algo"), header)] == "opt" &&
                                r[findfirst(==("minsup"), header)] == ms, drows)
        optrow === nothing && continue
        push!(labels, "$ds@$ms")
        push!(base_mb, fnum(mid[findfirst(==("alloc_bytes"), header)]) / 1e6)
        push!(opt_mb, fnum(drows[optrow][findfirst(==("alloc_bytes"), header)]) / 1e6)
    end
    n = length(labels)
    p = bar(1:n, base_mb; label = "base", bar_width = 0.4,
            xticks = (1:n, labels), xrotation = 30, ylabel = "MB",
            title = "Allocated memory (base vs opt)", legend = :topright)
    bar!(p, (1:n) .+ 0.4, opt_mb; label = "opt", bar_width = 0.4)
    savefig(p, joinpath(FIGURES, "memory.png"))
end

function fig_scalability()
    header, rows = read_csv(joinpath(RESULTS, "scalability.csv"))
    datasets = unique(col(header, rows, "dataset"))
    p = plot(title = "Scalability: time vs #transactions", xlabel = "#transactions",
             ylabel = "time (ms)", legend = :topleft)
    for ds in datasets, algo in ["base", "opt"]
        ar = [r for r in rows if r[findfirst(==("dataset"), header)] == ds &&
              r[findfirst(==("algo"), header)] == algo]
        isempty(ar) && continue
        x = fnum.(col(header, ar, "n_trans"))
        y = fnum.(col(header, ar, "time_ms"))
        o = sortperm(x)
        plot!(p, x[o], y[o]; marker = :circle, label = "$ds-$algo")
    end
    savefig(p, joinpath(FIGURES, "scalability.png"))
end

function fig_txnlen()
    header, rows = read_csv(joinpath(RESULTS, "txnlen.csv"))
    p = plot(title = "Time vs avg transaction length", xlabel = "avg length",
             ylabel = "time (ms)", legend = :topleft)
    for algo in ["base", "opt"]
        ar = [r for r in rows if r[findfirst(==("algo"), header)] == algo]
        isempty(ar) && continue
        x = fnum.(col(header, ar, "avg_len"))
        y = fnum.(col(header, ar, "time_ms"))
        o = sortperm(x)
        plot!(p, x[o], y[o]; marker = :circle, label = algo)
    end
    savefig(p, joinpath(FIGURES, "txnlen.png"))
end

function main()
    mkpath(FIGURES)
    fig_time_and_count()
    fig_memory()
    fig_scalability()
    fig_txnlen()
    println("Figures written to $FIGURES")
end

main()
```

- [ ] **Step 3: Chạy + verify PNG sinh ra**

```bash
cd "/home/lesliu/Documents/school/25_26_Semester_2/data-mining/lab2"
julia --project=. experiments/make_figures.jl
ls -la experiments/figures/
```
Expected: in "Figures written to ..."; có các PNG time_*, count_*, memory.png, scalability.png, txnlen.png.

- [ ] **Step 4: Commit**

```bash
git add Project.toml Manifest.toml experiments/make_figures.jl experiments/figures/*.png
git commit -m "feat: figure generation from experiment CSVs (Plots)"
```

---

## Task 8: notebooks/demo.ipynb — demo + đồ thị

**Files:**
- Modify `Project.toml` (thêm IJulia)
- Create `notebooks/demo.ipynb`

- [ ] **Step 1: Thêm IJulia**

```bash
cd "/home/lesliu/Documents/school/25_26_Semester_2/data-mining/lab2"
julia --project=. -e 'import Pkg; Pkg.add("IJulia")'
```
Expected: IJulia cài xong.

- [ ] **Step 2: Tạo `notebooks/demo.ipynb`** (JSON notebook, kernel julia)

Ghi file với nội dung sau (5 cell: setup, demo thuật toán, rồi 4 cell hiển thị hình từ experiments/figures qua `Images`/markdown — dùng cell code đọc PNG bằng `FileIO`/`load` nếu có, hoặc đơn giản include make_figures và hiển thị). Dùng nội dung tối giản, chắc chạy:

```json
{
 "cells": [
  {"cell_type":"markdown","metadata":{},"source":["# FP-Growth — Demo & Thực nghiệm (Chương 4)\n","Notebook minh hoạ thuật toán và hiển thị đồ thị thực nghiệm."]},
  {"cell_type":"code","execution_count":null,"metadata":{},"outputs":[],"source":[
    "import Pkg; Pkg.activate(joinpath(@__DIR__, \"..\"))\n",
    "using FrequentItemsetMining"]},
  {"cell_type":"markdown","metadata":{},"source":["## 1. Demo trên CSDL đồ chơi"]},
  {"cell_type":"code","execution_count":null,"metadata":{},"outputs":[],"source":[
    "tx = collect(values(load_transactions(joinpath(@__DIR__, \"..\", \"data\", \"toy\", \"test_1.txt\"))))\n",
    "m = FPGrowthOpt(0.6); fit!(m, tx)\n",
    "get_frequent_itemsets(m)"]},
  {"cell_type":"markdown","metadata":{},"source":["## 2. Sinh đồ thị thực nghiệm từ CSV"]},
  {"cell_type":"code","execution_count":null,"metadata":{},"outputs":[],"source":[
    "include(joinpath(@__DIR__, \"..\", \"experiments\", \"make_figures.jl\"))"]},
  {"cell_type":"markdown","metadata":{},"source":["## 3. Hiển thị đồ thị"]},
  {"cell_type":"code","execution_count":null,"metadata":{},"outputs":[],"source":[
    "using Base64\n",
    "figdir = joinpath(@__DIR__, \"..\", \"experiments\", \"figures\")\n",
    "for f in sort(readdir(figdir))\n",
    "    endswith(f, \".png\") || continue\n",
    "    display(\"text/markdown\", \"**$f**\")\n",
    "    display(MIME(\"image/png\"), read(joinpath(figdir, f)))\n",
    "end"]}
 ],
 "metadata": {
  "kernelspec": {"display_name":"Julia","language":"julia","name":"julia"},
  "language_info": {"name":"julia"}
 },
 "nbformat": 4,
 "nbformat_minor": 5
}
```

Tạo file bằng cách ghi đúng JSON trên vào `notebooks/demo.ipynb` (dùng Write tool, không qua shell heredoc).

- [ ] **Step 3: Verify notebook hợp lệ (JSON parse) + demo cell logic chạy được ngoài notebook**

```bash
cd "/home/lesliu/Documents/school/25_26_Semester_2/data-mining/lab2"
julia --project=. -e 'using JSON; @assert haskey(JSON.parsefile("notebooks/demo.ipynb"),"cells"); println("notebook JSON ok")' 2>/dev/null || python -c 'import json,sys; json.load(open("notebooks/demo.ipynb")); print("notebook JSON ok")'
julia --project=. -e '
using FrequentItemsetMining
tx = collect(values(load_transactions("data/toy/test_1.txt")))
m = FPGrowthOpt(0.6); fit!(m, tx)
@assert length(get_frequent_itemsets(m)) == 9
println("demo logic ok")'
```
Expected: `notebook JSON ok`; `demo logic ok`.

- [ ] **Step 4: (Best-effort) Thực thi notebook nếu jupyter có**

```bash
cd "/home/lesliu/Documents/school/25_26_Semester_2/data-mining/lab2"
if command -v jupyter >/dev/null 2>&1; then
  julia --project=. -e 'using IJulia; installkernel("Julia", "--project=@.")' 2>/dev/null || true
  jupyter nbconvert --to notebook --execute --inplace notebooks/demo.ipynb \
    --ExecutePreprocessor.timeout=600 && echo "notebook executed"
else
  echo "jupyter not installed — skip execute (notebook validated by JSON + logic checks)"
fi
```
Expected: hoặc `notebook executed`, hoặc thông báo skip (không phải lỗi).

- [ ] **Step 5: Commit**

```bash
git add Project.toml Manifest.toml notebooks/demo.ipynb
git commit -m "feat: demo notebook (algorithm demo + experiment figures)"
```

---

## Done criteria
- `julia --project=. experiments/run_experiments.jl` sinh đủ 4 CSV cho 5 dataset.
- correctness.csv: match_ratio=1.0, support_mismatch=0 cho opt & base (mọi điểm chạy được).
- `experiments/make_figures.jl` sinh đủ PNG (time/count/memory/scalability/txnlen).
- `notebooks/demo.ipynb` JSON hợp lệ, demo logic đúng (9 itemset trên test_1).
- Đồ thị cho thấy opt nhanh hơn + ít memory hơn base ở vùng minsup thấp.
