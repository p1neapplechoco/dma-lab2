module FrequentItemsetMining

export Transaction,
    DataLoader,
    FPGrowth,
    FPMax,
    combinations,
    fit!,
    get_frequent_itemsets,
    get_maximal_itemsets,
    load_transactions,
    load_unique_items,
    mine_roads,
    parse_items,
    simple_get_maximal_itemsets,
    write_itemsets

include("data_loader.jl")
include("fp_growth.jl")
include("fp_max.jl")
include("io.jl")

end
