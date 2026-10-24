#!/usr/bin/env bash
# Exports the PostgreSQL asset list to assets.json so that the MongoDB scan
# documents use the same hostnames and IP addresses as the relational data.
# Usage: ./export_assets.sh [database]
set -euo pipefail
cd "$(dirname "$0")"
psql -d "${1:-ead}" -X -At -c "
  SELECT json_agg(json_build_object('client_id', s.client_id,
                                    'hostname',  a.hostname,
                                    'ip',        host(a.ip_address))
                  ORDER BY a.asset_id)
  FROM ead.asset a JOIN ead.client_site s ON s.site_id = a.site_id" > assets.json
echo "Wrote $(grep -o hostname assets.json | wc -l) assets to assets.json"
