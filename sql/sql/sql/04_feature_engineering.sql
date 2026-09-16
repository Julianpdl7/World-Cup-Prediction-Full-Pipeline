-- 2026 FIFA World Cup Prediction Project
-- SQL feature engineering
--
-- Recent form and head-to-head features are calculated using only
-- matches occurring before the match being represented.

-- ================================================================
-- RECENT FORM
-- ================================================================

CREATE OR REPLACE VIEW team_recent_form AS

WITH team_match_history AS (
    SELECT
        m.match_id,
        m.match_date,
        m.home_team_id AS team_id,
        m.away_team_id AS opponent_id,
        m.home_score AS team_score,
        m.away_score AS opponent_score
    FROM matches m

    UNION ALL

    SELECT
        m.match_id,
        m.match_date,
        m.away_team_id AS team_id,
        m.home_team_id AS opponent_id,
        m.away_score AS team_score,
        m.home_score AS opponent_score
    FROM matches m
),

team_match_results AS (
    SELECT *,
        CASE
            WHEN team_score > opponent_score THEN 1
            ELSE 0
        END AS win,

        team_score - opponent_score AS goal_difference

    FROM team_match_history
)

SELECT
    match_id,
    match_date,
    team_id,
    opponent_id,

    COUNT(*) OVER (
        PARTITION BY team_id
        ORDER BY match_date, match_id
        ROWS BETWEEN 5 PRECEDING AND 1 PRECEDING
    ) AS previous_matches,

    COALESCE(
        SUM(win) OVER (
            PARTITION BY team_id
            ORDER BY match_date, match_id
            ROWS BETWEEN 5 PRECEDING AND 1 PRECEDING
        ),
        0
    ) AS previous_wins,

    ROUND(
        AVG(win::NUMERIC) OVER (
            PARTITION BY team_id
            ORDER BY match_date, match_id
            ROWS BETWEEN 5 PRECEDING AND 1 PRECEDING
        ),
        3
    ) AS recent_win_rate,

    ROUND(
        AVG(goal_difference::NUMERIC) OVER (
            PARTITION BY team_id
            ORDER BY match_date, match_id
            ROWS BETWEEN 5 PRECEDING AND 1 PRECEDING
        ),
        3
    ) AS recent_avg_goal_difference

FROM team_match_results;

-- Validate the rolling-window feature.

SELECT *
FROM team_recent_form
ORDER BY team_id, match_date
LIMIT 10;


-- ================================================================
-- HEAD-TO-HEAD FEATURES
-- ================================================================

DROP TABLE IF EXISTS team_head_to_head;

CREATE TABLE team_head_to_head AS
SELECT
    current_match.match_id,
    current_match.match_date,
    current_match.home_team_id,
    current_match.away_team_id,

    COUNT(previous_match.match_id) AS previous_head_to_head_matches,

    COUNT(*) FILTER (
        WHERE previous_match.home_team_id = current_match.home_team_id
          AND previous_match.home_score > previous_match.away_score
    )
    +
    COUNT(*) FILTER (
        WHERE previous_match.away_team_id = current_match.home_team_id
          AND previous_match.away_score > previous_match.home_score
    ) AS home_team_previous_h2h_wins,

    COUNT(*) FILTER (
        WHERE previous_match.home_team_id = current_match.away_team_id
          AND previous_match.home_score > previous_match.away_score
    )
    +
    COUNT(*) FILTER (
        WHERE previous_match.away_team_id = current_match.away_team_id
          AND previous_match.away_score > previous_match.home_score
    ) AS away_team_previous_h2h_wins

FROM matches current_match

LEFT JOIN matches previous_match
    ON (
        (
            previous_match.home_team_id = current_match.home_team_id
            AND previous_match.away_team_id = current_match.away_team_id
        )
        OR
        (
            previous_match.home_team_id = current_match.away_team_id
            AND previous_match.away_team_id = current_match.home_team_id
        )
    )
    AND previous_match.match_date < current_match.match_date

GROUP BY
    current_match.match_id,
    current_match.match_date,
    current_match.home_team_id,
    current_match.away_team_id;


CREATE OR REPLACE VIEW head_to_head_features AS
SELECT
    match_id,
    match_date,
    home_team_id,
    away_team_id,
    previous_head_to_head_matches,
    home_team_previous_h2h_wins,
    away_team_previous_h2h_wins,

    CASE
        WHEN previous_head_to_head_matches > 0
        THEN ROUND(
            home_team_previous_h2h_wins::NUMERIC
            / previous_head_to_head_matches,
            3
        )
        ELSE NULL
    END AS home_h2h_win_rate,

    CASE
        WHEN previous_head_to_head_matches > 0
        THEN ROUND(
            away_team_previous_h2h_wins::NUMERIC
            / previous_head_to_head_matches,
            3
        )
        ELSE NULL
    END AS away_h2h_win_rate

FROM team_head_to_head;


CREATE OR REPLACE VIEW head_to_head_model_features AS
SELECT
    *,

    CASE
        WHEN previous_head_to_head_matches > 0 THEN 1
        ELSE 0
    END AS has_h2h_history,

    CASE
        WHEN previous_head_to_head_matches > 0
        THEN home_h2h_win_rate - away_h2h_win_rate
        ELSE NULL
    END AS h2h_win_rate_difference

FROM head_to_head_features;

-- Validate the H2H feature coverage.

SELECT
    COUNT(*) AS total_model_matches,

    COUNT(*) FILTER (
        WHERE h2h.previous_head_to_head_matches > 0
    ) AS matches_with_h2h_history,

    COUNT(*) FILTER (
        WHERE h2h.previous_head_to_head_matches = 0
    ) AS matches_without_h2h_history,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE h2h.previous_head_to_head_matches > 0
        ) / COUNT(*),
        2
    ) AS percent_with_h2h_history

FROM match_rankings mr
JOIN head_to_head_features h2h
    ON mr.match_id = h2h.match_id;
