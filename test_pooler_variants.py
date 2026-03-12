import psycopg2
import os
from dotenv import load_dotenv

load_dotenv()

# The project ref
ref = "aaywhmjmsdkjzabtzfpg"
pw = "Kartik@9089361130"
host = "aws-0-ap-south-1.pooler.supabase.com"

variants = [
    # Variant 1: Project ref in username (standard Supavisor)
    {"user": f"postgres.{ref}", "port": 6543, "dbname": "postgres"},
    # Variant 2: Project ref in username, port 5432 (Session mode)
    {"user": f"postgres.{ref}", "port": 5432, "dbname": "postgres"},
    # Variant 3: Just postgres as user, ref in dbname
    {"user": "postgres", "port": 6543, "dbname": f"postgres.{ref}"},
]

for v in variants:
    print(f"\nTesting: {v}")
    dsn = f"host={host} port={v['port']} user={v['user']} password={pw} dbname={v['dbname']}"
    try:
        conn = psycopg2.connect(dsn, connect_timeout=5)
        print("SUCCESS!")
        conn.close()
        break
    except Exception as e:
        print(f"FAILED: {e}")
