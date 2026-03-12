import psycopg2
# Trying user=postgres and dbname=project-ref
dsn = "host=aws-0-ap-south-1.pooler.supabase.com port=6543 user=postgres password=Kartik@9089361130 dbname=aaywhmjmsdkjzabtzfpg"
print(f"Testing user=postgres and dbname=project-ref...")
try:
    conn = psycopg2.connect(dsn)
    print("Successfully connected!")
    conn.close()
except Exception as e:
    print(f"Connection failed: {e}")
