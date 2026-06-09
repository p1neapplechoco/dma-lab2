#!/usr/bin/env bash
# Tải SPMF jar dùng làm chuẩn đối chiếu (reference oracle) cho thực nghiệm Chương 4.
# SPMF chỉ chạy như TOOL hộp đen (không import lib, không sao chép mã nguồn).
# Yêu cầu: Java (openjdk >= 8). jar bị .gitignore vì nặng (~16MB).
#
# Dùng:  bash experiments/download_spmf.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="$SCRIPT_DIR/spmf/spmf.jar"
URL="https://www.philippe-fournier-viger.com/spmf/spmf.jar"

mkdir -p "$SCRIPT_DIR/spmf"

if [ -f "$DEST" ]; then
    echo "spmf.jar đã có: $DEST"
else
    echo "Tải SPMF jar từ $URL ..."
    curl -sS -L -o "$DEST" "$URL" --max-time 300
    echo "Đã lưu: $DEST ($(du -h "$DEST" | cut -f1))"
fi

# Kiểm tra Java + smoke test trên chess minsup 0.95 (kỳ vọng 77 itemset).
if ! command -v java >/dev/null 2>&1; then
    echo "CẢNH BÁO: chưa cài Java. Cài rồi mới chạy được SPMF." >&2
    exit 0
fi

echo "Lệnh chạy SPMF FPGrowth (dùng bởi experiments/spmf_runner.jl):"
echo "  java -jar spmf/spmf.jar run FPGrowth_itemsets <input> <output> <minsup>"
echo
echo "Smoke test (chess, minsup=0.95):"
java -jar "$DEST" run FPGrowth_itemsets \
    "$SCRIPT_DIR/../data/benchmark/chess.txt" /tmp/spmf_smoke.txt 0.95 \
    | grep -E "Frequent itemsets count|Total time" || true
