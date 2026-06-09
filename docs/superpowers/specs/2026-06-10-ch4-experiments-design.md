# Chương 4 — Thực nghiệm & đánh giá — Design

Ngày: 2026-06-10
Phạm vi: harness thực nghiệm FP-Growth (base vs opt vs SPMF) sinh CSV + notebook vẽ
đồ thị, phủ req 3.4.2 (a–f). Không đụng code thuật toán (Chương 3 đã xong).

## 1. Mục tiêu

- So correctness bản nhóm (base, opt) với **SPMF thật** (Java) trên các benchmark.
- Đo và vẽ: thời gian theo minsup, số itemset theo minsup, peak memory, scalability,
  ảnh hưởng độ dài giao dịch.
- Tách compute nặng (script `.jl` → CSV) khỏi trình bày (notebook đọc CSV → đồ thị).
- Reproducible: minsup grid + seed cố định.

## 2. Môi trường (đã xác nhận)

- Java: openjdk 26 (đã cài).
- SPMF: `experiments/spmf/spmf.jar` (15.6M, đã tải). Lệnh:
  `java -jar spmf.jar run FPGrowth_itemsets <in> <out> <minsup>` (minsup tương đối, vd `0.95`).
  - Output format trùng bản nhóm: dòng `item item ... #SUP: count`.
  - Stdout in `Frequent itemsets count : N`, `Total time ~ X ms`, `Max memory usage: Y mb`
    → parse được để lấy đường SPMF cho time + memory.
- Julia deps thêm: `Plots`, `IJulia`. Dùng stdlib `Random`, `Printf`, `Statistics`.
  Tự ghi CSV (không thêm CSV.jl).

## 3. Kiến trúc & file

```
experiments/
|-- spmf/spmf.jar              # SPMF (gitignore — 15.6M)
|-- spmf_runner.jl             # chạy SPMF + parse output/stats
|-- datagen.jl                 # subset (scalability) + synthetic (txn-length), seed cố định
|-- run_experiments.jl         # driver: chạy tất cả thực nghiệm -> results/*.csv
|-- results/                   # CSV output (commit, nhỏ)
|   |-- timing.csv
|   |-- scalability.csv
|   |-- txnlen.csv
|   |-- correctness.csv
|-- figures/                   # PNG do notebook xuất (gitignore hoặc commit nhẹ)
notebooks/
|-- demo.ipynb                 # IJulia: đọc CSV -> đồ thị + demo thuật toán
```

### 3.1 spmf_runner.jl — interface
- `run_spmf(input::String, minsup::Float64; timeout=120)` → `(out_path, n_itemsets, time_ms, mem_mb, status)`.
  Gọi java, parse stdout (3 dòng stats), trả số liệu; `status ∈ {:ok, :timeout, :error}`.
- `read_itemsets_spmf(path)::Dict{Set{String},Int}` — đọc file SPMF, key = Set item (chuẩn hoá so sánh).
- `to_itemset_sets(d::Dict{Tuple,Int})::Dict{Set{String},Int}` — chuyển output bản nhóm sang cùng dạng để so.

### 3.2 datagen.jl — interface
- `subset_prefix(input, fraction)::String` — lấy `fraction` đầu (deterministic) → file tạm, trả path.
  (Dùng prefix thay vì random để ổn định; vẫn phản ánh scalability theo #giao dịch.)
- `gen_synthetic(n_trans, n_items, avg_len; seed)::String` — sinh CSDL tổng hợp độ dài TB
  `avg_len` (độ dài mỗi giao dịch ~ Poisson quanh avg_len, clamp ≥1), item uniform 1..n_items.
  Trả path file tạm. Seed cố định.

### 3.3 run_experiments.jl — driver
- Đo bản nhóm bằng helper `measure(f; warmup=true)` → `(time_ms, alloc_bytes, n_itemsets)`
  dùng `@timed` (warm-up loại JIT).
- Mỗi config có timeout mềm: chạy in-process; grid chọn sao cho base khả thi. Nếu một
  config được đánh dấu rủi ro (vd accidents minsup thấp cho base) → bỏ qua base, ghi
  `status=skip`. SPMF có timeout cứng qua `run_spmf`.
- Ghi CSV bằng `open(...,"w")` + `println` (header + rows).

## 4. Ma trận thực nghiệm (req 3.4.2 a–f)

Datasets: `chess, mushrooms, retail, T10I4D100K, accidents` (data/benchmark).

minsup grid (giữ base khả thi; base enumerate ~mũ nên vỡ ở minsup thấp trên dense):
- chess:       [0.95, 0.9, 0.85, 0.8, 0.75, 0.7]
- mushrooms:   [0.5, 0.4, 0.3, 0.25, 0.2, 0.15]
- retail:      [0.05, 0.02, 0.01, 0.005, 0.002, 0.001]
- T10I4D100K:  [0.05, 0.02, 0.01, 0.005, 0.002, 0.001]
- accidents:   [0.9, 0.8, 0.7, 0.6, 0.5]   (base có thể skip ở điểm thấp)

| Exp | Mô tả | Nguồn dữ liệu | CSV |
|-----|-------|---------------|-----|
| a | Correctness opt&base vs SPMF | mỗi dataset, 3 điểm minsup giữa grid | correctness.csv |
| b | Time vs minsup (base/opt/SPMF) | full grid mỗi dataset | timing.csv |
| c | #itemsets vs minsup | dùng cột n_itemsets của timing.csv | timing.csv |
| d | Peak memory base vs opt | tại minsup giữa grid (1 điểm/dataset) | timing.csv (alloc_bytes) |
| e | Scalability | retail + accidents, fraction 0.1/0.25/0.5/0.75/1.0, minsup cố định | scalability.csv |
| f | Avg txn length | synthetic: n_trans=20000, n_items=200, avg_len∈{5,10,15,20,25}, minsup cố định | txnlen.csv |

minsup cố định: scalability retail=0.01, accidents=0.7; txnlen=0.02 (sẽ tinh chỉnh nếu ra 0 itemset).

## 5. CSV schema

- `timing.csv`: `dataset,minsup,algo,time_ms,alloc_bytes,n_itemsets,status`
  - algo ∈ {base, opt, spmf}. SPMF: alloc_bytes = mem_mb*1e6 (từ stats), time_ms từ stats.
- `correctness.csv`: `dataset,minsup,algo,n_ours,n_spmf,n_match,match_ratio,support_mismatch`
  - so set itemset (chuẩn hoá Set) + support; `match_ratio = n_match/n_spmf`;
    `support_mismatch` = số itemset trùng key nhưng lệch support.
- `scalability.csv`: `dataset,fraction,n_trans,algo,time_ms,n_itemsets,status`
- `txnlen.csv`: `avg_len,algo,time_ms,n_itemsets,status`

## 6. Notebook demo.ipynb (IJulia + Plots)

- Section demo: load toy, dựng FP-tree, in vài frequent itemset (minh hoạ thuật toán).
- Section đồ thị (đọc CSV trong experiments/results):
  - time vs minsup mỗi dataset (3 đường) → figures/time_<ds>.png
  - #itemsets vs minsup mỗi dataset → figures/count_<ds>.png
  - bar peak memory base vs opt (gộp dataset) → figures/memory.png
  - scalability time vs #trans → figures/scalability.png
  - txnlen time vs avg_len → figures/txnlen.png
- Trục thời gian dùng log nếu chênh lớn. Mỗi hình có title + axis label (caption ở report).

## 7. Reproducibility & guards

- minsup grid + fixed seed (datagen) hard-code trong run_experiments.jl/datagen.jl.
- SPMF timeout 120s/config; bản nhóm: chọn grid khả thi, skip+ghi status khi cần.
- Output CSV deterministic (sort rows trước khi ghi).

## 8. Ngoài phạm vi
- README, docs/Report.pdf, Chương 5 ứng dụng, tối ưu FPMax.
- Peak RSS thật của tiến trình Julia (dùng alloc_bytes làm proxy + SPMF mem từ stats).

## 9. Tiêu chí hoàn thành
- `julia --project=. experiments/run_experiments.jl` chạy xong, sinh đủ 4 CSV.
- correctness.csv: match_ratio = 1.0, support_mismatch = 0 cho opt & base vs SPMF trên
  các điểm minsup đã chọn (mọi benchmark).
- demo.ipynb Restart&RunAll không lỗi, xuất đủ đồ thị vào experiments/figures.
- Đồ thị cho thấy opt < base về thời gian + memory ở vùng minsup thấp.
