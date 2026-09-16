-- 2026 FIFA World Cup Prediction Project
-- ML-ready training dataset
--
-- This query combines the relational feature tables into the final
-- model-training dataset. The June 10, 2026 cutoff is intentional:
-- it prevents completed 2026 World Cup group-stage results from
-- entering pre-tournament model training.

DROP TABLE IF EXISTS model_training_data;

CREATE TABLE model_training_data AS
SELECT
    m.match_id,
    m.match_date,

    -- Team identifiers
    m.home_team_id,
    m.away_team_id,

    -- Match context
    m.neutral,

    -- FIFA rankings
    mr.home_fifa_rank,
    mr.away_fifa_rank,
    mr.home_fifa_rank - mr.away_fifa_rank
        AS fifa_rank_difference,

    mr.home_fifa_points,
    mr.away_fifa_points,
    mr.home_fifa_points - mr.away_fifa_points
        AS fifa_points_difference,

    -- Recent form
    home_form.recent_win_rate
        AS home_recent_win_rate,

    away_form.recent_win_rate
        AS away_recent_win_rate,

    home_form.recent_avg_goal_difference
        AS home_recent_goal_difference,

    away_form.recent_avg_goal_difference
        AS away_recent_goal_difference,

    -- Head-to-head history
    h2h.previous_head_to_head_matches,

    COALESCE(h2h.home_h2h_win_rate, 0)
        AS home_h2h_win_rate,

    COALESCE(h2h.away_h2h_win_rate, 0)
        AS away_h2h_win_rate,

    h2h.has_h2h_history,

    COALESCE(h2h.h2h_win_rate_difference, 0)
        AS h2h_win_rate_difference,

    -- Target variable
    mo.match_outcome

FROM matches m

JOIN match_rankings mr
    ON m.match_id = mr.match_id

JOIN team_recent_form home_form
    ON m.match_id = home_form.match_id
    AND m.home_team_id = home_form.team_id

JOIN team_recent_form away_form
    ON m.match_id = away_form.match_id
    AND m.away_team_id = away_form.team_id

JOIN head_to_head_model_features h2h
    ON m.match_id = h2h.match_id

JOIN match_outcomes mo
    ON m.match_id = mo.match_id

WHERE home_form.previous_matches = 5
  AND away_form.previous_matches = 5

  -- Prevent 2026 World Cup data leakage.
  AND m.match_date <= '2026-06-10';


-- ================================================================
-- VALIDATION
-- ================================================================

SELECT
    COUNT(*) AS total_matches,
    MIN(match_date) AS earliest_match,
    MAX(match_date) AS latest_match
FROM model_training_data;


SELECT
    match_outcome,
    COUNT(*) AS match_count,
    ROUND(
        100.0 * COUNT(*) / SUM(COUNT(*)) OVER (),
        2
    ) AS percentage
FROM model_training_data
GROUP BY match_outcome
ORDER BY match_count DESC;
