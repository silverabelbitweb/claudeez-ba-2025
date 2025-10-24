# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Java Spring Boot application for location management and distance calculations. Uses Spring Data JPA with Hibernate, PostgreSQL-specific features, and a custom `QueryService` abstraction for building complex JPA Criteria queries.

**Tech Stack**: Spring Boot, JPA/Hibernate, PostgreSQL, Lombok

## Architecture

### QueryService Pattern

Custom abstraction wrapping JPA Criteria API (`FeatureGetLocationsDistances.java`):

- `QueryService.Context<T, R>` - Provides `arrayAgg()`, `predicateBuilder()`, `orderBy2()`
- `SelectionWrapper<Output, ?>` - Maps JPA expressions to DTO setters
- `joinOn()` - Custom joins with ON clause predicates
- PostgreSQL `array_agg()` for aggregating related data in single queries

### Domain Model

- **Location** ↔ **Distance** (bidirectional: fromDistances/toDistances)
- **Location** → **Address**, **Company**
- **Company** → **Representative** (customer managers)
- **Classificator** - Status codes and enumerations

### Key Patterns

- **Bidirectional Distance Joins**: Join on both `Location_.fromDistances` and `Location_.toDistances`
- **Problem Detection**: Business logic detects missing data (contracts without distances, crop locations without distances)
- **Dynamic Filtering**: `MultiValueMap<String, String>` search parameters with predicate builders
- **Array Aggregations**: Collect related data (distances, names) into PostgreSQL arrays, transform to DTOs

## Performance Considerations

### Known Bottlenecks

**Pagination happens AFTER expensive operations:**
- 6+ `array_agg()` functions + complex joins execute on entire filtered dataset
- Then `OFFSET/FETCH FIRST` applies (computing thousands of rows to show 20-50)
- See `scratch_85.sql` line 97 - pagination is last step

**External service blocking query:**
- `FeatureGetLocationsDistances:54` - `contractExternalService.getCompaniesWithActiveContracts()`
- Called synchronously on every request
- **Fix**: Cache with Redis/Caffeine (5-15 min TTL)

**HAVING filters should be WHERE/JOIN ON:**
- Lines 133-136: `distances` and `problem` filters in HAVING clause
- Computed after aggregation instead of before
- Move to LEFT JOIN ON clauses to reduce aggregated rows

### Required Indexes

```sql
CREATE INDEX idx_location_status ON locations(status);
CREATE INDEX idx_company_status ON companies(status);
CREATE INDEX idx_distance_from_to ON distance(from_location_id, to_location_id);
CREATE INDEX idx_distance_to_from ON distance(to_location_id, from_location_id);
CREATE INDEX idx_location_company ON locations(company_id, status);
CREATE INDEX idx_location_crop ON locations(is_crop_location, status);
```

### Optimization Patterns

1. **Cache external dependencies** - Especially if used in WHERE/HAVING
2. **Push filters down** - HAVING → WHERE or JOIN ON when possible
3. **Two-query pattern** - Fetch IDs (paginated), then details for page items only
4. **Limit aggregations** - Only aggregate displayed/filtered data
5. **Keyset pagination** - Replace `OFFSET` with `WHERE id > ?` for large datasets

### QueryService Warnings

- Abstraction hides performance issues - monitor generated SQL
- `arrayAgg()` is expensive on large result sets
- GROUP BY includes all selected columns (59 columns in current query)
