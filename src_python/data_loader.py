class Transaction:
    def __init__(self, items):
        self.items = list(items)


class DataLoader:
    def __init__(self, file_path: str):
        self.file_path = file_path
        self.transactions = {}

    def __parse_items(self, line: str):
        clean_line = line.strip()
        if not clean_line:
            return []

        if "{" in clean_line and "}" in clean_line:
            clean_line = clean_line[clean_line.find("{") + 1 : clean_line.rfind("}")]

        return [item.strip() for item in clean_line.split(",") if item.strip()]

    def load_transactions(self):
        with open(self.file_path, "r", encoding="utf-8") as f:
            transaction_idx = 1
            for line in f:
                items = self.__parse_items(line)
                if not items:
                    continue

                transaction = Transaction(items)
                self.transactions[f"t{transaction_idx}"] = transaction
                transaction_idx += 1

    def get_transactions(self):
        if not self.transactions:
            self.load_transactions()

        return self.transactions

    def get_unique_items(self):
        unique_items = set()
        for transaction in self.transactions.values():
            unique_items.update(transaction.items)
        return unique_items
