# client.py
import socket
import time
import sys

SERVER_HOST = '127.0.0.1'  # The server's hostname or IP address
SERVER_PORT = 65432        # The port used by the server
CLIENT_SOURCE_PORT = 0     # 0 means OS picks an ephemeral port.
                           # For consistent testing, you can set a specific source port:
                           # CLIENT_SOURCE_PORT = 54321 (make sure it's not in use)

print(f"Attempting to connect to server {SERVER_HOST}:{SERVER_PORT}")
if CLIENT_SOURCE_PORT != 0:
    print(f"Using client source port: {CLIENT_SOURCE_PORT}")

try:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        if CLIENT_SOURCE_PORT != 0:
            try:
                s.bind(('', CLIENT_SOURCE_PORT)) # Bind to a specific source port
            except OSError as e:
                print(f"Error binding to source port {CLIENT_SOURCE_PORT}: {e}")
                print("This might be because the port is in TIME_WAIT from a previous run.")
                print("Try a different port or wait a couple of minutes.")
                sys.exit(1)

        s.connect((SERVER_HOST, SERVER_PORT))
        client_ip, client_port = s.getsockname()
        print(f"Connected from {client_ip}:{client_port} to {SERVER_HOST}:{SERVER_PORT}")

        try:
            for i in range(5): # Send a few messages
                message = f"Hello from client, message {i+1}"
                print(f"Client sending: {message!r}")
                s.sendall(message.encode())
                data = s.recv(1024)
                if not data:
                    print("Server closed connection or connection lost.")
                    break
                print(f"Client received: {data.decode()!r}")
                time.sleep(1)
            
            # After sending messages, or if server dies, the client will eventually try to close.
            # If the server has already vanished without sending a FIN, the client's close()
            # will initiate the active close, leading to TIME_WAIT on the client side.

        except ConnectionRefusedError:
            print("Connection refused. Is the server running?")
        except ConnectionResetError:
            print("Connection reset by server (server might have crashed or closed abruptly).")
        except BrokenPipeError:
            print("Broken pipe (server likely closed connection abruptly).")
        except Exception as e:
            print(f"An error occurred during communication: {e}")
        finally:
            print("Client is now closing its socket.")
            # s.close() # The 'with' statement handles this automatically upon exiting the block.
            # When s.close() is called (explicitly or by 'with'), if this is the active closer,
            # the socket will transition to TIME_WAIT.

            # To keep the script alive to observe TIME_WAIT, add a sleep here
            # This is *after* the socket is closed. TIME_WAIT is a kernel state.
            if CLIENT_SOURCE_PORT != 0: # Only relevant if we bound to a specific port
                print(f"Client socket (port {client_port}) closed. Check netstat for TIME_WAIT on this port.")
                print("Script will sleep for 120 seconds to allow observation...")
                time.sleep(120) 
            else:
                print("Client socket closed (ephemeral port).")


except Exception as e:
    print(f"Client could not connect or run: {e}")

print("Client finished.")