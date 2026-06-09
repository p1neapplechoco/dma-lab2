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
