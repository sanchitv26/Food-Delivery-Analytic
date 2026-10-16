import pandas as pd
import mysql.connector

df = pd.read_csv("D:/food_delivery_project/data/orders_load_ready.csv")
print("Rows in CSV:", len(df))

# Turn blanks (NaN) into proper NULLs for MySQL
df = df.astype(object).where(df.notna(), None)

conn = mysql.connector.connect(
    host="localhost",
    user="root",
    password="cement",
    database="food_delivery_analytics",
)
cur = conn.cursor()

cur.execute("DELETE FROM orders")   # start clean so re-running never duplicates rows

placeholders = ", ".join(["%s"] * df.shape[1])
sql = f"INSERT INTO orders VALUES ({placeholders})"

cur.executemany(sql, df.values.tolist())
conn.commit()

cur.execute("SELECT COUNT(*) FROM orders")
print("Rows now in MySQL:", cur.fetchone()[0])

cur.close()
conn.close()