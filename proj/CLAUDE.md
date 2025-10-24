# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This appears to be a Java Spring Boot application from the BalticAgro company domain, specifically dealing with location management and distance calculations. The codebase uses Spring Data JPA with Hibernate and implements complex database queries using the JPA Criteria API.

## Code Architecture

### Query Pattern
The application uses a custom `QueryService` abstraction layer that wraps JPA Criteria API queries. This pattern is evident in `FeatureGetLocationsDistances.java`:

- **Context-based query building**: Queries are built using `QueryService.Context<T, R>` which provides methods like `arrayAgg()`, `predicateBuilder()`, and `orderBy2()`
- **Complex joins with predicates**: The code uses custom `joinOn()` methods to create joins with ON clause predicates
- **Array aggregation**: PostgreSQL-specific array aggregation functions are used extensively for collecting related data (e.g., `array_agg()` for collecting distance information)
- **SelectionWrapper pattern**: Results are mapped to DTOs using `QueryService.SelectionWrapper<Output, ?>` which pairs JPA expressions with setter methods

### Domain Model
Based on the visible entities:
- **Location**: Core entity with addresses, companies, and bidirectional distance relationships
- **Company**: Has locations, customer managers, and contract status
- **Distance**: Represents distances between locations (fromLocation → toLocation)
- **Address**: Geographical address information
- **Classificator**: Used for status codes and other enumerated values

### Key Patterns

1. **Bidirectional Distance Relationships**: Distances are tracked in both directions (fromDistances and toDistances), requiring joins on both `Location_.fromDistances` and `Location_.toDistances`

2. **Problem Detection**: The service includes business logic to detect data quality issues:
   - Active contracts without crop locations
   - Active contracts without distance data
   - Crop locations without distance data

3. **Dynamic Filtering**: Uses Spring's `MultiValueMap<String, String>` for flexible search parameters with predicate builders

4. **Array Aggregation for Related Data**: Instead of separate queries, the code aggregates related data into PostgreSQL arrays in a single query, then transforms them into DTOs

## SQL Query Characteristics

The generated SQL queries (see `scratch_85.sql`) feature:
- Extensive use of LEFT JOINs for optional relationships
- Array aggregation with filters (`array_agg(...) filter (where ... is not null)`)
- GROUP BY with complex HAVING clauses for post-aggregation filtering
- Large IN clauses (suggesting batch operations or active contract checking)

## Java-Specific Notes

- **Package structure**: `ee.balticagro.company.domain.location`
- **Lombok**: Heavy use of Lombok annotations (@Getter, @Setter, @RequiredArgsConstructor, @Slf4j)
- **JPA Metamodel**: Uses JPA metamodel classes (e.g., `Location_`, `Company_`) for type-safe queries
- **Hibernate-specific features**: Uses `JpaExpression` and `JpaOrder` for advanced Hibernate features like null precedence control
