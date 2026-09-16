-- 2026 FIFA World Cup Prediction Project
-- PostgreSQL database schema
-- Extracted and cleaned from the project development history.

CREATE TABLE matches (
    match_id SERIAL PRIMARY KEY,
    match_date DATE NOT NULL,

    home_team_id INTEGER NOT NULL,
    away_team_id INTEGER NOT NULL,

    home_score INTEGER NOT NULL,
    away_score INTEGER NOT NULL,

    tournament VARCHAR(150),
    city VARCHAR(100),
    country VARCHAR(100),
    neutral BOOLEAN,

    CONSTRAINT fk_home_team
        FOREIGN KEY (home_team_id)
        REFERENCES teams(team_id),

    CONSTRAINT fk_away_team
        FOREIGN KEY (away_team_id)
        REFERENCES teams(team_id)
);

CREATE TABLE fifa_rankings (
    ranking_id SERIAL PRIMARY KEY,

    team_id INTEGER NOT NULL,

    fifa_rank INTEGER NOT NULL,
    total_points DECIMAL(10,2),
    previous_points DECIMAL(10,2),
    rank_change INTEGER,

    ranking_date DATE NOT NULL,

    CONSTRAINT fk_ranking_team
        FOREIGN KEY (team_id)
        REFERENCES teams(team_id)
);

CREATE TABLE team_name_mapping (
    mapping_id SERIAL PRIMARY KEY,

    source VARCHAR(50) NOT NULL,
    source_name VARCHAR(100) NOT NULL,
    standardized_name VARCHAR(100) NOT NULL,

    UNIQUE (source, source_name)
);

-- Staging tables preserve the raw source structure before
-- standardized records are inserted into the analytical tables.

CREATE TABLE staging_matches (
    date DATE,
    home_team VARCHAR(100),
    away_team VARCHAR(100),
    home_score INTEGER,
    away_score INTEGER,
    tournament VARCHAR(150),
    city VARCHAR(100),
    country VARCHAR(100),
    neutral BOOLEAN
);

CREATE TABLE staging_fifa_rankings (
    fifa_rank INTEGER,
    country_full VARCHAR(100),
    country_abrv VARCHAR(10),
    total_points DECIMAL(10,2),
    previous_points DECIMAL(10,2),
    rank_change INTEGER,
    confederation VARCHAR(10),
    rank_date DATE
);
