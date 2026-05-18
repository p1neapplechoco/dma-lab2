mutable struct FPMax
    growth::FPGrowth
    transactions::Vector{Set{String}}
end

FPMax(min_sup::Real) = FPMax(FPGrowth(min_sup), Vector{Set{String}}())

function fit!(model::FPMax, transactions)::FPMax
    transaction_list = collect(transactions)
    model.transactions = [Set(transaction.items) for transaction in transaction_list]

    sorted_transactions = [Transaction(sort(copy(transaction.items))) for transaction in transaction_list]
    fit!(model.growth, sorted_transactions)

    return model
end

function is_single_path(tree::FPGrowth)::Bool
    node = tree.root
    while !isempty(node.children)
        if length(node.children) > 1
            return false
        end
        node = first(values(node.children))
    end

    return true
end

function single_path_items(tree::FPGrowth)::Vector{String}
    items = String[]
    node = tree.root

    while !isempty(node.children)
        node = first(values(node.children))
        push!(items, node.item::String)
    end

    return items
end

function item_support_in_tree(tree::FPGrowth, item::String)::Int
    return sum(node.count for node in get(tree.nodes_table, item, FPNode[]))
end

function head_pattern_base(tree::FPGrowth, item::String)::Dict{Tuple{Vararg{String}}, Int}
    roads = Dict{Tuple{Vararg{String}}, Int}()

    for node in get(tree.nodes_table, item, FPNode[])
        path = String[]
        parent = node.parent

        while parent !== nothing && parent.item !== nothing
            push!(path, parent.item::String)
            parent = parent.parent
        end

        if !isempty(path)
            road = Tuple(reverse(path))
            roads[road] = get(roads, road, 0) + node.count
        end
    end

    return roads
end

function frequent_items_in_base(roads::Dict{Tuple{Vararg{String}}, Int}, min_sup_count::Int)::Dict{String, Int}
    support_counter = Dict{String, Int}()

    for (road, count) in roads
        for item in road
            support_counter[item] = get(support_counter, item, 0) + count
        end
    end

    return Dict(item => support for (item, support) in support_counter if support >= min_sup_count)
end

function build_conditional_tree(tree::FPGrowth, roads::Dict{Tuple{Vararg{String}}, Int}, item_supports::Dict{String, Int})::FPGrowth
    conditional_tree = FPGrowth(tree.min_sup)
    conditional_tree.min_sup_count = tree.min_sup_count
    conditional_tree.supports_table = copy(item_supports)

    for (road, count) in roads
        ordered_items = sort(collect(road); by = item -> (-item_supports[item], item))
        for _ in 1:count
            parent = conditional_tree.root
            for road_item in ordered_items
                parent = insert_item!(road_item, parent)
            end
        end
    end

    rebuild_nodes_table!(conditional_tree)
    return conditional_tree
end

function insert_mfi!(mfi_sets::Vector{Set{String}}, candidate::Set{String})
    isempty(candidate) && return

    for existing in mfi_sets
        if issubset(candidate, existing)
            return
        end
    end

    filter!(existing -> !issubset(existing, candidate) || existing == candidate, mfi_sets)
    push!(mfi_sets, candidate)
end

function support_in_transactions(item_bitsets::Dict{String, BitVector}, itemset::Set{String})::Int
    isempty(itemset) && return 0

    bitsets = (item_bitsets[item] for item in itemset)
    support_mask = copy(first(bitsets))
    for bitset in bitsets
        support_mask .&= bitset
    end

    return count(support_mask)
end

function get_maximal_itemsets(model::FPMax)::Dict{Tuple{Vararg{String}}, Int}
    if isempty(model.transactions)
        return Dict{Tuple{Vararg{String}}, Int}()
    end

    mfi_sets = Vector{Set{String}}()

    function fpmax!(tree::FPGrowth, head::Vector{String})
        if is_single_path(tree)
            candidate = union(Set(head), Set(single_path_items(tree)))
            insert_mfi!(mfi_sets, candidate)
            return
        end

        header_items = sort(collect(keys(tree.nodes_table)); by = item -> (item_support_in_tree(tree, item), item))

        for item in header_items
            push!(head, item)
            roads = head_pattern_base(tree, item)
            tail_supports = frequent_items_in_base(roads, tree.min_sup_count)
            tail = Set(keys(tail_supports))
            head_tail = union(Set(head), tail)

            if !any(mfi -> issubset(head_tail, mfi), mfi_sets)
                filtered_roads = Dict{Tuple{Vararg{String}}, Int}()
                for (road, count) in roads
                    filtered = Tuple([road_item for road_item in road if road_item in tail])
                    if !isempty(filtered)
                        filtered_roads[filtered] = get(filtered_roads, filtered, 0) + count
                    end
                end

                conditional_tree = build_conditional_tree(tree, filtered_roads, tail_supports)
                fpmax!(conditional_tree, head)
            end

            pop!(head)
        end
    end

    fpmax!(model.growth, String[])

    maximal_itemsets = Dict{Tuple{Vararg{String}}, Int}()
    for mfi in mfi_sets
        itemset = Tuple(sort(collect(mfi)))
        maximal_itemsets[itemset] = support_in_transactions(model.growth.item_bitsets, mfi)
    end

    return maximal_itemsets
end
