import os
import pymysql
from dotenv import load_dotenv

load_dotenv()

def get_connection():
    return pymysql.connect(
        host=os.getenv("DB_HOST", "localhost"),
        port=int(os.getenv("DB_PORT", 4000)),
        user=os.getenv("DB_USER", "root"),
        password=os.getenv("DB_PASSWORD", ""),
        database=os.getenv("DB_NAME", "turnbased_db"),
        cursorclass=pymysql.cursors.DictCursor,
        autocommit=True
    )

if __name__ == "__main__":
    conn = get_connection()
    try:
        with conn.cursor() as cursor:
            try:
                cursor.execute("ALTER TABLE players ADD COLUMN is_admin BOOLEAN DEFAULT FALSE")
                print("is_admin added")
            except Exception as e:
                print("is_admin failed:", e)
            try:
                cursor.execute("ALTER TABLE players ADD COLUMN is_banned BOOLEAN DEFAULT FALSE")
                print("is_banned added")
            except Exception as e:
                print("is_banned failed:", e)
    finally:
        conn.close()
