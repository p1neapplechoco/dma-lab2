using Printf

# Driver đo peak RSS thật (Sys.maxrss) cho từng cấu hình bằng cách spawn tiến trình
# riêng cho mỗi lần mining. Mỗi tiến trình mới reset RSS nên maxrss cuối là peak của
# đúng lần chạy đó (bao gồm runtime Julia + load package). Hàng "baseline" cho biết
# sàn RSS để ước lượng phần do chính thuật toán chiếm.
#
# Cách dùng: julia --project=. experiments/measure_memory.jl
# Kết quả: experiments/results/memory.csv

const ROOT = normpath(joinpath(@__DIR__, ".."))
const RESULTS = joinpath(@__DIR__, "results")
const WORKER = joinpath(@__DIR__, "mem_worker.jl")

dataset_path(name) = joinpath(ROOT, "data", "benchmark", "$(name).txt")

# (dataset, minsup, [algos]) — bám theo các điểm dùng trong hình bộ nhớ.
const CONFIGS = [
    ("chess",      0.80, ["base", "opt"]),
    ("chess",      0.85, ["base", "opt"]),
    ("mushrooms",  0.30, ["base", "opt"]),
    ("retail",     0.01, ["base", "opt"]),
    ("T10I4D100K", 0.01, ["base", "opt"]),
]

# Mỗi dataset đo 1 hàng baseline (load-only) để có sàn RSS.
const BASELINE_DATASETS = ["chess", "mushrooms", "retail", "T10I4D100K"]

function measure(path, s, algo)
    cmd = `julia --project=$ROOT $WORKER $path $s $algo`
    out = read(cmd, String)
    m = match(r"RESULT (\d+) (\d+)", out)
    m === nothing && error("no RESULT for $algo on $path @ $s:\n$out")
    return parse(Int, m.captures[1]), parse(Int, m.captures[2])
end

function main()
    mkpath(RESULTS)
    rows = Vector{Tuple}()
    for ds in BASELINE_DATASETS
        path = dataset_path(ds)
        isfile(path) || (@warn "missing $path"; continue)
        @info "baseline $ds"
        rss, n = measure(path, 0.0, "baseline")
        push!(rows, (ds, "-", "baseline", rss, round(rss / 1e6; digits = 2), n))
    end
    for (ds, s, algos) in CONFIGS
        path = dataset_path(ds)
        isfile(path) || (@warn "missing $path"; continue)
        for algo in algos
            @info "$algo $ds @ minsup=$s"
            rss, n = measure(path, s, algo)
            push!(rows, (ds, s, algo, rss, round(rss / 1e6; digits = 2), n))
        end
    end

    out = joinpath(RESULTS, "memory.csv")
    open(out, "w") do io
        println(io, "dataset,minsup,algo,peak_rss_bytes,peak_rss_mb,n_itemsets")
        for r in rows
            println(io, join(r, ","))
        end
    end
    @info "Done -> $out ($(length(rows)) rows)"
    for r in rows
        @printf("  %-12s %-5s %-9s %8.2f MB  n=%d\n",
                r[1], string(r[2]), r[3], r[5], r[6])
    end
end

main()
