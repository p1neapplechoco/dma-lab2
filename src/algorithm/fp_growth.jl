mutable struct FPGrowth
    min_sup::Float64
    min_sup_count::Int
    supports_table::Dict{String, Int}
    root::FPNode
    nodes_table::Dict{String, Vector{FPNode}}
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
    )
end

function insert_item!(item::String, parent::FPNode)::FPNode
    for child in parent.children
        if child.item == item
            child.count += 1
            return child
        end
    end

    new_node = FPNode(item, 1, parent)
    push!(parent.children, new_node)
    return new_node
end

function rebuild_nodes_table!(model::FPGrowth)
    nodes_table = Dict{String, Vector{FPNode}}()
    nodes_to_visit = collect(model.root.children)

    while !isempty(nodes_to_visit)
        node = pop!(nodes_to_visit)
        node_item = node.item::String
        if !haskey(nodes_table, node_item)
            nodes_table[node_item] = FPNode[]
        end
        push!(nodes_table[node_item], node)
        append!(nodes_to_visit, collect(node.children))
    end

    model.nodes_table = nodes_table
    return model
end

function fit!(model::FPGrowth, transactions)::FPGrowth
    transaction_list = collect(transactions)

    model.min_sup_count = ceil(Int, model.min_sup * length(transaction_list))
    model.supports_table = Dict{String, Int}()
    model.root = FPNode(nothing)
    model.nodes_table = Dict{String, Vector{FPNode}}()

    for transaction in transaction_list
        for item in transaction.items
            model.supports_table[item] = get(model.supports_table, item, 0) + 1
        end
    end

    model.supports_table = Dict(
        item => count
        for (item, count) in model.supports_table
        if count >= model.min_sup_count
    )

    for transaction in transaction_list
        transaction.items = sort(
            [item for item in transaction.items if haskey(model.supports_table, item)];
            by = item -> (-model.supports_table[item], item),
        )
    end

    for transaction in transaction_list
        parent = model.root
        for item in transaction.items
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

    for item in Set(keys(model.supports_table))
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

                for (road, count) in roads
                    if all(node_item -> node_item in road, subset)
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
