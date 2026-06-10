# Chương 5 — Market Basket Analysis — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Sinh luật kết hợp (support/confidence/lift) từ frequent itemsets của FPGrowthOpt trên groceries, xuất top-10 theo lift.

**Architecture:** Thêm `generate_rules` vào package (dùng `combinations` có sẵn). Script `application.jl` chạy trên groceries → top-10 + CSV. Test luật trên test_1. Notebook thêm section Ch5.

**Tech Stack:** Julia, package FrequentItemsetMining, Printf (stdlib).

---

## File Structure

- `src/association_rules.jl` — `AssociationRule` + `generate_rules` (CREATE)
- `src/FrequentItemsetMining.jl` — include + export (MODIFY)
- `experiments/application.jl` — driver groceries → rules → CSV (CREATE)
- `experiments/results/rules_groceries.csv` — output (commit)
- `test/test_correctness.jl` — thêm testset luật (MODIFY)
- `notebooks/demo.ipynb` — thêm section Ch5 (MODIFY)

---

## Task 1: association_rules.jl — generate_rules (TDD)

**Files:**
- Create: `src/association_rules.jl`
- Modify: `src/FrequentItemsetMining.jl`
- Test: `test/test_correctness.jl`

- [ ] **Step 1: Thêm testset thất bại vào cuối `test/test_correctness.jl`**

```julia
@testset "Association rules" begin
    transactions = collect(values(load_transactions("data/toy/test_1.txt")))
    model = FPGrowth(0.6); fit!(model, transactions)
    itemsets = get_frequent_itemsets(model)
    rules = generate_rules(itemsets, length(transactions); minconf = 0.5)

    idx = findfirst(x -> x.antecedent == ["1"] && x.consequent == ["3"], rules)
    @test idx !== nothing
    @test isapprox(rules[idx].confidence, 1.0; atol = 1e-9)
    @test isapprox(rules[idx].lift, 1.25; atol = 1e-9)
end
```

- [ ] **Step 2: Chạy test, kỳ vọng FAIL (generate_rules chưa có)**

```bash
cd "/home/lesliu/Documents/school/25_26_Semester_2/data-mining/lab2"
julia --project=. test/runtests.jl 2>&1 | grep -E "Association|UndefVarError|generate_rules" | head -3
```
Expected: lỗi `UndefVarError: generate_rules not defined` (hoặc testset Association fail/error).

- [ ] **Step 3: Tạo `src/association_rules.jl`**

```julia
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
```

- [ ] **Step 4: Wire include + export trong `src/FrequentItemsetMining.jl`**

Thêm `include("association_rules.jl")` ngay sau dòng `include("algorithm/fp_max.jl")`.
Thêm `AssociationRule,` và `generate_rules,` vào danh sách export (cạnh `FPGrowthOpt`).

- [ ] **Step 5: Chạy test, kỳ vọng PASS**

```bash
cd "/home/lesliu/Documents/school/25_26_Semester_2/data-mining/lab2"
julia --project=. test/runtests.jl 2>&1 | grep -E "Association rules|Fail|Error"
```
Expected: `Association rules | 3  3` Pass, không Fail/Error.

- [ ] **Step 6: Commit**

```bash
git add src/association_rules.jl src/FrequentItemsetMining.jl test/test_correctness.jl
git commit -m "feat: association rule generation (support/confidence/lift)"
```

---

## Task 2: application.jl — groceries top-10 + CSV

**Files:**
- Create: `experiments/application.jl`

- [ ] **Step 1: Tạo `experiments/application.jl`**

```julia
using FrequentItemsetMining
using Printf

const GROCERIES = joinpath(@__DIR__, "..", "data", "groceries.txt")
const RESULTS = joinpath(@__DIR__, "results")

function run_application(; minsup = 0.01, minconf = 0.2, topk = 10)
    transactions = collect(values(load_transactions(GROCERIES)))
    n = length(transactions)
    model = FPGrowthOpt(minsup); fit!(model, transactions)
    itemsets = get_frequent_itemsets(model)
    rules = generate_rules(itemsets, n; minconf = minconf)
    filter!(r -> r.lift > 1.0, rules)
    sort!(rules; by = r -> (-r.lift, join(r.antecedent, ";"), join(r.consequent, ";")))

    println("Groceries: $n giao dịch, minsup=$minsup, minconf=$minconf")
    println("#frequent itemsets=$(length(itemsets)), #rules(lift>1)=$(length(rules))")
    println("\nTop-$topk luật theo lift:")
    for r in rules[1:min(topk, length(rules))]
        @printf("{%s} => {%s}  sup=%.4f conf=%.3f lift=%.3f\n",
                join(r.antecedent, ", "), join(r.consequent, ", "),
                r.support, r.confidence, r.lift)
    end

    mkpath(RESULTS)
    out = joinpath(RESULTS, "rules_groceries.csv")
    open(out, "w") do io
        println(io, "antecedent,consequent,support,confidence,lift")
        for r in rules
            @printf(io, "%s,%s,%.6f,%.6f,%.6f\n",
                    join(r.antecedent, ";"), join(r.consequent, ";"),
                    r.support, r.confidence, r.lift)
        end
    end
    println("\nCSV: ", out)
    return rules
end

run_application()
```

- [ ] **Step 2: Chạy + kiểm output**

```bash
cd "/home/lesliu/Documents/school/25_26_Semester_2/data-mining/lab2"
julia --project=. experiments/application.jl 2>&1 | tail -18
echo "--- csv head ---"; head -5 experiments/results/rules_groceries.csv
```
Expected: in top-10 luật, lift giảm dần, đều > 1; ví dụ luật quen thuộc kiểu
`{other vegetables, ...} => {whole milk}` hoặc nhóm rau/sữa/thịt. CSV có header + nhiều dòng.

- [ ] **Step 3: Commit**

```bash
git add experiments/application.jl experiments/results/rules_groceries.csv
git commit -m "feat: market basket application on groceries (top-10 rules by lift)"
```

---

## Task 3: Notebook section Ch5 + verify toàn bộ

**Files:**
- Modify: `notebooks/demo.ipynb`

- [ ] **Step 1: Thêm 2 cell vào `notebooks/demo.ipynb`**

Chèn trước cell metadata cuối (sau cell hiển thị figures), 2 cell mới: 1 markdown + 1 code.
Markdown source:
```
## 4. Ứng dụng: Market Basket Analysis (groceries)
```
Code source (1 dòng):
```
include(joinpath(@__DIR__, "..", "experiments", "application.jl"))
```

Dùng Read tool xem cấu trúc JSON hiện tại rồi Edit chèn 2 object cell vào mảng `cells`
(đúng định dạng JSON, có dấu phẩy ngăn cách). Cấu trúc 2 cell:

```json
  {
   "cell_type": "markdown",
   "metadata": {},
   "source": ["## 4. Ứng dụng: Market Basket Analysis (groceries)"]
  },
  {
   "cell_type": "code",
   "execution_count": null,
   "metadata": {},
   "outputs": [],
   "source": ["include(joinpath(@__DIR__, \"..\", \"experiments\", \"application.jl\"))"]
  },
```

- [ ] **Step 2: Verify JSON hợp lệ**

```bash
cd "/home/lesliu/Documents/school/25_26_Semester_2/data-mining/lab2"
python -c 'import json; d=json.load(open("notebooks/demo.ipynb")); print("cells:", len(d["cells"]))'
```
Expected: `cells: 10` (8 cũ + 2 mới), không lỗi JSON.

- [ ] **Step 3: Chạy full test suite (đảm bảo không vỡ gì)**

```bash
cd "/home/lesliu/Documents/school/25_26_Semester_2/data-mining/lab2"
julia --project=. test/runtests.jl 2>&1 | grep -E "Summary|Fail|Error|Association"
```
Expected: mọi testset Pass (gồm "Association rules"), 0 Fail/Error.

- [ ] **Step 4: Commit**

```bash
git add notebooks/demo.ipynb
git commit -m "feat: notebook section for Ch5 market basket application"
```

---

## Done criteria
- `julia --project=. experiments/application.jl` in top-10 luật theo lift + sinh `rules_groceries.csv`.
- Test "Association rules" pass: {1}⇒{3} có confidence=1.0, lift=1.25.
- Toàn bộ `test/runtests.jl` pass.
- Luật sinh từ FPGrowthOpt của nhóm (không SPMF).
