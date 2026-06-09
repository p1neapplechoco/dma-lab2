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

function _item_support(nodes::Vector{FPNodeOpt})::Int
    s = 0
    @inbounds for nd in nodes
        s += nd.count
    end
    return s
end

function _is_single_path(root::FPNodeOpt)::Bool
    node = root
    while !isempty(node.children)
        length(node.children) > 1 && return false
        node = first(values(node.children))
    end
    return true
end

# (code, count) dọc theo single path, từ trên xuống.
function _single_path(root::FPNodeOpt)::Vector{Tuple{Int, Int}}
    res = Tuple{Int, Int}[]
    node = root
    while !isempty(node.children)
        node = first(values(node.children))
        push!(res, (node.item, node.count))
    end
    return res
end

function _record!(result::Dict{Vector{Int}, Int}, itemset::Vector{Int}, supp::Int)
    key = sort(itemset)
    result[key] = max(get(result, key, 0), supp)
    return result
end

function _mine!(root::FPNodeOpt, header::Dict{Int, Vector{FPNodeOpt}},
                suffix::Vector{Int}, min_count::Int, result::Dict{Vector{Int}, Int})
    # Single-path shortcut: sinh thẳng mọi tổ hợp con của path + suffix.
    if _is_single_path(root)
        path = _single_path(root)
        m = length(path)
        for mask in 1:((1 << m) - 1)
            subset = Int[]
            supp = typemax(Int)
            @inbounds for i in 1:m
                if (mask >> (i - 1)) & 1 == 1
                    push!(subset, path[i][1])
                    supp = min(supp, path[i][2])   # path counts không tăng khi đi xuống
                end
            end
            supp >= min_count && _record!(result, vcat(suffix, subset), supp)
        end
        return
    end

    for (code, nodes) in header
        supp = _item_support(nodes)
        supp < min_count && continue
        itemset = vcat(suffix, code)
        _record!(result, itemset, supp)

        # Conditional pattern base của code.
        base_paths = Vector{Tuple{Vector{Int}, Int}}()
        base_support = Dict{Int, Int}()
        for nd in nodes
            path = Int[]
            p = nd.parent
            while p !== nothing && p.item != -1
                push!(path, p.item)
                p = p.parent
            end
            if !isempty(path)
                reverse!(path)
                push!(base_paths, (path, nd.count))
                for it in path
                    base_support[it] = get(base_support, it, 0) + nd.count
                end
            end
        end

        # Conditional FP-tree: tỉa item < min_count, sắp theo (-support, code).
        cond_root = FPNodeOpt(-1)
        cond_header = Dict{Int, Vector{FPNodeOpt}}()
        for (path, cnt) in base_paths
            fpath = Int[it for it in path if get(base_support, it, 0) >= min_count]
            isempty(fpath) && continue
            sort!(fpath; by = it -> (-base_support[it], it))
            insert_path!(cond_root, fpath, cnt, cond_header)
        end

        if !isempty(cond_header)
            _mine!(cond_root, cond_header, itemset, min_count, result)
        end
    end
    return
end

function get_frequent_itemsets(model::FPGrowthOpt)::Dict{Tuple{Vararg{String}}, Int}
    result = Dict{Vector{Int}, Int}()
    _mine!(model.root, model.header, Int[], model.min_sup_count, result)

    out = Dict{Tuple{Vararg{String}}, Int}()
    for (codes, supp) in result
        items = sort([model.code_to_item[c] for c in codes])
        out[Tuple(items)] = supp
    end
    return out
end
