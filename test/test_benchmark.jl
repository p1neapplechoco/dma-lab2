using Test
using FrequentItemsetMining

# Đo thời gian + bộ nhớ cấp phát của một biểu thức, trả (giây, bytes).
function _measure(f)
    f()                                   # warm-up (loại chi phí biên dịch)
    stats = @timed f()
    return stats.time, stats.bytes
end

@testset "FP-Growth opt benchmark (base vs opt)" begin
    ds = "data/benchmark/chess.txt"
    transactions = collect(values(load_transactions(ds)))
    s = 0.9

    base_time, base_bytes = _measure() do
        m = FPGrowth(s); fit!(m, transactions); get_frequent_itemsets(m)
    end
    opt_time, opt_bytes = _measure() do
        m = FPGrowthOpt(s); fit!(m, transactions); get_frequent_itemsets(m)
    end

    println("[bench] chess minsup=$s")
    println("[bench] base: $(round(base_time*1e3; digits=1)) ms, $(base_bytes) bytes")
    println("[bench] opt : $(round(opt_time*1e3; digits=1)) ms, $(opt_bytes) bytes")
    println("[bench] speedup x$(round(base_time/opt_time; digits=2)), " *
            "mem x$(round(base_bytes/opt_bytes; digits=2))")

    # Khẳng định kết quả vẫn khớp (không assert cứng về tốc độ để tránh flaky).
    base = FPGrowth(s); fit!(base, transactions)
    opt = FPGrowthOpt(s); fit!(opt, transactions)
    @test get_frequent_itemsets(opt) == get_frequent_itemsets(base)
end
