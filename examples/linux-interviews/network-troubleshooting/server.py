# server.py
import socket
import time
import signal
import sys

HOST = '0.0.0.0'  # Listen on all available interfaces
PORT = 65432      # Port to listen on (non-privileged ports are > 1023)

def signal_handler(sig, frame):
    print('Signal received, server shutting down...')
    sys.exit(0)

signal.signal(signal.SIGINT, signal_handler) # Handle Ctrl+C

with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
    s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1) # Allow address reuse
    s.bind((HOST, PORT))
    s.listen()
    print(f"Server listening on {HOST}:{PORT}")

    try:
        conn, addr = s.accept()
        with conn:
            print(f"Connected by {addr}")
            try:
                # Keep the connection alive for a bit
                while True:
                    data = conn.recv(1024)
                    if not data:
                        print("Client closed connection (or connection lost before server sent FIN).")
                        break # Client closed or connection broke
                    print(f"Received from client: {data.decode()!r}")
                    conn.sendall(b"Server acknowledges: " + data)
                    # To make the server die after some interaction:
                    # time.sleep(10)
                    # print("Server simulating an abrupt exit/crash now...")
                    # sys.exit(1) # Abrupt exit

            except ConnectionResetError:
                print(f"Connection reset by client {addr}.")
            except BrokenPipeError:
                print(f"Broken pipe with client {addr} (client likely closed abruptly).")
            except Exception as e:
                print(f"Error during communication with {addr}: {e}")
            finally:
                print(f"Closing connection with {addr}")
                # conn.close() # Normally, context manager handles this.
                # If we want the server to initiate close, this is where it would be.
    except KeyboardInterrupt:
        print("Server shutting down due to KeyboardInterrupt.")
    finally:
        print("Server socket closed.")
        # s.close() # Normally, context manager handles this.