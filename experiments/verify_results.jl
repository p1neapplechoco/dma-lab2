using FrequentItemsetMining
using Printf

include(joinpath(@__DIR__, "datagen.jl"))   # subset_prefix, gen_synthetic

const RESULTS = joinpath(@__DIR__, "results")
const BENCH = joinpath(@__DIR__, "..", "data", "benchmark")
const GROCERIES = joinpath(@__DIR__, "..", "data", "groceries.txt")

# Đọc CSV đơn giản: trả về (header, rows::Vector{Vector{String}}).
function read_csv(path)
    lines = [l for l in readlines(path) if !isempty(strip(l))]
    header = String.(split(lines[1], ","))
    rows = [String.(split(l, ",")) for l in lines[2:end]]
    return header, rows
end

col(h, r, name) = r[findfirst(==(name), h)]

# Đếm số tập tối đại của bản FP-Max (count độc lập với thứ tự giao dịch).
count_opt(transactions, s) = (m = FPMax(s); fit!(m, transactions); length(get_maximal_itemsets(m)))

mutable struct Tally
    pass::Int
    fail::Int
end
Tally() = Tally(0, 0)

function check!(t::Tally, label, got, expect)
    ok = got == expect
    ok ? (t.pass += 1) : (t.fail += 1)
    @printf("  [%s] %-48s got=%-7d expect=%-7d\n", ok ? "PASS" : "FAIL", label, got, expect)
    return ok
end

# Groceries cho Chương 5: tách theo dấu phẩy vì item có khoảng trắng.
function load_groceries()
    txs = Transaction[]
    for line in eachline(GROCERIES)
        s = strip(line)
        isempty(s) && continue
        items = String[strip(it) for it in split(s, ",") if !isempty(strip(it))]
        push!(txs, Transaction(items))
    end
    return txs
end

function verify_all()
    t = Tally()

    # ---- Chương 4: timing.csv (đếm itemset của bản opt theo từng minsup) ----
    println("== Chương 4 — số tập tối đại theo minsup (timing.csv) ==")
    h, rows = read_csv(joinpath(RESULTS, "timing.csv"))
    for r in rows
        col(h, r, "algo") == "opt" && col(h, r, "status") == "ok" || continue
        ds = col(h, r, "dataset"); s = parse(Float64, col(h, r, "minsup"))
        expect = parse(Int, col(h, r, "n_maximal"))
        path = joinpath(BENCH, "$(ds).txt")
        isfile(path) || (@printf("  [SKIP] %s minsup=%s — thiếu %s\n", ds, col(h,r,"minsup"), path); continue)
        txs = collect(values(load_transactions(path)))
        check!(t, "$ds minsup=$(col(h,r,"minsup"))", count_opt(txs, s), expect)
    end

    # ---- Chương 4: scalability.csv (prefix theo dòng) ----
    println("\n== Chương 4 — scalability (scalability.csv) ==")
    h, rows = read_csv(joinpath(RESULTS, "scalability.csv"))
    for r in rows
        col(h, r, "algo") == "opt" || continue
        ds = col(h, r, "dataset"); frac = parse(Float64, col(h, r, "fraction"))
        s = ds == "accidents" ? 0.7 : 0.01      # minsup dùng trong exp_scalability
        expect = parse(Int, col(h, r, "n_maximal"))
        path = joinpath(BENCH, "$(ds).txt")
        isfile(path) || (@printf("  [SKIP] %s frac=%s — thiếu %s\n", ds, col(h,r,"fraction"), path); continue)
        sub = subset_prefix(path, frac)
        txs = collect(values(load_transactions(sub)))
        check!(t, "$ds frac=$(col(h,r,"fraction"))", count_opt(txs, s), expect)
    end

    # ---- Chương 4: txnlen.csv (dữ liệu tổng hợp, seed cố định) ----
    println("\n== Chương 4 — ảnh hưởng độ dài giao dịch (txnlen.csv) ==")
    h, rows = read_csv(joinpath(RESULTS, "txnlen.csv"))
    for r in rows
        avg = parse(Int, col(h, r, "avg_len"))
        expect = parse(Int, col(h, r, "n_maximal"))
        path = gen_synthetic(20000, 100, avg)
        txs = collect(values(load_transactions(path)))
        check!(t, "avg_len=$avg", count_opt(txs, 0.03), expect)
    end

    # ---- Chương 5: ứng dụng Groceries ----
    println("\n== Chương 5 — Market Basket (groceries) ==")
    txs = load_groceries()
    m = FPGrowthOpt(0.01); fit!(m, txs)
    itemsets = get_frequent_itemsets(m)
    rules = generate_rules(itemsets, length(txs); minconf = 0.2)
    filter!(r -> r.lift > 1.0, rules)
    check!(t, "groceries #frequent itemsets", length(itemsets), 333)
    check!(t, "groceries #rules (lift>1)", length(rules), 231)

    # ---- Tổng kết ----
    total = t.pass + t.fail
    println("\n================ TỔNG KẾT ================")
    @printf("PASS %d / %d", t.pass, total)
    t.fail > 0 ? @printf("  —  FAIL %d\n", t.fail) : println("  —  TẤT CẢ KHỚP REPORT")
    return t.fail == 0
end

verify_all()
