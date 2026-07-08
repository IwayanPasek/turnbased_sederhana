import os
import pymysql
from app.core.database import get_db_connection

def run():
    print("Running migration 008...")
    with open('migrations/008_achievements.sql', 'r') as f:
        sql_commands = f.read().split(';')
    
    conn = get_db_connection()
    try:
        with conn.cursor() as cursor:
            for command in sql_commands:
                if command.strip():
                    cursor.execute(command)
        conn.commit()
        print("Migration successful.")
    except Exception as e:
        print(f"Error executing command:\n{command}\nException: {e}")
    finally:
        conn.close()

if __name__ == '__main__':
    run()
