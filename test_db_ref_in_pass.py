import psycopg2
# Trying tenant ID in the password prefix
dsn = "host=aws-0-ap-south-1.pooler.supabase.com port=6543 user=postgres password=aaywhmjmsdkjzabtzfpg:Kartik@9089361130 dbname=postgres"
print(f"Testing project-ref in password prefix...")
try:
    conn = psycopg2.connect(dsn)
    print("Successfully connected!")
    conn.close()
except Exception as e:
    print(f"Connection failed: {e}")
