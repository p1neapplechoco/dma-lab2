struct AssociationRule
    antecedent::Vector{String}
    consequent::Vector{String}
    support::Float64      # sup(X∪Y) / N
    confidence::Float64   # sup(X∪Y) / sup(X)
    lift::Float64         # confidence / (sup(Y) / N)
end

# itemsets: Dict{Tuple{Vararg{String}}, Int} (support tuyệt đối), key đã sort theo chuỗi.
function generate_rules(itemsets::Dict{Tuple{Vararg{String}}, Int}, n_transactions::Int;
                        minconf::Float64 = 0.2)::Vector{AssociationRule}
    rules = AssociationRule[]
    for (z, supZ) in itemsets
        length(z) >= 2 || continue
        items = collect(z)
        for k in 1:(length(items) - 1)
            for x in combinations(items, k)
                y = [it for it in items if !(it in x)]
                supX = get(itemsets, Tuple(sort(x)), 0)
                supY = get(itemsets, Tuple(sort(y)), 0)
                (supX == 0 || supY == 0) && continue
                conf = supZ / supX
                conf >= minconf || continue
                lift = conf / (supY / n_transactions)
                push!(rules, AssociationRule(sort(x), sort(y),
                                             supZ / n_transactions, conf, lift))
            end
        end
    end
    return rules
end
