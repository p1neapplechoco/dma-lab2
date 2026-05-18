mutable struct FPNode
    item::Union{Nothing, String}
    count::Int
    parent::Union{Nothing, FPNode}
    children::Dict{String, FPNode}
end

FPNode(item::Union{Nothing, String}, count::Int = 0, parent::Union{Nothing, FPNode} = nothing) =
    FPNode(item, count, parent, Dict{String, FPNode}())

mutable struct FPGrowth
    min_sup::Float64
    min_sup_count::Int
    supports_table::Dict{String, Int}
    root::FPNode
    nodes_table::Dict{String, Vector{FPNode}}
    item_bitsets::Dict{String, BitVector}
end

function FPGrowth(min_sup::Real)
    if min_sup < 0 || min_sup > 1
        throw(ArgumentError("min_sup should be a value between 0 and 1"))
    end

    return FPGrowth(
        Float64(min_sup),
        0,
        Dict{String, Int}(),
        FPNode(nothing),
        Dict{String, Vector{FPNode}}(),
        Dict{String, BitVector}(),
    )
end

function combinations(items::AbstractVector{T}, size::Int) where {T}
    if size < 0 || size > length(items)
        return Vector{Vector{T}}()
    end
    if size == 0
        return [T[]]
    end

    result = Vector{Vector{T}}()
    current = Vector{T}()

    function backtrack(start_idx::Int)
        if length(current) == size
            push!(result, copy(current))
            return
        end

        remaining_needed = size - length(current)
        max_start = length(items) - remaining_needed + 1
        for idx in start_idx:max_start
            push!(current, items[idx])
            backtrack(idx + 1)
            pop!(current)
        end
    end

    backtrack(1)
    return result
end

function insert_item!(item::String, parent::FPNode)::FPNode
    child = get(parent.children, item, nothing)
    if child !== nothing
        child.count += 1
        return child
    end

    new_node = FPNode(item, 1, parent)
    parent.children[item] = new_node
    return new_node
end

function rebuild_nodes_table!(model::FPGrowth)
    nodes_table = DefaultDict{String, Vector{FPNode}}(() -> FPNode[])
    nodes_to_visit = collect(values(model.root.children))

    while !isempty(nodes_to_visit)
        node = pop!(nodes_to_visit)
        node_item = node.item::String
        push!(nodes_table[node_item], node)
        append!(nodes_to_visit, values(node.children))
    end

    model.nodes_table = Dict(nodes_table)
end

function support_bitsets(transactions)::Dict{String, BitVector}
    item_bitsets = DefaultDict{String, BitVector}(() -> falses(length(transactions)))

    for (transaction_idx, transaction) in enumerate(transactions)
        for item in transaction.items
            item_bitsets[item][transaction_idx] = true
        end
    end

    return Dict(item_bitsets)
end

function fit!(model::FPGrowth, transactions)::FPGrowth
    transaction_list = collect(transactions)
    model.min_sup_count = ceil(Int, model.min_sup * length(transaction_list))
    model.supports_table = Dict{String, Int}()
    model.root = FPNode(nothing)
    model.nodes_table = Dict{String, Vector{FPNode}}()
    model.item_bitsets = support_bitsets(transaction_list)

    model.supports_table = Dict(
        item => count(bitset)
        for (item, bitset) in model.item_bitsets
        if count(bitset) >= model.min_sup_count
    )

    for transaction in transaction_list
        ordered_items = sort(
            [item for item in transaction.items if haskey(model.supports_table, item)];
            by = item -> (-model.supports_table[item], item),
        )

        parent = model.root
        for item in ordered_items
            parent = insert_item!(item, parent)
        end
    end

    rebuild_nodes_table!(model)
    return model
end

function mine_roads(model::FPGrowth, item::String)::Dict{Tuple{Vararg{String}}, Int}
    if !haskey(model.nodes_table, item)
        return Dict{Tuple{Vararg{String}}, Int}()
    end

    roads = Dict{Tuple{Vararg{String}}, Int}()
    for node in model.nodes_table[item]
        path = String[]
        parent = node.parent

        while parent !== nothing && parent.item !== nothing
            push!(path, parent.item::String)
            parent = parent.parent
        end

        road = Tuple(reverse(path))
        roads[road] = get(roads, road, 0) + node.count
    end

    return roads
end

function get_frequent_itemsets(model::FPGrowth)::Dict{Tuple{Vararg{String}}, Int}
    frequent_itemsets = Dict{Tuple{Vararg{String}}, Int}()

    for item in keys(model.supports_table)
        roads = mine_roads(model, item)
        isempty(roads) && continue

        support_item = sum(values(roads))
        if support_item >= model.min_sup_count
            frequent_itemsets[(item,)] = support_item
        end

        node_counter = Dict{String, Int}()
        for (road, count) in roads
            for node_item in road
                node_counter[node_item] = get(node_counter, node_item, 0) + count
            end
        end

        valid_nodes = [node_item for (node_item, count) in node_counter if count >= model.min_sup_count]
        isempty(valid_nodes) && continue

        for size in 1:length(valid_nodes)
            for subset in combinations(valid_nodes, size)
                support = 0
                subset_set = Set(subset)

                for (road, count) in roads
                    if issubset(subset_set, Set(road))
                        support += count
                    end
                end

                if support >= model.min_sup_count
                    itemset = Tuple(sort([subset; item]))
                    frequent_itemsets[itemset] = max(get(frequent_itemsets, itemset, 0), support)
                end
            end
        end
    end

    return frequent_itemsets
end
