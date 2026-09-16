-- 2026 FIFA World Cup Prediction Project
-- PostgreSQL data ingestion and validation
--
-- Replace the source paths below with local paths when reproducing
-- the project. The original terminal history contained local paths,
-- which have intentionally been removed from this portfolio version.

-- Import match results. The source data contains "NA" values,
-- which PostgreSQL should interpret as NULL.

\copy staging_matches
FROM '/path/to/results.csv'
WITH (
    FORMAT csv,
    HEADER true,
    NULL 'NA'
);

-- Import FIFA ranking data using the same staging-table approach.
-- Adjust the filename/path to the local source file.

\copy staging_fifa_rankings
FROM '/path/to/fifa_rankings.csv'
WITH (
    FORMAT csv,
    HEADER true,
    NULL 'NA'
);

-- Validate the match import.

SELECT COUNT(*) AS total_staging_matches
FROM staging_matches;

-- Validate the FIFA ranking import.

SELECT COUNT(*) AS total_staging_rankings
FROM staging_fifa_rankings;

-- Check for incomplete match records before inserting
-- into the production matches table.

SELECT
    COUNT(*) AS total_rows,
    COUNT(*) FILTER (
        WHERE home_score IS NULL OR away_score IS NULL
    ) AS rows_with_missing_scores
FROM staging_matches;
