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
                print(f"SSL connection failed on temp connect, retrying without SSL: {e}")
                conn_params.pop("ssl", None)
                temp_conn = pymysql.connect(**conn_params)
            else:
                raise e

        try:
            with temp_conn.cursor() as cursor:
                cursor.execute(f"CREATE DATABASE IF NOT EXISTS {database}")
            temp_conn.commit()
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

            migrations_dir = os.path.join(os.path.dirname(__file__), "../../migrations")
            migrations_dir = os.path.abspath(migrations_dir)

            if not has_players:
                print("Tables not found, running schema migration (001)...")
                run_sql_file(conn, os.path.join(migrations_dir, "001_shop_upgrade_system.sql"))

            if not has_shop:
                print("Table 'shop_items' not found, running seed migration (002)...")
                run_sql_file(conn, os.path.join(migrations_dir, "002_seed_shop_items.sql"))

            if not has_battle_logs:
                print("Table 'battle_logs' not found, running gameplay mechanics migration (003)...")
                run_sql_file(conn, os.path.join(migrations_dir, "003_gameplay_mechanics.sql"))

            # Always run 004 to ensure granted_skill exists
            print("Running weapon skills migration (004)...")
            run_sql_file(conn, os.path.join(migrations_dir, "004_weapon_skills.sql"))

            print("Database check completed successfully.")
        finally:
            conn.close()

    except Exception as e:
        print(f"DATABASE AUTO-MIGRATION WARNING: {e}")
    print("======================================================")
