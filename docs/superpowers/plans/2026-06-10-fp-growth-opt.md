# FP-Growth tối ưu (Julia) + tái cấu trúc — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Thêm `FPGrowthOpt` (FP-Growth tối ưu họ tree) cho Julia, bổ sung chứ không thay base, và tái cấu trúc repo theo layout đề.

**Architecture:** 1 Julia package. Base giữ nguyên hành vi. Opt là file mới dùng integer-encoded tree (`Dict` children O(1)), recursive conditional FP-tree, single-path shortcut, tỉa sớm, type-stable + `@inbounds`. Output kiểu y hệt base → test `opt == base`.

**Tech Stack:** Julia ≥1.9, package `FrequentItemsetMining`, Test stdlib.

---

## File Structure

- `src/FrequentItemsetMining.jl` — module entry, includes + exports (MODIFY)
- `src/structures.jl` — `Transaction`, `DataLoader`, `FPNode`, `FPNodeOpt` (CREATE)
- `src/utils.jl` — `combinations` (CREATE)
- `src/data_loader.jl` — chỉ giữ hàm load/parse (MODIFY, bỏ struct)
- `src/io.jl` — `write_itemsets` (MOVE path, nội dung nguyên)
- `src/algorithm/fp_growth.jl` — base, bỏ struct FPNode + combinations (MOVE+MODIFY)
- `src/algorithm/fp_growth_opt.jl` — `FPGrowthOpt` (CREATE)
- `src/algorithm/fp_max.jl` — nguyên nội dung (MOVE)
- `main.jl` — thêm nhánh `fp-growth-opt` (MODIFY)
- `test/runtests.jl` — include 2 file con (MODIFY)
- `test/test_correctness.jl` — test cũ + opt==base (CREATE)
- `test/test_benchmark.jl` — khung đo base vs opt (CREATE)
- `data/toy/{test_1,test_2}.txt` — MOVE từ data/
- `python/fim/` ← `src_python/`, `python/main.py` ← `main.py` (MOVE)

---

## Task 1: Tái cấu trúc cây thư mục (mechanical move)

**Files:** moves only; no logic change yet.

- [ ] **Step 1: Tạo thư mục + di chuyển file Julia bằng git mv**

```bash
cd "/home/lesliu/Documents/school/25_26_Semester_2/data-mining/lab2"
mkdir -p src/algorithm data/toy
git mv src/fp_growth.jl src/algorithm/fp_growth.jl
git mv src/fp_max.jl src/algorithm/fp_max.jl
git mv data/test_1.txt data/toy/test_1.txt
git mv data/test_2.txt data/toy/test_2.txt
```

- [ ] **Step 2: Cập nhật include trong module**

Sửa `src/FrequentItemsetMining.jl`, thay block include (dòng 18-21) thành:

```julia
include("structures.jl")
include("utils.jl")
include("data_loader.jl")
include("algorithm/fp_growth.jl")
include("algorithm/fp_max.jl")
include("io.jl")
```

(structures.jl / utils.jl tạo ở Task 2; tạm thời sẽ lỗi cho tới Task 2 — chấp nhận, chưa chạy test ở step này.)

- [ ] **Step 3: Cập nhật path dữ liệu trong test cũ**

Sửa `test/runtests.jl`: đổi mọi `"data/test_1.txt"` → `"data/toy/test_1.txt"` (3 chỗ: dòng 9, 15, 33).

- [ ] **Step 4: Commit (reorg, chưa chạy được — sẽ pass sau Task 2)**

```bash
git add -A
git commit -m "refactor: move Julia sources into src/algorithm, data into data/toy"
```

---

## Task 2: Tách structures.jl + utils.jl (base giữ hành vi)

**Files:**
- Create: `src/structures.jl`, `src/utils.jl`
- Modify: `src/data_loader.jl`, `src/algorithm/fp_growth.jl`

- [ ] **Step 1: Tạo `src/structures.jl`**

```julia
mutable struct Transaction
    items::Vector{String}
end

mutable struct DataLoader
    file_path::String
    transactions::Dict{String, Transaction}
end

DataLoader(file_path::AbstractString) = DataLoader(String(file_path), Dict{String, Transaction}())

# Base FP-tree node (String item, Set children)
mutable struct FPNode
    item::Union{Nothing, String}
    count::Int
    parent::Union{Nothing, FPNode}
    children::Set{FPNode}
end

FPNode(item::Union{Nothing, String}, count::Int = 0, parent::Union{Nothing, FPNode} = nothing) =
    FPNode(item, count, parent, Set{FPNode}())

# Optimized FP-tree node (Int item, Dict children for O(1) insert)
mutable struct FPNodeOpt
    item::Int
    count::Int
    parent::Union{Nothing, FPNodeOpt}
    children::Dict{Int, FPNodeOpt}
end

FPNodeOpt(item::Int, count::Int = 0, parent::Union{Nothing, FPNodeOpt} = nothing) =
    FPNodeOpt(item, count, parent, Dict{Int, FPNodeOpt}())
```

- [ ] **Step 2: Tạo `src/utils.jl` (chuyển `combinations` từ base)**

```julia
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
```

- [ ] **Step 3: Xoá struct khỏi `src/data_loader.jl`**

Xoá dòng 1-10 (định nghĩa `Transaction`, `DataLoader`, constructor `DataLoader(...)`). File bắt đầu trực tiếp từ `function parse_items(...)`. Phần còn lại giữ nguyên.

- [ ] **Step 4: Xoá `FPNode` struct + `combinations` khỏi `src/algorithm/fp_growth.jl`**

Xoá dòng 1-9 (struct `FPNode` + constructor) và dòng 33-61 (hàm `combinations`). Giữ nguyên `FPGrowth` struct, `insert_item!`, `rebuild_nodes_table!`, `fit!`, `mine_roads`, `get_frequent_itemsets`.

- [ ] **Step 5: Chạy test cũ, phải pass nguyên**

```bash
cd "/home/lesliu/Documents/school/25_26_Semester_2/data-mining/lab2"
julia --project=. test/runtests.jl
```
Expected: 3 testset (Data loading / FP-Growth baseline / FP-Max baseline) đều Pass, 0 Fail.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "refactor: extract structures.jl and utils.jl, base behavior unchanged"
```

---

## Task 3: FPGrowthOpt — struct + fit! (xây tree integer-encoded)

**Files:**
- Create: `src/algorithm/fp_growth_opt.jl`
- Modify: `src/FrequentItemsetMining.jl` (include + export)

- [ ] **Step 1: Tạo `src/algorithm/fp_growth_opt.jl` với struct + fit! + insert_path!**

```julia
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
```

- [ ] **Step 2: Wire include + export trong `src/FrequentItemsetMining.jl`**

Thêm `include("algorithm/fp_growth_opt.jl")` ngay sau dòng include `fp_growth.jl`. Thêm `FPGrowthOpt,` và `insert_path!,` vào danh sách export (cạnh `FPGrowth`).

- [ ] **Step 3: Smoke test fit! ở REPL/script**

```bash
cd "/home/lesliu/Documents/school/25_26_Semester_2/data-mining/lab2"
julia --project=. -e 'using FrequentItemsetMining; t=collect(values(load_transactions("data/toy/test_1.txt"))); m=FPGrowthOpt(0.6); fit!(m,t); println(length(m.code_to_item), " items, header keys=", sort(collect(keys(m.header))))'
```
Expected: in `4 items, header keys=[1, 2, 3, 4]` (4 item phổ biến: 1,2,3,5; codes 1..4).

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat: FPGrowthOpt struct, integer-encoded fit! and insert_path!"
```

---

## Task 4: FPGrowthOpt — recursive mining + get_frequent_itemsets (TDD)

**Files:**
- Modify: `src/algorithm/fp_growth_opt.jl`
- Test: `test/test_correctness.jl` (tạm tạo testset opt ở Task 6; ở đây test inline qua script)

- [ ] **Step 1: Viết test thất bại (script khẳng định opt==base trên test_1)**

```bash
cd "/home/lesliu/Documents/school/25_26_Semester_2/data-mining/lab2"
julia --project=. -e '
using FrequentItemsetMining
t=collect(values(load_transactions("data/toy/test_1.txt")))
b=FPGrowth(0.6); fit!(b,t)
o=FPGrowthOpt(0.6); fit!(o,t)
@assert get_frequent_itemsets(o) == get_frequent_itemsets(b)
println("OK")'
```
Expected: FAIL — `get_frequent_itemsets(::FPGrowthOpt)` chưa định nghĩa (MethodError).

- [ ] **Step 2: Cài hàm mining + helpers vào `src/algorithm/fp_growth_opt.jl`**

Thêm vào cuối file:

```julia
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
```

- [ ] **Step 3: Chạy lại script Step 1, phải PASS**

```bash
cd "/home/lesliu/Documents/school/25_26_Semester_2/data-mining/lab2"
julia --project=. -e '
using FrequentItemsetMining
t=collect(values(load_transactions("data/toy/test_1.txt")))
b=FPGrowth(0.6); fit!(b,t)
o=FPGrowthOpt(0.6); fit!(o,t)
@assert get_frequent_itemsets(o) == get_frequent_itemsets(b)
println("OK")'
```
Expected: in `OK`.

- [ ] **Step 4: Kiểm chéo CSDL thứ 2 (test_2, nhiều minsup)**

```bash
cd "/home/lesliu/Documents/school/25_26_Semester_2/data-mining/lab2"
julia --project=. -e '
using FrequentItemsetMining
for f in ["data/toy/test_1.txt","data/toy/test_2.txt"], s in [0.2,0.4,0.6,0.8]
  t=collect(values(load_transactions(f)))
  b=FPGrowth(s); fit!(b,t); o=FPGrowthOpt(s); fit!(o,t)
  @assert get_frequent_itemsets(o)==get_frequent_itemsets(b) "mismatch $f $s"
end
println("ALL OK")'
```
Expected: in `ALL OK`.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: FPGrowthOpt recursive conditional FP-tree mining with single-path shortcut"
```

---

## Task 5: CLI — thêm thuật toán fp-growth-opt vào main.jl

**Files:** Modify `main.jl`

- [ ] **Step 1: Cập nhật usage + nhánh algorithm**

Trong `main.jl`, sửa dòng usage để liệt kê `fp-growth-opt`, và thêm nhánh trong `main`:

```julia
    if algorithm == "fp-growth"
        model = FPGrowth(min_sup)
        fit!(model, transactions)
        itemsets = get_frequent_itemsets(model)
    elseif algorithm == "fp-growth-opt"
        model = FPGrowthOpt(min_sup)
        fit!(model, transactions)
        itemsets = get_frequent_itemsets(model)
    elseif algorithm == "fp-max"
```

Và sửa dòng usage:
```julia
    println("  julia --project=. main.jl <input_path> <minsup> [fp-growth|fp-growth-opt|fp-max] [output_path]")
```

- [ ] **Step 2: Verify CLI opt khớp base**

```bash
cd "/home/lesliu/Documents/school/25_26_Semester_2/data-mining/lab2"
julia --project=. main.jl data/toy/test_1.txt 0.6 fp-growth > /tmp/base.txt
julia --project=. main.jl data/toy/test_1.txt 0.6 fp-growth-opt > /tmp/opt.txt
diff /tmp/base.txt /tmp/opt.txt && echo "IDENTICAL"
```
Expected: in `IDENTICAL` (không có diff).

- [ ] **Step 3: Commit**

```bash
git add main.jl
git commit -m "feat: add fp-growth-opt algorithm to CLI"
```

---

## Task 6: test_correctness.jl — gộp test cũ + opt==base trên nhiều CSDL

**Files:**
- Create: `test/test_correctness.jl`
- Modify: `test/runtests.jl`

- [ ] **Step 1: Tạo `test/test_correctness.jl`** (chuyển nội dung test cũ + thêm testset opt)

```julia
using Test
using FrequentItemsetMining

@testset "Data loading" begin
    @test parse_items("1, 2, 3") == ["1", "2", "3"]
    @test parse_items("{1, 2, 3}") == ["1", "2", "3"]
    @test parse_items("1 2 3") == ["1", "2", "3"]

    transactions = load_transactions("data/toy/test_1.txt")
    @test length(transactions) == 5
    @test transactions["t1"].items == ["1", "3", "4"]
end

@testset "FP-Growth baseline" begin
    transactions = collect(values(load_transactions("data/toy/test_1.txt")))
    model = FPGrowth(0.6)
    fit!(model, transactions)

    @test get_frequent_itemsets(model) == Dict(
        ("1",) => 3,
        ("2",) => 4,
        ("3",) => 4,
        ("5",) => 4,
        ("1", "3") => 3,
        ("2", "3") => 3,
        ("2", "5") => 4,
        ("3", "5") => 3,
        ("2", "3", "5") => 3,
    )
end

@testset "FP-Max baseline" begin
    transactions = collect(values(load_transactions("data/toy/test_1.txt")))
    model = FPMax(0.6)
    fit!(model, transactions)

    @test get_maximal_itemsets(model) == Dict(
        ("1", "3") => 3,
        ("2", "3", "5") => 3,
    )
end

@testset "FP-Growth opt == base" begin
    datasets = [
        "data/toy/test_1.txt",
        "data/toy/test_2.txt",
        "data/benchmark/chess.txt",
    ]
    minsups = Dict(
        "data/toy/test_1.txt" => [0.2, 0.4, 0.6, 0.8],
        "data/toy/test_2.txt" => [0.2, 0.4, 0.6, 0.8],
        "data/benchmark/chess.txt" => [0.9, 0.95],
    )

    for ds in datasets
        transactions = collect(values(load_transactions(ds)))
        for s in minsups[ds]
            base = FPGrowth(s); fit!(base, transactions)
            opt = FPGrowthOpt(s); fit!(opt, transactions)
            @test get_frequent_itemsets(opt) == get_frequent_itemsets(base)
        end
    end
end
```

- [ ] **Step 2: Rút gọn `test/runtests.jl` thành entry include**

Thay toàn bộ nội dung `test/runtests.jl` bằng:

```julia
include("test_correctness.jl")
include("test_benchmark.jl")
```

(`test_benchmark.jl` tạo ở Task 7. Nếu chạy trước Task 7 sẽ lỗi include — Task 7 tạo ngay sau.)

- [ ] **Step 3: Tạo file tạm rỗng để chạy correctness trước**

```bash
cd "/home/lesliu/Documents/school/25_26_Semester_2/data-mining/lab2"
printf '# placeholder, filled in Task 7\n' > test/test_benchmark.jl
julia --project=. test/runtests.jl
```
Expected: testset "Data loading", "FP-Growth baseline", "FP-Max baseline", "FP-Growth opt == base" đều Pass, 0 Fail.

- [ ] **Step 4: Commit**

```bash
git add test/test_correctness.jl test/runtests.jl test/test_benchmark.jl
git commit -m "test: correctness suite incl FPGrowthOpt == base over toy+chess datasets"
```

---

## Task 7: test_benchmark.jl — khung đo base vs opt

**Files:** Modify `test/test_benchmark.jl`

- [ ] **Step 1: Viết khung đo (in số liệu, assert mềm)**

Thay nội dung `test/test_benchmark.jl`:

```julia
using Test
using FrequentItemsetMining

# Đo thời gian + bộ nhớ cấp phát của một biểu thức, trả (giây, bytes).
function _measure(f)
    f()                                   # warm-up (loại chi phí biên dịch)
    stats = @timed f()
    return stats.time, stats.bytes
end

@testset "FP-Growth opt benchmark (base vs opt)" begin
    ds = "data/benchmark/chess.txt"
    transactions = collect(values(load_transactions(ds)))
    s = 0.9

    base_time, base_bytes = _measure() do
        m = FPGrowth(s); fit!(m, transactions); get_frequent_itemsets(m)
    end
    opt_time, opt_bytes = _measure() do
        m = FPGrowthOpt(s); fit!(m, transactions); get_frequent_itemsets(m)
    end

    println("[bench] chess minsup=$s")
    println("[bench] base: $(round(base_time*1e3; digits=1)) ms, $(base_bytes) bytes")
    println("[bench] opt : $(round(opt_time*1e3; digits=1)) ms, $(opt_bytes) bytes")
    println("[bench] speedup x$(round(base_time/opt_time; digits=2)), " *
            "mem x$(round(base_bytes/opt_bytes; digits=2))")

    # Khẳng định kết quả vẫn khớp (không assert cứng về tốc độ để tránh flaky).
    base = FPGrowth(s); fit!(base, transactions)
    opt = FPGrowthOpt(s); fit!(opt, transactions)
    @test get_frequent_itemsets(opt) == get_frequent_itemsets(base)
end
```

- [ ] **Step 2: Chạy full test suite**

```bash
cd "/home/lesliu/Documents/school/25_26_Semester_2/data-mining/lab2"
julia --project=. test/runtests.jl
```
Expected: tất cả testset Pass; in dòng `[bench] speedup x...` (kỳ vọng opt nhanh hơn base trên chess do tránh enumerate combinations ~mũ).

- [ ] **Step 3: Commit**

```bash
git add test/test_benchmark.jl
git commit -m "test: base-vs-opt benchmark harness for FP-Growth"
```

---

## Task 8: Di chuyển Python sang python/ (hoàn tất reorg)

**Files:** MOVE `src_python/` → `python/fim/`, `main.py` → `python/main.py`; Modify `python/main.py`

- [ ] **Step 1: git mv Python sources**

```bash
cd "/home/lesliu/Documents/school/25_26_Semester_2/data-mining/lab2"
mkdir -p python
git mv src_python python/fim
git mv main.py python/main.py
```

- [ ] **Step 2: Sửa import + path trong `python/main.py`**

Đổi dòng 2 `from src_python import ...` → `from fim import DataLoader, Transaction, FPGrowth, FPMax`.
Đổi dòng 4 `DATA_PATH = Path("./data/test_1.txt")` → `DATA_PATH = Path(__file__).resolve().parent.parent / "data" / "toy" / "test_1.txt"`.

- [ ] **Step 3: Verify Python demo chạy**

```bash
cd "/home/lesliu/Documents/school/25_26_Semester_2/data-mining/lab2/python"
python main.py | tail -5
```
Expected: in danh sách frequent + maximal itemsets, không lỗi import.

- [ ] **Step 4: Commit**

```bash
cd "/home/lesliu/Documents/school/25_26_Semester_2/data-mining/lab2"
git add -A
git commit -m "refactor: move Python implementation into python/fim"
```

---

## Done criteria
- `julia --project=. test/runtests.jl` → toàn bộ Pass.
- `get_frequent_itemsets(FPGrowthOpt) == get_frequent_itemsets(FPGrowth)` mọi CSDL test.
- `main.jl ... fp-growth-opt` cho output giống `fp-growth`.
- Benchmark in speedup base-vs-opt trên chess.
- Cây thư mục khớp layout đề (src/algorithm, data/toy, data/benchmark, python/, test/).
