module FrequentItemsetMining

export Transaction,
    AssociationRule,
    DataLoader,
    FPGrowth,
    FPGrowthOpt,
    FPMax,
    combinations,
    generate_rules,
    insert_path!,
    fit!,
    get_frequent_itemsets,
    get_maximal_itemsets,
    load_transactions,
    load_unique_items,
    mine_roads,
    parse_items,
    simple_get_maximal_itemsets,
    write_itemsets

include("structures.jl")
include("utils.jl")
include("data_loader.jl")
include("algorithm/fp_growth.jl")
include("algorithm/fp_growth_opt.jl")
include("algorithm/fp_max.jl")
include("association_rules.jl")
include("io.jl")

end
