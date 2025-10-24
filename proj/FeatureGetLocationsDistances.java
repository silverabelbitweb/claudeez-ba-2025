package ee.balticagro.company.domain.location;

import ee.balticagro.common.service.QueryService;
import ee.balticagro.common.util.SpecificationUtil;
import ee.balticagro.company.data.entity.classificator.Classificator;
import ee.balticagro.company.data.entity.classificator.Classificator_;
import ee.balticagro.company.data.entity.company.BaseCompany_;
import ee.balticagro.company.data.entity.company.Company;
import ee.balticagro.company.data.entity.company.Company_;
import ee.balticagro.company.data.entity.location.Address;
import ee.balticagro.company.data.entity.location.Address_;
import ee.balticagro.company.data.entity.location.Location;
import ee.balticagro.company.data.entity.location.Location_;
import ee.balticagro.company.data.entity.representative.Person_;
import ee.balticagro.company.data.entity.representative.Representative_;
import ee.balticagro.company.data.repository.util.AbstractSpecifications;
import ee.balticagro.company.domain.contract.ContractDataFetcher;
import ee.balticagro.company.domain.distance.common.Distance;
import ee.balticagro.company.domain.distance.common.Distance_;
import jakarta.persistence.criteria.*;
import jakarta.persistence.metamodel.ListAttribute;
import jakarta.persistence.metamodel.SingularAttribute;
import lombok.Getter;
import lombok.RequiredArgsConstructor;
import lombok.Setter;
import lombok.extern.slf4j.Slf4j;
import org.hibernate.query.NullPrecedence;
import org.hibernate.query.criteria.JpaExpression;
import org.hibernate.query.criteria.JpaOrder;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.util.MultiValueMap;
import org.springframework.util.ObjectUtils;

import java.util.*;
import java.util.function.BiConsumer;
import java.util.function.Function;
import java.util.stream.IntStream;
import java.util.stream.Stream;

@Slf4j
@Service
@RequiredArgsConstructor
class FeatureGetLocationsDistances {

    private final QueryService queryService;
    private final ContractDataFetcher contractExternalService;

    public Page<Output> get(MultiValueMap<String, String> search, Pageable pageable) {
        log.info("Getting locations distances");

        List<Long> companiesWithActiveContracts = contractExternalService.getCompaniesWithActiveContracts();

        return queryService.findAll(Location.class, context -> {
            Root<Location> root = context.getRoot();
            CriteriaBuilder builder = context.getBuilder();
            Join<Location, Address> addressJoin = root.join(Location_.address, JoinType.LEFT);
            Join<Location, Company> companyJoin = root.join(Location_.company);
            Path<String> customerManagerNamePath = companyJoin.join(Company_.customerManager, JoinType.LEFT).join(Representative_.person, JoinType.LEFT).get(Person_.name);
            Path<String> customerManagerNamesPath = companyJoin.join(Company_.customerManagers, JoinType.LEFT).join(Representative_.person, JoinType.LEFT).get(Person_.name);
            Join<Company, Location> allLocationsJoin = joinOn(companyJoin, Company_.locations, join ->
                    SpecificationUtil.in(join.get(Location_.status).get(Classificator_.code), Classificator.LOCATION_STATUS_ACTIVE));
            List<DistancesJoinWrapper> distancesJoins = DistancesJoinWrapper.distancesJoins(context, search);
            Predicate companyHasActiveContractPredicate = SpecificationUtil.in(companyJoin.get(BaseCompany_.id), companiesWithActiveContracts);
            Predicate distancesEmptyPredicate = builder.and(distancesJoins.stream().map(x -> x.locationIdArrayAgg.isNull()).toArray(Predicate[]::new));

            List<QueryService.SelectionWrapper<Output, Boolean>> problemsSelections = List.of(
                    QueryService.SelectionWrapper.of(
                            builder.and(companyHasActiveContractPredicate, builder.equal(builder.sum(cast(allLocationsJoin.get(Location_.cropLocation), Integer.class)), 0)),
                            addProblem("Aktiivne leping, aga vilja asukoht puudu"))
                    , QueryService.SelectionWrapper.of(
                            builder.and(companyHasActiveContractPredicate, distancesEmptyPredicate),
                            addProblem("Aktiivne leping, aga distantsid puudu"))
                    , QueryService.SelectionWrapper.of(
                            builder.and(SpecificationUtil.in(context.getRoot().get(Location_.cropLocation), true), distancesEmptyPredicate),
                            addProblem("Vilja asukoht, aga distantsid puudu"))
            );
            Predicate problemsPredicate = builder.or(problemsSelections.stream().map(wrapper -> (Predicate) wrapper.getSelection()).toArray(Predicate[]::new));

            List<QueryService.SelectionWrapper<Output, ?>> simpleSelections = List.of(
                    QueryService.SelectionWrapper.of(root, Output::setLocation),
                    QueryService.SelectionWrapper.of(addressJoin, Output::setAddress),
                    QueryService.SelectionWrapper.of(companyJoin, Output::setCompany),
                    QueryService.SelectionWrapper.of(customerManagerNamePath, Output::setCustomerManagerName)
            );

            context.setResultSupplier(Output::new)
                    .setSelections(Stream.<Stream<QueryService.SelectionWrapper<Output, ?>>>of(
                            simpleSelections.stream(),
                            distancesJoins.stream().flatMap(DistancesJoinWrapper::selections),
                            problemsSelections.stream().map(QueryService.SelectionWrapper::downCast),
                            Stream.of(
                                    QueryService.SelectionWrapper.of(context.arrayAgg(customerManagerNamesPath), Output::setCustomerManagerNames)
                                    , QueryService.SelectionWrapper.of(companyHasActiveContractPredicate, Output::setCompanyHasActiveContract)
                            )
                    ).flatMap(Function.identity()).toList())
                    .setPredicate(builder.and(
                            context.predicateBuilder()
                                    .in(List.of(Classificator.COMPANY_STATUS_NORMAL, Classificator.COMPANY_STATUS_REVIEW_REQUIRED), companyJoin.get(Company_.status).get(Classificator_.code))
                                    .in(Classificator.LOCATION_STATUS_ACTIVE, root.get(Location_.status).get(Classificator_.code))
                                    .add(getExcludedCompaniesPredicate(companyJoin, search.getOrDefault("excludedCompanies", Collections.emptyList())))
                                    .and(),
                            context.predicateBuilder()
                                    .in(search.getOrDefault("locationId", Collections.emptyList()).stream().map(SpecificationUtil::tryGetLong).toList(), Location_.id)
                                    .in(search.getOrDefault("companyId", Collections.emptyList()).stream().map(SpecificationUtil::tryGetLong).toList(), companyJoin.get(BaseCompany_.id))
                                    .lowerLike(search.get("locationName"), root.get(Location_.locationName))
                                    .lowerLike(search.get("companyName"), companyJoin.get(BaseCompany_.name))
                                    .lowerLike(search.get("address"), addressJoin.get(Address_.formattedAddress))
                                    .in(search.getFirst("cropLocation") instanceof String cropLocation ? "true".equals(cropLocation) : null, Location_.cropLocation)
                                    .add(Optional.ofNullable(search.getFirst("companyHasActiveContract")).map(companyHasActiveContract -> "true".equals(companyHasActiveContract)
                                            ? companyHasActiveContractPredicate
                                            : companyHasActiveContractPredicate.not()))
                                    .add(search.getFirst("dateCreated") instanceof String dateCreated ? AbstractSpecifications.makeDatePredicate(dateCreated, root.get(Location_.dateCreated), builder) : null)
                                    .add(search.getFirst("dateModified") instanceof String dateModified ? AbstractSpecifications.makeDatePredicate(dateModified, root.get(Location_.dateModified), builder) : null)
                                    .add(!ObjectUtils.isEmpty(search.get("customerManagers"))
                                            ? builder.or(search.get("customerManagers").stream().flatMap(name -> Stream.of(
                                                    SpecificationUtil.lowerLike(builder, customerManagerNamePath, name),
                                                    SpecificationUtil.lowerLike(builder, customerManagerNamesPath, name)
                                            )).toArray(Predicate[]::new))
                                            : null)
                                    .add(DistancesJoinWrapper.locationNamePredicate(distancesJoins))
                                    .buildWithSearch(search.getFirst("search") instanceof String searchSearch && "true".equals(searchSearch)))
                    )
                    .groupBy(simpleSelections.stream().map(QueryService.SelectionWrapper::getSelection).toArray(Expression[]::new))
                    .setPageable(pageable)
                    .orderBy2(pageable.getSort(), Map.of(
                            "distances", DistancesJoinWrapper.orderSupplier(distancesJoins)
                            , "companyHasActiveContract", order -> List.of(context.getOrderFunc(order).apply(companyHasActiveContractPredicate))
                            , "problem", order -> List.of(context.getOrderFunc(order).apply(problemsPredicate))
                    ))
                    .setHaving(List.of(context.predicateBuilder()
                            .add(SpecificationUtil.EMPTY_VALUES.equals(search.getFirst("distances")) ? distancesEmptyPredicate : null)
                            .add(Optional.ofNullable(search.getFirst("problem")).map((String problem) -> "true".equals(problem) ? problemsPredicate : problemsPredicate.not()))
                            .and()))
            ;
        });
    }

    private static BiConsumer<Output, Boolean> addProblem(String problem) {
        return (output, value) -> {
            if (Boolean.TRUE.equals(value)) {
                output.getProblems().add(problem);
            }
        };
    }

    private static Predicate getExcludedCompaniesPredicate(Join<Location, Company> companyJoin, List<String> excludedCompanyIdList) {
        List<Long> ids = excludedCompanyIdList.stream().flatMap(string -> Arrays.stream(string.split(","))).map(SpecificationUtil::tryGetLong).filter(Objects::nonNull).toList();

        return !ids.isEmpty()
                ? SpecificationUtil.in(companyJoin.get(BaseCompany_.id), ids).not()
                : null;
    }

    private static <T, U> ListJoin<T, U> joinOn(From<?, T> from, ListAttribute<T, U> attribute, Function<Join<T, U>, Predicate> restriction) {
        ListJoin<T, U> join = from.join(attribute);
        join.on(restriction.apply(join));

        return join;
    }

    private static <T, U> Expression<U> cast(Expression<T> expression, Class<U> clazz) {
        return expression instanceof JpaExpression<T> jpaExpression ? jpaExpression.cast(clazz) : expression.as(clazz);
    }

    @Getter
    @Setter
    public static class Output {

        private Location location;
        private Address address;
        private Company company;
        private String customerManagerName;
        private String[] customerManagerNames;
        private Boolean companyHasActiveContract;
        private List<String> problems = new ArrayList<>();
        private Distances fromDistances = new Distances();
        private Distances toDistances = new Distances();

        public List<DistanceDto> getDistances() {
            return Stream.of(toDistances.stream(), fromDistances.stream()).flatMap(Function.identity()).distinct().sorted(Comparator.comparing(DistanceDto::name)).toList();
        }

        public Set<String> getCustomerManagers() {
            var names = new LinkedHashSet<String>();
            if (!ObjectUtils.isEmpty(customerManagerName)) {
                names.add(customerManagerName);
            }
            if (!ObjectUtils.isEmpty(customerManagerNames)) {
                names.addAll(Arrays.asList(customerManagerNames));
            }

            return names;
        }
    }

    public record DistanceDto(Long id, String name, Integer distanceInKilometres) {}

    @Setter
    private static final class Distances {

        private Long[] locationIdsArray;
        private String[] locationNamesArray;
        private Integer[] distancesArray;

        private Stream<DistanceDto> stream() {
            return !ObjectUtils.isEmpty(locationIdsArray)
                    ? IntStream.range(0, locationIdsArray.length).mapToObj(i -> new DistanceDto(locationIdsArray[i], locationNamesArray[i], distancesArray[i]))
                    : Stream.empty();
        }
    }

    private static final class DistancesJoinWrapper {

        private final QueryService.Context<Location, Output> context;
        private final Join<Location, Distance> distancesJoin;
        private final Join<Distance, Location> locationJoin;
        private final Expression<Long[]> locationIdArrayAgg;
        private final Function<Output, Distances> dtoSupplier;
        private final boolean isSearch;
        private final Predicate[] predicates;

        private DistancesJoinWrapper(
                QueryService.Context<Location, Output> context,
                MultiValueMap<String, String> search,
                Function<Output, Distances> dtoSupplier,
                ListAttribute<Location, Distance> distancesAttribute,
                SingularAttribute<Distance, Location> locationAttribute
        ) {
            this.context = context;
            this.dtoSupplier = dtoSupplier;
            this.distancesJoin = context.getRoot().join(distancesAttribute, JoinType.LEFT);
            this.locationJoin = distancesJoin.join(locationAttribute, JoinType.LEFT);
            this.locationIdArrayAgg = context.arrayAgg(null, locationJoin.get(Location_.id));
            this.isSearch = search.getFirst("search") instanceof String searchSearch && "true".equals(searchSearch);
            this.predicates = !ObjectUtils.isEmpty(search.get("distances"))
                    ? search.get("distances").stream().map(distance -> SpecificationUtil.lowerLike(context.getBuilder(), locationJoin.get(Location_.locationName), distance)).toArray(Predicate[]::new)
                    : null;

            if (!isSearch && predicates != null && !SpecificationUtil.EMPTY_VALUES.equals(search.getFirst("distances"))) {
                this.distancesJoin.on(context.getBuilder().or(predicates));
            }
        }

        private Stream<QueryService.SelectionWrapper<Output, ?>> selections() {
            return Stream.of(
                    QueryService.SelectionWrapper.of(locationIdArrayAgg, (output, o) -> dtoSupplier.apply(output).setLocationIdsArray(o)),
                    QueryService.SelectionWrapper.of(context.arrayAgg(null, locationJoin.get(Location_.locationName)), (output, o) -> dtoSupplier.apply(output).setLocationNamesArray(o)),
                    QueryService.SelectionWrapper.of(context.arrayAgg(null, distancesJoin.get(Distance_.distanceInKilometres)), (output, o) -> dtoSupplier.apply(output).setDistancesArray(o))
            );
        }

        private static Predicate locationNamePredicate(List<DistancesJoinWrapper> distancesJoins) {
            var builder = distancesJoins.getFirst().context.getBuilder();

            return distancesJoins.getFirst().isSearch && distancesJoins.getFirst().predicates != null
                    ? builder.or(distancesJoins.stream().flatMap(distanceJoin -> Arrays.stream(distanceJoin.predicates)).toArray(Predicate[]::new))
                    : null;
        }

        private static Function<Sort.Order, List<Order>> orderSupplier(List<DistancesJoinWrapper> distancesJoins) {
            return sortOrder -> {
                return distancesJoins.stream().map(distancesJoin -> {
                    var order = distancesJoins.getFirst().context.getOrderFunc(sortOrder).apply(distancesJoin.locationIdArrayAgg);

                    if (order instanceof JpaOrder jpaOrder) {
                        jpaOrder.nullPrecedence(sortOrder.isDescending() ? NullPrecedence.FIRST : NullPrecedence.NONE);
                    }

                    return order;
                }).toList();
            };
        }

        public static List<DistancesJoinWrapper> distancesJoins(QueryService.Context<Location, Output> context, MultiValueMap<String, String> search) {
            return List.of(
                    new DistancesJoinWrapper(context, search, Output::getFromDistances, Location_.fromDistances, Distance_.toLocation),
                    new DistancesJoinWrapper(context, search, Output::getToDistances, Location_.toDistances, Distance_.fromLocation)
            );
        }
    }
}
