from urllib.parse import quote, unquote, urlparse


SUPABASE_PROJECT_REF = "aaywhmjmsdkjzabtzfpg"
SUPABASE_POOLER_HOST = "aws-1-ap-northeast-1.pooler.supabase.com"
SUPABASE_POOLER_PORT = 6543

_PLACEHOLDER_HOSTS = {"host", "hostname", "localhost", "127.0.0.1"}


def normalize_database_url(database_url):
    if not database_url:
        return database_url

    parsed = urlparse(database_url)
    hostname = (parsed.hostname or "").lower()
    uses_legacy_host = hostname in _PLACEHOLDER_HOSTS
    uses_supabase_direct_host = hostname.startswith("db.") and hostname.endswith(".supabase.co")

    if not uses_legacy_host and not uses_supabase_direct_host:
        return database_url

    scheme = parsed.scheme or "postgresql"
    username = quote(f"postgres.{SUPABASE_PROJECT_REF}", safe=".")
    password = parsed.password or ""
    password_segment = f":{quote(unquote(password), safe='')}" if password else ""
    database_name = parsed.path or "/postgres"
    query = f"?{parsed.query}" if parsed.query else ""
    fragment = f"#{parsed.fragment}" if parsed.fragment else ""

    return (
        f"{scheme}://{username}{password_segment}@"
        f"{SUPABASE_POOLER_HOST}:{SUPABASE_POOLER_PORT}{database_name}{query}{fragment}"
    )
