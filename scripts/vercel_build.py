import os
import subprocess
import sys
from urllib.parse import urlparse

from smartcity.database_url import normalize_database_url


def run_manage(*args):
    subprocess.check_call([sys.executable, "manage.py", *args])


def main():
    raw_database_url = os.getenv("DATABASE_URL", "")
    database_url = normalize_database_url(raw_database_url)
    if database_url != raw_database_url:
        os.environ["DATABASE_URL"] = database_url
        print("INFO: Normalized DATABASE_URL to the Supabase pooler host.", file=sys.stderr)

    if os.getenv("VERCEL") and not database_url:
        print(
            "ERROR: DATABASE_URL is required on Vercel. "
            "Without a real Postgres database, DB-backed pages fail with Server Error (500).",
            file=sys.stderr,
        )
        return 1

    parsed_database_url = urlparse(database_url)
    hostname = parsed_database_url.hostname or ""
    username = parsed_database_url.username or ""
    try:
        port = parsed_database_url.port
    except ValueError:
        print(
            "ERROR: DATABASE_URL has an invalid port. Use a full Postgres URL, "
            "for example postgres://postgres.<project-ref>:<password>@"
            "aws-0-<region>.pooler.supabase.com:6543/postgres.",
            file=sys.stderr,
        )
        return 1

    if os.getenv("VERCEL") and hostname.lower() in {"host", "hostname", "localhost", "127.0.0.1"}:
        print(
            "ERROR: DATABASE_URL still contains a local or placeholder host. "
            "Use the real production database host. For Supabase on Vercel, use the "
            "Supavisor transaction pooler URL from Supabase Project -> Connect -> "
            "Connection string -> Transaction pooler.",
            file=sys.stderr,
        )
        return 1
    if os.getenv("VERCEL") and hostname.startswith("db.") and hostname.endswith(".supabase.co"):
        print(
            "ERROR: Vercel cannot reliably connect to Supabase direct database hosts "
            "(db.<project>.supabase.co:5432) because they resolve to IPv6. "
            "Set DATABASE_URL to the Supabase Supavisor pooler connection string instead, "
            "for example postgres://postgres.<project-ref>:<password>@aws-0-<region>.pooler.supabase.com:6543/postgres.",
            file=sys.stderr,
        )
        return 1

    if os.getenv("VERCEL") and hostname.endswith(".pooler.supabase.com"):
        if port != 6543 or "." not in username:
            print(
                "ERROR: Supabase pooler DATABASE_URL should use transaction mode, "
                "for example postgres://postgres.<project-ref>:<password>@"
                "aws-0-<region>.pooler.supabase.com:6543/postgres.",
                file=sys.stderr,
            )
            return 1

    run_manage("check", "--deploy")
    run_manage("migrate", "--noinput")
    run_manage("collectstatic", "--noinput")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
