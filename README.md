# Hospital Management Database System

## Project Overview

This repository contains the database design and operational tooling for a hospital management system. The development is part of the "Security of Databases" course taught at the University of Luxembourg.

The database supports core hospital workflows such as appointment scheduling, medical examinations, laboratory testing, and patient record management. The system is designed for multiple roles, including patients, doctors, laboratory staff, data entry personnel, and system administrators.

Given the sensitive nature of medical data, the database enforces strict access control, role-based permissions, and auditing. The database is hosted on Supabase (PostgreSQL) and follows best practices for security, backup, and recovery.

---

## Supabase Project

The database is deployed on Supabase.

Supabase project URL:  
```
https://bcweptazyanghinzmasl.supabase.co
```

Database access is restricted to authorized roles, and direct PostgreSQL connections are used for administrative operations such as backups.

---

## Backup and Recovery

Logical backups are implemented using `pg_dump` from an external trusted environment. This approach is required because Supabase Edge Functions do not support database-level backup utilities. Backups are automated via shell scripts, encrypted before storage, and stored off-site in accordance with the 3-2-1 backup strategy.

To reproduce the backup and recovery process, export the database password as an environment variable before running the scripts:

```bash
export PGPASSWORD="<SUPABASE_DATABASE_PASSWORD>"
```

Additionally, the Supabase database runs PostgreSQL 17.x; therefore, `pg_dump` version **17.6 or newer** must be installed and used to avoid client–server version mismatches.

Backup files themselves are not included in this repository for security and confidentiality reasons.

---

## Repository Structure

```
hospital-db-system/
├── README.md
├── backup_scripts/
│   ├── backup.sh
│   └── restore.sh
├── sql_queries/
│   ├── ...
├── table_info/
│   ├── patient.md
│   ├── appointment.md
│   ├── examination.md
│   └── lab_test.md
│   └── ...
└── diagrams/
    └── schema.png
```

### Directory Description

- `backup_scripts/`  
  Scripts for automated logical backups and database recovery using `pg_dump` and `pg_restore`.

- `sql_queries/`  
  SQL definitions for the database schema, roles, and access control policies.

- `table_info/`  
  Documentation describing the purpose, structure, and access control of each table.

- `diagrams/`  
  Database schema diagrams illustrating table relationships.


