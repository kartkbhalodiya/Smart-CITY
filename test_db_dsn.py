import psycopg2
# DSN string format
dsn = "host=aws-0-ap-south-1.pooler.supabase.com port=6543 user=postgres.aaywhmjmsdkjzabtzfpg password=Kartik@9089361130 dbname=postgres"
print(f"Testing DSN connection to pooler...")
try:
    conn = psycopg2.connect(dsn)
    print("Successfully connected!")
    conn.close()
except Exception as e:
    print(f"Connection failed: {e}")
