using FrequentItemsetMining
using Printf

const GROCERIES = joinpath(@__DIR__, "..", "data", "groceries.txt")
const RESULTS = joinpath(@__DIR__, "results")

# groceries dùng phẩy làm separator và item có khoảng trắng ("whole milk").
# parse_items generic sẽ space-split các dòng 1-item -> sai, nên parse comma-only ở đây.
function load_groceries(path)
    txs = Transaction[]
    for line in eachline(path)
        s = strip(line)
        isempty(s) && continue
        items = String[strip(it) for it in split(s, ",") if !isempty(strip(it))]
        push!(txs, Transaction(items))
    end
    return txs
end

function run_application(; minsup = 0.01, minconf = 0.2, topk = 10)
    transactions = load_groceries(GROCERIES)
    n = length(transactions)
    model = FPGrowthOpt(minsup); fit!(model, transactions)
    itemsets = get_frequent_itemsets(model)
    rules = generate_rules(itemsets, n; minconf = minconf)
    filter!(r -> r.lift > 1.0, rules)
    sort!(rules; by = r -> (-r.lift, join(r.antecedent, ";"), join(r.consequent, ";")))

    println("Groceries: $n giao dịch, minsup=$minsup, minconf=$minconf")
    println("#frequent itemsets=$(length(itemsets)), #rules(lift>1)=$(length(rules))")
    println("\nTop-$topk luật theo lift:")
    for r in rules[1:min(topk, length(rules))]
        @printf("{%s} => {%s}  sup=%.4f conf=%.3f lift=%.3f\n",
                join(r.antecedent, ", "), join(r.consequent, ", "),
                r.support, r.confidence, r.lift)
    end

    mkpath(RESULTS)
    out = joinpath(RESULTS, "rules_groceries.csv")
    open(out, "w") do io
        println(io, "antecedent,consequent,support,confidence,lift")
        for r in rules
            @printf(io, "%s,%s,%.6f,%.6f,%.6f\n",
                    join(r.antecedent, ";"), join(r.consequent, ";"),
                    r.support, r.confidence, r.lift)
        end
    end
    println("\nCSV: ", out)
    return rules
end

run_application()
