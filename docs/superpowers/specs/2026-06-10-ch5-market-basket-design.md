# Chương 5 — Ứng dụng: Market Basket Analysis — Design

Ngày: 2026-06-10
Phạm vi: sinh luật kết hợp (association rules) từ frequent itemsets do **chính cài đặt
của nhóm** (`FPGrowthOpt`) tạo ra, trên CSDL groceries. Phủ req §3.5 (Chương 5, optional).

## 1. Mục tiêu

- Từ frequent itemsets → sinh luật X ⇒ Y với support, confidence, lift.
- Xếp top-10 luật theo lift (giữ lift > 1), xuất bảng + CSV.
- Dùng FPGrowthOpt của nhóm, KHÔNG dùng SPMF/thư viện FIM (req §3.5: "Phần ứng dụng
  không được dùng kết quả từ thư viện FIM có sẵn").

## 2. Dữ liệu

- `data/groceries.txt` (đã có trong repo): 9835 giao dịch, 169 item tên thật
  (comma-separated, vd `citrus fruit,semi-finished bread,...`). `parse_items` đọc được.
- Không cần tải thêm.

## 3. Kiến trúc & file

```
src/association_rules.jl     # struct + generate_rules (vào package, export)
experiments/application.jl   # driver: groceries -> rules -> top-10 + CSV
experiments/results/rules_groceries.csv   # output (commit)
test/test_correctness.jl     # thêm testset luật trên test_1
notebooks/demo.ipynb         # thêm section Ch5 (in top-10)
```

### 3.1 src/association_rules.jl

```julia
struct AssociationRule
    antecedent::Vector{String}
    consequent::Vector{String}
    support::Float64      # sup(X∪Y) / N      (relative)
    confidence::Float64   # sup(X∪Y) / sup(X)
    lift::Float64         # confidence / (sup(Y) / N)
end

# itemsets: Dict{Tuple{Vararg{String}}, Int} (support tuyệt đối) từ get_frequent_itemsets.
# Trả vector luật có confidence >= minconf.
generate_rules(itemsets, n_transactions::Int; minconf::Float64 = 0.2)::Vector{AssociationRule}
```

Thuật toán:
- Lập `support_abs(itemset_sorted_tuple) -> count` từ `itemsets` (key đã sort sẵn).
- Với mỗi Z trong keys, `length(Z) >= 2`:
  - Với mỗi kích thước k = 1..length(Z)-1, mỗi subset X = `combinations(collect(Z), k)`:
    - Y = các item trong Z không thuộc X.
    - supX = support_abs[sort(X)]; supZ = itemsets[Z]; supY = support_abs[sort(Y)].
    - conf = supZ / supX; lift = conf / (supY / n_transactions).
    - Nếu conf >= minconf → push AssociationRule(sort(X), sort(Y), supZ/n, conf, lift).
- Mọi sup luôn tồn tại trong `itemsets` (tính chất downward-closure: subset của frequent
  itemset cũng frequent).

Export `AssociationRule`, `generate_rules` trong `FrequentItemsetMining.jl`. Cần
`combinations` (đã có trong utils.jl).

### 3.2 experiments/application.jl

```julia
using FrequentItemsetMining
# load groceries -> FPGrowthOpt(minsup) -> itemsets -> generate_rules(minconf)
# -> lọc lift>1 -> sort lift desc -> top-10 -> in bảng + ghi CSV
```
- minsup = 0.01, minconf = 0.2, N = số giao dịch.
- In top-10: `{antecedent} => {consequent}  sup=.. conf=.. lift=..`.
- Ghi `experiments/results/rules_groceries.csv` (sort lift desc, toàn bộ luật lift>1).

### 3.3 CSV schema
`antecedent,consequent,support,confidence,lift`
- antecedent/consequent: item nối bằng `;` (tránh trùng dấu `,` của CSV).

## 4. Test (test_correctness.jl, thêm testset)

Trên `data/toy/test_1.txt`, FPGrowth(0.6), build rules minconf=0.5. Kiểm 1 luật cụ thể:
- itemset {1,3} sup=3, {1} sup=3, {3} sup=4, N=5.
- luật {1}⇒{3}: conf = 3/3 = 1.0; lift = 1.0 / (4/5) = 1.25.
- `@test` tồn tại luật antecedent=["1"], consequent=["3"] với confidence≈1.0, lift≈1.25.

## 5. Notebook

Thêm section "## 4. Ứng dụng: Market Basket (groceries)" gọi `include application.jl`
hoặc lặp lại logic, in top-10 luật.

## 6. Reproducibility
- minsup/minconf hard-code trong application.jl. Không random.
- CSV sort deterministic (lift desc, tie-break antecedent rồi consequent).

## 7. Ngoài phạm vi
- README, docs/Report.pdf (giải thích ý nghĩa kinh doanh viết ở report).
- Metric khác (conviction, leverage) — chỉ support/confidence/lift theo spec.

## 8. Tiêu chí hoàn thành
- `julia --project=. experiments/application.jl` in top-10 luật theo lift + sinh CSV.
- Test luật trên test_1 pass (conf=1.0, lift=1.25 cho {1}⇒{3}).
- Toàn bộ `test/runtests.jl` vẫn pass.
- Luật sinh từ FPGrowthOpt của nhóm (không dùng SPMF).
