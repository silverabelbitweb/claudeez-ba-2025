--
-- PostgreSQL database dump
--

\restrict 1206Lea9FI6g9XdDZC6RBpAodo8Dtm8BhQpOaaUMm0cV2DjGdrVSEXsg5Bs9FC3

-- Dumped from database version 13.11
-- Dumped by pg_dump version 13.22 (Debian 13.22-1.pgdg13+1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: company; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA company;


ALTER SCHEMA company OWNER TO postgres;

--
-- Name: additional_info_context_type; Type: TYPE; Schema: company; Owner: postgres
--

CREATE TYPE company.additional_info_context_type AS ENUM (
    'COMPANY',
    'COMPANY_ADDITIONAL',
    'COMPANY_FARM_DATA',
    'COMPANY_CREDIT_RISK_DATA',
    'LOCATION'
);


ALTER TYPE company.additional_info_context_type OWNER TO postgres;

--
-- Name: gdpr_status; Type: TYPE; Schema: company; Owner: postgres
--

CREATE TYPE company.gdpr_status AS ENUM (
    'ALLOWED',
    'FORBIDDEN',
    'PENDING'
);


ALTER TYPE company.gdpr_status OWNER TO postgres;

--
-- Name: log_type; Type: TYPE; Schema: company; Owner: postgres
--

CREATE TYPE company.log_type AS ENUM (
    'create',
    'update',
    'delete'
);


ALTER TYPE company.log_type OWNER TO postgres;

--
-- Name: get_company_ids(); Type: FUNCTION; Schema: company; Owner: postgres
--

CREATE FUNCTION company.get_company_ids() RETURNS TABLE(company_id integer)
    LANGUAGE plpgsql
    AS $$
	BEGIN
		RETURN QUERY SELECT t1.* FROM dblink('dbname=warehouse user=bitweb-user password=56oty02OEPhtsBsT5A355L0V4n5RG4KZ', '
			SELECT DISTINCT clients.external_company_id
			FROM
				jobs JOIN
				job_products ON jobs.id = job_products.job_id JOIN
				clients ON job_products.client_id = clients.id JOIN
				products ON job_products.product_id = products.id
			WHERE
				jobs.type = ''OUTCOMING'' AND
				products.group_name IN (''Vaetised'', ''Taimekaitse'') AND
				clients.external_company_id IS NOT NULL AND
				jobs.created_at > ''2020-11-17''') t1 (rec int);
	END;
$$;


ALTER FUNCTION company.get_company_ids() OWNER TO postgres;

--
-- Name: get_current_user(); Type: FUNCTION; Schema: company; Owner: postgres
--

CREATE FUNCTION company.get_current_user() RETURNS text
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN current_setting('session_variables.current_user');
    EXCEPTION WHEN OTHERS THEN
    RETURN user;
END;
$$;


ALTER FUNCTION company.get_current_user() OWNER TO postgres;

--
-- Name: get_current_user_id(); Type: FUNCTION; Schema: company; Owner: postgres
--

CREATE FUNCTION company.get_current_user_id() RETURNS text
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN current_setting('session_variables.current_user_id');
    EXCEPTION WHEN OTHERS THEN
    RETURN NULL;
END;
$$;


ALTER FUNCTION company.get_current_user_id() OWNER TO postgres;

--
-- Name: set_session_variables(text, text); Type: FUNCTION; Schema: company; Owner: postgres
--

CREATE FUNCTION company.set_session_variables(username text, user_id text) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    PERFORM set_config('session_variables.current_user', username, FALSE);
    PERFORM set_config('session_variables.current_user_id', user_id, FALSE);
END;
$$;


ALTER FUNCTION company.set_session_variables(username text, user_id text) OWNER TO postgres;

--
-- Name: trim_table_columns(); Type: FUNCTION; Schema: company; Owner: postgres
--

CREATE FUNCTION company.trim_table_columns() RETURNS void
    LANGUAGE plpgsql
    AS $$
    declare
        selectrow record;
    begin
    for selectrow in
    select
           'UPDATE '||quote_ident(c.table_name)||' SET '||quote_ident(c.COLUMN_NAME)||'=TRIM('||quote_ident(c.COLUMN_NAME)||')  WHERE '||quote_ident(c.COLUMN_NAME)||' ILIKE ''% '' ' as script
    from (
           select
              table_name, COLUMN_NAME
           from
              INFORMATION_SCHEMA.COLUMNS
           where
              table_schema='public' and table_name!='schema_version' and (data_type='text' or data_type='character varying' or data_type='character')
         ) c
    loop
    execute selectrow.script;
    end loop;
    end;
  $$;


ALTER FUNCTION company.trim_table_columns() OWNER TO postgres;

--
-- Name: additional_info_id_seq; Type: SEQUENCE; Schema: company; Owner: postgres
--

CREATE SEQUENCE company.additional_info_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE company.additional_info_id_seq OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: additional_info; Type: TABLE; Schema: company; Owner: postgres
--

CREATE TABLE company.additional_info (
    id integer DEFAULT nextval('company.additional_info_id_seq'::regclass) NOT NULL,
    company_id integer,
    key character varying(100) NOT NULL,
    value text NOT NULL,
    location_id integer,
    person_id integer,
    context character varying(100) DEFAULT 'droon'::character varying NOT NULL,
    date_modified timestamp without time zone DEFAULT now()
);


ALTER TABLE company.additional_info OWNER TO postgres;

--
-- Name: additional_info_context_id_seq; Type: SEQUENCE; Schema: company; Owner: postgres
--

CREATE SEQUENCE company.additional_info_context_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE company.additional_info_context_id_seq OWNER TO postgres;

--
-- Name: additional_info_context; Type: TABLE; Schema: company; Owner: postgres
--

CREATE TABLE company.additional_info_context (
    id integer DEFAULT nextval('company.additional_info_context_id_seq'::regclass) NOT NULL,
    value character varying(100) NOT NULL,
    type company.additional_info_context_type NOT NULL
);


ALTER TABLE company.additional_info_context OWNER TO postgres;

--
-- Name: additional_info_key_id_seq; Type: SEQUENCE; Schema: company; Owner: postgres
--

CREATE SEQUENCE company.additional_info_key_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE company.additional_info_key_id_seq OWNER TO postgres;

--
-- Name: additional_info_keys; Type: TABLE; Schema: company; Owner: postgres
--

CREATE TABLE company.additional_info_keys (
    id integer DEFAULT nextval('company.additional_info_key_id_seq'::regclass) NOT NULL,
    additional_info_context_id integer NOT NULL,
    value character varying(50) NOT NULL
);


ALTER TABLE company.additional_info_keys OWNER TO postgres;

--
-- Name: address_id_seq; Type: SEQUENCE; Schema: company; Owner: postgres
--

CREATE SEQUENCE company.address_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE company.address_id_seq OWNER TO postgres;

--
-- Name: addresses; Type: TABLE; Schema: company; Owner: postgres
--

CREATE TABLE company.addresses (
    id integer DEFAULT nextval('company.address_id_seq'::regclass) NOT NULL,
    place_id character varying(250),
    latitude numeric,
    longitude numeric,
    premise character varying(250),
    street_number character varying(250),
    route character varying(250),
    locality character varying(250),
    administrative_area_level_1 character varying(250),
    country character varying(250),
    postal_code character varying(250),
    formatted_address character varying(250) NOT NULL,
    full_address character varying(250),
    administrative_area_level_2 character varying(250),
    date_created timestamp without time zone DEFAULT now() NOT NULL,
    date_modified timestamp without time zone DEFAULT now(),
    room character varying(50),
    country_code character varying(5)
);


ALTER TABLE company.addresses OWNER TO postgres;

--
-- Name: classificator_id_seq; Type: SEQUENCE; Schema: company; Owner: postgres
--

CREATE SEQUENCE company.classificator_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE company.classificator_id_seq OWNER TO postgres;

--
-- Name: classificators; Type: TABLE; Schema: company; Owner: postgres
--

CREATE TABLE company.classificators (
    id integer DEFAULT nextval('company.classificator_id_seq'::regclass) NOT NULL,
    code character varying(50) NOT NULL,
    classificator character varying(50) NOT NULL,
    value character varying(100) NOT NULL
);


ALTER TABLE company.classificators OWNER TO postgres;

--
-- Name: company_id_seq; Type: SEQUENCE; Schema: company; Owner: postgres
--

CREATE SEQUENCE company.company_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE company.company_id_seq OWNER TO postgres;

--
-- Name: companies; Type: TABLE; Schema: company; Owner: postgres
--

CREATE TABLE company.companies (
    id integer DEFAULT nextval('company.company_id_seq'::regclass) NOT NULL,
    name character varying(90) NOT NULL,
    reg_no character varying(50),
    nav_customer_id integer,
    nav_vendor_id integer,
    date_created timestamp without time zone DEFAULT now() NOT NULL,
    date_modified timestamp without time zone DEFAULT now(),
    company_type character varying(50),
    customer_manager_id integer,
    status character varying(50) DEFAULT 'COMPANY_STATUS_NORMAL'::character varying NOT NULL,
    credit boolean DEFAULT false NOT NULL,
    bank_account_number character varying(50),
    vat_reg_no character varying(50),
    review_cause text,
    deleted boolean DEFAULT false NOT NULL,
    vat_reg_no_missing boolean DEFAULT false NOT NULL,
    bank_swift_code character varying(25),
    used boolean DEFAULT true NOT NULL,
    is_problematic boolean DEFAULT false NOT NULL,
    bank_account_number_missing_reason text,
    in_credit_risk_management boolean,
    approver_id integer
);


ALTER TABLE company.companies OWNER TO postgres;

--
-- Name: company_group; Type: TABLE; Schema: company; Owner: postgres
--

CREATE TABLE company.company_group (
    id integer NOT NULL,
    name text,
    type_code text NOT NULL,
    person_id integer
);


ALTER TABLE company.company_group OWNER TO postgres;

--
-- Name: company_group_id_seq; Type: SEQUENCE; Schema: company; Owner: postgres
--

ALTER TABLE company.company_group ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME company.company_group_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: company_groups_companies; Type: TABLE; Schema: company; Owner: postgres
--

CREATE TABLE company.company_groups_companies (
    company_groups_id integer NOT NULL,
    companies_id integer NOT NULL
);


ALTER TABLE company.company_groups_companies OWNER TO postgres;

--
-- Name: company_has_customer_manager_id_seq; Type: SEQUENCE; Schema: company; Owner: postgres
--

CREATE SEQUENCE company.company_has_customer_manager_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE company.company_has_customer_manager_id_seq OWNER TO postgres;

--
-- Name: company_has_customer_manager; Type: TABLE; Schema: company; Owner: postgres
--

CREATE TABLE company.company_has_customer_manager (
    id integer DEFAULT nextval('company.company_has_customer_manager_id_seq'::regclass) NOT NULL,
    company_id integer NOT NULL,
    representative_id integer NOT NULL
);


ALTER TABLE company.company_has_customer_manager OWNER TO postgres;

--
-- Name: company_has_relation_id_seq; Type: SEQUENCE; Schema: company; Owner: postgres
--

CREATE SEQUENCE company.company_has_relation_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE company.company_has_relation_id_seq OWNER TO postgres;

--
-- Name: company_has_relation; Type: TABLE; Schema: company; Owner: postgres
--

CREATE TABLE company.company_has_relation (
    id integer DEFAULT nextval('company.company_has_relation_id_seq'::regclass) NOT NULL,
    company_id integer NOT NULL,
    relation character varying(50) DEFAULT 'COMPANY_RELATION_CLIENT'::character varying NOT NULL
);


ALTER TABLE company.company_has_relation OWNER TO postgres;

--
-- Name: coordinate_distance; Type: TABLE; Schema: company; Owner: postgres
--

CREATE TABLE company.coordinate_distance (
    origin_latitude numeric(20,3) NOT NULL,
    origin_longitude numeric(20,3) NOT NULL,
    destination_latitude numeric(20,3) NOT NULL,
    destination_longitude numeric(20,3) NOT NULL,
    distance_in_kilometres integer NOT NULL
);


ALTER TABLE company.coordinate_distance OWNER TO postgres;

--
-- Name: distance; Type: TABLE; Schema: company; Owner: postgres
--

CREATE TABLE company.distance (
    from_location_id integer NOT NULL,
    to_location_id integer NOT NULL,
    distance_in_kilometres integer NOT NULL
);


ALTER TABLE company.distance OWNER TO postgres;

--
-- Name: fence; Type: TABLE; Schema: company; Owner: postgres
--

CREATE TABLE company.fence (
    id integer NOT NULL,
    latitude text NOT NULL,
    longitude text NOT NULL
);


ALTER TABLE company.fence OWNER TO postgres;

--
-- Name: fence_id_seq; Type: SEQUENCE; Schema: company; Owner: postgres
--

CREATE SEQUENCE company.fence_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE company.fence_id_seq OWNER TO postgres;

--
-- Name: fence_id_seq; Type: SEQUENCE OWNED BY; Schema: company; Owner: postgres
--

ALTER SEQUENCE company.fence_id_seq OWNED BY company.fence.id;


--
-- Name: imported_id_seq; Type: SEQUENCE; Schema: company; Owner: postgres
--

CREATE SEQUENCE company.imported_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE company.imported_id_seq OWNER TO postgres;

--
-- Name: imported; Type: TABLE; Schema: company; Owner: postgres
--

CREATE TABLE company.imported (
    id integer DEFAULT nextval('company.imported_id_seq'::regclass) NOT NULL,
    key character varying(100) NOT NULL,
    value text NOT NULL
);


ALTER TABLE company.imported OWNER TO postgres;

--
-- Name: keyword_id_seq; Type: SEQUENCE; Schema: company; Owner: postgres
--

CREATE SEQUENCE company.keyword_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE company.keyword_id_seq OWNER TO postgres;

--
-- Name: keywords; Type: TABLE; Schema: company; Owner: postgres
--

CREATE TABLE company.keywords (
    id integer DEFAULT nextval('company.keyword_id_seq'::regclass) NOT NULL,
    value character varying(50) NOT NULL,
    type character varying(100) DEFAULT 'KEYWORD_TYPE_COMPANY'::character varying NOT NULL
);


ALTER TABLE company.keywords OWNER TO postgres;

--
-- Name: location_email; Type: TABLE; Schema: company; Owner: postgres
--

CREATE TABLE company.location_email (
    location_id integer NOT NULL,
    email text NOT NULL,
    send_delivery_order boolean DEFAULT false NOT NULL
);


ALTER TABLE company.location_email OWNER TO postgres;

--
-- Name: location_id_seq; Type: SEQUENCE; Schema: company; Owner: postgres
--

CREATE SEQUENCE company.location_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE company.location_id_seq OWNER TO postgres;

--
-- Name: location_usage; Type: TABLE; Schema: company; Owner: postgres
--

CREATE TABLE company.location_usage (
    id integer NOT NULL,
    location_id integer NOT NULL,
    warehouse_id integer NOT NULL,
    warehouse_job_count integer NOT NULL
);


ALTER TABLE company.location_usage OWNER TO postgres;

--
-- Name: location_usage_id_seq; Type: SEQUENCE; Schema: company; Owner: postgres
--

CREATE SEQUENCE company.location_usage_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE company.location_usage_id_seq OWNER TO postgres;

--
-- Name: location_usage_id_seq; Type: SEQUENCE OWNED BY; Schema: company; Owner: postgres
--

ALTER SEQUENCE company.location_usage_id_seq OWNED BY company.location_usage.id;


--
-- Name: locations; Type: TABLE; Schema: company; Owner: postgres
--

CREATE TABLE company.locations (
    id integer DEFAULT nextval('company.location_id_seq'::regclass) NOT NULL,
    company_id integer NOT NULL,
    address_id integer,
    location_name character varying(100) NOT NULL,
    location_type character varying(50),
    date_created timestamp without time zone DEFAULT now() NOT NULL,
    date_modified timestamp without time zone DEFAULT now(),
    primary_contact_id integer,
    location_code character varying(100),
    email character varying(200),
    phone character varying(200),
    status character varying(50) DEFAULT 'LOCATION_STATUS_ACTIVE'::character varying NOT NULL,
    scrap_warehouse boolean DEFAULT false NOT NULL,
    additional_emails character varying(50)[],
    is_crop_location boolean DEFAULT false NOT NULL,
    last_warehouse_job_creation_date date,
    has_worker boolean DEFAULT true NOT NULL,
    fence_id integer,
    alternative_warehouse_code character varying(100)
);


ALTER TABLE company.locations OWNER TO postgres;

--
-- Name: log_id_seq; Type: SEQUENCE; Schema: company; Owner: postgres
--

CREATE SEQUENCE company.log_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE company.log_id_seq OWNER TO postgres;

--
-- Name: log; Type: TABLE; Schema: company; Owner: postgres
--

CREATE TABLE company.log (
    id integer DEFAULT nextval('company.log_id_seq'::regclass) NOT NULL,
    created_by_user text NOT NULL,
    type company.log_type NOT NULL,
    create_time timestamp without time zone DEFAULT now() NOT NULL,
    system_log_data text,
    company_id integer,
    location_id integer,
    representative_id integer,
    request text
);


ALTER TABLE company.log OWNER TO postgres;

--
-- Name: person_id_seq; Type: SEQUENCE; Schema: company; Owner: postgres
--

CREATE SEQUENCE company.person_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE company.person_id_seq OWNER TO postgres;

--
-- Name: persons; Type: TABLE; Schema: company; Owner: postgres
--

CREATE TABLE company.persons (
    id integer DEFAULT nextval('company.person_id_seq'::regclass) NOT NULL,
    name character varying(90) NOT NULL,
    personal_code character varying(50),
    phone character varying(100),
    email character varying(200),
    date_created timestamp without time zone DEFAULT now() NOT NULL,
    date_modified timestamp without time zone DEFAULT now(),
    status character varying(50) DEFAULT 'PERSON_STATUS_ACTIVE'::character varying NOT NULL,
    joined_person_id integer,
    first_name character varying(100),
    last_name character varying(100),
    email_usage_allowed company.gdpr_status DEFAULT 'PENDING'::company.gdpr_status NOT NULL,
    phone_usage_allowed company.gdpr_status DEFAULT 'PENDING'::company.gdpr_status NOT NULL,
    plant_protection_no character varying(50),
    plant_protection_validity_date timestamp without time zone,
    deletion_reason text,
    plant_protection_entry_type character varying(50) DEFAULT 'PLANT_PROTECTION_ENTRY_AUTOMATIC'::character varying NOT NULL,
    is_problematic boolean DEFAULT false NOT NULL,
    birthday date,
    address_id integer,
    address_usage_allowed company.gdpr_status DEFAULT 'PENDING'::company.gdpr_status NOT NULL,
    plant_protection_code text
);


ALTER TABLE company.persons OWNER TO postgres;

--
-- Name: representative_id_seq; Type: SEQUENCE; Schema: company; Owner: postgres
--

CREATE SEQUENCE company.representative_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE company.representative_id_seq OWNER TO postgres;

--
-- Name: representatives; Type: TABLE; Schema: company; Owner: postgres
--

CREATE TABLE company.representatives (
    id integer DEFAULT nextval('company.representative_id_seq'::regclass) NOT NULL,
    person_id integer NOT NULL,
    company_id integer,
    job_title character varying(100),
    nav_salesperson_code character varying(50),
    mandate_type character varying(50),
    status character varying(50) DEFAULT 'REPRESENTATIVE_STATUS_ACTIVE'::character varying,
    email character varying(200),
    phone character varying(100),
    date_created timestamp without time zone,
    date_modified timestamp without time zone,
    is_primary boolean DEFAULT false NOT NULL
);


ALTER TABLE company.representatives OWNER TO postgres;

--
-- Name: representative_person_view; Type: VIEW; Schema: company; Owner: postgres
--

CREATE VIEW company.representative_person_view AS
 SELECT subquery.type,
    subquery.representative_id,
    subquery.person_id,
    subquery.company_id,
    subquery.status,
    subquery.job_title,
    subquery.mandate_type,
    subquery.nav_salesperson_code,
    subquery.name,
    subquery.first_name,
    subquery.last_name,
    subquery.personal_code,
    subquery.phone,
    subquery.email,
    subquery.representative_phone,
    subquery.representative_email,
    row_number() OVER (PARTITION BY true::boolean) AS row_number
   FROM ( SELECT 1 AS type,
            r.id AS representative_id,
            p.id AS person_id,
            r.company_id,
            r.status,
            r.job_title,
            r.mandate_type,
            r.nav_salesperson_code,
            p.name,
            p.first_name,
            p.last_name,
            p.personal_code,
            p.phone,
            p.email,
            r.phone AS representative_phone,
            r.email AS representative_email
           FROM (company.representatives r
             LEFT JOIN company.persons p ON ((r.person_id = p.id)))
        UNION
         SELECT 2 AS type,
            NULL::integer AS int4,
            p.id,
            NULL::integer AS int4,
            p.status,
            NULL::character varying AS "varchar",
            NULL::character varying AS "varchar",
            NULL::character varying AS "varchar",
            p.name,
            p.first_name,
            p.last_name,
            p.personal_code,
            p.phone,
            p.email,
            NULL::character varying AS "varchar",
            NULL::character varying AS "varchar"
           FROM company.persons p) subquery;


ALTER TABLE company.representative_person_view OWNER TO postgres;

--
-- Name: schema_version; Type: TABLE; Schema: company; Owner: postgres
--

CREATE TABLE company.schema_version (
    installed_rank integer NOT NULL,
    version character varying(50),
    description character varying(200) NOT NULL,
    type character varying(20) NOT NULL,
    script character varying(1000) NOT NULL,
    checksum integer,
    installed_by character varying(100) NOT NULL,
    installed_on timestamp without time zone DEFAULT now() NOT NULL,
    execution_time integer NOT NULL,
    success boolean NOT NULL
);


ALTER TABLE company.schema_version OWNER TO postgres;

--
-- Name: selected_keyword_id_seq; Type: SEQUENCE; Schema: company; Owner: postgres
--

CREATE SEQUENCE company.selected_keyword_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE company.selected_keyword_id_seq OWNER TO postgres;

--
-- Name: selected_keywords; Type: TABLE; Schema: company; Owner: postgres
--

CREATE TABLE company.selected_keywords (
    id integer DEFAULT nextval('company.selected_keyword_id_seq'::regclass) NOT NULL,
    company_id integer,
    value character varying(50) NOT NULL,
    person_id integer,
    representative_id integer,
    location_id integer,
    debt_keyword_company_id integer
);


ALTER TABLE company.selected_keywords OWNER TO postgres;

--
-- Name: shedlock; Type: TABLE; Schema: company; Owner: postgres
--

CREATE TABLE company.shedlock (
    name character varying(64) NOT NULL,
    lock_until timestamp(3) without time zone,
    locked_at timestamp(3) without time zone,
    locked_by character varying(255)
);


ALTER TABLE company.shedlock OWNER TO postgres;

--
-- Name: fence id; Type: DEFAULT; Schema: company; Owner: postgres
--

ALTER TABLE ONLY company.fence ALTER COLUMN id SET DEFAULT nextval('company.fence_id_seq'::regclass);


--
-- Name: location_usage id; Type: DEFAULT; Schema: company; Owner: postgres
--

ALTER TABLE ONLY company.location_usage ALTER COLUMN id SET DEFAULT nextval('company.location_usage_id_seq'::regclass);


--
-- Name: additional_info_context additional_info_context_pkey; Type: CONSTRAINT; Schema: company; Owner: postgres
--

ALTER TABLE ONLY company.additional_info_context
    ADD CONSTRAINT additional_info_context_pkey PRIMARY KEY (id);


--
-- Name: additional_info_keys additional_info_keys_pkey; Type: CONSTRAINT; Schema: company; Owner: postgres
--

ALTER TABLE ONLY company.additional_info_keys
    ADD CONSTRAINT additional_info_keys_pkey PRIMARY KEY (id);


--
-- Name: additional_info additional_info_pkey; Type: CONSTRAINT; Schema: company; Owner: postgres
--

ALTER TABLE ONLY company.additional_info
    ADD CONSTRAINT additional_info_pkey PRIMARY KEY (id);


--
-- Name: addresses addresses_pkey; Type: CONSTRAINT; Schema: company; Owner: postgres
--

ALTER TABLE ONLY company.addresses
    ADD CONSTRAINT addresses_pkey PRIMARY KEY (id);


--
-- Name: classificators classificators_code_key; Type: CONSTRAINT; Schema: company; Owner: postgres
--

ALTER TABLE ONLY company.classificators
    ADD CONSTRAINT classificators_code_key UNIQUE (code);


--
-- Name: classificators classificators_pkey; Type: CONSTRAINT; Schema: company; Owner: postgres
--

ALTER TABLE ONLY company.classificators
    ADD CONSTRAINT classificators_pkey PRIMARY KEY (id);


--
-- Name: companies companies_pkey; Type: CONSTRAINT; Schema: company; Owner: postgres
--

ALTER TABLE ONLY company.companies
    ADD CONSTRAINT companies_pkey PRIMARY KEY (id);


--
-- Name: company_group company_group_pkey; Type: CONSTRAINT; Schema: company; Owner: postgres
--

ALTER TABLE ONLY company.company_group
    ADD CONSTRAINT company_group_pkey PRIMARY KEY (id);


--
-- Name: company_groups_companies company_groups_companies_pkey; Type: CONSTRAINT; Schema: company; Owner: postgres
--

ALTER TABLE ONLY company.company_groups_companies
    ADD CONSTRAINT company_groups_companies_pkey PRIMARY KEY (company_groups_id, companies_id);


--
-- Name: company_has_customer_manager company_has_customer_manager_pkey; Type: CONSTRAINT; Schema: company; Owner: postgres
--

ALTER TABLE ONLY company.company_has_customer_manager
    ADD CONSTRAINT company_has_customer_manager_pkey PRIMARY KEY (id);


--
-- Name: company_has_relation company_has_relation_pkey; Type: CONSTRAINT; Schema: company; Owner: postgres
--

ALTER TABLE ONLY company.company_has_relation
    ADD CONSTRAINT company_has_relation_pkey PRIMARY KEY (id);


--
-- Name: coordinate_distance coordinate_distance_pkey; Type: CONSTRAINT; Schema: company; Owner: postgres
--

ALTER TABLE ONLY company.coordinate_distance
    ADD CONSTRAINT coordinate_distance_pkey PRIMARY KEY (origin_latitude, origin_longitude, destination_latitude, destination_longitude);


--
-- Name: distance distance_pkey; Type: CONSTRAINT; Schema: company; Owner: postgres
--

ALTER TABLE ONLY company.distance
    ADD CONSTRAINT distance_pkey PRIMARY KEY (from_location_id, to_location_id);


--
-- Name: fence fence_pkey; Type: CONSTRAINT; Schema: company; Owner: postgres
--

ALTER TABLE ONLY company.fence
    ADD CONSTRAINT fence_pkey PRIMARY KEY (id);


--
-- Name: imported imported_pkey; Type: CONSTRAINT; Schema: company; Owner: postgres
--

ALTER TABLE ONLY company.imported
    ADD CONSTRAINT imported_pkey PRIMARY KEY (id);


--
-- Name: keywords keywords_pkey; Type: CONSTRAINT; Schema: company; Owner: postgres
--

ALTER TABLE ONLY company.keywords
    ADD CONSTRAINT keywords_pkey PRIMARY KEY (id);


--
-- Name: location_email location_email_pkey; Type: CONSTRAINT; Schema: company; Owner: postgres
--

ALTER TABLE ONLY company.location_email
    ADD CONSTRAINT location_email_pkey PRIMARY KEY (location_id, email);


--
-- Name: location_usage location_usage_pkey; Type: CONSTRAINT; Schema: company; Owner: postgres
--

ALTER TABLE ONLY company.location_usage
    ADD CONSTRAINT location_usage_pkey PRIMARY KEY (id);


--
-- Name: locations locations_pkey; Type: CONSTRAINT; Schema: company; Owner: postgres
--

ALTER TABLE ONLY company.locations
    ADD CONSTRAINT locations_pkey PRIMARY KEY (id);


--
-- Name: log log_pkey; Type: CONSTRAINT; Schema: company; Owner: postgres
--

ALTER TABLE ONLY company.log
    ADD CONSTRAINT log_pkey PRIMARY KEY (id);


--
-- Name: persons persons_pkey; Type: CONSTRAINT; Schema: company; Owner: postgres
--

ALTER TABLE ONLY company.persons
    ADD CONSTRAINT persons_pkey PRIMARY KEY (id);


--
-- Name: representatives representatives_nav_salesperson_code_key; Type: CONSTRAINT; Schema: company; Owner: postgres
--

ALTER TABLE ONLY company.representatives
    ADD CONSTRAINT representatives_nav_salesperson_code_key UNIQUE (nav_salesperson_code);


--
-- Name: representatives representatives_pkey; Type: CONSTRAINT; Schema: company; Owner: postgres
--

ALTER TABLE ONLY company.representatives
    ADD CONSTRAINT representatives_pkey PRIMARY KEY (id);


--
-- Name: schema_version schema_version_pk; Type: CONSTRAINT; Schema: company; Owner: postgres
--

ALTER TABLE ONLY company.schema_version
    ADD CONSTRAINT schema_version_pk PRIMARY KEY (installed_rank);


--
-- Name: selected_keywords selected_keywords_pkey; Type: CONSTRAINT; Schema: company; Owner: postgres
--

ALTER TABLE ONLY company.selected_keywords
    ADD CONSTRAINT selected_keywords_pkey PRIMARY KEY (id);


--
-- Name: shedlock shedlock_pkey; Type: CONSTRAINT; Schema: company; Owner: postgres
--

ALTER TABLE ONLY company.shedlock
    ADD CONSTRAINT shedlock_pkey PRIMARY KEY (name);


--
-- Name: additional_info_company_id_idx; Type: INDEX; Schema: company; Owner: postgres
--

CREATE INDEX additional_info_company_id_idx ON company.additional_info USING btree (company_id);


--
-- Name: additional_info_keys_additional_info_context_id_idx; Type: INDEX; Schema: company; Owner: postgres
--

CREATE INDEX additional_info_keys_additional_info_context_id_idx ON company.additional_info_keys USING btree (additional_info_context_id);


--
-- Name: additional_info_location_id_idx; Type: INDEX; Schema: company; Owner: postgres
--

CREATE INDEX additional_info_location_id_idx ON company.additional_info USING btree (location_id);


--
-- Name: additional_info_person_id_idx; Type: INDEX; Schema: company; Owner: postgres
--

CREATE INDEX additional_info_person_id_idx ON company.additional_info USING btree (person_id);


--
-- Name: companies_company_type_idx; Type: INDEX; Schema: company; Owner: postgres
--

CREATE INDEX companies_company_type_idx ON company.companies USING btree (company_type);


--
-- Name: companies_customer_manager_id_idx; Type: INDEX; Schema: company; Owner: postgres
--

CREATE INDEX companies_customer_manager_id_idx ON company.companies USING btree (customer_manager_id);


--
-- Name: companies_status_idx; Type: INDEX; Schema: company; Owner: postgres
--

CREATE INDEX companies_status_idx ON company.companies USING btree (status);


--
-- Name: company_has_customer_manager_company_id_idx; Type: INDEX; Schema: company; Owner: postgres
--

CREATE INDEX company_has_customer_manager_company_id_idx ON company.company_has_customer_manager USING btree (company_id);


--
-- Name: company_has_customer_manager_representative_id_idx; Type: INDEX; Schema: company; Owner: postgres
--

CREATE INDEX company_has_customer_manager_representative_id_idx ON company.company_has_customer_manager USING btree (representative_id);


--
-- Name: company_has_relation_company_id_idx; Type: INDEX; Schema: company; Owner: postgres
--

CREATE INDEX company_has_relation_company_id_idx ON company.company_has_relation USING btree (company_id);


--
-- Name: company_has_relation_relation_idx; Type: INDEX; Schema: company; Owner: postgres
--

CREATE INDEX company_has_relation_relation_idx ON company.company_has_relation USING btree (relation);


--
-- Name: distance_least_greatest_idx; Type: INDEX; Schema: company; Owner: postgres
--

CREATE UNIQUE INDEX distance_least_greatest_idx ON company.distance USING btree (LEAST(from_location_id, to_location_id), GREATEST(from_location_id, to_location_id));


--
-- Name: keywords_type_idx; Type: INDEX; Schema: company; Owner: postgres
--

CREATE INDEX keywords_type_idx ON company.keywords USING btree (type);


--
-- Name: locations_address_id_idx; Type: INDEX; Schema: company; Owner: postgres
--

CREATE INDEX locations_address_id_idx ON company.locations USING btree (address_id);


--
-- Name: locations_company_id_idx; Type: INDEX; Schema: company; Owner: postgres
--

CREATE INDEX locations_company_id_idx ON company.locations USING btree (company_id);


--
-- Name: locations_location_type_idx; Type: INDEX; Schema: company; Owner: postgres
--

CREATE INDEX locations_location_type_idx ON company.locations USING btree (location_type);


--
-- Name: locations_primary_contact_id_idx; Type: INDEX; Schema: company; Owner: postgres
--

CREATE INDEX locations_primary_contact_id_idx ON company.locations USING btree (primary_contact_id);


--
-- Name: locations_status_idx; Type: INDEX; Schema: company; Owner: postgres
--

CREATE INDEX locations_status_idx ON company.locations USING btree (status);


--
-- Name: persons_joined_person_id_idx; Type: INDEX; Schema: company; Owner: postgres
--

CREATE INDEX persons_joined_person_id_idx ON company.persons USING btree (joined_person_id);


--
-- Name: persons_status_idx; Type: INDEX; Schema: company; Owner: postgres
--

CREATE INDEX persons_status_idx ON company.persons USING btree (status);


--
-- Name: representatives_company_id_idx; Type: INDEX; Schema: company; Owner: postgres
--

CREATE INDEX representatives_company_id_idx ON company.representatives USING btree (company_id);


--
-- Name: representatives_mandate_type_idx; Type: INDEX; Schema: company; Owner: postgres
--

CREATE INDEX representatives_mandate_type_idx ON company.representatives USING btree (mandate_type);


--
-- Name: representatives_person_id_idx; Type: INDEX; Schema: company; Owner: postgres
--

CREATE INDEX representatives_person_id_idx ON company.representatives USING btree (person_id);


--
-- Name: representatives_status_idx; Type: INDEX; Schema: company; Owner: postgres
--

CREATE INDEX representatives_status_idx ON company.representatives USING btree (status);


--
-- Name: schema_version_s_idx; Type: INDEX; Schema: company; Owner: postgres
--

CREATE INDEX schema_version_s_idx ON company.schema_version USING btree (success);


--
-- Name: selected_keywords_company_id_idx; Type: INDEX; Schema: company; Owner: postgres
--

CREATE INDEX selected_keywords_company_id_idx ON company.selected_keywords USING btree (company_id);


--
-- Name: selected_keywords_location_id_idx; Type: INDEX; Schema: company; Owner: postgres
--

CREATE INDEX selected_keywords_location_id_idx ON company.selected_keywords USING btree (location_id);


--
-- Name: selected_keywords_person_id_idx; Type: INDEX; Schema: company; Owner: postgres
--

CREATE INDEX selected_keywords_person_id_idx ON company.selected_keywords USING btree (person_id);


--
-- Name: selected_keywords_representative_id_idx; Type: INDEX; Schema: company; Owner: postgres
--

CREATE INDEX selected_keywords_representative_id_idx ON company.selected_keywords USING btree (representative_id);


--
-- Name: additional_info additional_info_company_id_fkey; Type: FK CONSTRAINT; Schema: company; Owner: postgres
--

ALTER TABLE ONLY company.additional_info
    ADD CONSTRAINT additional_info_company_id_fkey FOREIGN KEY (company_id) REFERENCES company.companies(id);


--
-- Name: additional_info_keys additional_info_keys_additional_info_context_id_fkey; Type: FK CONSTRAINT; Schema: company; Owner: postgres
--

ALTER TABLE ONLY company.additional_info_keys
    ADD CONSTRAINT additional_info_keys_additional_info_context_id_fkey FOREIGN KEY (additional_info_context_id) REFERENCES company.additional_info_context(id);


--
-- Name: additional_info additional_info_location_id_fkey; Type: FK CONSTRAINT; Schema: company; Owner: postgres
--

ALTER TABLE ONLY company.additional_info
    ADD CONSTRAINT additional_info_location_id_fkey FOREIGN KEY (location_id) REFERENCES company.locations(id);


--
-- Name: additional_info additional_info_person_id_fkey; Type: FK CONSTRAINT; Schema: company; Owner: postgres
--

ALTER TABLE ONLY company.additional_info
    ADD CONSTRAINT additional_info_person_id_fkey FOREIGN KEY (person_id) REFERENCES company.persons(id);


--
-- Name: companies companies_approver_id_fkey; Type: FK CONSTRAINT; Schema: company; Owner: postgres
--

ALTER TABLE ONLY company.companies
    ADD CONSTRAINT companies_approver_id_fkey FOREIGN KEY (approver_id) REFERENCES company.representatives(id);


--
-- Name: companies companies_company_type_fkey; Type: FK CONSTRAINT; Schema: company; Owner: postgres
--

ALTER TABLE ONLY company.companies
    ADD CONSTRAINT companies_company_type_fkey FOREIGN KEY (company_type) REFERENCES company.classificators(code);


--
-- Name: companies companies_customer_manager_id_fkey; Type: FK CONSTRAINT; Schema: company; Owner: postgres
--

ALTER TABLE ONLY company.companies
    ADD CONSTRAINT companies_customer_manager_id_fkey FOREIGN KEY (customer_manager_id) REFERENCES company.representatives(id);


--
-- Name: companies companies_status_fkey; Type: FK CONSTRAINT; Schema: company; Owner: postgres
--

ALTER TABLE ONLY company.companies
    ADD CONSTRAINT companies_status_fkey FOREIGN KEY (status) REFERENCES company.classificators(code);


--
-- Name: company_group company_group_person_id_fkey; Type: FK CONSTRAINT; Schema: company; Owner: postgres
--

ALTER TABLE ONLY company.company_group
    ADD CONSTRAINT company_group_person_id_fkey FOREIGN KEY (person_id) REFERENCES company.persons(id);


--
-- Name: company_group company_group_type_code_fkey; Type: FK CONSTRAINT; Schema: company; Owner: postgres
--

ALTER TABLE ONLY company.company_group
    ADD CONSTRAINT company_group_type_code_fkey FOREIGN KEY (type_code) REFERENCES company.classificators(code);


--
-- Name: company_groups_companies company_groups_companies_companies_id_fkey; Type: FK CONSTRAINT; Schema: company; Owner: postgres
--

ALTER TABLE ONLY company.company_groups_companies
    ADD CONSTRAINT company_groups_companies_companies_id_fkey FOREIGN KEY (companies_id) REFERENCES company.companies(id);


--
-- Name: company_groups_companies company_groups_companies_company_groups_id_fkey; Type: FK CONSTRAINT; Schema: company; Owner: postgres
--

ALTER TABLE ONLY company.company_groups_companies
    ADD CONSTRAINT company_groups_companies_company_groups_id_fkey FOREIGN KEY (company_groups_id) REFERENCES company.company_group(id);


--
-- Name: company_has_customer_manager company_has_customer_manager_company_id_fkey; Type: FK CONSTRAINT; Schema: company; Owner: postgres
--

ALTER TABLE ONLY company.company_has_customer_manager
    ADD CONSTRAINT company_has_customer_manager_company_id_fkey FOREIGN KEY (company_id) REFERENCES company.companies(id);


--
-- Name: company_has_customer_manager company_has_customer_manager_representative_id_fkey; Type: FK CONSTRAINT; Schema: company; Owner: postgres
--

ALTER TABLE ONLY company.company_has_customer_manager
    ADD CONSTRAINT company_has_customer_manager_representative_id_fkey FOREIGN KEY (representative_id) REFERENCES company.representatives(id);


--
-- Name: company_has_relation company_has_relation_company_id_fkey; Type: FK CONSTRAINT; Schema: company; Owner: postgres
--

ALTER TABLE ONLY company.company_has_relation
    ADD CONSTRAINT company_has_relation_company_id_fkey FOREIGN KEY (company_id) REFERENCES company.companies(id);


--
-- Name: company_has_relation company_has_relation_relation_fkey; Type: FK CONSTRAINT; Schema: company; Owner: postgres
--

ALTER TABLE ONLY company.company_has_relation
    ADD CONSTRAINT company_has_relation_relation_fkey FOREIGN KEY (relation) REFERENCES company.classificators(code);


--
-- Name: distance distance_from_location_id_fkey; Type: FK CONSTRAINT; Schema: company; Owner: postgres
--

ALTER TABLE ONLY company.distance
    ADD CONSTRAINT distance_from_location_id_fkey FOREIGN KEY (from_location_id) REFERENCES company.locations(id);


--
-- Name: distance distance_to_location_id_fkey; Type: FK CONSTRAINT; Schema: company; Owner: postgres
--

ALTER TABLE ONLY company.distance
    ADD CONSTRAINT distance_to_location_id_fkey FOREIGN KEY (to_location_id) REFERENCES company.locations(id);


--
-- Name: keywords fk_keywords_has_classificator1; Type: FK CONSTRAINT; Schema: company; Owner: postgres
--

ALTER TABLE ONLY company.keywords
    ADD CONSTRAINT fk_keywords_has_classificator1 FOREIGN KEY (type) REFERENCES company.classificators(code) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: location_email location_email_location_id_fkey; Type: FK CONSTRAINT; Schema: company; Owner: postgres
--

ALTER TABLE ONLY company.location_email
    ADD CONSTRAINT location_email_location_id_fkey FOREIGN KEY (location_id) REFERENCES company.locations(id);


--
-- Name: location_usage location_usage_location_id_fkey; Type: FK CONSTRAINT; Schema: company; Owner: postgres
--

ALTER TABLE ONLY company.location_usage
    ADD CONSTRAINT location_usage_location_id_fkey FOREIGN KEY (location_id) REFERENCES company.locations(id);


--
-- Name: locations locations_address_id_fkey; Type: FK CONSTRAINT; Schema: company; Owner: postgres
--

ALTER TABLE ONLY company.locations
    ADD CONSTRAINT locations_address_id_fkey FOREIGN KEY (address_id) REFERENCES company.addresses(id);


--
-- Name: locations locations_company_id_fkey; Type: FK CONSTRAINT; Schema: company; Owner: postgres
--

ALTER TABLE ONLY company.locations
    ADD CONSTRAINT locations_company_id_fkey FOREIGN KEY (company_id) REFERENCES company.companies(id);


--
-- Name: locations locations_fence_id_fkey; Type: FK CONSTRAINT; Schema: company; Owner: postgres
--

ALTER TABLE ONLY company.locations
    ADD CONSTRAINT locations_fence_id_fkey FOREIGN KEY (fence_id) REFERENCES company.fence(id);


--
-- Name: locations locations_location_type_fkey; Type: FK CONSTRAINT; Schema: company; Owner: postgres
--

ALTER TABLE ONLY company.locations
    ADD CONSTRAINT locations_location_type_fkey FOREIGN KEY (location_type) REFERENCES company.classificators(code);


--
-- Name: locations locations_primary_contact_id_fkey; Type: FK CONSTRAINT; Schema: company; Owner: postgres
--

ALTER TABLE ONLY company.locations
    ADD CONSTRAINT locations_primary_contact_id_fkey FOREIGN KEY (primary_contact_id) REFERENCES company.representatives(id);


--
-- Name: locations locations_status_fkey; Type: FK CONSTRAINT; Schema: company; Owner: postgres
--

ALTER TABLE ONLY company.locations
    ADD CONSTRAINT locations_status_fkey FOREIGN KEY (status) REFERENCES company.classificators(code);


--
-- Name: log log_company_id_fkey; Type: FK CONSTRAINT; Schema: company; Owner: postgres
--

ALTER TABLE ONLY company.log
    ADD CONSTRAINT log_company_id_fkey FOREIGN KEY (company_id) REFERENCES company.companies(id);


--
-- Name: log log_location_id_fkey; Type: FK CONSTRAINT; Schema: company; Owner: postgres
--

ALTER TABLE ONLY company.log
    ADD CONSTRAINT log_location_id_fkey FOREIGN KEY (location_id) REFERENCES company.locations(id);


--
-- Name: log log_representative_id_fkey; Type: FK CONSTRAINT; Schema: company; Owner: postgres
--

ALTER TABLE ONLY company.log
    ADD CONSTRAINT log_representative_id_fkey FOREIGN KEY (representative_id) REFERENCES company.representatives(id);


--
-- Name: persons persons_address_id_fkey; Type: FK CONSTRAINT; Schema: company; Owner: postgres
--

ALTER TABLE ONLY company.persons
    ADD CONSTRAINT persons_address_id_fkey FOREIGN KEY (address_id) REFERENCES company.addresses(id);


--
-- Name: persons persons_joined_person_id_fkey; Type: FK CONSTRAINT; Schema: company; Owner: postgres
--

ALTER TABLE ONLY company.persons
    ADD CONSTRAINT persons_joined_person_id_fkey FOREIGN KEY (joined_person_id) REFERENCES company.persons(id);


--
-- Name: persons persons_plant_protection_entry_type_fkey; Type: FK CONSTRAINT; Schema: company; Owner: postgres
--

ALTER TABLE ONLY company.persons
    ADD CONSTRAINT persons_plant_protection_entry_type_fkey FOREIGN KEY (plant_protection_entry_type) REFERENCES company.classificators(code);


--
-- Name: persons persons_status_fkey; Type: FK CONSTRAINT; Schema: company; Owner: postgres
--

ALTER TABLE ONLY company.persons
    ADD CONSTRAINT persons_status_fkey FOREIGN KEY (status) REFERENCES company.classificators(code);


--
-- Name: representatives representatives_company_id_fkey; Type: FK CONSTRAINT; Schema: company; Owner: postgres
--

ALTER TABLE ONLY company.representatives
    ADD CONSTRAINT representatives_company_id_fkey FOREIGN KEY (company_id) REFERENCES company.companies(id);


--
-- Name: representatives representatives_mandate_type_fkey; Type: FK CONSTRAINT; Schema: company; Owner: postgres
--

ALTER TABLE ONLY company.representatives
    ADD CONSTRAINT representatives_mandate_type_fkey FOREIGN KEY (mandate_type) REFERENCES company.classificators(code);


--
-- Name: representatives representatives_person_id_fkey; Type: FK CONSTRAINT; Schema: company; Owner: postgres
--

ALTER TABLE ONLY company.representatives
    ADD CONSTRAINT representatives_person_id_fkey FOREIGN KEY (person_id) REFERENCES company.persons(id);


--
-- Name: representatives representatives_status_fkey; Type: FK CONSTRAINT; Schema: company; Owner: postgres
--

ALTER TABLE ONLY company.representatives
    ADD CONSTRAINT representatives_status_fkey FOREIGN KEY (status) REFERENCES company.classificators(code);


--
-- Name: selected_keywords selected_keywords_company_id_fkey; Type: FK CONSTRAINT; Schema: company; Owner: postgres
--

ALTER TABLE ONLY company.selected_keywords
    ADD CONSTRAINT selected_keywords_company_id_fkey FOREIGN KEY (company_id) REFERENCES company.companies(id);


--
-- Name: selected_keywords selected_keywords_debt_keyword_company_id_fkey; Type: FK CONSTRAINT; Schema: company; Owner: postgres
--

ALTER TABLE ONLY company.selected_keywords
    ADD CONSTRAINT selected_keywords_debt_keyword_company_id_fkey FOREIGN KEY (debt_keyword_company_id) REFERENCES company.companies(id);


--
-- Name: selected_keywords selected_keywords_location_id_fkey; Type: FK CONSTRAINT; Schema: company; Owner: postgres
--

ALTER TABLE ONLY company.selected_keywords
    ADD CONSTRAINT selected_keywords_location_id_fkey FOREIGN KEY (location_id) REFERENCES company.locations(id);


--
-- Name: selected_keywords selected_keywords_person_id_fkey; Type: FK CONSTRAINT; Schema: company; Owner: postgres
--

ALTER TABLE ONLY company.selected_keywords
    ADD CONSTRAINT selected_keywords_person_id_fkey FOREIGN KEY (person_id) REFERENCES company.persons(id);


--
-- Name: selected_keywords selected_keywords_representative_id_fkey; Type: FK CONSTRAINT; Schema: company; Owner: postgres
--

ALTER TABLE ONLY company.selected_keywords
    ADD CONSTRAINT selected_keywords_representative_id_fkey FOREIGN KEY (representative_id) REFERENCES company.representatives(id);


--
-- PostgreSQL database dump complete
--

\unrestrict 1206Lea9FI6g9XdDZC6RBpAodo8Dtm8BhQpOaaUMm0cV2DjGdrVSEXsg5Bs9FC3

