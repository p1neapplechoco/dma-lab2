mutable struct FPGrowthOpt
    min_sup::Float64
    min_sup_count::Int
    item_to_code::Dict{String, Int}
    code_to_item::Vector{String}
    root::FPNodeOpt
    header::Dict{Int, Vector{FPNodeOpt}}
end

function FPGrowthOpt(min_sup::Real)
    if min_sup < 0 || min_sup > 1
        throw(ArgumentError("min_sup should be a value between 0 and 1"))
    end

    return FPGrowthOpt(
        Float64(min_sup),
        0,
        Dict{String, Int}(),
        String[],
        FPNodeOpt(-1),
        Dict{Int, Vector{FPNodeOpt}}(),
    )
end

# Insert a path of item codes with a given weight, updating the header table.
function insert_path!(root::FPNodeOpt, path::Vector{Int}, count::Int,
                      header::Dict{Int, Vector{FPNodeOpt}})
    parent = root
    @inbounds for item in path
        child = get(parent.children, item, nothing)
        if child === nothing
            child = FPNodeOpt(item, 0, parent)
            parent.children[item] = child
            push!(get!(header, item, FPNodeOpt[]), child)
        end
        child.count += count
        parent = child
    end
    return root
end

function fit!(model::FPGrowthOpt, transactions)::FPGrowthOpt
    transaction_list = collect(transactions)
    n = length(transaction_list)
    model.min_sup_count = ceil(Int, model.min_sup * n)

    support = Dict{String, Int}()
    for transaction in transaction_list
        for item in transaction.items
            support[item] = get(support, item, 0) + 1
        end
    end

    # Prune infrequent 1-items, order by (-support, item) for deterministic codes.
    frequent = [item for (item, c) in support if c >= model.min_sup_count]
    sort!(frequent; by = item -> (-support[item], item))

    model.item_to_code = Dict{String, Int}()
    model.code_to_item = String[]
    for (i, item) in enumerate(frequent)
        model.item_to_code[item] = i
        push!(model.code_to_item, item)
    end

    model.root = FPNodeOpt(-1)
    model.header = Dict{Int, Vector{FPNodeOpt}}()

    for transaction in transaction_list
        codes = Int[]
        for item in transaction.items
            c = get(model.item_to_code, item, 0)
            c != 0 && push!(codes, c)
        end
        # Codes assigned by support desc => sorting ascending = support-desc order.
        sort!(codes)
        isempty(codes) && continue
        insert_path!(model.root, codes, 1, model.header)
    end

    return model
end
