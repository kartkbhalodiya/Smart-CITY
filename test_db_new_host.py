import psycopg2
# Trying the .supabase.com hostname which sometimes resolves to IPv4 pooler
db_url = "postgres://postgres:Kartik%409089361130@aaywhmjmsdkjzabtzfpg.supabase.com:5432/postgres"
print(f"Testing aaywhmjmsdkjzabtzfpg.supabase.com (5432) connection...")
try:
    conn = psycopg2.connect(db_url)
    print("Successfully connected!")
    conn.close()
except Exception as e:
    print(f"Connection failed: {e}")
