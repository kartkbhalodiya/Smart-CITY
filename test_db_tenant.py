import psycopg2
# Trying the tenant-specific pooler hostname
db_url = "postgres://postgres.aaywhmjmsdkjzabtzfpg:Kartik%409089361130@aaywhmjmsdkjzabtzfpg.pooler.supabase.com:5432/postgres"
print(f"Testing Tenant-specific Pooler (5432) connection...")
try:
    conn = psycopg2.connect(db_url)
    print("Successfully connected to Tenant Pooler!")
    conn.close()
except Exception as e:
    print(f"Connection failed: {e}")
