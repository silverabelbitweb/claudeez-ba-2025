/*
 * TEST COMPARISON SCRIPT
 * ======================
 *
 * This script helps you compare the original and optimized queries to ensure:
 * 1. Both queries return the same results
 * 2. Optimized query is faster
 * 3. Optimized query uses indexes correctly
 * 4. No regressions in functionality
 *
 * HOW TO USE:
 * -----------
 * 1. Replace parameter placeholders (?, ?, ...) with actual values
 * 2. Run each test section separately
 * 3. Compare results between original and optimized queries
 * 4. Document any discrepancies
 *
 * IMPORTANT:
 * ----------
 * This script assumes you have:
 * - Created all required indexes (run create_indexes.sql first)
 * - Test data in your database (ideally staging/production copy)
 * - Appropriate permissions to run EXPLAIN ANALYZE
 */

-- ============================================================================
-- SETUP: Define test parameters
-- ============================================================================

-- Replace these with actual parameter values for your test case
-- Example values shown - adjust based on your needs

\set company_status_active '''ACTIVE'''
\set company_status_pending '''PENDING'''
\set location_status '''ACTIVE'''
\set excluded_company_id 999999
\set is_crop_location TRUE
\set crop_count 0
\set page_offset 0
\set page_limit 20

-- For IN clauses, you'll need to replace the long lists manually
-- Example: (1, 2, 3, 4, ..., 92) - these are company IDs with active contracts

-- ============================================================================
-- TEST 1: Result Set Consistency
-- ============================================================================
-- Verify both queries return the same location IDs

\echo '========================================='
\echo 'TEST 1: Result Set Consistency'
\echo '========================================='

-- Note: You need to replace the ? placeholders with actual values
-- This is a template - adjust based on your parameter values

WITH
original_results AS (
    -- Paste your ORIGINAL query here with parameters filled in
    -- Make sure to only SELECT the ID column for comparison
    SELECT DISTINCT l1_0.id as location_id
    FROM locations l1_0
    -- ... rest of original query
    -- ORDER BY and LIMIT as in original
),
optimized_results AS (
    -- Paste your OPTIMIZED query here with parameters filled in
    -- Make sure to only SELECT the ID column for comparison
    SELECT DISTINCT l1_0.id as location_id
    FROM (
        -- ... optimized query CTEs
        SELECT l1_0.id
        FROM paginated_location_ids pli
        INNER JOIN locations l1_0 ON l1_0.id = pli.id
        -- ... rest of optimized query
    ) sub
)
SELECT
    (SELECT COUNT(*) FROM original_results) as original_count,
    (SELECT COUNT(*) FROM optimized_results) as optimized_count,
    (SELECT COUNT(*)
     FROM original_results o
     WHERE NOT EXISTS (SELECT 1 FROM optimized_results op WHERE op.location_id = o.location_id)
    ) as missing_in_optimized,
    (SELECT COUNT(*)
     FROM optimized_results op
     WHERE NOT EXISTS (SELECT 1 FROM original_results o WHERE o.location_id = op.location_id)
    ) as extra_in_optimized;

-- Expected result: original_count = optimized_count, missing = 0, extra = 0

-- ============================================================================
-- TEST 2: Performance Comparison
-- ============================================================================
-- Compare execution times between original and optimized queries

\echo '========================================='
\echo 'TEST 2: Performance Comparison'
\echo '========================================='

-- Test 2a: Original query with timing
\echo 'Running ORIGINAL query with EXPLAIN ANALYZE...'
\timing on

EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
-- Paste ORIGINAL query here with parameters filled in
SELECT l1_0.id,
       l1_0.location_name,
       -- ... all columns
       array_agg(tl1_0.id) FILTER (WHERE tl1_0.id IS NOT NULL)
       -- ... rest of original query
FROM locations l1_0
-- ... complete original query
;

\timing off

-- Record the "Execution Time" value from output


-- Test 2b: Optimized query with timing
\echo 'Running OPTIMIZED query with EXPLAIN ANALYZE...'
\timing on

EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
-- Paste OPTIMIZED query here with parameters filled in
WITH
locations_without_distances AS (
    -- ... optimized query CTEs
),
-- ... rest of CTEs
paginated_location_ids AS (
    -- ... pagination CTE
)
SELECT l1_0.id,
       l1_0.location_name,
       -- ... all columns
FROM paginated_location_ids pli
-- ... rest of optimized query
;

\timing off

-- Record the "Execution Time" value from output


-- Compare execution times:
-- Original: _____ ms
-- Optimized: _____ ms
-- Improvement: _____ x faster

-- ============================================================================
-- TEST 3: Index Usage Verification
-- ============================================================================
-- Verify that optimized query uses indexes correctly

\echo '========================================='
\echo 'TEST 3: Index Usage Verification'
\echo '========================================='

-- Reset index statistics
SELECT pg_stat_reset_single_table_counters('locations'::regclass);
SELECT pg_stat_reset_single_table_counters('companies'::regclass);
SELECT pg_stat_reset_single_table_counters('distance'::regclass);

-- Run optimized query (paste with parameters)
-- <run your optimized query here>

-- Check which indexes were used
SELECT
    schemaname,
    tablename,
    indexname,
    idx_scan as times_used,
    idx_tup_read as tuples_read,
    idx_tup_fetch as tuples_fetched
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

-- Expected result: All indexes should show idx_scan > 0
-- If idx_scan = 0 for any index, that index wasn't used (investigate why)

-- ============================================================================
-- TEST 4: Sequential Scan Detection
-- ============================================================================
-- Ensure no sequential scans on large tables

\echo '========================================='
\echo 'TEST 4: Sequential Scan Detection'
\echo '========================================='

-- Run EXPLAIN (not ANALYZE) to see query plan without execution
EXPLAIN (VERBOSE)
-- Paste OPTIMIZED query here
;

-- Review output for "Seq Scan" on locations, companies, or distance tables
-- These should NOT appear:
--   - "Seq Scan on locations"
--   - "Seq Scan on companies"
--   - "Seq Scan on distance"
--
-- These are OK:
--   - "Seq Scan on paginated_location_ids" (CTE scan)
--   - "Index Scan" on any table
--   - "Bitmap Heap Scan" (uses index)

-- ============================================================================
-- TEST 5: Data Correctness - Sample Verification
-- ============================================================================
-- Verify that array aggregations and computed columns are correct

\echo '========================================='
\echo 'TEST 5: Data Correctness'
\echo '========================================='

-- Test 5a: Pick a specific location and verify distances
\set test_location_id 12345  -- Replace with actual location ID

-- From original query (manual verification)
SELECT
    l.id,
    l.location_name,
    array_agg(DISTINCT d1.to_location_id) as from_distances,
    array_agg(DISTINCT d2.from_location_id) as to_distances
FROM locations l
LEFT JOIN distance d1 ON l.id = d1.from_location_id
LEFT JOIN distance d2 ON l.id = d2.to_location_id
WHERE l.id = :test_location_id
GROUP BY l.id, l.location_name;

-- From optimized query (extract for same location)
-- Run optimized query and find the row for :test_location_id
-- Compare arrays manually

-- Test 5b: Verify problem detection flags
WITH loc_without_dist AS (
    SELECT l.id
    FROM locations l
    WHERE l.status = :location_status
      AND NOT EXISTS (SELECT 1 FROM distance d WHERE d.from_location_id = l.id)
      AND NOT EXISTS (SELECT 1 FROM distance d WHERE d.to_location_id = l.id)
)
SELECT
    l.id,
    l.location_name,
    l.is_crop_location,
    CASE WHEN l.id IN (SELECT id FROM loc_without_dist) THEN TRUE ELSE FALSE END as has_no_distances,
    c.id as company_id,
    c.name as company_name
FROM locations l
JOIN companies c ON c.id = l.company_id
WHERE l.id = :test_location_id;

-- Verify this matches the optimized query result for the same location

-- ============================================================================
-- TEST 6: Pagination Consistency
-- ============================================================================
-- Verify pagination works correctly across pages

\echo '========================================='
\echo 'TEST 6: Pagination Consistency'
\echo '========================================='

-- Test 6a: Get all IDs without pagination
WITH all_ids AS (
    -- Run optimized query without OFFSET/LIMIT
    -- (remove the pagination from paginated_location_ids CTE)
    SELECT l1_0.id
    FROM locations l1_0
    -- ... rest of query without OFFSET/LIMIT
    ORDER BY l1_0.date_created DESC NULLS LAST
)
SELECT COUNT(*) as total_locations FROM all_ids;

-- Record total count: _____


-- Test 6b: Get paginated results for multiple pages
-- Page 1 (OFFSET 0, LIMIT 20)
-- <run optimized query with OFFSET 0>

-- Page 2 (OFFSET 20, LIMIT 20)
-- <run optimized query with OFFSET 20>

-- Page 3 (OFFSET 40, LIMIT 20)
-- <run optimized query with OFFSET 40>

-- Verify:
-- 1. No duplicate IDs across pages
-- 2. IDs are in correct sort order (date_created DESC)
-- 3. Total IDs across all pages matches total count from 6a

-- ============================================================================
-- TEST 7: Parameter Variation Testing
-- ============================================================================
-- Test different parameter combinations

\echo '========================================='
\echo 'TEST 7: Parameter Variation Testing'
\echo '========================================='

-- Test case 1: Filter by company with contract
-- Expected: Locations belonging to companies with active contracts
-- <run optimized query with contract company IDs>

-- Test case 2: Filter by crop locations without distances
-- Expected: Crop locations that have no distances
-- <run optimized query with is_crop_location = TRUE>

-- Test case 3: Exclude specific company
-- Expected: No results for excluded company
-- <run optimized query with excluded company ID>
SELECT COUNT(*) as should_be_zero
FROM (
    -- <paste optimized query result here>
) results
WHERE company_id = :excluded_company_id;

-- Expected: 0

-- ============================================================================
-- TEST 8: Load Testing (Concurrent Queries)
-- ============================================================================
-- Simulate multiple users running queries simultaneously

\echo '========================================='
\echo 'TEST 8: Load Testing'
\echo '========================================='

-- Use pgbench or similar tool for proper load testing
-- This is a simple sequential test for reference

\echo 'Running 10 iterations of optimized query...'
\timing on

-- Run optimized query 10 times
-- <paste optimized query>
-- <paste optimized query>
-- ... repeat 10 times

\timing off

-- Record average execution time: _____ ms

-- Compare with original query (if time permits)

-- ============================================================================
-- TEST 9: Edge Cases
-- ============================================================================
-- Test boundary conditions and edge cases

\echo '========================================='
\echo 'TEST 9: Edge Cases'
\echo '========================================='

-- Edge case 1: Empty result set
-- Modify parameters to return no results
-- Expected: Both queries return 0 rows
-- <run with impossible filter combination>

-- Edge case 2: Single result
-- Modify parameters to return exactly 1 result
-- Expected: Both queries return same 1 row
-- <run with very specific filters>

-- Edge case 3: Large page offset
-- Test pagination at end of dataset
-- Expected: Query remains fast even with large offset
-- <run with OFFSET = total_count - 20>

-- Edge case 4: All locations without distances
-- Test when most locations match the "problem" criteria
-- Expected: Query should still complete quickly
-- <run with filters that match many locations>

-- ============================================================================
-- TEST 10: Memory Usage Comparison
-- ============================================================================
-- Compare memory usage between original and optimized queries

\echo '========================================='
\echo 'TEST 10: Memory Usage'
\echo '========================================='

-- Note: This requires PostgreSQL to be configured with log_statement = 'all'
-- and log_temp_files = 0 to log temporary file usage

-- Check shared buffer usage
EXPLAIN (ANALYZE, BUFFERS)
-- <paste optimized query>
;

-- Look for "Buffers:" in the output
-- Shared read/hit/written values
-- Temp read/written values (should be minimal or zero)

-- Example output interpretation:
-- "Buffers: shared hit=1234 read=56"
--   -> Good: Most data from cache (high hit ratio)
--
-- "Buffers: shared hit=1234 temp read=5678 written=5678"
--   -> Bad: Using temp files (query needs too much memory)

-- ============================================================================
-- TEST RESULTS SUMMARY TEMPLATE
-- ============================================================================

\echo '========================================='
\echo 'TEST RESULTS SUMMARY'
\echo '========================================='

/*
Fill in the results after running all tests:

TEST 1 - Result Set Consistency:
  Original count: _____
  Optimized count: _____
  Missing in optimized: _____
  Extra in optimized: _____
  Status: [PASS/FAIL]

TEST 2 - Performance Comparison:
  Original execution time: _____ ms
  Optimized execution time: _____ ms
  Improvement factor: _____ x
  Status: [PASS/FAIL]

TEST 3 - Index Usage:
  idx_location_status used: [YES/NO]
  idx_company_status used: [YES/NO]
  idx_distance_from_to used: [YES/NO]
  idx_distance_to_from used: [YES/NO]
  idx_location_company used: [YES/NO]
  idx_location_crop used: [YES/NO]
  Status: [PASS/FAIL]

TEST 4 - Sequential Scan Detection:
  Sequential scans found: [YES/NO]
  Tables affected: _____
  Status: [PASS/FAIL]

TEST 5 - Data Correctness:
  Array aggregations match: [YES/NO]
  Problem flags match: [YES/NO]
  Status: [PASS/FAIL]

TEST 6 - Pagination Consistency:
  Total count matches: [YES/NO]
  No duplicates across pages: [YES/NO]
  Sort order correct: [YES/NO]
  Status: [PASS/FAIL]

TEST 7 - Parameter Variations:
  All scenarios return correct results: [YES/NO]
  Status: [PASS/FAIL]

TEST 8 - Load Testing:
  Average execution time: _____ ms
  Acceptable performance under load: [YES/NO]
  Status: [PASS/FAIL]

TEST 9 - Edge Cases:
  Empty result set: [PASS/FAIL]
  Single result: [PASS/FAIL]
  Large offset: [PASS/FAIL]
  Many matches: [PASS/FAIL]
  Status: [PASS/FAIL]

TEST 10 - Memory Usage:
  Temp files used: [YES/NO]
  Buffer usage acceptable: [YES/NO]
  Status: [PASS/FAIL]

OVERALL STATUS: [PASS/FAIL]
READY FOR PRODUCTION: [YES/NO]

Notes:
______________________________________________________________________
______________________________________________________________________
______________________________________________________________________
*/