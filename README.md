# Khai thác tập phổ biến — FP-Growth

Đồ án cài đặt từ đầu họ thuật toán **FP-Growth** cho bài toán khai thác tập phổ biến (Frequent Itemset Mining), gồm ba nhánh: FP-Growth cơ bản, FP-Growth tối ưu và FP-Max. Cài đặt chính bằng **Julia**, đóng gói thành package `FrequentItemsetMining`. Báo cáo đầy đủ nằm ở `docs/Report.pdf`.

Không sử dụng bất kỳ thư viện FIM có sẵn nào. SPMF chỉ được gọi như một công cụ hộp đen để đối chiếu kết quả ở Chương 4.

## Cấu trúc thư mục

```
.
├── src/                         # Package Julia FrequentItemsetMining
│   ├── FrequentItemsetMining.jl # Module entry
│   ├── structures.jl            # Transaction, DataLoader, FPNode, FPNodeOpt
│   ├── utils.jl                 # Tiện ích chung (combinations, ...)
│   ├── data_loader.jl           # Đọc dữ liệu giao dịch (định dạng SPMF và dấu phẩy)
│   ├── algorithm/
│   │   ├── fp_growth.jl         # FP-Growth cơ bản
│   │   ├── fp_growth_opt.jl     # FP-Growth tối ưu
│   │   └── fp_max.jl            # FP-Max
│   ├── association_rules.jl     # Sinh luật kết hợp (Chương 5)
│   └── io.jl                    # Xuất itemset theo định dạng SPMF
├── main.jl                      # Giao diện dòng lệnh
├── test/                        # Bộ kiểm thử tự động
├── experiments/                 # Harness thực nghiệm Chương 4 và ứng dụng Chương 5
├── data/                        # CSDL toy, benchmark và Groceries
├── notebooks/demo.ipynb         # Notebook minh hoạ (Restart & Run All)
├── docs/Report.pdf              # Báo cáo
├── Project.toml / Manifest.toml # Khai báo và khoá phiên bản phụ thuộc
```

## Môi trường và cài đặt

Yêu cầu **Julia ≥ 1.9** (kiểm thử trên Julia 1.12).

### Cài đặt Julia

Cách khuyến nghị là dùng `juliaup` — trình quản lý phiên bản chính thức của Julia.

- **Linux / macOS:**

  ```bash
  curl -fsSL https://install.julialang.org | sh
  ```

- **Windows:** cài từ Microsoft Store (tìm "Julia") hoặc chạy `winget install julia -s msstore`.

Sau khi cài, mở terminal mới và kiểm tra:

```bash
juliaup add 1.12      # tuỳ chọn: ghim đúng phiên bản đã kiểm thử
julia --version       # kỳ vọng: julia version 1.12.x (hoặc >= 1.9)
```

Nếu không muốn dùng `juliaup`, có thể tải bản cài sẵn cho từng hệ điều hành tại <https://julialang.org/downloads/> rồi thêm thư mục `bin` của Julia vào `PATH`.

### Cài đặt phụ thuộc

Từ thư mục gốc của đồ án, cài phụ thuộc theo `Manifest.toml` đã khoá để đảm bảo tái lập:

```bash
julia --project=. -e 'using Pkg; Pkg.instantiate()'
```

## Cách chạy

Giao diện dòng lệnh nhận đường dẫn dữ liệu, ngưỡng minsup tương đối, thuật toán và đường dẫn output (tuỳ chọn):

```bash
julia --project=. main.jl <input_path> <minsup> [fp-growth|fp-growth-opt|fp-max|rules] [output_path]
```

Ví dụ khai thác tập phổ biến trên CSDL toy với minsup `0.6`:

```bash
julia --project=. main.jl data/toy/test_1.txt 0.6 fp-growth-opt output.txt
```

Đầu vào theo định dạng SPMF: mỗi giao dịch một dòng, item cách nhau bằng khoảng trắng (parser cũng chấp nhận dòng có dấu phẩy). Đầu ra theo dạng:

```
item1 item2 ... #SUP: support_count
```

Chế độ `rules` sinh trực tiếp luật kết hợp (lift > 1, sắp theo lift) từ tập phổ biến. Ngưỡng confidence đặt qua `MINCONF` (mặc định `0.2`), số luật in ra qua `TOPK` (mặc định `10`). Với dữ liệu item có khoảng trắng trong tên (ví dụ Groceries), đặt `SEP=comma` để chỉ tách theo dấu phẩy:

```bash
SEP=comma julia --project=. main.jl data/groceries.txt 0.01 rules rules.csv
```

Lệnh trên tái tạo kết quả phần ứng dụng: 333 frequent itemsets và 231 luật.

## Kiểm thử

```bash
julia --project=. test/runtests.jl
```

Bộ kiểm thử gồm: kiểm tra parser ba định dạng, FP-Growth và FP-Max trên CSDL toy ở Chương 2, đối chiếu bản tối ưu với bản cơ bản trên **năm CSDL khác nhau** (hai toy và ba benchmark: chess, mushrooms, retail), kiểm tra sinh luật kết hợp, và benchmark đối chiếu base/opt trên chess. Output lần chạy gần nhất (25/25 pass):

```
Test Summary:                         | Pass  Total
Data loading                          |    5      5
FP-Growth baseline                    |    1      1
FP-Max baseline                       |    1      1
FP-Growth opt == base                 |   14     14
Association rules                     |    3      3
FP-Growth opt benchmark (base vs opt) |    1      1
[bench] chess minsup=0.9 — opt nhanh hơn base x4.06, mem x2.09
```

> Lưu ý: các tỉ lệ tốc độ/bộ nhớ trong dòng [bench] là số đo on-the-fly của
> test, phụ thuộc máy và lần chạy (JIT warm-up, GC) nên có thể dao động và
> không trùng với số liệu cố định ở Bảng 7 của báo cáo.

## Tái lập thực nghiệm Chương 4

Thực nghiệm cần SPMF (làm chuẩn đối chiếu) và đầy đủ năm tập benchmark.

1. **Tải SPMF jar** (yêu cầu Java ≥ 8, jar bị `.gitignore` vì nặng):

   ```bash
   bash experiments/download_spmf.sh
   ```

2. **Tải dataset.** Toàn bộ dữ liệu (gồm cả `accidents.txt` > 25MB không đưa vào repo) được lưu trên Google Drive. Tải về và đặt đúng theo cây thư mục `data/`:

   > Thư mục dữ liệu trên Google Drive: <https://drive.google.com/drive/folders/1TuKapS5SYeWS1D8Zs4gegZHlqNAh36NE?usp=sharing>

   Bốn tập chess, mushrooms, retail, T10I4D100K đã có sẵn trong `data/benchmark/`; chỉ cần bổ sung `accidents.txt` từ Drive vào `data/benchmark/` để chạy đầy đủ thực nghiệm.

3. **Chạy thực nghiệm** (sinh các file CSV trong `experiments/results/`):

   ```bash
   julia --project=. experiments/run_experiments.jl
   ```

   Có thể giới hạn tập dữ liệu qua biến môi trường, ví dụ bỏ qua accidents:

   ```bash
   EXP_DATASETS=chess,mushrooms,retail,T10I4D100K julia --project=. experiments/run_experiments.jl
   ```

4. **Sinh biểu đồ** (vào `experiments/figures/`):

   ```bash
   julia --project=. experiments/make_figures.jl
   ```

## Ứng dụng Chương 5 — phân tích giỏ hàng

Sinh luật kết hợp trên tập Groceries (minsup `0.01`, minconf `0.2`), in top-10 luật theo lift và ghi `experiments/results/rules_groceries.csv`:

```bash
julia --project=. experiments/application.jl
```

Kết quả mong đợi: 333 frequent itemsets và 231 luật có lift lớn hơn 1.

## Notebook

`notebooks/demo.ipynb` dùng kernel Julia, minh hoạ pipeline từ nạp dữ liệu tới khai thác và sinh luật. Trước khi nộp đã chạy Restart & Run All để mọi cell có output tuần tự.

## Tái lập (reproducibility)

Mọi dữ liệu tổng hợp dùng seed cố định (`experiments/datagen.jl`, seed `42`); `Manifest.toml` khoá toàn bộ phiên bản phụ thuộc. Chạy lại các lệnh trên cho ra cùng kết quả.
