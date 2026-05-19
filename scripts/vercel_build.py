import os
import subprocess
import sys


def run_manage(*args):
    subprocess.check_call([sys.executable, "manage.py", *args])


def main():
    if os.getenv("VERCEL") and not os.getenv("DATABASE_URL"):
        print(
            "ERROR: DATABASE_URL is required on Vercel. "
            "Without a real Postgres database, DB-backed pages fail with Server Error (500).",
            file=sys.stderr,
        )
        return 1

    run_manage("check", "--deploy")
    run_manage("migrate", "--noinput")
    run_manage("collectstatic", "--noinput")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
