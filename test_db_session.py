import psycopg2
db_url = "postgres://postgres.aaywhmjmsdkjzabtzfpg:Kartik%409089361130@aws-0-ap-south-1.pooler.supabase.com:5432/postgres"
print(f"Testing Session Pooler (5432) connection...")
try:
    conn = psycopg2.connect(db_url)
    print("Successfully connected to Session Pooler!")
    conn.close()
except Exception as e:
    print(f"Connection failed: {e}")
