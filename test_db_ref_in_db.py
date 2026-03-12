import psycopg2
# Trying to put project ref in the dbname
dsn = "host=aws-0-ap-south-1.pooler.supabase.com port=6543 user=postgres password=Kartik@9089361130 dbname=postgres.aaywhmjmsdkjzabtzfpg"
print(f"Testing project-ref in dbname...")
try:
    conn = psycopg2.connect(dsn)
    print("Successfully connected!")
    conn.close()
except Exception as e:
    print(f"Connection failed: {e}")
