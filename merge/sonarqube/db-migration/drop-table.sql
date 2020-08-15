UPDATE pg_database SET datallowconn = 'false' WHERE datname = 'sonar';

SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = 'sonar';

DROP DATABASE "sonar";
