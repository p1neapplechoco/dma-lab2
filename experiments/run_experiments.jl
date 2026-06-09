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

function main()
    mkpath(RESULTS)
    @info "Correctness..."; exp_correctness()
    @info "Timing..."; exp_timing()
    @info "Done. CSV in $RESULTS"
end

main()
