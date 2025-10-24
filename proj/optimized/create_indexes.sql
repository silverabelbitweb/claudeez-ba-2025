/*
 * INDEX CREATION SCRIPT FOR OPTIMIZED QUERY
 * ==========================================
 *
 * This script creates the required indexes for scratch_85_optimized.sql
 *
 * DEPLOYMENT INSTRUCTIONS:
 * ------------------------
 * 1. Run this script in PRODUCTION during low-traffic period
 * 2. Uses "CREATE INDEX CONCURRENTLY" to avoid blocking table writes
 * 3. Monitor progress with: SELECT * FROM pg_stat_progress_create_index;
 * 4. Verify completion before deploying application changes
 *
 * EXECUTION TIME ESTIMATES:
 * -------------------------
 * Each index takes approximately 1-5 minutes per 100K rows:
 * - 10K rows: ~30 seconds per index
 * - 100K rows: ~3 minutes per index
 * - 1M rows: ~20 minutes per index
 *
 * ROLLBACK:
 * ---------
 * If needed, drop indexes with: DROP INDEX CONCURRENTLY <index_name>;
 * See rollback.sql for full rollback script.
 */

-- ============================================================================
-- INDEX 1: Location Status
-- ============================================================================
-- Used by: All CTEs and main query WHERE clauses
-- Selectivity: High (typically 2-3 status values, ACTIVE is most common)
-- Impact: Critical for filtering active locations

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_location_status
ON locations(status);

-- Verify creation
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_location_status') THEN
        RAISE NOTICE 'Index idx_location_status created successfully';
    ELSE
        RAISE EXCEPTION 'Failed to create idx_location_status';
    END IF;
END $$;

-- ============================================================================
-- INDEX 2: Company Status
-- ============================================================================
-- Used by: All CTEs WHERE c.status IN (?, ?)
-- Selectivity: High (ACTIVE, PENDING most common)
-- Impact: Critical for filtering active companies

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_company_status
ON companies(status);

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_company_status') THEN
        RAISE NOTICE 'Index idx_company_status created successfully';
    ELSE
        RAISE EXCEPTION 'Failed to create idx_company_status';
    END IF;
END $$;

-- ============================================================================
-- INDEX 3: Distance From-To (Forward Direction)
-- ============================================================================
-- Used by: CTE locations_without_distances (NOT EXISTS subquery)
-- Selectivity: Very high (covering index for distance lookups)
-- Impact: Critical for identifying locations without FROM distances

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_distance_from_to
ON distance(from_location_id, to_location_id);

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_distance_from_to') THEN
        RAISE NOTICE 'Index idx_distance_from_to created successfully';
    ELSE
        RAISE EXCEPTION 'Failed to create idx_distance_from_to';
    END IF;
END $$;

-- ============================================================================
-- INDEX 4: Distance To-From (Reverse Direction)
-- ============================================================================
-- Used by: CTE locations_without_distances (NOT EXISTS subquery)
-- Selectivity: Very high (covering index for reverse distance lookups)
-- Impact: Critical for identifying locations without TO distances

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_distance_to_from
ON distance(to_location_id, from_location_id);

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_distance_to_from') THEN
        RAISE NOTICE 'Index idx_distance_to_from created successfully';
    ELSE
        RAISE EXCEPTION 'Failed to create idx_distance_to_from';
    END IF;
END $$;

-- ============================================================================
-- INDEX 5: Location Company Composite (Most Important!)
-- ============================================================================
-- Used by: paginated_location_ids CTE (JOIN and WHERE)
-- Selectivity: Very high (composite index on company_id + status)
-- Impact: CRITICAL for pagination performance (main bottleneck elimination)
-- Note: Column order matters! company_id first (JOIN), then status (WHERE)

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_location_company
ON locations(company_id, status);

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_location_company') THEN
        RAISE NOTICE 'Index idx_location_company created successfully';
    ELSE
        RAISE EXCEPTION 'Failed to create idx_location_company';
    END IF;
END $$;

-- ============================================================================
-- INDEX 6: Location Crop Status Composite
-- ============================================================================
-- Used by: CTE companies_with_crop_but_no_distances
-- Selectivity: Medium (is_crop_location is boolean, status filters further)
-- Impact: Important for crop location problem detection

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_location_crop
ON locations(is_crop_location, status);

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_location_crop') THEN
        RAISE NOTICE 'Index idx_location_crop created successfully';
    ELSE
        RAISE EXCEPTION 'Failed to create idx_location_crop';
    END IF;
END $$;

-- ============================================================================
-- VERIFICATION QUERIES
-- ============================================================================

-- Show all newly created indexes
SELECT
    schemaname,
    tablename,
    indexname,
    indexdef
FROM pg_indexes
WHERE indexname IN (
    'idx_location_status',
    'idx_company_status',
    'idx_distance_from_to',
    'idx_distance_to_from',
    'idx_location_company',
    'idx_location_crop'
)
ORDER BY tablename, indexname;

-- Show index sizes (should be reasonable, not too large)
SELECT
    schemaname,
    tablename,
    indexname,
    pg_size_pretty(pg_relation_size(indexrelid)) as index_size
FROM pg_stat_user_indexes
WHERE indexname IN (
    'idx_location_status',
    'idx_company_status',
    'idx_distance_from_to',
    'idx_distance_to_from',
    'idx_location_company',
    'idx_location_crop'
)
ORDER BY pg_relation_size(indexrelid) DESC;

-- Check if indexes are valid (should all be 't')
SELECT
    indexname,
    indisvalid as is_valid
FROM pg_index
JOIN pg_class ON pg_class.oid = pg_index.indexrelid
WHERE relname IN (
    'idx_location_status',
    'idx_company_status',
    'idx_distance_from_to',
    'idx_distance_to_from',
    'idx_location_company',
    'idx_location_crop'
);

-- ============================================================================
-- MONITORING QUERIES (Run during index creation)
-- ============================================================================

-- Monitor index creation progress (run in separate session while indexes are being created)
-- Uncomment to use:
/*
SELECT
    a.pid,
    a.datname,
    p.phase,
    p.tuples_done,
    p.tuples_total,
    p.current_locker_pid,
    a.query
FROM pg_stat_progress_create_index p
JOIN pg_stat_activity a ON a.pid = p.pid;
*/

-- Check for blocking queries (if index creation seems stuck)
-- Uncomment to use:
/*
SELECT
    pid,
    usename,
    pg_blocking_pids(pid) as blocked_by,
    query as blocked_query
FROM pg_stat_activity
WHERE cardinality(pg_blocking_pids(pid)) > 0;
*/

-- ============================================================================
-- POST-DEPLOYMENT STATISTICS UPDATE
-- ============================================================================

-- Update table statistics to help query planner use new indexes effectively
ANALYZE locations;
ANALYZE companies;
ANALYZE distance;

RAISE NOTICE 'All indexes created successfully! Run EXPLAIN ANALYZE on optimized query to verify index usage.';

-- ============================================================================
-- EXPECTED EXPLAIN PLAN INDICATORS
-- ============================================================================
/*
After creating these indexes, EXPLAIN ANALYZE should show:

1. "Index Scan using idx_location_company on locations"
   → Confirms composite index used for company + status filter

2. "Index Scan using idx_distance_from_to on distance"
   → Confirms forward distance lookup uses index

3. "Index Scan using idx_distance_to_from on distance"
   → Confirms reverse distance lookup uses index

4. "Index Scan using idx_location_crop on locations"
   → Confirms crop location filtering uses index

5. No "Seq Scan" on locations, companies, or distance tables
   → All table scans replaced with index scans

If you see "Seq Scan" instead of "Index Scan", investigate:
- Are table statistics up to date? Run ANALYZE
- Is the query parameterized correctly?
- Are indexes valid? Check pg_index.indisvalid
*/