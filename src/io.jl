function write_itemsets(itemsets::Dict{Tuple{Vararg{String}}, Int}, output_path::AbstractString)
    open(output_path, "w") do io
        for itemset in sort(collect(keys(itemsets)); by = itemset -> (length(itemset), join(itemset, "\0")))
            println(io, join(itemset, " "), " #SUP: ", itemsets[itemset])
        end
    end
end
