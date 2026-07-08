#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MIGRATIONS_DIR="$REPO_ROOT/supabase/migrations"

usage() {
  cat <<EOF
Usage: $0 [--conn <DATABASE_URL>] [--clean] [--yes] [--list]

Options:
  --conn <DATABASE_URL>  Connection string (overrides .env). Example: postgresql://user:pass@localhost:5432/db
  --clean                Drop and recreate public schema before applying migrations (dangerous).
  --yes                  Skip confirmation prompt when --clean is used.
  --list                 Only list the ordered migration files (no DB changes).

This script applies SQL files from the project's `supabase/migrations` directory in ascending filename order.
It tries to load credentials from a `.env` file in the repository root if no `--conn` is provided.
EOF
}

# parse args
CLEAN=false
ASSUME_YES=false
LIST_ONLY=false
CONN=""

while [[ $# -gt 0 ]]; do
  case "${1:-}" in
    --conn)
      CONN="$2"; shift 2;;
    --clean)
      CLEAN=true; shift;;
    --yes)
      ASSUME_YES=true; shift;;
    --list)
      LIST_ONLY=true; shift;;
    -h|--help)
      usage; exit 0;;
    *)
      echo "Unknown option: $1"; usage; exit 2;;
  esac
done

# Load .env if present (simple, non-destructive source)
if [[ -f "$REPO_ROOT/.env" ]]; then
  # shellcheck disable=SC1090
  set -a; source "$REPO_ROOT/.env"; set +a
fi

# Determine connection
if [[ -z "$CONN" ]]; then
  if [[ -n "${DATABASE_URL:-}" ]]; then
    CONN="$DATABASE_URL"
  elif [[ -n "${SUPABASE_DB_URL:-}" ]]; then
    CONN="$SUPABASE_DB_URL"
  else
    # Allow env-style PG variables
    if [[ -n "${PGHOST:-}" ]] || [[ -n "${PGUSER:-}" ]]; then
      # Build a connection string
      : ${PGHOST:=localhost}
      : ${PGPORT:=5432}
      : ${PGUSER:=postgres}
      : ${PGDATABASE:=postgres}
      # PGPASSWORD might be empty; psql will prompt
      CONN="postgresql://$PGUSER@$PGHOST:$PGPORT/$PGDATABASE"
    fi
  fi
fi

if [[ "$LIST_ONLY" == true ]]; then
  echo "Migrations directory: $MIGRATIONS_DIR"
  find "$MIGRATIONS_DIR" -maxdepth 1 -type f -name "*.sql" | sort
  exit 0
fi

if [[ -z "$CONN" ]]; then
  echo "No database connection found. Provide --conn or set DATABASE_URL / SUPABASE_DB_URL or PG* env vars in .env." >&2
  exit 2
fi

# Ensure psql exists
if ! command -v psql >/dev/null 2>&1; then
  echo "psql not found in PATH. Please install PostgreSQL client tools." >&2
  exit 2
fi

# Confirm clean action
if [[ "$CLEAN" == true ]]; then
  if [[ "$ASSUME_YES" != true ]]; then
    echo "WARNING: --clean will DROP SCHEMA public CASCADE and recreate it. This will erase data. Continue? (y/N)"
    read -r ans || true
    if [[ "${ans,,}" != "y" && "${ans,,}" != "yes" ]]; then
      echo "Aborted by user."; exit 1
    fi
  fi
  echo "Dropping and recreating public schema..."
  psql "$CONN" -v ON_ERROR_STOP=1 -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;"
fi

# Apply migrations
mapfile -t files < <(find "$MIGRATIONS_DIR" -maxdepth 1 -type f -name "*.sql" | sort)
if [[ ${#files[@]} -eq 0 ]]; then
  echo "No migration files found in $MIGRATIONS_DIR" >&2; exit 1
fi

echo "Applying ${#files[@]} migration(s) to $CONN"
for f in "${files[@]}"; do
  echo "--> Applying: $f"
  psql "$CONN" -v ON_ERROR_STOP=1 -f "$f"
done

echo "All migrations applied."
