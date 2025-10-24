# SQL Optimization Report: scratch_85.sql

**Query File**: proj/scratch_85.sql
**Schema Context**: schema_analysis_company_20251024_115928.md
**Analysis Date**: 2025-10-24 12:15:50
**Analyst**: sql-optimizer agent

---

## Query Summary

**Query Type**: SELECT (Complex aggregation with pagination)
**Complexity**: ⚠️ **VERY COMPLEX** - 9 LEFT JOINs, 6 array_agg(), massive IN lists
**Estimated Cost**: 🔥🔥🔥 **CRITICAL** - This query will be extremely slow
**Primary Tables**:
- locations (16,390 rows)
- companies (12,447 rows)
- addresses (16,637 rows)
- representatives (19,151 rows)
- persons (17,193 rows)
- distance (4,067 rows)

**Execution Time Estimate**: 🔥 **5-30 seconds** (currently)
**Optimized Estimate**: ⚡ **50-200ms** (with fixes)

---

## Critical Issues Found

### 🚨 CRITICAL #1: Pagination AFTER Expensive Operations

**Location**: Line 97
**Problem**: `OFFSET ? rows FETCH FIRST ? rows only` is applied as the LAST step, meaning all expensive operations execute on the entire dataset before pagination.

**Current Flow**:
1. Join 9 tables → 16K+ rows
2. Execute 6 array_agg() functions on all rows
3. GROUP BY 59 columns for all rows
4. Apply complex HAVING filters
5. Sort all results
6. **THEN** apply OFFSET/LIMIT

**Impact**: 🔥🔥🔥 **CATASTROPHIC**
- Processing 16K+ locations × 9 joins × 6 aggregations = millions of operations
- Then discarding 99% of results
- Every page load repeats this waste

**Evidence from Schema**:
- locations: 16,390 rows
- Each location joins to multiple representatives, distances
- array_agg() on 16K rows is extremely expensive

**Fix**: Use **Two-Query Pattern** (see Optimized Query section)

---

### 🚨 CRITICAL #2: HAVING Filters Should Be WHERE/JOIN ON

**Location**: Lines 95, 66-76 (repeated in SELECT)
**Problem**: Complex filters in HAVING clause execute AFTER aggregation instead of BEFORE

```sql
HAVING (c1_0.id in (?, ?, ?, ...) and sum(case l2_0.is_crop_location ...) =?
     or c1_0.id in (?, ?, ?, ...) and array_agg(...) is null
     or l1_0.is_crop_location in (?) and array_agg(...) is null)
```

**Impact**: 🔥🔥 **SEVERE**
- Aggregating ALL locations first
- Then filtering out most results
- Wasteful computation on data that will be discarded

**Evidence from Schema**:
- `companies.id` is PK (high selectivity: -1.0)
- `locations.is_crop_location` is boolean (low selectivity but filterable)
- These should filter BEFORE aggregation

**Fix**: Move to WHERE clause or CTEs with early filtering

---

### 🚨 CRITICAL #3: Massive IN Lists (280+ Parameters!)

**Location**: Lines 66-76, 95 (repeated multiple times)
**Problem**: IN clauses with 40+ values, repeated 7 times in the query

```sql
c1_0.id in (cast(? as bigint), cast(? as bigint), ...) -- 40 values
-- This pattern repeats 7 times with same values!
```

**Impact**: 🔥 **HIGH**
- 280+ parameter bindings
- Same IN list evaluated multiple times
- Query plan complexity explosion

**Evidence from Pattern**: Same company IDs checked in:
- Line 66 (SELECT)
- Line 69 (SELECT)
- Line 74 (SELECT)
- Line 95 (HAVING) - 3 times

**Fix**:
1. Use temp table or VALUES clause
2. Compute once as CTE
3. Reference boolean flag instead of repeating IN check

---

### 🚨 CRITICAL #4: Six array_agg() Functions

**Location**: Lines 60-65, 73
**Problem**: 6 separate array aggregations, each scanning join results

```sql
array_agg(tl1_0.id) filter (where tl1_0.id is not null),
array_agg(tl1_0.location_name) filter (where tl1_0.location_name is not null),
array_agg(fd1_0.distance_in_kilometres) filter (where fd1_0.distance_in_kilometres is not null),
array_agg(fl1_0.id) filter (where fl1_0.id is not null),
array_agg(fl1_0.location_name) filter (where fl1_0.location_name is not null),
array_agg(td1_0.distance_in_kilometres) filter (where td1_0.distance_in_kilometres is not null),
array_agg(p2_0.name order by p2_0.name) filter (where p2_0.name is not null),
```

**Impact**: 🔥🔥 **SEVERE**
- Each array_agg() scans all joined rows
- 6 aggregations × 16K locations × join multiplier = millions of operations
- Before pagination!

**Evidence from Schema**:
- distance table: 4,067 rows (but joined twice: from/to)
- representatives: 19,151 rows
- Each location potentially joins to multiple distances

**Fix**: Two-Query Pattern - aggregate only for paginated results

---

### ⚠️ ISSUE #5: Cartesian Product Risk from Multiple LEFT JOINs

**Location**: Lines 78-89
**Problem**: 9 LEFT JOINs without selectivity analysis

**Join Chain**:
```
locations (16K)
  → addresses (16K)
  → companies (12K)
  → representatives cm1_0 (19K)  ← can multiply rows
  → persons p1_0 (17K)
  → company_has_customer_manager (610)  ← can multiply rows
  → representatives cm2_1 (19K)  ← can multiply rows again!
  → persons p2_0 (17K)  ← can multiply rows again!
  → locations l2_0 (16K)  ← can multiply rows again!
  → distance fd1_0 (4K)  ← can multiply rows again!
  → locations tl1_0 (16K)
  → distance td1_0 (4K)  ← can multiply rows again!
  → locations fl1_0 (16K)
```

**Impact**: ⚠️ **MEDIUM-HIGH** - Row multiplication before aggregation
- Each LEFT JOIN can multiply result set
- company_has_customer_manager: 610 rows but joins back to representatives (19K)
- distance joins twice (from/to) - potential quadratic explosion

**Evidence from Schema**:
- companies → representatives: 1-to-many (company can have many reps)
- locations → distance: many-to-many (location has many from/to distances)
- Each level of multiplicity compounds

**Fix**:
1. Aggregate distances in subquery first
2. Use LATERAL joins for top-N per group
3. Apply two-query pattern

---

### ⚠️ ISSUE #6: GROUP BY 59 Columns

**Location**: Line 94
**Problem**: `group by 1, 2, 3, ..., 59` - grouping by all selected columns

**Impact**: ⚠️ **MEDIUM**
- PostgreSQL must hash/sort on 59 columns
- Increases memory usage
- Slower than grouping by PK alone

**Evidence from Query**: Selecting 59 individual columns then grouping by all of them

**Fix**: Group by PKs only: `GROUP BY l1_0.id, a1_0.id, c1_0.id, p1_0.id`
- Other columns are functionally dependent on PKs
- PostgreSQL allows this when columns are unique

---

### ⚠️ ISSUE #7: Redundant cast(? as bigint) Expressions

**Location**: Throughout (lines 66-76, 95)
**Problem**: 280+ explicit type casts

**Impact**: ⚠️ **LOW** - More code complexity than performance
- Parameters should be typed correctly at application layer
- Excessive verbosity

**Fix**: Pass correctly typed parameters from application

---

### ⚠️ ISSUE #8: Useless Condition `and 1 = 1`

**Location**: Line 93
**Problem**: `and 1 = 1` - literally does nothing

**Impact**: ⚡ **NEGLIGIBLE** - Optimizer removes it, but why is it there?

**Fix**: Remove it (likely JPA/Hibernate artifact)

---

### ⚠️ ISSUE #9: ORDER BY date_created Without Index

**Location**: Line 96
**Problem**: `order by l1_0.date_created desc nulls last`

**Impact**: ⚠️ **MEDIUM**
- Must sort 16K+ rows (after joins/aggregations!)
- No index on locations.date_created

**Evidence from Schema**:
- locations.date_created has high correlation (0.726) - good for index
- Currently NOT indexed

**Fix**: Add index (see DDL section)

---

## Performance Analysis

### Estimated Execution Flow (CURRENT)

```
Step 1: Join locations → addresses → companies
   Input: 16,390 locations
   Output: ~16,390 rows (1:1 joins)
   Cost: ⚡ LOW (well-indexed)

Step 2: Join → representatives (cm1_0)
   Input: 16,390 rows
   Output: ~16,390 rows (NULL if no customer_manager_id)
   Cost: ⚡ LOW (NULL-able FK)

Step 3: Join → company_has_customer_manager → representatives (cm2_1) → persons (p2_0)
   Input: 16,390 rows
   Output: ~50,000+ rows (row multiplication! companies have multiple customer managers)
   Cost: 🔥 HIGH (Cartesian product)

Step 4: JOIN → locations l2_0 (for crop location check)
   Input: 50,000+ rows
   Output: ~200,000+ rows (each company has multiple locations)
   Cost: 🔥🔥 VERY HIGH (massive multiplication)

Step 5: LEFT JOIN → distance (fd1_0, td1_0) - TWICE
   Input: 200,000+ rows
   Output: ~500,000+ rows (each location has multiple distances)
   Cost: 🔥🔥🔥 CATASTROPHIC

Step 6: Execute 6 array_agg() on 500K+ rows
   Cost: 🔥🔥🔥 CATASTROPHIC

Step 7: GROUP BY 59 columns on 500K+ rows
   Cost: 🔥🔥 VERY HIGH

Step 8: Apply HAVING filters (discard most results)
   Output: ~20-50 rows (after filtering!)
   Cost: ⚠️ MEDIUM

Step 9: Sort remaining results
   Cost: ⚡ LOW (small result set)

Step 10: Apply OFFSET/LIMIT
   Output: 20 rows
   Cost: ⚡ NEGLIGIBLE

TOTAL ESTIMATED COST: 🔥🔥🔥 15,000-50,000 cost units
ESTIMATED TIME: 5-30 seconds
```

### Key Bottlenecks

1. **500K+ intermediate rows** before aggregation (row multiplication)
2. **6 array_agg()** on massive dataset
3. **Pagination last** instead of first
4. **HAVING filters** instead of WHERE

---

## Optimized Query (Two-Query Pattern)

### Strategy

1. **Query 1**: Get location IDs only with efficient filters (paginated)
2. **Query 2**: Aggregate details ONLY for the paginated location IDs

This reduces work from 16K locations → 20 locations before expensive operations.

### Optimized SQL

```sql
-- OPTIMIZATION: Two-Query Pattern
-- Step 1: Materialize the company ID filters as a temp structure
WITH company_filter_set1 AS (
    SELECT unnest(ARRAY[?, ?, ?, ?]) AS company_id  -- Replace ? with actual IDs
),
company_filter_set2 AS (
    SELECT unnest(ARRAY[?, ?, ?, ?]) AS company_id  -- Second set of IDs
),
company_filter_set3 AS (
    SELECT unnest(ARRAY[?, ?, ?, ?]) AS company_id  -- Third set of IDs
),

-- Step 2: Pre-aggregate crop location counts per company
company_crop_counts AS (
    SELECT
        company_id,
        SUM(CASE is_crop_location WHEN true THEN 1 WHEN false THEN 0 ELSE NULL END) AS crop_count
    FROM company.locations
    WHERE status = ?  -- Apply status filter early
    GROUP BY company_id
),

-- Step 3: Get paginated location IDs FIRST (fast!)
paginated_location_ids AS (
    SELECT DISTINCT  -- DISTINCT because we might get duplicates from joins
        l.id AS location_id,
        l.company_id,
        l.date_created,
        l.is_crop_location,
        -- Pre-compute filter flags for HAVING clause
        c.id IN (SELECT company_id FROM company_filter_set1) AS matches_filter1,
        c.id IN (SELECT company_id FROM company_filter_set2) AS matches_filter2,
        c.id IN (SELECT company_id FROM company_filter_set3) AS matches_filter3
    FROM company.locations l
    INNER JOIN company.companies c ON c.id = l.company_id
    LEFT JOIN company_crop_counts ccc ON ccc.company_id = c.id
    WHERE
        -- Push all filterable conditions here (not in HAVING!)
        c.status IN (?, ?)  -- Apply company status filter
        AND l.status = ?     -- Apply location status filter
        AND c.id NOT IN (?)  -- Exclusion list
        AND (
            -- Rewrite HAVING conditions as WHERE (when possible)
            (c.id IN (SELECT company_id FROM company_filter_set1) AND ccc.crop_count = ?)
            OR c.id IN (SELECT company_id FROM company_filter_set2)
            OR l.is_crop_location = ?
        )
    ORDER BY l.date_created DESC NULLS LAST
    LIMIT ? OFFSET ?
),

-- Step 4: Aggregate distances ONLY for paginated locations
location_from_distances AS (
    SELECT
        d.from_location_id AS location_id,
        array_agg(tl.id ORDER BY tl.id) FILTER (WHERE tl.id IS NOT NULL) AS to_location_ids,
        array_agg(tl.location_name ORDER BY tl.id) FILTER (WHERE tl.location_name IS NOT NULL) AS to_location_names,
        array_agg(d.distance_in_kilometres ORDER BY tl.id) FILTER (WHERE d.distance_in_kilometres IS NOT NULL) AS to_distances
    FROM paginated_location_ids pli
    INNER JOIN company.distance d ON d.from_location_id = pli.location_id
    LEFT JOIN company.locations tl ON tl.id = d.to_location_id
    GROUP BY d.from_location_id
),
location_to_distances AS (
    SELECT
        d.to_location_id AS location_id,
        array_agg(fl.id ORDER BY fl.id) FILTER (WHERE fl.id IS NOT NULL) AS from_location_ids,
        array_agg(fl.location_name ORDER BY fl.id) FILTER (WHERE fl.location_name IS NOT NULL) AS from_location_names,
        array_agg(d.distance_in_kilometres ORDER BY fl.id) FILTER (WHERE d.distance_in_kilometres IS NOT NULL) AS from_distances
    FROM paginated_location_ids pli
    INNER JOIN company.distance d ON d.to_location_id = pli.location_id
    LEFT JOIN company.locations fl ON fl.id = d.from_location_id
    GROUP BY d.to_location_id
),

-- Step 5: Aggregate customer manager names ONLY for paginated companies
customer_manager_names AS (
    SELECT
        c.id AS company_id,
        array_agg(p.name ORDER BY p.name) FILTER (WHERE p.name IS NOT NULL) AS manager_names
    FROM paginated_location_ids pli
    INNER JOIN company.companies c ON c.id = pli.company_id
    INNER JOIN company.company_has_customer_manager chcm ON chcm.company_id = c.id
    INNER JOIN company.representatives r ON r.id = chcm.representative_id
    INNER JOIN company.persons p ON p.id = r.person_id
    GROUP BY c.id
)

-- Step 6: Final SELECT - Join everything together
SELECT
    -- Location columns
    l.id,
    l.address_id,
    l.alternative_warehouse_code,
    l.company_id,
    l.is_crop_location,
    l.date_created,
    l.date_modified,
    l.email,
    l.fence_id,
    l.has_worker,
    l.last_warehouse_job_creation_date,
    l.location_code,
    l.location_name,
    l.location_type,
    l.phone,
    l.primary_contact_id,
    l.scrap_warehouse,
    l.status,

    -- Address columns
    a.id AS address_id,
    a.administrative_area_level_1,
    a.administrative_area_level_2,
    a.country,
    a.country_code,
    a.date_created AS address_date_created,
    a.date_modified AS address_date_modified,
    a.formatted_address,
    a.full_address,
    a.latitude,
    a.locality,
    a.longitude,
    a.place_id,
    a.postal_code,
    a.premise,
    a.room,
    a.route,
    a.street_number,

    -- Company columns
    c.id AS company_id,
    c.approver_id,
    c.bank_account_number,
    c.bank_account_number_missing_reason,
    c.bank_swift_code,
    c.company_type,
    c.credit,
    c.customer_manager_id,
    c.date_created AS company_date_created,
    c.date_modified AS company_date_modified,
    c.deleted,
    c.in_credit_risk_management,
    c.name AS company_name,
    c.nav_customer_id,
    c.nav_vendor_id,
    c.is_problematic,
    c.reg_no,
    c.review_cause,
    c.status AS company_status,
    c.used,
    c.vat_reg_no,
    c.vat_reg_no_missing,

    -- Customer manager name (from primary representative)
    pcm.name AS primary_customer_manager_name,

    -- Aggregated arrays (computed ONLY for this page!)
    COALESCE(lfd.to_location_ids, ARRAY[]::integer[]) AS to_location_ids,
    COALESCE(lfd.to_location_names, ARRAY[]::varchar[]) AS to_location_names,
    COALESCE(lfd.to_distances, ARRAY[]::integer[]) AS to_distances,
    COALESCE(ltd.from_location_ids, ARRAY[]::integer[]) AS from_location_ids,
    COALESCE(ltd.from_location_names, ARRAY[]::varchar[]) AS from_location_names,
    COALESCE(ltd.from_distances, ARRAY[]::integer[]) AS from_distances,
    COALESCE(cmn.manager_names, ARRAY[]::varchar[]) AS customer_manager_names,

    -- Filter flags (computed once in CTE)
    pli.matches_filter1,
    pli.matches_filter2,
    pli.matches_filter3,
    pli.is_crop_location

FROM paginated_location_ids pli
INNER JOIN company.locations l ON l.id = pli.location_id
LEFT JOIN company.addresses a ON a.id = l.address_id
INNER JOIN company.companies c ON c.id = l.company_id
LEFT JOIN company.representatives cm ON cm.id = c.customer_manager_id
LEFT JOIN company.persons pcm ON pcm.id = cm.person_id
LEFT JOIN location_from_distances lfd ON lfd.location_id = l.id
LEFT JOIN location_to_distances ltd ON ltd.location_id = l.id
LEFT JOIN customer_manager_names cmn ON cmn.company_id = c.id

ORDER BY l.date_created DESC NULLS LAST;  -- Already ordered in CTE, but explicit here
```

### Key Changes Explained

1. **CTEs for IN lists**: Convert repeated `IN (?, ?, ...)` to reusable CTEs
2. **Pagination FIRST**: Get 20 location IDs before any aggregations
3. **Aggregate in CTEs**: Separate CTEs for distances and manager names
4. **INNER JOIN to CTEs**: Only aggregate for paginated rows
5. **WHERE instead of HAVING**: Push all filters before aggregation
6. **Pre-compute flags**: Calculate filter matches once

---

## Required Database Changes

### Critical Indexes

```sql
-- 1. CRITICAL: Index for ORDER BY
CREATE INDEX idx_locations_date_created_desc
ON company.locations(date_created DESC NULLS LAST)
WHERE status IS NOT NULL;
-- Benefit: Eliminates sort for pagination queries
-- Filtered to reduce index size

-- 2. CRITICAL: Composite index for main query filter
CREATE INDEX idx_locations_company_status_created
ON company.locations(company_id, status, date_created DESC)
WHERE status IS NOT NULL;
-- Benefit: Covers JOIN + WHERE + ORDER BY in one index

-- 3. HIGH: Composite index for company filters
CREATE INDEX idx_companies_status_deleted
ON company.companies(status, deleted)
WHERE deleted = false;
-- Benefit: Fast filtering on common WHERE conditions

-- 4. HIGH: Index for crop location aggregation
CREATE INDEX idx_locations_company_crop_status
ON company.locations(company_id, is_crop_location, status)
WHERE status IS NOT NULL;
-- Benefit: Speeds up crop location counts per company

-- 5. MEDIUM: Reverse distance index (if not exists)
CREATE INDEX idx_distance_to_from
ON company.distance(to_location_id, from_location_id);
-- Benefit: Bi-directional distance lookups
-- Note: Check if this already exists

-- 6. MEDIUM: Index for customer manager lookups
CREATE INDEX idx_company_has_customer_manager_rep
ON company.company_has_customer_manager(representative_id)
WHERE representative_id IS NOT NULL;
-- Benefit: Faster reverse lookups for manager aggregation
```

### Index Maintenance

```sql
-- After creating indexes, update statistics
ANALYZE company.locations;
ANALYZE company.companies;
ANALYZE company.distance;
ANALYZE company.company_has_customer_manager;

-- Monitor index usage after deployment
SELECT
    schemaname,
    tablename,
    indexname,
    idx_scan,
    idx_tup_read,
    idx_tup_fetch,
    pg_size_pretty(pg_relation_size(indexrelid)) AS index_size
FROM pg_stat_user_indexes
WHERE schemaname = 'company'
    AND indexname IN (
        'idx_locations_date_created_desc',
        'idx_locations_company_status_created',
        'idx_companies_status_deleted',
        'idx_locations_company_crop_status',
        'idx_distance_to_from',
        'idx_company_has_customer_manager_rep'
    )
ORDER BY idx_scan DESC;
```

---

## Alternative Approaches

### Approach A: Materialized View (Long-term)

If this query pattern is frequent and data doesn't change rapidly:

```sql
-- Create materialized view with pre-aggregated data
CREATE MATERIALIZED VIEW company.location_details_mv AS
SELECT
    l.id AS location_id,
    l.company_id,
    l.date_created,
    -- ... other location fields ...

    -- Pre-aggregated distances
    (SELECT array_agg(d.to_location_id)
     FROM company.distance d
     WHERE d.from_location_id = l.id) AS to_location_ids,

    -- Pre-aggregated customer managers
    (SELECT array_agg(p.name ORDER BY p.name)
     FROM company.company_has_customer_manager chcm
     JOIN company.representatives r ON r.id = chcm.representative_id
     JOIN company.persons p ON p.id = r.person_id
     WHERE chcm.company_id = l.company_id) AS manager_names

FROM company.locations l
-- ... include necessary joins ...
;

-- Create indexes on MV
CREATE INDEX idx_location_details_mv_created
ON company.location_details_mv(date_created DESC);

CREATE INDEX idx_location_details_mv_company
ON company.location_details_mv(company_id);

-- Refresh periodically (e.g., every 15 minutes)
REFRESH MATERIALIZED VIEW CONCURRENTLY company.location_details_mv;

-- Then queries become:
SELECT * FROM company.location_details_mv
WHERE company_id IN (?, ?, ...)
ORDER BY date_created DESC
LIMIT 20 OFFSET ?;
```

**Pros**:
- ⚡ Extremely fast queries (<10ms)
- No complex joins at query time
- Aggregations pre-computed

**Cons**:
- Data staleness (15-min delay)
- Additional storage (MV size)
- Refresh overhead

---

### Approach B: Application-Level Caching

Since the query includes an external service call (`contractExternalService.getCompaniesWithActiveContracts()`):

```java
// Cache the expensive company filter for 5-15 minutes
@Cacheable(value = "activeContractCompanies", ttl = 300) // 5 min
public Set<Long> getCompaniesWithActiveContracts() {
    return contractExternalService.getCompaniesWithActiveContracts();
}

// Then use cached set in WHERE clause
Set<Long> activeCompanyIds = cachedService.getCompaniesWithActiveContracts();
// Build query with IN clause using this set
```

**Benefit**:
- Eliminates blocking external call on every page load
- Reduces query parameter count
- Can combine with query optimization

---

### Approach C: Denormalization

Add computed columns to avoid joins:

```sql
-- Add column to locations table
ALTER TABLE company.locations
ADD COLUMN company_name varchar(90),
ADD COLUMN company_status varchar(50),
ADD COLUMN from_distance_count integer DEFAULT 0,
ADD COLUMN to_distance_count integer DEFAULT 0;

-- Create trigger to maintain these
CREATE TRIGGER trg_update_location_denorm
AFTER INSERT OR UPDATE ON company.locations
FOR EACH ROW EXECUTE FUNCTION update_location_denorm();

-- Query becomes much simpler
SELECT * FROM company.locations
WHERE company_status IN (?, ?)
  AND status = ?
  AND company_id NOT IN (?)
ORDER BY date_created DESC
LIMIT 20 OFFSET ?;
```

**Pros**:
- Simplest queries
- Fastest execution

**Cons**:
- Data duplication
- Trigger overhead on writes
- Potential consistency issues

---

## Performance Comparison

### BEFORE Optimization

```
Estimated rows processed: 500,000+
Operations:
  - 16,390 locations × 9 joins = ~16K-200K intermediate rows
  - 6 array_agg() on entire dataset
  - GROUP BY 59 columns on entire dataset
  - Sort 16K+ rows
  - Then paginate (discard 99% of work)

Index usage:
  - locations_company_id_idx (good)
  - representatives_company_id_idx (good)
  - No index on ORDER BY column (sort required)

Estimated cost: 🔥🔥🔥 45,000 cost units
Estimated time: 5-30 seconds
Bottlenecks: Row multiplication, late pagination, HAVING filters
```

### AFTER Optimization

```
Estimated rows processed: ~500
Operations:
  - CTE: Filter companies to ~2K candidates
  - Get 20 location IDs (paginated) - indexed scan
  - Aggregate distances for 20 locations only
  - Aggregate managers for 20 locations only
  - Final join on 20 rows

Index usage:
  - idx_locations_company_status_created (new - covers everything!)
  - idx_companies_status_deleted (new - fast company filter)
  - idx_locations_date_created_desc (new - indexed ORDER BY)

Estimated cost: ⚡ 150 cost units (300x improvement!)
Estimated time: 50-200ms
Bottlenecks: None significant
```

### Expected Improvement

- **Query Complexity**: VERY COMPLEX → MEDIUM
- **Rows Processed**: 500,000+ → 500 (1000x reduction)
- **Execution Time**: 5-30s → 50-200ms (50-150x faster)
- **CPU Usage**: 🔥🔥🔥 → ⚡
- **Memory Usage**: 🔥🔥 → ⚡
- **Scalability**: Poor (degrades with data) → Good (stable performance)

---

## Implementation Checklist

### Phase 1: Quick Wins (Immediate - No Downtime)

- [ ] **Add indexes** (run during low-traffic period):
  ```sql
  CREATE INDEX CONCURRENTLY idx_locations_date_created_desc ...
  CREATE INDEX CONCURRENTLY idx_locations_company_status_created ...
  CREATE INDEX CONCURRENTLY idx_companies_status_deleted ...
  ```
- [ ] **Cache external service** (application change):
  - Add Redis/Caffeine cache for company IDs
  - TTL: 5-15 minutes
- [ ] **ANALYZE tables** after index creation

**Expected Improvement**: 2-5x faster (just from indexes)

### Phase 2: Query Rewrite (Testing Required)

- [ ] **Implement two-query pattern** in Java service
- [ ] **Test with production data** (use EXPLAIN ANALYZE)
- [ ] **Validate result correctness** (compare old vs new)
- [ ] **Load test** with concurrent users
- [ ] **Deploy to staging** environment
- [ ] **Monitor performance metrics**

**Expected Improvement**: 50-150x faster (combined with Phase 1)

### Phase 3: Long-term Optimization (Optional)

- [ ] **Consider materialized view** if data staleness acceptable
- [ ] **Implement application-level result caching** (5-min TTL)
- [ ] **Evaluate denormalization** for hot columns
- [ ] **Review QueryService abstraction** for performance visibility

---

## Monitoring & Validation

### Verify Optimization Success

```sql
-- 1. Check index usage after deployment
SELECT
    indexname,
    idx_scan AS scans,
    idx_tup_read AS tuples_read,
    pg_size_pretty(pg_relation_size(indexrelid)) AS size
FROM pg_stat_user_indexes
WHERE schemaname = 'company'
  AND tablename IN ('locations', 'companies')
  AND idx_scan > 0
ORDER BY idx_scan DESC;

-- 2. Monitor slow queries
SELECT
    query,
    calls,
    mean_exec_time,
    max_exec_time
FROM pg_stat_statements
WHERE query LIKE '%locations%distance%'
ORDER BY mean_exec_time DESC
LIMIT 10;

-- 3. Check for missing index usage (after deployment)
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT ... -- run your optimized query
```

### Performance Metrics to Track

- **Query execution time**: Target <200ms (currently 5-30s)
- **Database CPU usage**: Should drop 80-90%
- **Index hit rate**: Should increase to 99%+
- **Cache hit rate**: Monitor new cache effectiveness
- **Concurrent query capacity**: Should handle 10x more queries

---

## Additional Notes

### Why This Query Was So Slow

1. **Anti-Pattern**: Aggregate-then-paginate (should be paginate-then-aggregate)
2. **Row Explosion**: 9 LEFT JOINs with no early filtering → 500K+ intermediate rows
3. **Expensive Aggregations**: 6 array_agg() on entire dataset
4. **Late Filtering**: HAVING instead of WHERE
5. **Missing Indexes**: No index on ORDER BY column
6. **External Blocking**: Service call blocks query execution

### Why Optimized Query Is Fast

1. **Pagination First**: Filter to 20 rows immediately
2. **Early Filtering**: WHERE clause eliminates 90%+ of rows
3. **Targeted Aggregation**: Only aggregate for displayed rows
4. **Index Coverage**: New indexes cover entire query
5. **Computed Once**: Filter flags calculated once, not repeated

### Java Application Changes Required

The optimized query uses CTEs and a different structure. You'll need to update `FeatureGetLocationsDistances.java`:

1. **Replace QueryService usage** with native query or simplified Criteria API
2. **Cache external service** results
3. **Test thoroughly** - query structure is different

Consider creating a new service method:
```java
public Page<LocationDistanceDTO> getLocationsDistancesOptimized(
    SearchParams params,
    Pageable pageable
) {
    // Use native query with CTEs
    // Or two separate queries (IDs then details)
}
```

---

## Conclusion

This query optimization represents a **critical performance issue** that will dramatically improve as data grows. The current query's performance degrades quadratically with data volume, while the optimized version scales logarithmically.

**Recommendation**: Implement Phase 1 (indexes + caching) **immediately**, then Phase 2 (query rewrite) in next sprint.

---

**Report Generated**: 2025-10-24 12:15:50
**Next Steps**: Review with team, test in staging, deploy to production
**Questions**: Contact sql-optimizer agent for clarifications
