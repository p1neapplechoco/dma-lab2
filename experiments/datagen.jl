using Random

const TMP_DIR = joinpath(@__DIR__, "tmp")

function _ensure_tmp()
    isdir(TMP_DIR) || mkpath(TMP_DIR)
    return TMP_DIR
end

# Lấy `fraction` giao dịch đầu (deterministic prefix).
function subset_prefix(input::String, fraction::Float64)::String
    _ensure_tmp()
    lines = readlines(input)
    n = max(1, round(Int, fraction * length(lines)))
    tag = replace(string(fraction), "." => "")
    out = joinpath(TMP_DIR, "subset_$(splitext(basename(input))[1])_$(tag).txt")
    open(out, "w") do io
        for i in 1:n
            println(io, lines[i])
        end
    end
    return out
end

# CSDL tổng hợp: n_trans giao dịch, item 1..n_items, độ dài ~ avg_len (Gaussian, clamp).
function gen_synthetic(n_trans::Int, n_items::Int, avg_len::Int; seed::Int = 42)::String
    _ensure_tmp()
    rng = MersenneTwister(seed + avg_len)
    out = joinpath(TMP_DIR, "synth_n$(n_trans)_i$(n_items)_l$(avg_len).txt")
    open(out, "w") do io
        for _ in 1:n_trans
            len = round(Int, avg_len + randn(rng) * (avg_len / 4))
            len = clamp(len, 1, n_items)
            items = randperm(rng, n_items)[1:len]
            println(io, join(sort(items), " "))
        end
    end
    return out
end
