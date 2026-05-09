import collections
from collections import defaultdict
from typing import List, Dict, Tuple, Optional
import numpy as np


class FPNode:
    """
    node class to represent the fp-tree
    """

    def __init__(
        self, item: Optional[str], count: int = 0, parent: Optional["FPNode"] = None
    ):
        self.item = item
        self.count = count
        self.parent = parent
        self.children = set()


class FPGrowth:
    def __init__(self, min_sup: float):
        if not 0 <= min_sup <= 1:
            raise ValueError("min_sup should be a value between 0 and 1")

        self.min_sup = min_sup
        self.supports_table = defaultdict(int)

        self.root = FPNode(None)
        self.nodes_table = {}

    def __insert_item(self, item: str, parent: FPNode):

        for child in parent.children:
            if child.item == item:
                child.count += 1
                return child

        new_node = FPNode(item, 1, parent)
        parent.children.add(new_node)
        return new_node

    def fit(self, transactions):
        # step 1: count the support of each item
        for transaction in transactions:
            for item in transaction.items:
                self.supports_table[item] += 1

        # step 2: filter out items that do not meet the minimum support
        self.supports_table = {
            item: count
            for item, count in self.supports_table.items()
            if count >= self.min_sup * len(transactions)
        }

        # step 3: sort items in transactions by support count
        for transaction in transactions:
            transaction.items = sorted(
                [item for item in transaction.items if item in self.supports_table],
                key=lambda x: self.supports_table[x],
                reverse=True,
            )

        # step 4: build the fp-tree
        for transaction in transactions:
            root = self.root
            for item in transaction.items:
                root = self.__insert_item(item, root)

        # step 5: build the nodes table
        self.nodes_table = defaultdict(list)
        nodes_to_visit = [child for child in self.root.children]
        while nodes_to_visit:
            node = nodes_to_visit.pop()
            self.nodes_table[node.item].append(node)
            nodes_to_visit.extend(node.children)

    def mine_roads(self, item: str) -> Dict[Tuple[str, ...], int]:
        if item not in self.nodes_table:
            return {}

        roads = {}
        for node in self.nodes_table[item]:
            count = node.count
            road = []
            parent = node.parent

            while parent and parent.item is not None:
                road.append(parent.item)
                parent = parent.parent

            roads[(tuple(road[::-1]))] = count

        return roads

    def visualize_tree(self, node, prefix="", is_last=True, is_root=True):
        if is_root:
            print("root" if node.item is None else f"{node.item}: {node.count}")
        else:
            connector = "└── " if is_last else "├── "
            print(f"{prefix}{connector}{node.item}: {node.count}")

        marker = "" if is_root else ("    " if is_last else "│   ")
        new_prefix = prefix + marker

        for i, child in enumerate(node.children):
            is_last_child = i == len(node.children) - 1
            self.visualize_tree(child, new_prefix, is_last_child, is_root=False)
