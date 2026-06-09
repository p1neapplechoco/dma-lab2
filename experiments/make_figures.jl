ENV["GKSwstype"] = "100"   # GR headless, không cần display
using Plots
gr()

const RESULTS = joinpath(@__DIR__, "results")
const FIGURES = joinpath(@__DIR__, "figures")

function read_csv(path)
    lines = readlines(path)
    header = String.(split(lines[1], ","))
    rows = [String.(split(l, ",")) for l in lines[2:end] if !isempty(strip(l))]
    return header, rows
end

col(header, rows, name) = [r[findfirst(==(name), header)] for r in rows]

fnum(x) = (v = tryparse(Float64, x); v === nothing ? NaN : v)

function fig_time_and_count()
    header, rows = read_csv(joinpath(RESULTS, "timing.csv"))
    datasets = unique(col(header, rows, "dataset"))
    for ds in datasets
        drows = [r for r in rows if r[findfirst(==("dataset"), header)] == ds]
        p = plot(title = "Time vs minsup — $ds", xlabel = "minsup", ylabel = "time (ms)",
                 yscale = :log10, legend = :topright)
        for algo in ["base", "opt", "spmf"]
            ar = [r for r in drows if r[findfirst(==("algo"), header)] == algo &&
                  r[findfirst(==("status"), header)] == "ok"]
            isempty(ar) && continue
            x = fnum.(col(header, ar, "minsup"))
            y = fnum.(col(header, ar, "time_ms"))
            keep = .!isnan.(y) .& (y .> 0)
            any(keep) && plot!(p, x[keep], y[keep]; marker = :circle, label = algo)
        end
        savefig(p, joinpath(FIGURES, "time_$(ds).png"))

        ar = [r for r in drows if r[findfirst(==("algo"), header)] == "opt"]
        x = fnum.(col(header, ar, "minsup"))
        y = fnum.(col(header, ar, "n_itemsets"))
        pc = plot(x, y; marker = :square, title = "#Frequent itemsets vs minsup — $ds",
                  xlabel = "minsup", ylabel = "#itemsets", yscale = :log10, legend = false)
        savefig(pc, joinpath(FIGURES, "count_$(ds).png"))
    end
end

function fig_memory()
    header, rows = read_csv(joinpath(RESULTS, "timing.csv"))
    datasets = unique(col(header, rows, "dataset"))
    labels = String[]; base_mb = Float64[]; opt_mb = Float64[]
    for ds in datasets
        drows = [r for r in rows if r[findfirst(==("dataset"), header)] == ds &&
                 r[findfirst(==("status"), header)] == "ok"]
        baserows = [r for r in drows if r[findfirst(==("algo"), header)] == "base"]
        isempty(baserows) && continue
        mid = baserows[cld(length(baserows), 2)]
        ms = mid[findfirst(==("minsup"), header)]
        optrow = findfirst(r -> r[findfirst(==("algo"), header)] == "opt" &&
                                r[findfirst(==("minsup"), header)] == ms, drows)
        optrow === nothing && continue
        push!(labels, "$ds@$ms")
        push!(base_mb, fnum(mid[findfirst(==("alloc_bytes"), header)]) / 1e6)
        push!(opt_mb, fnum(drows[optrow][findfirst(==("alloc_bytes"), header)]) / 1e6)
    end
    isempty(labels) && return
    n = length(labels)
    p = bar(1:n, base_mb; label = "base", bar_width = 0.4,
            xticks = (1:n, labels), xrotation = 30, ylabel = "MB",
            title = "Allocated memory (base vs opt)", legend = :topright)
    bar!(p, (1:n) .+ 0.4, opt_mb; label = "opt", bar_width = 0.4)
    savefig(p, joinpath(FIGURES, "memory.png"))
end

function fig_scalability()
    header, rows = read_csv(joinpath(RESULTS, "scalability.csv"))
    datasets = unique(col(header, rows, "dataset"))
    p = plot(title = "Scalability: time vs #transactions", xlabel = "#transactions",
             ylabel = "time (ms)", legend = :topleft)
    for ds in datasets, algo in ["base", "opt"]
        ar = [r for r in rows if r[findfirst(==("dataset"), header)] == ds &&
              r[findfirst(==("algo"), header)] == algo]
        isempty(ar) && continue
        x = fnum.(col(header, ar, "n_trans"))
        y = fnum.(col(header, ar, "time_ms"))
        o = sortperm(x)
        plot!(p, x[o], y[o]; marker = :circle, label = "$ds-$algo")
    end
    savefig(p, joinpath(FIGURES, "scalability.png"))
end

function fig_txnlen()
    header, rows = read_csv(joinpath(RESULTS, "txnlen.csv"))
    p = plot(title = "Time vs avg transaction length", xlabel = "avg length",
             ylabel = "time (ms)", legend = :topleft)
    for algo in ["base", "opt"]
        ar = [r for r in rows if r[findfirst(==("algo"), header)] == algo]
        isempty(ar) && continue
        x = fnum.(col(header, ar, "avg_len"))
        y = fnum.(col(header, ar, "time_ms"))
        o = sortperm(x)
        plot!(p, x[o], y[o]; marker = :circle, label = algo)
    end
    savefig(p, joinpath(FIGURES, "txnlen.png"))
end

function main()
    mkpath(FIGURES)
    fig_time_and_count()
    fig_memory()
    fig_scalability()
    fig_txnlen()
    println("Figures written to $FIGURES")
end

main()
