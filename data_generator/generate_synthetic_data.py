#!/usr/bin/env python3
"""
Synthetic pharma commercial data generator.

Simulates ~N days of daily extracts from three source systems:

  mdm  -> product, hcp, sales_rep     (full "current state" extract each day;
                                        source_updated_at only changes on the
                                        rows that actually changed -- this is
                                        what lets a dbt snapshot timestamp
                                        strategy detect SCD2 changes)
  crm  -> hcp_visit                   (append-only event extract, one file
                                        of "today's visits" per day)
  erp  -> distributor, warehouse,     (distributor/warehouse: full
          sales_order, inventory_     current-state extract, SCD1 style;
          snapshot, return             sales_order/return: append-only event
                                        extracts; inventory_snapshot: full
                                        daily snapshot of on-hand qty by
                                        warehouse/product/batch)

Output layout mirrors the S3 raw landing zone:
    <raw_dir>/<source>/<table>/dt=YYYY-MM-DD/<table>_YYYYMMDD.csv

Usage:
    python generate_synthetic_data.py [--config config.yaml]
"""
from __future__ import annotations

import argparse
import csv
import datetime as dt
import os
import random
import sys
import uuid
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

import yaml
from faker import Faker

THERAPEUTIC_CATEGORIES = {
    "Oncology": ["Hematologist-Oncologist", "Medical Oncologist", "Radiation Oncologist"],
    "Cardiology": ["Cardiologist", "Interventional Cardiologist"],
    "Immunology": ["Rheumatologist", "Allergist-Immunologist"],
    "Endocrinology": ["Endocrinologist", "Diabetologist"],
    "Neurology": ["Neurologist", "Neuro-Oncologist"],
    "Respiratory": ["Pulmonologist", "Allergist-Immunologist"],
    "Infectious Disease": ["Infectious Disease Specialist", "Internal Medicine"],
    "Dermatology": ["Dermatologist"],
}
FORMULATIONS = ["Tablet", "Capsule", "Injection", "Oral Solution", "Prefilled Syringe", "Infusion"]
PRICE_TIERS = ["Tier 1 - Specialty", "Tier 2 - Branded", "Tier 3 - Generic-Equivalent"]
HCP_TIERS = ["Tier A - Key Opinion Leader", "Tier B - High Prescriber", "Tier C - Standard"]
VISIT_TYPES = ["Office Call", "Lunch & Learn", "Conference Booth", "Virtual Detail", "Sample Drop Only"]
DISTRIBUTOR_TIERS = ["National Wholesaler", "Regional Wholesaler", "Specialty Pharmacy Network"]
RETURN_REASONS = ["Damaged in Transit", "Overstock", "Near Expiry", "Product Recall", "Wrong Item Shipped"]
REGIONS = ["Northeast", "Southeast", "Midwest", "Southwest", "West"]


def load_config(path: str) -> dict:
    with open(path) as f:
        return yaml.safe_load(f)


class Clock:
    """Deterministic-ish 'now' for a given simulated business day, so files
    written for dt=2026-06-05 all carry timestamps on/after 2026-06-05."""

    def __init__(self, sim_date: dt.date):
        self.sim_date = sim_date

    def timestamp(self, hour: int | None = None) -> dt.datetime:
        h = hour if hour is not None else random.randint(6, 20)
        m = random.randint(0, 59)
        s = random.randint(0, 59)
        return dt.datetime.combine(self.sim_date, dt.time(h, m, s))

    def iso(self, hour: int | None = None) -> str:
        return self.timestamp(hour).isoformat(sep=" ")


@dataclass
class Product:
    product_id: str
    ndc_code: str
    product_name: str
    therapeutic_category: str
    formulation: str
    list_price: float
    price_tier: str
    is_active: bool
    source_updated_at: str


@dataclass
class Hcp:
    hcp_id: str
    npi_number: str
    first_name: str
    last_name: str
    specialty: str
    hcp_tier: str
    territory_id: str
    city: str
    state: str
    zip_code: str
    source_updated_at: str


@dataclass
class SalesRep:
    rep_id: str
    first_name: str
    last_name: str
    hire_date: str
    territory_id: str
    manager_rep_id: str
    region: str
    source_updated_at: str


@dataclass
class Distributor:
    distributor_id: str
    distributor_name: str
    distributor_tier: str
    city: str
    state: str
    zip_code: str
    source_updated_at: str


@dataclass
class Warehouse:
    warehouse_id: str
    warehouse_name: str
    region: str
    city: str
    state: str
    source_updated_at: str


@dataclass
class Batch:
    batch_id: str
    product_id: str
    manufacture_date: dt.date
    lot_expiry_date: dt.date


class PharmaDataGenerator:
    def __init__(self, config: dict, raw_dir: Path):
        self.cfg = config
        self.raw_dir = raw_dir
        random.seed(config["simulation"]["seed"])
        self.fake = Faker()
        Faker.seed(config["simulation"]["seed"])

        self.territories: list[str] = []
        self.products: dict[str, Product] = {}
        self.hcps: dict[str, Hcp] = {}
        self.reps: dict[str, SalesRep] = {}
        self.distributors: dict[str, Distributor] = {}
        self.warehouses: dict[str, Warehouse] = {}
        self.batches: dict[str, list[Batch]] = {}  # product_id -> [Batch]
        # inventory[(warehouse_id, product_id, batch_id)] = qty_on_hand
        self.inventory: dict[tuple, int] = {}
        self.order_seq = 0
        self.return_seq = 0
        self.visit_seq = 0
        self.recent_orders: list[dict] = []  # rolling window for generating returns

    # ---------------------------------------------------------------- init
    def init_master_data(self):
        v = self.cfg["volumes"]
        self.territories = [f"TERR-{i:03d}" for i in range(1, v["num_territories"] + 1)]
        self._init_products(v["num_products"], v["batches_per_product"])
        self._init_distributors(v["num_distributors"])
        self._init_warehouses(v["num_warehouses"])
        self._init_reps(v["num_sales_reps"])
        self._init_hcps(v["num_hcps"])

    def _init_products(self, n: int, batches_per_product: int):
        clock = Clock(self.start_date)
        stems = ["Card", "Onc", "Immu", "Endo", "Neuro", "Resp", "Derma", "Infec"]
        for i in range(1, n + 1):
            pid = f"PROD-{i:04d}"
            category = random.choice(list(THERAPEUTIC_CATEGORIES.keys()))
            name = f"{random.choice(stems)}{self.fake.lexify('??').capitalize()}{i:03d}"
            price = round(random.uniform(45.0, 3200.0), 2)
            product = Product(
                product_id=pid,
                ndc_code=f"{random.randint(10000,99999)}-{random.randint(1000,9999)}-{random.randint(10,99)}",
                product_name=f"{name} {random.choice(FORMULATIONS)}",
                therapeutic_category=category,
                formulation=random.choice(FORMULATIONS),
                list_price=price,
                price_tier=random.choice(PRICE_TIERS),
                is_active=True,
                source_updated_at=clock.iso(hour=6),
            )
            self.products[pid] = product
            self.batches[pid] = []
            for b in range(batches_per_product):
                mfg = self.start_date - dt.timedelta(days=random.randint(30, 300))
                shelf_life_days = random.choice([540, 730, 900])  # 18/24/30 months
                batch = Batch(
                    batch_id=f"LOT-{pid[-4:]}-{b+1:02d}",
                    product_id=pid,
                    manufacture_date=mfg,
                    lot_expiry_date=mfg + dt.timedelta(days=shelf_life_days),
                )
                self.batches[pid].append(batch)
                # seed initial inventory across a couple of warehouses; done after warehouses init below

    def _init_distributors(self, n: int):
        clock = Clock(self.start_date)
        for i in range(1, n + 1):
            did = f"DIST-{i:04d}"
            self.distributors[did] = Distributor(
                distributor_id=did,
                distributor_name=f"{self.fake.company()} Pharmaceutical Distribution",
                distributor_tier=random.choice(DISTRIBUTOR_TIERS),
                city=self.fake.city(),
                state=self.fake.state_abbr(),
                zip_code=self.fake.zipcode(),
                source_updated_at=clock.iso(hour=6),
            )

    def _init_warehouses(self, n: int):
        clock = Clock(self.start_date)
        for i in range(1, n + 1):
            wid = f"WH-{i:03d}"
            self.warehouses[wid] = Warehouse(
                warehouse_id=wid,
                warehouse_name=f"{self.fake.city()} Distribution Center",
                region=random.choice(REGIONS),
                city=self.fake.city(),
                state=self.fake.state_abbr(),
                source_updated_at=clock.iso(hour=6),
            )
        # now that warehouses exist, seed initial inventory for every batch
        for pid, batches in self.batches.items():
            for batch in batches:
                for wid in random.sample(list(self.warehouses.keys()), k=min(3, len(self.warehouses))):
                    self.inventory[(wid, pid, batch.batch_id)] = random.randint(200, 2000)

    def _init_reps(self, n: int):
        clock = Clock(self.start_date)
        rep_ids = [f"REP-{i:04d}" for i in range(1, n + 1)]
        # first ~15% are managers (manager_rep_id = None)
        num_managers = max(1, n // 7)
        managers = rep_ids[:num_managers]
        for i, rid in enumerate(rep_ids, start=1):
            is_manager = rid in managers
            self.reps[rid] = SalesRep(
                rep_id=rid,
                first_name=self.fake.first_name(),
                last_name=self.fake.last_name(),
                hire_date=self.fake.date_between(start_date="-8y", end_date="-30d").isoformat(),
                territory_id=random.choice(self.territories),
                manager_rep_id="" if is_manager else random.choice(managers),
                region=random.choice(REGIONS),
                source_updated_at=clock.iso(hour=6),
            )

    def _init_hcps(self, n: int):
        clock = Clock(self.start_date)
        for i in range(1, n + 1):
            hid = f"HCP-{i:05d}"
            category = random.choice(list(THERAPEUTIC_CATEGORIES.keys()))
            specialty = random.choice(THERAPEUTIC_CATEGORIES[category])
            self.hcps[hid] = Hcp(
                hcp_id=hid,
                npi_number=f"{random.randint(1000000000, 1999999999)}",
                first_name=self.fake.first_name(),
                last_name=self.fake.last_name(),
                specialty=specialty,
                hcp_tier=random.choice(HCP_TIERS),
                territory_id=random.choice(self.territories),
                city=self.fake.city(),
                state=self.fake.state_abbr(),
                zip_code=self.fake.zipcode(),
                source_updated_at=clock.iso(hour=6),
            )

    # ------------------------------------------------------------- daily
    def simulate_day(self, sim_date: dt.date):
        self.clock = Clock(sim_date)
        self._mutate_master_data(sim_date)
        self._maybe_replenish_inventory(sim_date)
        orders = self._generate_orders(sim_date)
        returns = self._generate_returns(sim_date)
        visits = self._generate_visits(sim_date)
        inv_snapshot = self._snapshot_inventory(sim_date)

        self._write_csv("mdm", "product", sim_date, self._products_rows())
        self._write_csv("mdm", "hcp", sim_date, self._hcps_rows())
        self._write_csv("mdm", "sales_rep", sim_date, self._reps_rows())
        self._write_csv("erp", "distributor", sim_date, self._distributors_rows())
        self._write_csv("erp", "warehouse", sim_date, self._warehouses_rows())
        self._write_csv("crm", "hcp_visit", sim_date, visits)
        self._write_csv("erp", "sales_order", sim_date, orders)
        self._write_csv("erp", "return", sim_date, returns)
        self._write_csv("erp", "inventory_snapshot", sim_date, inv_snapshot)

    def _mutate_master_data(self, sim_date: dt.date):
        rates = self.cfg["master_data_change_rates"]
        for p in self.products.values():
            if random.random() < rates["product_change_chance_per_day"]:
                # simulate a price/tier revision
                p.list_price = round(p.list_price * random.uniform(0.95, 1.08), 2)
                p.price_tier = random.choice(PRICE_TIERS)
                p.source_updated_at = self.clock.iso(hour=7)
        for h in self.hcps.values():
            if random.random() < rates["hcp_change_chance_per_day"]:
                # territory realignment or tier change
                if random.random() < 0.5:
                    h.territory_id = random.choice(self.territories)
                else:
                    h.hcp_tier = random.choice(HCP_TIERS)
                h.source_updated_at = self.clock.iso(hour=7)
        for r in self.reps.values():
            if random.random() < rates["rep_change_chance_per_day"]:
                r.territory_id = random.choice(self.territories)
                r.source_updated_at = self.clock.iso(hour=7)
        for d in self.distributors.values():
            if random.random() < rates["distributor_change_chance_per_day"]:
                d.distributor_tier = random.choice(DISTRIBUTOR_TIERS)
                d.source_updated_at = self.clock.iso(hour=7)
        for w in self.warehouses.values():
            if random.random() < rates["warehouse_change_chance_per_day"]:
                w.warehouse_name = f"{self.fake.city()} Distribution Center"
                w.source_updated_at = self.clock.iso(hour=7)

    def _maybe_replenish_inventory(self, sim_date: dt.date):
        chance = self.cfg["daily_activity"]["replenishment_chance_per_product_day"]
        for pid, batches in self.batches.items():
            if random.random() < chance:
                mfg = sim_date
                shelf_life_days = random.choice([540, 730, 900])
                new_batch = Batch(
                    batch_id=f"LOT-{pid[-4:]}-{len(batches)+1:02d}",
                    product_id=pid,
                    manufacture_date=mfg,
                    lot_expiry_date=mfg + dt.timedelta(days=shelf_life_days),
                )
                batches.append(new_batch)
                wid = random.choice(list(self.warehouses.keys()))
                self.inventory[(wid, pid, new_batch.batch_id)] = random.randint(500, 3000)

    def _active_batches_for(self, pid: str, warehouse_id: str, as_of: dt.date) -> list[Batch]:
        candidates = [
            b for b in self.batches[pid]
            if self.inventory.get((warehouse_id, pid, b.batch_id), 0) > 0
        ]
        # FEFO: first-expire-first-out
        candidates.sort(key=lambda b: b.lot_expiry_date)
        return candidates

    def _generate_orders(self, sim_date: dt.date) -> list[dict]:
        lo, hi = self.cfg["daily_activity"]["order_lines_per_day"]
        n = random.randint(lo, hi)
        rows = []
        product_ids = list(self.products.keys())
        warehouse_ids = list(self.warehouses.keys())
        for _ in range(n):
            pid = random.choice(product_ids)
            wid = random.choice(warehouse_ids)
            batches = self._active_batches_for(pid, wid, sim_date)
            if not batches:
                continue
            batch = batches[0]  # FEFO
            available = self.inventory[(wid, pid, batch.batch_id)]
            qty = min(available, random.randint(5, 250))
            if qty <= 0:
                continue
            self.inventory[(wid, pid, batch.batch_id)] -= qty

            self.order_seq += 1
            order_id = f"ORD-{sim_date:%Y%m%d}-{self.order_seq:05d}"
            product = self.products[pid]
            discount_pct = round(random.uniform(0.0, 0.15), 4)
            rebate_pct = round(random.uniform(0.0, 0.10), 4)
            gross = round(qty * product.list_price, 2)
            chargeback_amount = round(gross * random.uniform(0.0, 0.05), 2)
            ship_date = sim_date + dt.timedelta(days=random.randint(0, 3))

            row = {
                "order_id": order_id,
                "order_line_id": f"{order_id}-L1",
                "order_date": sim_date.isoformat(),
                "distributor_id": random.choice(list(self.distributors.keys())),
                "product_id": pid,
                "batch_id": batch.batch_id,
                "warehouse_id": wid,
                "quantity": qty,
                "list_price": product.list_price,
                "discount_pct": discount_pct,
                "rebate_pct": rebate_pct,
                "chargeback_amount": chargeback_amount,
                "ship_date": ship_date.isoformat(),
                "created_at": self.clock.iso(),
            }
            rows.append(row)
            self.recent_orders.append(row)
        # keep only last 14 days of orders in the rolling window used for returns
        cutoff = sim_date - dt.timedelta(days=14)
        self.recent_orders = [
            o for o in self.recent_orders if dt.date.fromisoformat(o["order_date"]) >= cutoff
        ]
        return rows

    def _generate_returns(self, sim_date: dt.date) -> list[dict]:
        lo, hi = self.cfg["daily_activity"]["returns_per_day"]
        n = random.randint(lo, hi)
        rows = []
        if not self.recent_orders:
            return rows
        for _ in range(n):
            src = random.choice(self.recent_orders)
            self.return_seq += 1
            rows.append({
                "return_id": f"RET-{sim_date:%Y%m%d}-{self.return_seq:05d}",
                "original_order_id": src["order_id"],
                "product_id": src["product_id"],
                "batch_id": src["batch_id"],
                "distributor_id": src["distributor_id"],
                "return_date": sim_date.isoformat(),
                "quantity": min(src["quantity"], random.randint(1, src["quantity"])),
                "reason_code": random.choice(RETURN_REASONS),
                "recall_flag": random.random() < 0.03,
                "created_at": self.clock.iso(),
            })
        return rows

    def _generate_visits(self, sim_date: dt.date) -> list[dict]:
        lo, hi = self.cfg["daily_activity"]["hcp_visits_per_day"]
        n = random.randint(lo, hi)
        rows = []
        rep_ids = list(self.reps.keys())
        hcp_ids = list(self.hcps.keys())
        product_ids = list(self.products.keys())
        for _ in range(n):
            self.visit_seq += 1
            samples = random.choice([0, 0, 5, 10, 15, 25])
            rows.append({
                "visit_id": f"VISIT-{sim_date:%Y%m%d}-{self.visit_seq:05d}",
                "rep_id": random.choice(rep_ids),
                "hcp_id": random.choice(hcp_ids),
                "visit_date": sim_date.isoformat(),
                "visit_type": random.choice(VISIT_TYPES),
                "duration_minutes": random.randint(5, 60),
                "samples_dropped_qty": samples,
                "sample_product_id": random.choice(product_ids) if samples > 0 else "",
                "created_at": self.clock.iso(),
            })
        return rows

    def _snapshot_inventory(self, sim_date: dt.date) -> list[dict]:
        rows = []
        for (wid, pid, batch_id), qty in self.inventory.items():
            batch = next(b for b in self.batches[pid] if b.batch_id == batch_id)
            rows.append({
                "snapshot_date": sim_date.isoformat(),
                "warehouse_id": wid,
                "product_id": pid,
                "batch_id": batch_id,
                "lot_expiry_date": batch.lot_expiry_date.isoformat(),
                "qty_on_hand": qty,
                "created_at": self.clock.iso(hour=23),
            })
        return rows

    # --------------------------------------------------------- row dumps
    def _products_rows(self):
        return [vars(p) for p in self.products.values()]

    def _hcps_rows(self):
        return [vars(h) for h in self.hcps.values()]

    def _reps_rows(self):
        return [vars(r) for r in self.reps.values()]

    def _distributors_rows(self):
        return [vars(d) for d in self.distributors.values()]

    def _warehouses_rows(self):
        return [vars(w) for w in self.warehouses.values()]

    # ------------------------------------------------------------ io
    def _write_csv(self, source: str, table: str, sim_date: dt.date, rows: list[dict]):
        if not rows:
            return
        out_dir = self.raw_dir / source / table / f"dt={sim_date:%Y-%m-%d}"
        out_dir.mkdir(parents=True, exist_ok=True)
        out_path = out_dir / f"{table}_{sim_date:%Y%m%d}.csv"
        fieldnames = list(rows[0].keys())
        with open(out_path, "w", newline="") as f:
            writer = csv.DictWriter(f, fieldnames=fieldnames)
            writer.writeheader()
            writer.writerows(rows)

    def run(self):
        sim = self.cfg["simulation"]
        self.start_date = dt.date.fromisoformat(sim["start_date"])
        self.init_master_data()
        num_days = sim["num_days"]
        for offset in range(num_days):
            sim_date = self.start_date + dt.timedelta(days=offset)
            self.simulate_day(sim_date)
            print(f"[generate_synthetic_data] wrote day {offset+1}/{num_days}: {sim_date.isoformat()}")
        print(f"[generate_synthetic_data] done. Output under: {self.raw_dir.resolve()}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", default=os.path.join(os.path.dirname(__file__), "config.yaml"))
    args = parser.parse_args()

    config = load_config(args.config)
    base_dir = Path(os.path.dirname(os.path.abspath(args.config)))
    raw_dir = (base_dir / config["output"]["raw_dir"]).resolve()
    raw_dir.mkdir(parents=True, exist_ok=True)

    gen = PharmaDataGenerator(config, raw_dir)
    gen.run()


if __name__ == "__main__":
    sys.exit(main())
