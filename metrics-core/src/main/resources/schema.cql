--
-- Copyright 2014-2015 Red Hat, Inc. and/or its affiliates
-- and other contributors as indicated by the @author tags.
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--    http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
--

-- This CQL file is used to create the schema temporarily until we get a better schema
-- change management tool in place. The file is parsed and executed by SchemaManger.
--
-- NOTE: Statements must must be preceded by -- #
--
-- Comments that start with a double dash like this are suppressed.

-- #

CREATE KEYSPACE ${keyspace} WITH replication = {'class': 'SimpleStrategy', 'replication_factor': 1}

-- #

CREATE TYPE ${keyspace}.aggregation_template (
    type int,
    src text,
    interval text,
    fns set<text>
);

-- #

-- The retentions map entries are <metric_type, interval> --> retention

CREATE TABLE ${keyspace}.tenants (
    id text PRIMARY KEY,
    retentions map<frozen<tuple<int, text>>, int>,
    aggregation_templates list<frozen<aggregation_template>>
);

-- #

CREATE TYPE ${keyspace}.aggregate_data (
    type text,
    value double,
    time timeuuid,
    src_metric text,
    src_metric_interval text
);

-- #

CREATE TABLE ${keyspace}.data (
    tenant_id text,
    type int,
    metric text,
    interval text,
    dpart bigint,
    time timeuuid,
    data_retention int static,
    meta_data map<text, text> static,
    n_value double,
    availability blob,
    aggregates set<frozen <aggregate_data>>,
    tags map<text, text>,
    PRIMARY KEY ((tenant_id, type, metric, interval, dpart), time)
)
WITH CLUSTERING ORDER BY (time DESC);

-- #

CREATE TABLE ${keyspace}.counters (
    tenant_id text,
    group text,
    c_name text,
    c_value counter,
    PRIMARY KEY ((tenant_id, group), c_name)
);

-- #

CREATE TABLE ${keyspace}.tags (
    tenant_id text,
    tag text,
    type int,
    metric text,
    interval text,
    time timeuuid,
    n_value double,
    aggregates set<frozen <aggregate_data>>,
    availability blob,
    tag_desc text,
    PRIMARY KEY ((tenant_id, tag, type), metric, interval, time)
);

-- #

CREATE TABLE ${keyspace}.metrics_idx (
    tenant_id text,
    type int,
    metric text,
    interval text,
    meta_data map<text, text>,
    data_retention int,
    PRIMARY KEY ((tenant_id, type), interval, metric)
) WITH compaction = { 'class': 'LeveledCompactionStrategy' };

-- #

-- For the retentions_idx table a partial metric id is used as clustering
-- columns. Remember that a metric id consists of the type, the metric name,
-- and the interval. The type is used in the partition key, while the name and
-- interval are used as clustering columns. We also store tenant-level
-- retentions in this table. They will be stored using some special, reserved
-- names, e.g., [numeric], [availability]. Square brackets are reserved
-- characters, so we can safely use these.
--
-- The retention is stored in seconds.

CREATE TABLE ${keyspace}.retentions_idx (
    tenant_id text,
    type int,
    interval text,
    metric text,
    retention int,
    PRIMARY KEY ((tenant_id, type), interval, metric)
) WITH compaction = { 'class': 'LeveledCompactionStrategy' };