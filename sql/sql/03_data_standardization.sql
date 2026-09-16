-- 2026 FIFA World Cup Prediction Project
-- Team-name standardization and relational data integration

-- Standardize team names across the match-results source and
-- the FIFA/team reference data.

INSERT INTO team_name_mapping (
    source,
    source_name,
    standardized_name
)
VALUES
    ('matches', 'Brunei', 'Brunei Darussalam'),
    ('matches', 'Cape Verde', 'Cabo Verde'),
    ('matches', 'Czech Republic', 'Czechia'),
    ('matches', 'DR Congo', 'Congo DR'),
    ('matches', 'Gambia', 'The Gambia'),
    ('matches', 'Hong Kong', 'Hong Kong, China'),
    ('matches', 'Iran', 'IR Iran'),
    ('matches', 'Ivory Coast', 'Côte d''Ivoire'),
    ('matches', 'Kyrgyzstan', 'Kyrgyz Republic'),
    ('matches', 'North Korea', 'Korea DPR'),
    ('matches', 'Saint Kitts and Nevis', 'St Kitts and Nevis'),
    ('matches', 'Saint Lucia', 'St Lucia'),
    ('matches', 'Saint Vincent and the Grenadines', 'St Vincent and the Grenadines'),
    ('matches', 'South Korea', 'Korea Republic'),
    ('matches', 'Taiwan', 'Chinese Taipei'),
    ('matches', 'Turkey', 'Türkiye'),
    ('matches', 'United States', 'USA'),
    ('matches', 'United States Virgin Islands', 'US Virgin Islands');

-- Load FIFA rankings after matching source country names to
-- standardized team records.

INSERT INTO fifa_rankings (
    team_id,
    fifa_rank,
    total_points,
    previous_points,
    rank_change,
    ranking_date
)
SELECT
    t.team_id,
    sfr.fifa_rank,
    sfr.total_points,
    sfr.previous_points,
    sfr.rank_change,
    sfr.rank_date
FROM staging_fifa_rankings sfr
JOIN teams t
    ON sfr.country_full = t.team_name;

-- Review how many ranking records were successfully integrated.

SELECT COUNT(*) AS total_ranking_records
FROM fifa_rankings;

-- Confirm that every staged FIFA ranking row matched a team.

SELECT COUNT(*) AS unmatched_ranking_records
FROM staging_fifa_rankings sfr
LEFT JOIN teams t
    ON sfr.country_full = t.team_name
WHERE t.team_id IS NULL;

-- Standardize match-team names and validate how many completed
-- matches can be represented using the relational team table.

WITH standardized_matches AS (
    SELECT
        sm.date,
        COALESCE(home_map.standardized_name, sm.home_team) AS home_team,
        COALESCE(away_map.standardized_name, sm.away_team) AS away_team,
        sm.home_score,
        sm.away_score,
        sm.tournament,
        sm.city,
        sm.country,
        sm.neutral
    FROM staging_matches sm
    LEFT JOIN team_name_mapping home_map
        ON sm.home_team = home_map.source_name
        AND home_map.source = 'matches'
    LEFT JOIN team_name_mapping away_map
        ON sm.away_team = away_map.source_name
        AND away_map.source = 'matches'
    WHERE sm.date >= '2018-06-14'
      AND sm.home_score IS NOT NULL
      AND sm.away_score IS NOT NULL
)
SELECT
    COUNT(*) AS total_completed_matches,

    COUNT(*) FILTER (
        WHERE home.team_id IS NOT NULL
          AND away.team_id IS NOT NULL
    ) AS matches_with_both_teams,

    COUNT(*) FILTER (
        WHERE home.team_id IS NULL
           OR away.team_id IS NULL
    ) AS matches_excluded

FROM standardized_matches sm
LEFT JOIN teams home
    ON sm.home_team = home.team_name
LEFT JOIN teams away
    ON sm.away_team = away.team_name;

-- Insert standardized, completed matches into the relational
-- matches table.

INSERT INTO matches (
    match_date,
    home_team_id,
    away_team_id,
    home_score,
    away_score,
    tournament,
    city,
    country,
    neutral
)
SELECT
    sm.date,
    home.team_id,
    away.team_id,
    sm.home_score,
    sm.away_score,
    sm.tournament,
    sm.city,
    sm.country,
    sm.neutral
FROM staging_matches sm
LEFT JOIN team_name_mapping home_map
    ON sm.home_team = home_map.source_name
    AND home_map.source = 'matches'
LEFT JOIN team_name_mapping away_map
    ON sm.away_team = away_map.source_name
    AND away_map.source = 'matches'
JOIN teams home
    ON COALESCE(home_map.standardized_name, sm.home_team) = home.team_name
JOIN teams away
    ON COALESCE(away_map.standardized_name, sm.away_team) = away.team_name
WHERE sm.date >= '2018-06-14'
  AND sm.home_score IS NOT NULL
  AND sm.away_score IS NOT NULL;

-- Final row-count validation.

SELECT COUNT(*) AS total_matches
FROM matches;
