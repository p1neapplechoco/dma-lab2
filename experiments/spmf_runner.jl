using FrequentItemsetMining

const SPMF_JAR = joinpath(@__DIR__, "spmf", "spmf.jar")

# Chạy SPMF FPGrowth_itemsets. Trả (out_path, n_itemsets, time_ms, mem_mb, status).
function run_spmf(input::String, minsup::Float64; timeout_s::Int = 120)
    isfile(SPMF_JAR) || error("spmf.jar not found at $SPMF_JAR")
    out_path = tempname() * ".txt"
    log_path = tempname() * ".log"
    cmd = `java -jar $SPMF_JAR run FPGrowth_itemsets $input $out_path $(string(minsup))`

    status = :ok
    n_itemsets = -1
    time_ms = NaN
    mem_mb = NaN
    try
        proc = run(pipeline(cmd; stdout = log_path, stderr = devnull); wait = false)
        t0 = time()
        while process_running(proc)
            if time() - t0 > timeout_s
                kill(proc)
                status = :timeout
                break
            end
            sleep(0.05)
        end
        if status == :ok
            text = read(log_path, String)
            m = match(r"Frequent itemsets count\s*:\s*(\d+)", text)
            m !== nothing && (n_itemsets = parse(Int, m.captures[1]))
            mt = match(r"Total time ~?\s*([\d.]+)\s*ms", text)
            mt !== nothing && (time_ms = parse(Float64, mt.captures[1]))
            mm = match(r"Max memory usage:\s*([\d.]+)\s*mb", text)
            mm !== nothing && (mem_mb = parse(Float64, mm.captures[1]))
        end
    catch
        status = :error
    end
    return (out_path, n_itemsets, time_ms, mem_mb, status)
end

# Chạy SPMF FPMax. Trả (out_path, n_maximal, time_ms, mem_mb, status). Output file dạng #SUP.
function run_spmf_fpmax(input::String, minsup::Float64; timeout_s::Int = 120)
    isfile(SPMF_JAR) || error("spmf.jar not found at $SPMF_JAR")
    out_path = tempname() * ".txt"
    log_path = tempname() * ".log"
    cmd = `java -jar $SPMF_JAR run FPMax $input $out_path $(string(minsup))`

    status = :ok
    n_itemsets = -1
    time_ms = NaN
    mem_mb = NaN
    try
        proc = run(pipeline(cmd; stdout = log_path, stderr = devnull); wait = false)
        t0 = time()
        while process_running(proc)
            if time() - t0 > timeout_s
                kill(proc)
                status = :timeout
                break
            end
            sleep(0.05)
        end
        if status == :ok
            text = read(log_path, String)
            m = match(r"Maximal frequent itemset count\s*:\s*(\d+)", text)
            m !== nothing && (n_itemsets = parse(Int, m.captures[1]))
            mt = match(r"Total time ~?\s*([\d.]+)\s*ms", text)
            mt !== nothing && (time_ms = parse(Float64, mt.captures[1]))
            mm = match(r"Max memory usage:\s*([\d.]+)\s*mb", text)
            mm !== nothing && (mem_mb = parse(Float64, mm.captures[1]))
        end
    catch
        status = :error
    end
    return (out_path, n_itemsets, time_ms, mem_mb, status)
end

# Đọc file output SPMF -> Dict{Set{String}, Int} (chuẩn hoá để so).
function read_itemsets_spmf(path::String)::Dict{Set{String}, Int}
    result = Dict{Set{String}, Int}()
    isfile(path) || return result
    for line in eachline(path)
        s = strip(line)
        isempty(s) && continue
        parts = split(s, "#SUP:")
        length(parts) != 2 && continue
        items = Set(String.(split(strip(parts[1]))))
        supp = parse(Int, strip(parts[2]))
        result[items] = supp
    end
    return result
end

# Output bản nhóm -> cùng dạng Set để so.
function to_itemset_sets(d::Dict{Tuple{Vararg{String}}, Int})::Dict{Set{String}, Int}
    out = Dict{Set{String}, Int}()
    for (k, v) in d
        out[Set(k)] = v
    end
    return out
end
