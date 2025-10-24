# Database Schema Analysis

Analyze a PostgreSQL database schema and generate a comprehensive report.

## Instructions

You are tasked with analyzing a PostgreSQL database schema. Follow these steps:

1. **Gather Database Connection Parameters**
   - Use the AskUserQuestion tool to collect:
     - Database host (default: localhost)
     - Database port (default: 5432)
     - Database name
     - Username
     - Password (will be used securely)
     - Output format preference: "SQL DDL" or "Detailed Analysis Report"

2. **Test Connection**
   - First, test if `psql` is available on the system
   - Test database connectivity with provided credentials

3. **Extract Schema Information**

   For **SQL DDL** output:
   - Use `pg_dump` with `--schema-only` flag to extract complete schema
   - Include tables, views, sequences, indexes, constraints, and functions

   For **Detailed Analysis Report** output:
   - Extract and analyze:
     - All tables with column details (types, nullability, defaults)
     - Primary keys and foreign keys
     - Indexes (including duplicate or missing indexes)
     - Constraints (unique, check, exclusion)
     - Sequences
     - Views and materialized views
     - Functions and stored procedures
     - Triggers
     - Table sizes and row counts
     - Relationships (with cardinality)
   - Generate insights:
     - Tables without primary keys
     - Missing indexes on foreign keys
     - Naming convention issues
     - Potential performance concerns

4. **Generate Output**
   - Save the result to a file:
     - For SQL DDL: `db-schema-<dbname>-<timestamp>.sql`
     - For Report: `db-schema-analysis-<dbname>-<timestamp>.md`
   - Display a summary to the user
   - Include the file path for easy access

## Security Notes

- Passwords should only be used in command execution, never logged
- Use `PGPASSWORD` environment variable for psql/pg_dump
- Remind user not to commit files with sensitive connection strings

## Example pg_dump Command

```bash
PGPASSWORD='password' pg_dump -h host -p port -U username -d database --schema-only --no-owner --no-privileges
```

## Example psql Queries for Analysis

```sql
-- List all tables with row counts
SELECT schemaname, tablename,
       pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_tables
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;

-- List all columns with types
SELECT table_name, column_name, data_type, character_maximum_length,
       is_nullable, column_default
FROM information_schema.columns
WHERE table_schema NOT IN ('pg_catalog', 'information_schema')
ORDER BY table_name, ordinal_position;

-- List all foreign keys
SELECT
    tc.table_name,
    kcu.column_name,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name,
    tc.constraint_name
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
  ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage AS ccu
  ON ccu.constraint_name = tc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
ORDER BY tc.table_name;

-- List all indexes
SELECT
    schemaname,
    tablename,
    indexname,
    indexdef
FROM pg_indexes
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
ORDER BY tablename, indexname;
```

Begin by gathering the connection parameters.