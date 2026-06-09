from collections import defaultdict
from itertools import combinations
from typing import Dict, List, Set, Tuple

from .fp_growth import FPGrowth


class FPMax(FPGrowth):
    def __init__(self, min_sup: float):
        super().__init__(min_sup)
        self.transactions: List[Set[str]] = []

    def fit(self, transactions):
        transaction_list = list(transactions)
        self.transactions = [set(transaction.items) for transaction in transaction_list]

        # Ensure deterministic tie-breaking for equal-support items.
        for transaction in transaction_list:
            transaction.items = sorted(transaction.items)

        super().fit(transaction_list)

    def simple_get_maximal_itemsets(self) -> Dict[Tuple[str, ...], int]:
        """
        Brute-force maximal itemsets used as a correctness baseline.
        """
        if not self.transactions:
            return {}

        frequent_itemsets = {}
        unique_items = sorted({item for tx in self.transactions for item in tx})

        for size in range(1, len(unique_items) + 1):
            for itemset in combinations(unique_items, size):
                itemset_set = set(itemset)
                support = sum(1 for tx in self.transactions if itemset_set.issubset(tx))
                if support >= self.min_sup_count:
                    frequent_itemsets[itemset] = support

        itemsets = list(frequent_itemsets.keys())
        itemset_sets = {itemset: set(itemset) for itemset in itemsets}

        maximal_itemsets = {}

        for itemset in itemsets:
            current_set = itemset_sets[itemset]
            is_strict_subset = any(
                itemset != other and current_set < itemset_sets[other]
                for other in itemsets
            )

            if not is_strict_subset:
                maximal_itemsets[itemset] = frequent_itemsets[itemset]

        return maximal_itemsets

    def _is_single_path(self, tree) -> bool:
        node = tree.root
        while node.children:
            if len(node.children) > 1:
                return False
            node = next(iter(node.children))
        return True

    def _single_path_items(self, tree) -> List[str]:
        items = []
        node = tree.root
        while node.children:
            node = next(iter(node.children))
            items.append(node.item)
        return items

    def _item_support_in_tree(self, tree, item: str) -> int:
        return sum(node.count for node in tree.nodes_table.get(item, []))

    def _head_pattern_base(self, tree, item: str) -> Dict[Tuple[str, ...], int]:
        roads = defaultdict(int)

        for node in tree.nodes_table.get(item, []):
            path = []
            parent = node.parent

            while parent and parent.item is not None:
                path.append(parent.item)
                parent = parent.parent

            if path:
                roads[tuple(reversed(path))] += node.count

        return dict(roads)

    def _frequent_items_in_base(
        self, roads: Dict[Tuple[str, ...], int]
    ) -> Dict[str, int]:
        support_counter = defaultdict(int)

        for road, count in roads.items():
            for item in road:
                support_counter[item] += count

        return {
            item: support
            for item, support in support_counter.items()
            if support >= self.min_sup_count
        }

    def _build_conditional_tree(
        self, roads: Dict[Tuple[str, ...], int], item_supports: Dict[str, int]
    ):
        tree = FPMax(self.min_sup)
        tree.min_sup_count = self.min_sup_count
        tree.supports_table = dict(item_supports)
        tree.nodes_table = defaultdict(list)

        for road, count in roads.items():
            ordered_items = sorted(road, key=lambda x: (-item_supports[x], x))
            for _ in range(count):
                parent = tree.root
                for road_item in ordered_items:
                    parent = tree._FPGrowth__insert_item(road_item, parent)

        nodes_to_visit = list(tree.root.children)
        while nodes_to_visit:
            node = nodes_to_visit.pop()
            tree.nodes_table[node.item].append(node)
            nodes_to_visit.extend(node.children)

        return tree

    def _insert_mfi(self, mfi_sets: List[Set[str]], candidate: Set[str]):
        if not candidate:
            return

        for existing in mfi_sets:
            if candidate.issubset(existing):
                return

        pruned_sets = [existing for existing in mfi_sets if not existing < candidate]
        pruned_sets.append(candidate)
        mfi_sets[:] = pruned_sets

    def _support_in_transactions(self, itemset: Set[str]) -> int:
        return sum(
            1 for transaction in self.transactions if itemset.issubset(transaction)
        )

    def get_maximal_itemsets(self) -> Dict[Tuple[str, ...], int]:
        """
        FP-Max mining using Head/Tail subset checking.
        """
        if not self.transactions:
            return {}

        mfi_sets: List[Set[str]] = []

        def fpmax(tree, head: List[str]):
            if self._is_single_path(tree):
                candidate = set(head) | set(self._single_path_items(tree))
                self._insert_mfi(mfi_sets, candidate)
                return

            header_items = sorted(
                tree.nodes_table.keys(),
                key=lambda x: (self._item_support_in_tree(tree, x), x),
            )

            for item in header_items:
                head.append(item)
                roads = self._head_pattern_base(tree, item)
                tail_supports = self._frequent_items_in_base(roads)
                tail = set(tail_supports.keys())

                if not any((set(head) | tail).issubset(mfi) for mfi in mfi_sets):
                    filtered_roads = defaultdict(int)
                    for road, count in roads.items():
                        filtered = tuple(
                            road_item for road_item in road if road_item in tail
                        )
                        if filtered:
                            filtered_roads[filtered] += count

                    conditional_tree = self._build_conditional_tree(
                        dict(filtered_roads), tail_supports
                    )
                    fpmax(conditional_tree, head)

                head.pop()

        fpmax(self, [])

        maximal_itemsets = {}
        for mfi in mfi_sets:
            itemset = tuple(sorted(mfi))
            maximal_itemsets[itemset] = self._support_in_transactions(mfi)

        return maximal_itemsets
