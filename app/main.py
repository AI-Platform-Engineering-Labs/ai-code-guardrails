"""orders-api: the small service used in the "Vibe Coding to Production" demo."""

import os
import sqlite3
import uuid
from contextlib import closing
from datetime import UTC, datetime

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field

DB_PATH = os.getenv("DB_PATH", "/tmp/orders.db")  # noqa: S108 - demo storage, recreated on start

app = FastAPI(title="orders-api", version=os.getenv("APP_VERSION", "dev"))


def db() -> sqlite3.Connection:
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def init_db() -> None:
    with closing(db()) as conn, conn:
        conn.execute(
            "CREATE TABLE IF NOT EXISTS orders "
            "(id TEXT PRIMARY KEY, item TEXT NOT NULL, quantity INTEGER NOT NULL, created_at TEXT NOT NULL)"
        )


init_db()


class OrderIn(BaseModel):
    item: str = Field(min_length=1, max_length=100)
    quantity: int = Field(gt=0, le=1000)


@app.get("/healthz")
def healthz() -> dict:
    return {"status": "ok", "version": app.version}


@app.post("/orders", status_code=201)
def create_order(order: OrderIn) -> dict:
    record = {
        "id": str(uuid.uuid4()),
        "item": order.item,
        "quantity": order.quantity,
        "created_at": datetime.now(UTC).isoformat(),
    }
    with closing(db()) as conn, conn:
        conn.execute(
            "INSERT INTO orders (id, item, quantity, created_at) VALUES (:id, :item, :quantity, :created_at)",
            record,
        )
    return record


@app.get("/orders/{order_id}")
def get_order(order_id: str) -> dict:
    with closing(db()) as conn:
        row = conn.execute("SELECT * FROM orders WHERE id = ?", (order_id,)).fetchone()
    if row is None:
        raise HTTPException(status_code=404, detail="order not found")
    return dict(row)
