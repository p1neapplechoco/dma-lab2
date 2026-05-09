from pathlib import Path
from src_python import DataLoader, Transaction, FPGrowth, FPMax

DATA_PATH = Path("./data/test_2.txt")
data_loader = DataLoader(str(DATA_PATH))

transactions = data_loader.get_transactions()
unique_items = data_loader.get_unique_items()

for t_id, transaction in transactions.items():
    print(f"{t_id}: {transaction.items}")

fp_growth = FPGrowth(min_sup=0.6)
fp_growth.fit(transactions.values())
fp_growth.visualize_tree(fp_growth.root)

for item in unique_items:
    roads = fp_growth.mine_roads(item)
    if not roads:
        continue
    print(f"\nItem: {item}")
    for road, count in roads.items():
        print(f"Road: {' -> '.join(road)}, Count: {count}")
