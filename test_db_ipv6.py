import psycopg2
# Trying to use the IPv6 address directly
dsn = "host=[2406:da14:271:991a:1f9d:761b:9e44:ed5e] port=5432 user=postgres password=Kartik@9089361130 dbname=postgres"
print(f"Testing IPv6 connection...")
try:
    conn = psycopg2.connect(dsn)
    print("Successfully connected!")
    conn.close()
except Exception as e:
    print(f"Connection failed: {e}")
