using FrequentItemsetMining

function print_usage()
    println("Usage:")
    println("  julia --project=. main.jl <input_path> <minsup> [fp-growth|fp-max] [output_path]")
    println()
    println("Examples:")
    println("  julia --project=. main.jl data/test_1.txt 0.6 fp-growth")
    println("  julia --project=. main.jl data/test_1.txt 0.6 fp-max output.txt")
end

function print_itemsets(itemsets::Dict{Tuple{Vararg{String}}, Int})
    for itemset in sort(collect(keys(itemsets)); by = itemset -> (length(itemset), join(itemset, "\0")))
        println(join(itemset, " "), " #SUP: ", itemsets[itemset])
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

    transactions = collect(values(load_transactions(input_path)))

    if algorithm == "fp-growth"
        model = FPGrowth(min_sup)
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
