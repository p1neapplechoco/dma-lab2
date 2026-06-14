using FrequentItemsetMining

# Worker chạy trong tiến trình riêng để đo peak RSS thật của một lần mining.
# Cách dùng: julia --project=. experiments/mem_worker.jl <path> <minsup> <base|opt|baseline>
# In ra: RESULT <peak_rss_bytes> <n_maximal>
# - opt: FPMax trực tiếp (MFI + tỉa superset).
# - base: naive maximal (mine toàn bộ frequent bằng FPGrowthOpt rồi lọc maximal).
# - baseline: chỉ load package + dữ liệu (không mining) -> sàn RSS để trừ ra phần thuật toán.

function run_worker()
    path = ARGS[1]
    s = parse(Float64, ARGS[2])
    algo = ARGS[3]
    transactions = collect(values(load_transactions(path)))
    n = 0
    if algo == "opt"
        m = FPMax(s); fit!(m, transactions); n = length(get_maximal_itemsets(m))
    elseif algo == "base"
        m = FPGrowthOpt(s); fit!(m, transactions); n = length(maximal_from_frequent(get_frequent_itemsets(m)))
    elseif algo == "baseline"
        n = length(transactions)  # chỉ load, không mining
    else
        error("unknown algo $algo")
    end
    GC.gc()
    println("RESULT ", Sys.maxrss(), " ", n)
end

run_worker()
