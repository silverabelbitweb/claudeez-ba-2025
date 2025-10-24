/*
 * ROLLBACK SCRIPT FOR OPTIMIZED QUERY INDEXES
 * ============================================
 *
 * Use this script to remove the indexes created by create_indexes.sql
 *
 * WHEN TO USE:
 * ------------
 * - Indexes are causing performance degradation
 * - Disk space issues (indexes taking too much space)
 * - Need to rollback optimization completely
 * - Testing purposes (create/drop cycle)
 *
 * IMPORTANT NOTES:
 * ----------------
 * 1. Uses "DROP INDEX CONCURRENTLY" to avoid blocking table access
 * 2. These indexes benefit both original AND optimized queries
 * 3. Only drop if you're certain they're causing issues
 * 4. After dropping, run ANALYZE on tables to update statistics
 *
 * EXECUTION TIME:
 * ---------------
 * Each DROP INDEX CONCURRENTLY takes 1-30 seconds depending on table size
 *
 * RECOMMENDATION:
 * ---------------
 * Before dropping indexes, verify they're the problem:
 * - Check index bloat: SELECT * FROM pgstattuple_approx('index_name');
 * - Check usage: SELECT * FROM pg_stat_user_indexes WHERE indexname = 'index_name';
 * - Check size: SELECT pg_size_pretty(pg_relation_size('index_name'));
 */

-- ============================================================================
-- STEP 1: VERIFY CURRENT INDEX STATE
-- ============================================================================

-- Show which indexes exist and their usage
SELECT
    schemaname,
    tablename,
    indexname,
    idx_scan as times_used,
    idx_tup_read as tuples_read,
    idx_tup_fetch as tuples_fetched,
    pg_size_pretty(pg_relation_size(indexrelid)) as size
FROM pg_stat_user_indexes
WHERE indexname IN (
    'idx_location_status',
    'idx_company_status',
    'idx_distance_from_to',
    'idx_distance_to_from',
    'idx_location_company',
    'idx_location_crop'
)
ORDER BY idx_scan DESC;

-- ============================================================================
-- STEP 2: BACKUP INDEX DEFINITIONS (for recreation if needed)
-- ============================================================================

-- Save index definitions to console output (copy this!)
SELECT
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
ORDER BY indexname;

-- ============================================================================
-- STEP 3: DROP INDEXES CONCURRENTLY
-- ============================================================================

-- WARNING: This is the point of no return!
-- Make sure you have the index definitions saved above

-- Drop index 1: Location Status
DROP INDEX CONCURRENTLY IF EXISTS idx_location_status;
RAISE NOTICE 'Dropped idx_location_status';

-- Drop index 2: Company Status
DROP INDEX CONCURRENTLY IF EXISTS idx_company_status;
RAISE NOTICE 'Dropped idx_company_status';

-- Drop index 3: Distance From-To
DROP INDEX CONCURRENTLY IF EXISTS idx_distance_from_to;
RAISE NOTICE 'Dropped idx_distance_from_to';

-- Drop index 4: Distance To-From
DROP INDEX CONCURRENTLY IF EXISTS idx_distance_to_from;
RAISE NOTICE 'Dropped idx_distance_to_from';

-- Drop index 5: Location Company Composite (MOST IMPORTANT - drop last)
DROP INDEX CONCURRENTLY IF EXISTS idx_location_company;
RAISE NOTICE 'Dropped idx_location_company';

-- Drop index 6: Location Crop Status Composite
DROP INDEX CONCURRENTLY IF EXISTS idx_location_crop;
RAISE NOTICE 'Dropped idx_location_crop';

-- ============================================================================
-- STEP 4: VERIFY INDEXES ARE DROPPED
-- ============================================================================

-- This should return no rows if all indexes are dropped
SELECT
    schemaname,
    tablename,
    indexname
FROM pg_indexes
WHERE indexname IN (
    'idx_location_status',
    'idx_company_status',
    'idx_distance_from_to',
    'idx_distance_to_from',
    'idx_location_company',
    'idx_location_crop'
);

-- ============================================================================
-- STEP 5: UPDATE TABLE STATISTICS
-- ============================================================================

-- Update statistics so query planner knows indexes are gone
ANALYZE locations;
ANALYZE companies;
ANALYZE distance;

RAISE NOTICE 'Rollback complete. All indexes dropped successfully.';

-- ============================================================================
-- STEP 6: RECLAIM DISK SPACE (OPTIONAL)
-- ============================================================================

-- Note: Dropping indexes doesn't immediately free disk space
-- Space is reclaimed during the next VACUUM operation

-- Check current table sizes
SELECT
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as total_size,
    pg_size_pretty(pg_relation_size(schemaname||'.'||tablename)) as table_size,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename) - pg_relation_size(schemaname||'.'||tablename)) as indexes_size
FROM pg_tables
WHERE tablename IN ('locations', 'companies', 'distance')
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;

-- To immediately reclaim space (LOCKS TABLE - use with caution!):
-- VACUUM FULL locations;
-- VACUUM FULL companies;
-- VACUUM FULL distance;

-- Safer option (doesn't lock table, runs in background):
-- VACUUM locations;
-- VACUUM companies;
-- VACUUM distance;

-- ============================================================================
-- POST-ROLLBACK ACTIONS
-- ============================================================================

/*
After running this rollback script:

1. **Application Changes**:
   - Set feature flag: feature.optimized-location-query=false
   - Restart application or reload configuration
   - Original query will now execute without these indexes

2. **Monitor Performance**:
   - Original query may be slower without indexes
   - Even the original query benefited from idx_location_company
   - Consider keeping some indexes (especially idx_location_company)

3. **Disk Space**:
   - Run VACUUM to reclaim space: VACUUM locations; VACUUM companies; VACUUM distance;
   - Check space with: SELECT pg_size_pretty(pg_database_size(current_database()));

4. **Re-enable Optimization** (if rollback was for testing):
   - Re-run create_indexes.sql
   - Set feature flag to true
   - Monitor for 24 hours

5. **Document the Rollback**:
   - Record why rollback was necessary
   - Note any issues encountered
   - Update OPTIMIZATION_REPORT.md with findings
*/

-- ============================================================================
-- TROUBLESHOOTING ROLLBACK ISSUES
-- ============================================================================

/*
Issue 1: "DROP INDEX CONCURRENTLY cannot run inside a transaction block"
Solution: Execute each DROP INDEX statement separately, not in a transaction

Issue 2: DROP INDEX is stuck/hanging
Check for blocking processes:
    SELECT pid, usename, query, state
    FROM pg_stat_activity
    WHERE state != 'idle'
    AND pid != pg_backend_pid();

Kill blocking process if needed (use with caution!):
    SELECT pg_terminate_backend(pid);

Issue 3: Cannot drop index because it's being used
Solution: Stop application first, then drop indexes

Issue 4: Need to drop indexes immediately (emergency)
Use regular DROP INDEX (WARNING: locks table!):
    DROP INDEX idx_location_status;
    DROP INDEX idx_company_status;
    -- etc.

Issue 5: Accidentally dropped wrong indexes
Solution: Re-run create_indexes.sql
*/

-- ============================================================================
-- PARTIAL ROLLBACK OPTIONS
-- ============================================================================

/*
If only specific indexes are problematic, you can drop them individually:

Option A: Keep composite indexes, drop simple ones
DROP INDEX CONCURRENTLY IF EXISTS idx_location_status;
DROP INDEX CONCURRENTLY IF EXISTS idx_company_status;
-- Keep: idx_location_company, idx_location_crop (more beneficial)

Option B: Keep distance indexes, drop location indexes
DROP INDEX CONCURRENTLY IF EXISTS idx_location_company;
DROP INDEX CONCURRENTLY IF EXISTS idx_location_crop;
-- Keep: idx_distance_from_to, idx_distance_to_from (distance queries need these)

Option C: Keep most important index only
DROP INDEX CONCURRENTLY IF EXISTS idx_location_status;
DROP INDEX CONCURRENTLY IF EXISTS idx_company_status;
DROP INDEX CONCURRENTLY IF EXISTS idx_distance_from_to;
DROP INDEX CONCURRENTLY IF EXISTS idx_distance_to_from;
DROP INDEX CONCURRENTLY IF EXISTS idx_location_crop;
-- Keep: idx_location_company (single most important index)

*/

-- ============================================================================
-- RECREATION SHORTCUTS
-- ============================================================================

/*
If you need to recreate a specific index quickly:

CREATE INDEX CONCURRENTLY idx_location_status ON locations(status);
CREATE INDEX CONCURRENTLY idx_company_status ON companies(status);
CREATE INDEX CONCURRENTLY idx_distance_from_to ON distance(from_location_id, to_location_id);
CREATE INDEX CONCURRENTLY idx_distance_to_from ON distance(to_location_id, from_location_id);
CREATE INDEX CONCURRENTLY idx_location_company ON locations(company_id, status);
CREATE INDEX CONCURRENTLY idx_location_crop ON locations(is_crop_location, status);

Then run: ANALYZE locations; ANALYZE companies; ANALYZE distance;
*/