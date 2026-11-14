# Testing Guide: Running the TerraCyber Database Project in the Cloud

This guide takes you step by step through running and testing all five portfolios, collecting your own outputs and screenshots, and committing them to GitHub. You do **not** need to install anything on your laptop: everything runs in a browser through **GitHub Codespaces**.

**Time needed:** about 3 to 4 hours in total, which you can spread over several sessions (one per portfolio is a good rhythm for your commit history).

## Contents

1. [Which option to use](#1-which-option-to-use)
2. [Before you start](#2-before-you-start)
3. [Part A: Create your Codespace](#3-part-a-create-your-codespace)
4. [Part B: Portfolios 1 to 3 (PostgreSQL)](#4-part-b-portfolios-1-to-3-postgresql)
5. [Part C: Portfolio 4 (MongoDB and Neo4j)](#5-part-c-portfolio-4-mongodb-and-neo4j)
6. [Part D: Portfolio 5 (distributed setup)](#6-part-d-portfolio-5-distributed-setup)
7. [Part E: Save and commit your evidence](#7-part-e-save-and-commit-your-evidence)
8. [Part F: Stop the Codespace when you finish](#8-part-f-stop-the-codespace-when-you-finish)
9. [Troubleshooting](#9-troubleshooting)
10. [Other options: Azure VM or your own laptop](#10-other-options-azure-vm-or-your-own-laptop)

## 1. Which option to use

| Option | What it is | Cost | Recommended for |
| --- | --- | --- | --- |
| **GitHub Codespaces** (recommended) | A Linux machine in your browser, opened directly from your repository | Free within the monthly allowance (see below) | Everything: all five portfolios |
| Azure virtual machine | An Ubuntu server you create in Azure | Uses Azure credit; charged while running | If you prefer Azure or have used up the Codespaces allowance |
| Your own laptop | Docker Desktop and PostgreSQL installed locally | Free | If your laptop has at least 16 GB RAM |

**Why Codespaces:** your repository is already on GitHub, so the Codespace opens with all the files in place. The repository contains a configuration file (`.devcontainer/devcontainer.json`) that installs Docker, the PostgreSQL 16 client and Graphviz automatically, so there is nothing to set up by hand. Your changes can be committed straight back to GitHub from the same window.

**Free allowance:** GitHub Free personal accounts include 120 core hours and 15 GB of storage per month. On the recommended 4-core machine that is about 30 hours of running time, far more than this guide needs. Without a payment method on your account, GitHub simply stops the Codespace when the allowance is used up; it does not charge you.

## 2. Before you start

- You are signed in to GitHub as the owner of `MIVA-Data-Base-Management-for-Terracyb-Consulting`.
- Use a recent Chrome, Edge or Firefox.
- Know how to take a screenshot on your computer: **Windows:** `Windows + Shift + S`; **Mac:** `Cmd + Shift + 4`.
- **About the existing screenshots:** the repository already contains screenshots captured from test runs on 14 November 2026. As you go through this guide, replace each one with your own capture (same file name) and update the date in its README caption. Your own runs are the strongest evidence of your work.

**Note on testing:** every script in this guide was run successfully on PostgreSQL 16. The Codespace setup itself has not yet been run end to end, so if a step behaves differently, check [section 9](#9-troubleshooting).

## 3. Part A: Create your Codespace

1. Open your repository on GitHub.
2. Click the green **Code** button, then the **Codespaces** tab.
3. Click the **...** menu next to "Create codespace on main" and choose **New with options**.
4. Set **Machine type** to **4-core** (16 GB RAM). Portfolio 5 runs seven database containers and needs the memory.
5. Click **Create codespace**. A VS Code editor opens in the browser. The first start takes 3 to 5 minutes while the tools are installed; wait until the terminal at the bottom shows a prompt and no more installation messages.
6. Check the setup in the terminal:

```bash
docker --version          # expected: Docker version 2x.x
psql --version            # expected: psql (PostgreSQL) 16.x
```

**Useful Codespace tips:**

- **Project folder:** the variable `$CODESPACE_VSCODE_FOLDER` always points to the repository folder, so `cd "$CODESPACE_VSCODE_FOLDER"` takes you back to the top.

- **Terminal:** if it is not visible, use the menu **Terminal > New Terminal**.
- **Two terminals side by side:** click the **split** icon (two rectangles) in the terminal toolbar. You need this for Portfolio 3.
- **Browsing files:** the file explorer is on the left; screenshots (`.png`) and logs open with a click.

## 4. Part B: Portfolios 1 to 3 (PostgreSQL)

### B1. Start PostgreSQL 16

```bash
docker run -d --name ead-pg -e POSTGRES_PASSWORD=terracyber-demo -p 5432:5432 postgres:16
sleep 10
createdb ead
```

The Codespace already sets `PGHOST`, `PGUSER` and `PGPASSWORD`, so `psql -d ead` connects without asking for a password.

### B2. Portfolio 1: design and constraints

```bash
cd "$CODESPACE_VSCODE_FOLDER"/portfolio-1-database-design
psql -d ead -f schema.sql
psql -d ead -f seed.sql | tee output/seed-row-counts.txt
psql -d ead -c "\dt ead.*"
psql -d ead -f test_constraints.sql 2>&1 | tee constraint-test-output.txt
python3 make_erd.py
```

| Check | Expected result |
| --- | --- |
| `seed.sql` row counts | 18 tables; `finding` = 66240, `asset` = 850, `client` = 20, `state` = 37 |
| `\dt ead.*` | 18 rows |
| `test_constraints.sql` | 12 lines containing `ERROR`, one under each of T1 to T12 |
| `make_erd.py` | `erd.png written: 18 tables, 22 relationships` |

**Screenshots to take** (save into `portfolio-1-database-design/screenshots/` with these names):

| File | What to capture |
| --- | --- |
| `01-tables.png` | The terminal after `\dt ead.*` |
| `02-seed-row-counts.png` | The row-count table at the end of `seed.sql` |
| `03-constraint-tests.png` | The 12 errors from `test_constraints.sql` |

To save a screenshot into the Codespace, drag the image file from your computer onto the `screenshots` folder in the file explorer, and confirm replacing the old file.

### B3. Portfolio 2: queries and optimisation

```bash
cd ../portfolio-2-query-optimisation
./run_queries.sh
./run_benchmark.sh
psql -d ead -f join_strategies.sql > plans/join-strategies.txt
```

| Check | Expected result |
| --- | --- |
| `run_queries.sh` | 9 files in `results/query-results/` |
| `run_benchmark.sh` | A timing table; Q1, Q2 and Q6b much faster after; Q3, Q5 and Q6a about the same |
| `plans/before/` and `plans/after/` | 9 and 10 plan files |

Then:

1. Open `results/timings.md` and copy your numbers into the table in section 5 of `portfolio-2-query-optimisation/README.md`.
2. Replace the hardware line with your machine type (for example "GitHub Codespaces, 4-core, 16 GB RAM").
3. Rewrite the interpretation paragraph in your own words.

**Screenshots:** `01-q1-plan-before-after.png` (run `cat plans/before/q1_open_critical_findings.txt`, then `cat plans/after/q1_open_critical_findings.txt`, and capture the key lines), `02-benchmark.png` (the end of `run_benchmark.sh`) and `03-q8-result.png` (run `cat results/query-results/q8_open_risk_by_office_and_zone.txt`).

### B4. Portfolio 3: transactions and concurrency

**Scripted scenarios:**

```bash
cd ../portfolio-3-transactions-concurrency
./run_all.sh
grep -h "Final\|read:\|Analysts after" output/*.log
```

| Check | Expected result |
| --- | --- |
| Lost update | `Final hours_allocated: 110.0` (no lock), then `115.0` (with FOR UPDATE) |
| Isolation, Part 1 | READ COMMITTED: two different counts; REPEATABLE READ: the same count twice |
| Isolation, Part 2 | REPEATABLE READ: `Analysts after: 0`; SERIALIZABLE: `could not serialize access` and `Analysts after: 1` |
| Deadlock | `ERROR: deadlock detected`; one session is the victim, the other finishes |

**Two-terminal lock demo (the brief's side-by-side screenshot):**

1. Split the terminal so you have two side by side (and open a third with **Terminal > New Terminal** for the monitor).
2. In **both** terminals: `cd "$CODESPACE_VSCODE_FOLDER"/portfolio-3-transactions-concurrency`
3. In the **left** terminal, run `psql -d ead -a -f session_a.sql`
4. **Within 4 seconds**, in the **right** terminal, run `psql -d ead -a -f session_b.sql`. It pauses at "B requests the same row": it is waiting for A's lock.
5. **While B waits**, run `psql -d ead -a -f monitor.sql` in the third terminal: B shows `Lock | transactionid`.
6. When A commits, B continues and reads A's value. Take the screenshot of both terminals: `01-lock-wait-two-terminals.png`. The monitor gives `02-lock-wait-monitor.png`.
7. Reset for another try:

```bash
psql -d ead -c "UPDATE ead.engagement_staff SET hours_allocated = 50 WHERE engagement_id = 1 AND consultant_id = 6;"
```

**Other screenshots:** `03` to `06` (lost update, isolation, write skew, deadlock): open each log in `output/` and capture it, or re-run the individual script, for example `./05_deadlock.sh`.

**Commit now** (see [Part E](#7-part-e-save-and-commit-your-evidence)), then stop the PostgreSQL container if you are moving on to Portfolio 5 in the same session:

```bash
docker stop ead-pg
```

## 5. Part C: Portfolio 4 (MongoDB and Neo4j)

```bash
cd "$CODESPACE_VSCODE_FOLDER"/portfolio-4-nosql
docker compose up -d
sleep 30                     # Neo4j needs about half a minute to start
docker compose ps            # tc-mongo and tc-neo4j should be "Up"
```

**MongoDB:**

```bash
docker exec -i tc-mongo mongosh terracyber /scripts/01_create_collection.js
docker exec -i tc-mongo mongosh terracyber /scripts/02_load_evidence.js
docker exec -i tc-mongo mongosh terracyber /scripts/03_queries.js > evidence-samples/mongo-output.txt
less evidence-samples/mongo-output.txt          # press q to exit
```

| Check | Expected result |
| --- | --- |
| `01_create_collection.js` | "Collection 'evidence' created" and a validator rejection message (expected) |
| `02_load_evidence.js` | "Total documents: 3006" |
| `03_queries.js`, indexes | BEFORE: stage `COLLSCAN`, `docsExamined` 3006; AFTER: stage `IXSCAN`, far fewer documents examined |

**Screenshot:** one scan document, for example:

```bash
docker exec -it tc-mongo mongosh terracyber --eval 'printjson(db.evidence.findOne({_id: "EV-2026-00001"}))'
```

**Neo4j:**

```bash
docker exec tc-neo4j cypher-shell -u neo4j -p terracyber-demo -f /scripts/01_create_graph.cypher
docker exec tc-neo4j cypher-shell -u neo4j -p terracyber-demo -f /scripts/02_attack_paths.cypher > evidence-samples/neo4j-output.txt
cat evidence-samples/neo4j-output.txt
```

Expected: attack paths that start from `lagoon-1-010`, `lagoon-1-003` or `lagoon-1-007` and end at critical assets, plus shortest paths, blast radius and choke points.

**Neo4j Browser screenshot (the graph picture):**

1. Open the **Ports** tab next to the terminal. Right-click port **7687**, choose **Port Visibility > Public**. Do the same for **7474**.
2. Click the globe icon next to port **7474** to open Neo4j Browser.
3. In the connection form, set **Connect URL** to the address shown for port 7687, written as `neo4j+s://<that-address>:443` (copy the address from the Ports tab and remove `https://`).
4. Log in with user `neo4j` and password `terracyber-demo`, run `MATCH (n) RETURN n`, and take the screenshot.
5. If Neo4j Browser will not connect, capture the `cypher-shell` output instead and note this in the README; the attack-path results are the substance of the evidence.

Set both ports back to **Private** afterwards. Then stop the containers:

```bash
docker compose down
```

## 6. Part D: Portfolio 5 (distributed setup)

Make sure port 5432 is free (`docker stop ead-pg` from Part B), then:

```bash
cd "$CODESPACE_VSCODE_FOLDER"/portfolio-5-distributed-cloud
docker compose up -d
docker compose ps            # repeat until the three pg- containers show "(healthy)"
```

The first start takes 1 to 2 minutes: `pg-lagos` loads the schema and 66,240 findings, then `pg-portharcourt` copies it.

**Screenshot:** `docker compose ps` with all containers running (`04-docker-compose-ps.png`).

**Run in this order** (sharding needs a writable Lagos primary, and the failover demo stops Lagos):

```bash
# 1. Sharding: public-sector findings to Abuja
docker exec -i pg-lagos psql -U postgres -d ead -f /sql/geo_sharding.sql 2>&1 | tee output/geo_sharding.log

# 2. MongoDB replica set, all three sites up
docker exec -i mongo-portharcourt mongosh \
    "mongodb://mongo-lagos,mongo-portharcourt,mongo-abuja/terracyber?replicaSet=rs0" \
    /scripts/replica-set-demo.js 2>&1 | tee output/mongo_rs_before_failure.log

# 3. MongoDB failover: lose Lagos, wait for the election, run again
docker stop mongo-lagos
sleep 15
docker exec -i mongo-portharcourt mongosh \
    "mongodb://mongo-portharcourt,mongo-abuja/terracyber?replicaSet=rs0" \
    /scripts/replica-set-demo.js 2>&1 | tee output/mongo_rs_after_failure.log
docker start mongo-lagos

# 4. PostgreSQL replication and failover (stops pg-lagos)
./replication_failover_demo.sh 2>&1 | tee output/replication_failover.log
```

| Check | Expected result |
| --- | --- |
| `geo_sharding.log` | `finding_geo_private` 31870, `finding_geo_ngo` 16810, `finding_geo_public` 17560; a `Foreign Scan` with `Remote SQL` |
| `mongo_rs_before_failure.log` | `mongo-lagos` PRIMARY, two SECONDARY; `w:3` acknowledged |
| `mongo_rs_after_failure.log` | A new PRIMARY in Port Harcourt or Abuja; `w:3` NOT fully acknowledged |
| `replication_failover.log` | `state \| streaming` in the primary's status; read-only error on Port Harcourt; promotion time; the write succeeds after promotion |

**Optional, strong CAP evidence:** the synchronous replication steps in section 5.5 of the Portfolio 5 README. Run them **before** step 4 above, because they need the Lagos primary running.

**Screenshots:** `01-replication-status-and-read-only.png`, `02-geo-sharding.png` and `03-failover-promotion.png` (replacing the local test-run versions), plus `04-docker-compose-ps.png`. In the Portfolio 5 README, update section 6 to describe your Docker run instead of the local test run.

When finished, remove the containers and their data:

```bash
docker compose down -v
```

## 7. Part E: Save and commit your evidence

Commit after **each portfolio**, so your history shows the work as it happened. In the terminal:

```bash
cd "$CODESPACE_VSCODE_FOLDER"
git add -A
git commit -m "Portfolio 1: my own test run outputs and screenshots"
git push
```

Change the message for each portfolio. Alternatively, use the **Source Control** icon on the left: write a message, click **Commit**, then **Sync Changes**.

**Checklist after each portfolio:**

- [ ] Outputs and logs saved in the folders named above
- [ ] Screenshots replaced with your own, using the same file names
- [ ] README captions updated: replace "test run 14 Nov 2026" with your date and "GitHub Codespaces"
- [ ] Evidence checklist in the portfolio README ticked
- [ ] Committed and pushed

## 8. Part F: Stop the Codespace when you finish

A running Codespace uses your free hours even when you are not typing. It stops automatically after 30 minutes of inactivity, but it is better to stop it yourself:

1. Go to [github.com/codespaces](https://github.com/codespaces).
2. Click **...** next to your Codespace and choose **Stop codespace**.
3. To continue later, open it again from the same page: your files are kept.
4. When the whole portfolio is finished and pushed, choose **Delete** to free the storage allowance.

## 9. Troubleshooting

| Problem | Cause and fix |
| --- | --- |
| `psql: command not found` | Setup did not finish. Run `sudo apt-get update && sudo apt-get install -y postgresql-client-16 graphviz` |
| `psql` asks for a password | Run `export PGHOST=localhost PGUSER=postgres PGPASSWORD=terracyber-demo` |
| `createdb: connection refused` | PostgreSQL was still starting. Wait 10 seconds and repeat |
| `port is already allocated` (Portfolio 5) | The Part B container still holds port 5432. Run `docker stop ead-pg` |
| `pg-portharcourt` keeps restarting | The primary was not ready. Run `docker compose down -v && docker compose up -d` and wait longer |
| Out of memory, containers exit | Use a 4-core, 16 GB machine: stop the Codespace, then **Change machine type** at github.com/codespaces |
| `./run_all.sh: Permission denied` | Run `chmod +x *.sh` in that folder |
| `the input device is not a TTY` | Use `docker exec -i` (without `t`) when output goes to a file |
| Neo4j Browser does not connect | See the Neo4j steps in Part C; the `cypher-shell` output is acceptable evidence |
| A script fails halfway | Reset the database: `dropdb ead && createdb ead`, then reload `schema.sql` and `seed.sql` |

## 10. Other options: Azure VM or your own laptop

### Azure virtual machine

1. In the Azure portal, create a virtual machine: **Ubuntu Server 24.04 LTS**, size **Standard B4ms** (4 vCPU, 16 GB RAM) or **B2ms** (2 vCPU, 8 GB) for Portfolios 1 to 4 only. Allow SSH from **your IP address only**.
2. Connect with `ssh azureuser@<public-ip>`.
3. Install the tools:

   ```bash
   sudo apt-get update
   sudo apt-get install -y docker.io docker-compose-v2 postgresql-client-16 graphviz git
   sudo usermod -aG docker $USER && newgrp docker
   git clone https://github.com/Osita-Odo/MIVA-Data-Base-Management-for-Terracyb-Consulting.git
   cd MIVA-Data-Base-Management-for-Terracyb-Consulting
   export PGHOST=localhost PGUSER=postgres PGPASSWORD=terracyber-demo
   ```

4. Follow Parts B to E from here. Wherever the guide says `cd "$CODESPACE_VSCODE_FOLDER"`, use the cloned folder instead.
5. **Stop (deallocate) the VM** in the portal when you finish, or it keeps using credit. For the Neo4j Browser, use an SSH tunnel (`ssh -L 7474:localhost:7474 -L 7687:localhost:7687 azureuser@<public-ip>`) rather than opening ports to the internet.

### Your own laptop

Install **Docker Desktop**, **Git** and the **PostgreSQL 16 command-line tools**. On Windows, run the scripts in **WSL** (Ubuntu). Clone the repository, set the three `PG` variables shown above, and follow Parts B to E. Close other heavy programs before Portfolio 5.
