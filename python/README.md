# Bản prototype Python (code ban đầu)

Thư mục này là **bản cài đặt ban đầu** của đồ án, viết bằng Python để thử nghiệm ý tưởng FP-Growth và FP-Max trước khi xây dựng bản chính thức.

> ⚠️ Đây **không phải** sản phẩm nộp. Cài đặt đầy đủ, đã tối ưu, kiểm thử và dùng cho thực nghiệm/báo cáo là package Julia `FrequentItemsetMining` ở thư mục gốc của repo (xem `README.md` ở gốc). Thư mục này giữ lại để tham khảo quá trình phát triển.

## Nội dung

- `fim/data_loader.py` — đọc giao dịch (định dạng SPMF, dấu phẩy, hoặc `{...}`).
- `fim/fp_growth.py` — FP-tree và khai thác toàn bộ tập phổ biến (FP-Growth).
- `fim/fp_max.py` — FP-Max khai thác tập phổ biến tối đại: nhận diện single-path, danh sách MFI loại tập con, tỉa theo siêu tập; kèm `simple_get_maximal_itemsets` (brute-force) làm baseline đối chiếu.
- `main.py` — demo nhanh trên CSDL toy `data/toy/test_1.txt`.

## Chạy thử

Yêu cầu Python ≥ 3.8, không cần thư viện ngoài.

```bash
cd python
python main.py
```
