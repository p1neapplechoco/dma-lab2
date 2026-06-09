# FP-Growth tối ưu (Julia) + tái cấu trúc thư mục — Design

Ngày: 2026-06-10
Phạm vi: bổ sung bản FP-Growth tối ưu cho Julia (Chương 3 — "Tối ưu hóa bộ nhớ và
tốc độ"), giữ nguyên bản cơ bản để so sánh. Kèm tái cấu trúc thư mục bám template đồ án.

## 1. Mục tiêu

- Thêm `FPGrowthOpt` — FP-Growth tối ưu, **bổ sung** chứ không thay thế `FPGrowth` cơ bản.
- Bản base giữ nguyên hành vi để Chương 4 đo cải thiện base-vs-opt.
- Output kiểu y hệt base (`Dict{Tuple{Vararg{String}}, Int}`) → test correctness so trực
  tiếp `get_frequent_itemsets(opt) == get_frequent_itemsets(base)`.
- Tái cấu trúc repo theo layout gợi ý trong đề.

## 2. Layout thư mục đích

```
lab2/
|-- README.md
|-- Project.toml              # Julia
|-- pyproject.toml            # Python
|-- main.jl                   # CLI Julia
|-- src/                      # Julia package FrequentItemsetMining
|   |-- FrequentItemsetMining.jl   # module entry (tên bắt buộc theo Pkg)
|   |-- structures.jl              # FPNode, Transaction, DataLoader
|   |-- utils.jl                   # combinations + helper chung
|   |-- data_loader.jl
|   |-- io.jl
|   |-- algorithm/
|       |-- fp_growth.jl           # BASE (giữ nguyên logic)
|       |-- fp_growth_opt.jl       # OPT (mới)
|       |-- fp_max.jl
|-- python/
|   |-- main.py
|   |-- fim/                       # = src_python cũ
|       |-- __init__.py
|       |-- data_loader.py
|       |-- fp_growth.py
|       |-- fp_growth_opt.py        # (để sau, không bắt buộc lần này)
|       |-- fp_max.py
|-- test/                          # giữ tên 'test' (Pkg convention)
|   |-- runtests.jl                # entry: include 2 file dưới
|   |-- test_correctness.jl
|   |-- test_benchmark.jl
|-- data/
|   |-- toy/                       # test_1.txt, test_2.txt
|   |-- benchmark/                 # chess, mushrooms, retail, T10I4D100K (+accidents gitignored)
|-- notebooks/
|   |-- demo.ipynb                 # (để sau)
|-- docs/
|   |-- Report.pdf                 # (để sau)
```

### Ràng buộc Julia Pkg
- Module entry phải là `src/FrequentItemsetMining.jl` (tên = tên package) → không chôn
  dưới `src/julia/`. Các file khác `include` theo path tương đối nên đặt trong
  `src/algorithm/` tự do.
- `test/` (số ít) giữ theo convention để `julia --project=. test/runtests.jl` và
  `Pkg.test()` chạy được (req 4.1). Template ghi `tests/` nhưng đề cũng ghi
  `test/runtests.jl` ở §4.1 — chọn `test/` để khớp lệnh chạy. `runtests.jl` include
  `test_correctness.jl` + `test_benchmark.jl`.
- Python để sau, lần này chỉ **di chuyển** `src_python` → `python/fim`, `main.py` →
  `python/main.py`. Không thêm `fp_growth_opt.py` lần này.

## 3. Refactor tách structures/utils (base giữ hành vi)

- `structures.jl`: đưa `Transaction`, `DataLoader` (từ data_loader.jl), `FPNode`
  (từ fp_growth.jl) về một chỗ. Base struct `FPGrowth`/`FPMax` ở lại file thuật toán.
- `utils.jl`: đưa `combinations` (đang nằm trong fp_growth.jl) ra dùng chung cho base,
  opt, fp_max.
- Mục tiêu: **không đổi logic**, chỉ di chuyển. Test base hiện có phải vẫn pass nguyên.

## 4. FPGrowthOpt — thiết kế

### 4.1 Cấu trúc dữ liệu
```julia
mutable struct FPNodeOpt
    item::Int                       # mã hoá integer (-1 = root)
    count::Int
    parent::Union{Nothing, FPNodeOpt}
    children::Dict{Int, FPNodeOpt}  # O(1) insert, thay Set linear-scan của base
end

mutable struct FPGrowthOpt
    min_sup::Float64
    min_sup_count::Int
    item_to_code::Dict{String, Int} # encode
    code_to_item::Vector{String}    # decode (index = code)
    code_support::Vector{Int}       # support theo code (cho thứ tự + tỉa)
    root::FPNodeOpt
    header::Dict{Int, Vector{FPNodeOpt}}
end
```

### 4.2 Kỹ thuật tối ưu (đúng họ tree, theo gợi ý đề)
1. **Recursive conditional FP-tree mining** — thuật toán FP-Growth chuẩn: với mỗi item
   (thứ tự support tăng dần) → dựng conditional pattern base → conditional FP-tree →
   đệ quy. Thay cho enumerate combinations ~mũ của base. *Cải thiện độ phức tạp chính.*
2. **Single-path shortcut** — khi conditional tree là 1 đường → sinh thẳng toàn bộ
   combination của path (kèm min count trên path làm support), không recurse từng item.
3. **Tỉa nhánh sớm** — loại item < min_sup_count trước khi dựng conditional tree.
4. **Nén FP-tree** — count merge sẵn trên node + header table.
5. **Integer encoding + type-stable + `@inbounds`** — mine trên Int, decode cuối; struct
   typed chặt; tránh global untyped (req 4.1 performance anti-patterns).

### 4.3 API (cùng signature base)
```julia
FPGrowthOpt(min_sup::Real)
fit!(model::FPGrowthOpt, transactions)::FPGrowthOpt
get_frequent_itemsets(model::FPGrowthOpt)::Dict{Tuple{Vararg{String}}, Int}
```
- `fit!`: đếm support 1-item → tỉa < min_sup_count → encode integer theo support desc
  (tie-break: chuỗi item, để deterministic/reproducible) → sort item mỗi giao dịch theo
  thứ tự đó → chèn vào tree → dựng header.
- `get_frequent_itemsets`: gọi đệ quy `fpgrowth!(tree, suffix, result)`, decode code →
  String, trả Dict với key `Tuple(sort(itemset_strings))` để khớp định dạng base.

### 4.4 Tie-break / reproducibility
- Thứ tự item = `(-support, item_string)` — giống base, đảm bảo kết quả ổn định và khớp.
- Không random; nếu cần seed thì cố định (req 4.1 reproducibility).

## 5. Tích hợp & CLI
- `FrequentItemsetMining.jl` include thêm `algorithm/fp_growth_opt.jl`, export `FPGrowthOpt`.
- `main.jl`: thêm nhánh algorithm `fp-growth-opt` → dùng `FPGrowthOpt`.
- Cập nhật path include sau khi chuyển file vào `src/algorithm/`.

## 6. Testing (`test/`)
- `test_correctness.jl`:
  - Giữ test data-loading + base FP-Growth + base FP-Max hiện có.
  - **Mới**: với mỗi CSDL trong {toy/test_1, toy/test_2, benchmark/chess @minsup cao} →
    assert `get_frequent_itemsets(FPGrowthOpt(s)) == get_frequent_itemsets(FPGrowth(s))`.
  - Mục tiêu phụ: tiến tới ≥5 CSDL (req 3.3.2) — lần này thêm test_2 + 1 benchmark, đủ
    nền để mở rộng.
- `test_benchmark.jl`: khung đo (để Chương 4 dùng) — lần này tối thiểu: chạy được, đo
  thời gian base vs opt trên 1 CSDL nhỏ, `@test` opt không chậm hơn base ở CSDL đủ lớn
  (hoặc chỉ in số liệu, không assert cứng để tránh flaky). Chi tiết benchmark đầy đủ làm sau.
- `runtests.jl`: `include("test_correctness.jl"); include("test_benchmark.jl")`.

## 7. Ngoài phạm vi (làm sau)
- Đo lường benchmark đầy đủ (time/memory/scalability) cho Chương 4.
- `fp_growth_opt.py`, `demo.ipynb`, `README.md`, `docs/Report.pdf`.
- Tối ưu FPMax.

## 8. Tiêu chí hoàn thành
- Toàn bộ test cũ vẫn pass sau refactor (không phá base).
- `get_frequent_itemsets(opt) == get_frequent_itemsets(base)` trên mọi CSDL test.
- `julia --project=. test/runtests.jl` pass toàn bộ.
- `main.jl ... fp-growth-opt` chạy ra kết quả khớp `fp-growth`.
