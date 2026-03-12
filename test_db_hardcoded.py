import psycopg2
db_url = "postgres://postgres.aaywhmjmsdkjzabtzfpg:Kartik%409089361130@aws-0-ap-south-1.pooler.supabase.com:6543/postgres"
print(f"Testing HARDCODED connection...")
try:
    conn = psycopg2.connect(db_url)
    print("Successfully connected!")
    conn.close()
except Exception as e:
    print(f"Connection failed: {e}")
