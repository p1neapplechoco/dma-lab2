using FrequentItemsetMining
using Printf

function print_usage()
    println("Usage:")
    println("  julia --project=. main.jl <input_path> <minsup> [fp-growth|fp-growth-opt|fp-max|rules] [output_path]")
    println()
    println("Modes:")
    println("  fp-growth | fp-growth-opt | fp-max : khai thác itemsets, in/ghi 'item ... #SUP: count'")
    println("  rules : sinh luật kết hợp (lift > 1) từ tập phổ biến (FP-Growth tối ưu)")
    println()
    println("Env:")
    println("  SEP=comma        tách item CHỈ theo dấu phẩy (cho dữ liệu item có khoảng trắng, ví dụ groceries)")
    println("  MINCONF=<float>  (rules) ngưỡng confidence tối thiểu (mặc định 0.2)")
    println("  TOPK=<int>       (rules) số luật in ra màn hình theo lift giảm dần (mặc định 10)")
    println()
    println("Examples:")
    println("  julia --project=. main.jl data/toy/test_1.txt 0.6 fp-growth")
    println("  julia --project=. main.jl data/toy/test_1.txt 0.6 fp-max output.txt")
    println("  SEP=comma julia --project=. main.jl data/groceries.txt 0.01 rules rules.csv")
end

function print_itemsets(itemsets::Dict{Tuple{Vararg{String}}, Int})
    for itemset in sort(collect(keys(itemsets)); by = itemset -> (length(itemset), join(itemset, "\0")))
        println(join(itemset, " "), " #SUP: ", itemsets[itemset])
    end
end

# Parser cho CLI. Mặc định dùng parser tự nhận diện của package (SPMF/space hoặc
# comma). Với dữ liệu mà item có khoảng trắng trong tên (ví dụ groceries: "whole milk"),
# đặt SEP=comma để tách CHỈ theo dấu phẩy, tránh space-split sai các dòng một item.
function load_transactions_cli(path)
    if get(ENV, "SEP", "auto") == "comma"
        txs = Transaction[]
        for line in eachline(path)
            s = strip(line)
            isempty(s) && continue
            items = String[strip(it) for it in split(s, ",") if !isempty(strip(it))]
            push!(txs, Transaction(items))
        end
        return txs
    end
    return collect(values(load_transactions(path)))
end

function run_rules(itemsets::Dict{Tuple{Vararg{String}}, Int}, n_transactions::Int,
                   output_path)
    minconf = haskey(ENV, "MINCONF") ? parse(Float64, ENV["MINCONF"]) : 0.2
    topk = haskey(ENV, "TOPK") ? parse(Int, ENV["TOPK"]) : 10

    rules = generate_rules(itemsets, n_transactions; minconf = minconf)
    filter!(r -> r.lift > 1.0, rules)
    sort!(rules; by = r -> (-r.lift, join(r.antecedent, ";"), join(r.consequent, ";")))

    println("#frequent itemsets=", length(itemsets),
            ", #rules(lift>1)=", length(rules),
            " (minconf=", minconf, ")")
    println("\nTop-", min(topk, length(rules)), " luật theo lift:")
    for r in rules[1:min(topk, length(rules))]
        @printf("{%s} => {%s}  sup=%.4f conf=%.3f lift=%.3f\n",
                join(r.antecedent, ", "), join(r.consequent, ", "),
                r.support, r.confidence, r.lift)
    end

    if output_path !== nothing
        open(output_path, "w") do io
            println(io, "antecedent,consequent,support,confidence,lift")
            for r in rules
                @printf(io, "%s,%s,%.6f,%.6f,%.6f\n",
                        join(r.antecedent, ";"), join(r.consequent, ";"),
                        r.support, r.confidence, r.lift)
            end
        end
        println("\nCSV: ", output_path)
    end
end

function main(args)
    if length(args) < 2 || length(args) > 4
        print_usage()
        return 1
    end

    input_path = args[1]
    min_sup = parse(Float64, args[2])
    algorithm = length(args) >= 3 ? lowercase(args[3]) : "fp-growth"
    output_path = length(args) == 4 ? args[4] : nothing

    transactions = load_transactions_cli(input_path)

    if algorithm == "rules"
        model = FPGrowthOpt(min_sup)
        fit!(model, transactions)
        itemsets = get_frequent_itemsets(model)
        run_rules(itemsets, length(transactions), output_path)
        return 0
    end

    if algorithm == "fp-growth"
        model = FPGrowth(min_sup)
        fit!(model, transactions)
        itemsets = get_frequent_itemsets(model)
    elseif algorithm == "fp-growth-opt"
        model = FPGrowthOpt(min_sup)
        fit!(model, transactions)
        itemsets = get_frequent_itemsets(model)
    elseif algorithm == "fp-max"
        model = FPMax(min_sup)
        fit!(model, transactions)
        itemsets = get_maximal_itemsets(model)
    else
        println(stderr, "Unknown algorithm: ", algorithm)
        print_usage()
        return 1
    end

    if output_path === nothing
        print_itemsets(itemsets)
    else
        write_itemsets(itemsets, output_path)
    end

    return 0
end

exit(main(ARGS))
