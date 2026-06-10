using Test
using FrequentItemsetMining

@testset "Data loading" begin
    @test parse_items("1, 2, 3") == ["1", "2", "3"]
    @test parse_items("{1, 2, 3}") == ["1", "2", "3"]
    @test parse_items("1 2 3") == ["1", "2", "3"]

    transactions = load_transactions("data/toy/test_1.txt")
    @test length(transactions) == 5
    @test transactions["t1"].items == ["1", "3", "4"]
end

@testset "FP-Growth baseline" begin
    transactions = collect(values(load_transactions("data/toy/test_1.txt")))
    model = FPGrowth(0.6)
    fit!(model, transactions)

    @test get_frequent_itemsets(model) == Dict(
        ("1",) => 3,
        ("2",) => 4,
        ("3",) => 4,
        ("5",) => 4,
        ("1", "3") => 3,
        ("2", "3") => 3,
        ("2", "5") => 4,
        ("3", "5") => 3,
        ("2", "3", "5") => 3,
    )
end

@testset "FP-Max baseline" begin
    transactions = collect(values(load_transactions("data/toy/test_1.txt")))
    model = FPMax(0.6)
    fit!(model, transactions)

    @test get_maximal_itemsets(model) == Dict(
        ("1", "3") => 3,
        ("2", "3", "5") => 3,
    )
end

@testset "FP-Growth opt == base" begin
    datasets = [
        "data/toy/test_1.txt",
        "data/toy/test_2.txt",
        "data/benchmark/chess.txt",
    ]
    minsups = Dict(
        "data/toy/test_1.txt" => [0.2, 0.4, 0.6, 0.8],
        "data/toy/test_2.txt" => [0.2, 0.4, 0.6, 0.8],
        "data/benchmark/chess.txt" => [0.9, 0.95],
    )

    for ds in datasets
        transactions = collect(values(load_transactions(ds)))
        for s in minsups[ds]
            base = FPGrowth(s); fit!(base, transactions)
            opt = FPGrowthOpt(s); fit!(opt, transactions)
            @test get_frequent_itemsets(opt) == get_frequent_itemsets(base)
        end
    end
end

@testset "Association rules" begin
    transactions = collect(values(load_transactions("data/toy/test_1.txt")))
    model = FPGrowth(0.6); fit!(model, transactions)
    itemsets = get_frequent_itemsets(model)
    rules = generate_rules(itemsets, length(transactions); minconf = 0.5)

    idx = findfirst(x -> x.antecedent == ["1"] && x.consequent == ["3"], rules)
    @test idx !== nothing
    @test isapprox(rules[idx].confidence, 1.0; atol = 1e-9)
    @test isapprox(rules[idx].lift, 1.25; atol = 1e-9)
end
