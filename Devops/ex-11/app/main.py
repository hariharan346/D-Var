import os
import sys
import socket
import time
import psycopg2

def main():
    db_host = os.getenv("DB_HOST", "postgres")
    db_port = os.getenv("DB_PORT", "5432")
    db_user = os.getenv("DB_USER", "postgres")
    db_password = os.getenv("DB_PASSWORD", "admin123")
    
    print(f"Connecting to database at {db_host}:{db_port}...")
    
    try:
        # Attempt to establish database connection
        connection = psycopg2.connect(
            host=db_host,
            port=db_port,
            user=db_user,
            password=db_password,
            connect_timeout=3
        )
        print("Connection successful! Running payment-service loop...")
        connection.close()
        
        # Keep application running successfully
        while True:
            time.sleep(3600)
            
    except Exception as e:
        # Get host IP for logging
        try:
            db_ip = socket.gethostbyname(db_host)
        except Exception:
            db_ip = "10.96.102.15" # Realistic ClusterIP fallback
            
        # Output exact panic traceback expected in the incident
        print("panic:")
        print(f"dial tcp {db_ip}:{db_port}: connection refused")
        sys.exit(1)

if __name__ == "__main__":
    main()
