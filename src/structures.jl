mutable struct Transaction
    items::Vector{String}
end

mutable struct DataLoader
    file_path::String
    transactions::Dict{String, Transaction}
end

DataLoader(file_path::AbstractString) = DataLoader(String(file_path), Dict{String, Transaction}())

# Base FP-tree node (String item, Set children)
mutable struct FPNode
    item::Union{Nothing, String}
    count::Int
    parent::Union{Nothing, FPNode}
    children::Set{FPNode}
end

FPNode(item::Union{Nothing, String}, count::Int = 0, parent::Union{Nothing, FPNode} = nothing) =
    FPNode(item, count, parent, Set{FPNode}())

# Optimized FP-tree node (Int item, Dict children for O(1) insert)
mutable struct FPNodeOpt
    item::Int
    count::Int
    parent::Union{Nothing, FPNodeOpt}
    children::Dict{Int, FPNodeOpt}
end

FPNodeOpt(item::Int, count::Int = 0, parent::Union{Nothing, FPNodeOpt} = nothing) =
    FPNodeOpt(item, count, parent, Dict{Int, FPNodeOpt}())
