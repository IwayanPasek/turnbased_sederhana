import os
import pymysql
from fastapi import HTTPException
from dotenv import load_dotenv

load_dotenv()


def get_db_connection():
    host = os.getenv("DB_HOST", "127.0.0.1")
    port = int(os.getenv("DB_PORT", "3306"))
    user = os.getenv("DB_USER", "root")
    password = os.getenv("DB_PASSWORD", "")
    database = os.getenv("DB_NAME", "turnbased_db")

    use_ssl = (
        os.getenv("DB_USE_SSL", "0").lower() in ("1", "true", "yes")
        or "tidbcloud" in host
    )

    try:
        conn_params = {
            "host": host,
            "port": port,
            "user": user,
            "password": password,
            "database": database,
            "cursorclass": pymysql.cursors.DictCursor,
            "connect_timeout": 10,
        }
        if use_ssl:
            conn_params["ssl"] = {"ssl": {}}

        try:
            return pymysql.connect(**conn_params)
        except pymysql.MySQLError as e:
            if use_ssl:
                print(f"SSL connection failed, retrying without SSL: {e}")
                if "ssl" in conn_params:
                    del conn_params["ssl"]
                return pymysql.connect(**conn_params)
            raise e
    except pymysql.MySQLError as e:
        print(f"ERROR DATABASE: {e}")
        raise HTTPException(status_code=500, detail="Gagal terhubung ke database")


def run_sql_file(connection, file_path):
    if not os.path.exists(file_path):
        print(f"Migration file not found: {file_path}")
        return

    print(f"Running migration file: {file_path}")
    try:
        with open(file_path, "r", encoding="utf-8") as f:
            sql_content = f.read()

        queries = []
        current_query = []
        for line in sql_content.split("\n"):
            stripped = line.strip()
            if (
                not stripped
                or stripped.startswith("--")
                or stripped.startswith("/*")
                or stripped.startswith("*")
            ):
                continue
            current_query.append(line)
            if stripped.endswith(";"):
                queries.append("\n".join(current_query))
                current_query = []

        with connection.cursor() as cursor:
            cursor.execute("SET FOREIGN_KEY_CHECKS = 0;")
            for query in queries:
                q_strip = query.strip()
                if not q_strip:
                    continue
                try:
                    cursor.execute(q_strip)
                except Exception as e:
                    print(f"Warning during query execution: {e}")
            cursor.execute("SET FOREIGN_KEY_CHECKS = 1;")
        connection.commit()
        print(f"Migration file executed successfully: {file_path}")
    except Exception as e:
        print(f"Error running migration {file_path}: {e}")


def startup_db_migration():
    """Ensure database exists and tables are fully initialized/migrated on startup."""
    print("====== STARTING DATABASE CHECK & AUTO-MIGRATION ======")
    try:
        host = os.getenv("DB_HOST", "127.0.0.1")
        port = int(os.getenv("DB_PORT", "3306"))
        user = os.getenv("DB_USER", "root")
        password = os.getenv("DB_PASSWORD", "")
        database = os.getenv("DB_NAME", "turnbased_db")

        conn_params = {
            "host": host,
            "port": port,
            "user": user,
            "password": password,
            "cursorclass": pymysql.cursors.DictCursor,
            "connect_timeout": 5,
        }

        use_ssl = (
            os.getenv("DB_USE_SSL", "0").lower() in ("1", "true", "yes")
            or "tidbcloud" in host
        )
        if use_ssl:
            conn_params["ssl"] = {"ssl": {}}

        try:
            temp_conn = pymysql.connect(**conn_params)
        except Exception as e:
            if use_ssl:
                print(
                    f"SSL connection failed on temp connect, retrying without SSL: {e}"
                )
                conn_params.pop("ssl", None)
                temp_conn = pymysql.connect(**conn_params)
            else:
                raise e

        try:
            with temp_conn.cursor() as cursor:
                cursor.execute(f"CREATE DATABASE IF NOT EXISTS {database}")
            temp_conn.commit()
        except Exception as db_e:
            print(f"CREATE DATABASE failed (normal for TiDB Serverless): {db_e}")
        finally:
            temp_conn.close()

        conn = get_db_connection()
        try:
            with conn.cursor() as cursor:
                cursor.execute("SHOW TABLES LIKE 'players'")
                has_players = cursor.fetchone()

                cursor.execute("SHOW TABLES LIKE 'shop_items'")
                has_shop = cursor.fetchone()

                cursor.execute("SHOW TABLES LIKE 'battle_logs'")
                has_battle_logs = cursor.fetchone()

                cursor.execute("SHOW TABLES LIKE 'player_attributes'")
                has_player_attributes = cursor.fetchone()

                cursor.execute("SHOW TABLES LIKE 'match_history'")
                has_match_history = cursor.fetchone()

            migrations_dir = os.path.join(os.path.dirname(__file__), "../../migrations")
            migrations_dir = os.path.abspath(migrations_dir)

            if not has_players:
                print("Tables not found, running schema migration (001)...")
                run_sql_file(
                    conn, os.path.join(migrations_dir, "001_shop_upgrade_system.sql")
                )

            if not has_shop:
                print("Table 'shop_items' not found, running seed migration (002)...")
                run_sql_file(
                    conn, os.path.join(migrations_dir, "002_seed_shop_items.sql")
                )

            if not has_battle_logs:
                print(
                    "Table 'battle_logs' not found, running gameplay mechanics migration (003)..."
                )
                run_sql_file(
                    conn, os.path.join(migrations_dir, "003_gameplay_mechanics.sql")
                )

            # Run 004 only if weapon skill items are not yet seeded
            with conn.cursor() as check_cursor:
                check_cursor.execute(
                    "SELECT COUNT(*) as cnt FROM shop_items WHERE granted_skill IS NOT NULL"
                )
                row = check_cursor.fetchone()
                weapon_skills_seeded = (row["cnt"] if row else 0) > 0

            if not weapon_skills_seeded:
                print("Running weapon skills migration (004)...")
                run_sql_file(conn, os.path.join(migrations_dir, "004_weapon_skills.sql"))
            else:
                print("Migration 004 already applied, skipping.")

            if not has_player_attributes:
                print("Table 'player_attributes' not found, running attributes migration (005)...")
                run_sql_file(conn, os.path.join(migrations_dir, "005_player_attributes.sql"))

            if not has_match_history:
                print("Table 'match_history' not found, running history migration (006)...")
                run_sql_file(conn, os.path.join(migrations_dir, "006_match_history.sql"))

            with conn.cursor() as check_cursor:
                check_cursor.execute("SHOW INDEX FROM player_stats WHERE Key_name = 'idx_player_stats_mmr_desc'")
                has_mmr_index = check_cursor.fetchone()

            if not has_mmr_index:
                print("Index 'idx_player_stats_mmr_desc' not found, running leaderboard indexing migration (007)...")
                run_sql_file(conn, os.path.join(migrations_dir, "007_leaderboard_index.sql"))

            with conn.cursor() as check_cursor:
                check_cursor.execute("SHOW TABLES LIKE 'guilds'")
                has_guilds = check_cursor.fetchone()
            
            if not has_guilds:
                print("Table 'guilds' not found, running guild system migration (009)...")
                run_sql_file(conn, os.path.join(migrations_dir, "009_guild_system.sql"))

            with conn.cursor() as check_cursor:
                check_cursor.execute("SHOW TABLES LIKE 'achievements'")
                has_achievements = check_cursor.fetchone()
            
            if not has_achievements:
                print("Table 'achievements' not found, running achievements migration (008)...")
                run_sql_file(conn, os.path.join(migrations_dir, "008_achievements.sql"))

            with conn.cursor() as check_cursor:
                check_cursor.execute("SHOW TABLES LIKE 'daily_quests_master'")
                has_daily_quests = check_cursor.fetchone()
            
            if not has_daily_quests:
                print("Table 'daily_quests_master' not found, running daily quests migration (010)...")
                run_sql_file(conn, os.path.join(migrations_dir, "010_daily_quests.sql"))

            with conn.cursor() as check_cursor:
                check_cursor.execute("SHOW COLUMNS FROM players LIKE 'avatar_style'")
                has_avatars = check_cursor.fetchone()
            
            if not has_avatars:
                print("Column 'avatar_style' not found, running player avatars migration (010)...")
                run_sql_file(conn, os.path.join(migrations_dir, "010_player_avatars.sql"))

            with conn.cursor() as check_cursor:
                check_cursor.execute("SHOW COLUMNS FROM players LIKE 'is_admin'")
                has_admin_col = check_cursor.fetchone()
            
            if not has_admin_col:
                print("Column 'is_admin' not found, running player admin migration (011)...")
                run_sql_file(conn, os.path.join(migrations_dir, "011_player_admin.sql"))

            with conn.cursor() as check_cursor:
                check_cursor.execute("SHOW COLUMNS FROM players LIKE 'gacha_pity_counter'")
                has_pity_col = check_cursor.fetchone()
            
            if not has_pity_col:
                print("Column 'gacha_pity_counter' not found, running gacha pity migration (012)...")
                run_sql_file(conn, os.path.join(migrations_dir, "012_gacha_pity.sql"))

            with conn.cursor() as check_cursor:
                check_cursor.execute("SHOW COLUMNS FROM players LIKE 'level'")
                has_level_col = check_cursor.fetchone()
            
            if not has_level_col:
                print("Column 'level' not found, running player level migration (013)...")
                run_sql_file(conn, os.path.join(migrations_dir, "013_player_level_system.sql"))

            with conn.cursor() as check_cursor:
                check_cursor.execute("SHOW TABLES LIKE 'system_config'")
                has_sys_config = check_cursor.fetchone()
            
            if not has_sys_config:
                print("Table 'system_config' not found, running system announcement migration (014)...")
                run_sql_file(conn, os.path.join(migrations_dir, "014_system_announcement.sql"))

            conn.commit()
            print("Database check completed successfully.")
        finally:
            conn.close()

    except Exception as e:
        print(f"DATABASE AUTO-MIGRATION WARNING: {e}")
    print("======================================================")
