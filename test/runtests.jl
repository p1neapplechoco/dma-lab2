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
