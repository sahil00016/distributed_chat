import socket
import threading
import json
import os
from datetime import datetime
from config import HOST, PORT, MAX_CLIENTS, BUFFER_SIZE, FILE_BUFFER_SIZE, ENCODING

class ChatServer:
    def __init__(self):
        self.server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.server_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.clients = {}  # {socket: {'username': str, 'address': tuple}}
        self.clients_lock = threading.Lock()
        
    def start(self):
        """Start the chat server"""
        try:
            self.server_socket.bind((HOST, PORT))
            self.server_socket.listen(MAX_CLIENTS)
            print(f"[SERVER STARTED] Listening on {HOST}:{PORT}")
            print(f"[INFO] Max clients: {MAX_CLIENTS}")
            print("=" * 50)
            
            while True:
                client_socket, address = self.server_socket.accept()
                print(f"[NEW CONNECTION] {address} connected")
                
                # Handle client in a new thread
                client_thread = threading.Thread(
                    target=self.handle_client,
                    args=(client_socket, address)
                )
                client_thread.daemon = True
                client_thread.start()
                
        except KeyboardInterrupt:
            print("\n[SHUTDOWN] Server shutting down...")
            self.shutdown()
        except Exception as e:
            print(f"[ERROR] Server error: {e}")
            self.shutdown()
    
    def handle_client(self, client_socket, address):
        """Handle individual client connection"""
        username = None
        
        try:
            while True:
                # Receive message from client
                data = client_socket.recv(BUFFER_SIZE).decode(ENCODING)
                
                if not data:
                    break
                
                # Parse JSON message
                try:
                    message = json.loads(data)
                    msg_type = message.get('type')
                    
                    if msg_type == 'connect':
                        username = message.get('username')
                        self.handle_connect(client_socket, address, username)
                        
                    elif msg_type == 'message':
                        self.handle_message(client_socket, message)
                        
                    elif msg_type == 'file_request':
                        self.handle_file_request(client_socket, message)
                        
                    elif msg_type == 'disconnect':
                        break
                        
                except json.JSONDecodeError:
                    print(f"[ERROR] Invalid JSON from {address}")
                    
        except ConnectionResetError:
            print(f"[CONNECTION RESET] {address}")
        except Exception as e:
            print(f"[ERROR] Error handling client {address}: {e}")
        finally:
            self.disconnect_client(client_socket, username)
    
    def handle_connect(self, client_socket, address, username):
        """Handle new client connection"""
        with self.clients_lock:
            self.clients[client_socket] = {
                'username': username,
                'address': address
            }
        
        print(f"[USER JOINED] {username} from {address}")
        
        # Send success response
        response = {
            'type': 'connect_success',
            'message': f'Welcome {username}!',
            'timestamp': datetime.now().isoformat()
        }
        self.send_message(client_socket, response)
        
        # Broadcast user list to all clients
        self.broadcast_user_list()
        
        # Notify all clients about new user
        notification = {
            'type': 'user_joined',
            'username': username,
            'message': f'{username} joined the chat',
            'timestamp': datetime.now().isoformat()
        }
        self.broadcast(notification, exclude=client_socket)
    
    def handle_message(self, sender_socket, message):
        """Handle chat message from client"""
        with self.clients_lock:
            sender_info = self.clients.get(sender_socket)
        
        if not sender_info:
            return
        
        username = sender_info['username']
        content = message.get('content', '')
        
        print(f"[MESSAGE] {username}: {content}")
        
        # Broadcast message to all clients
        broadcast_msg = {
            'type': 'message',
            'username': username,
            'content': content,
            'timestamp': datetime.now().isoformat()
        }
        self.broadcast(broadcast_msg)
    
    def handle_file_request(self, sender_socket, message):
        """Handle file transfer request"""
        with self.clients_lock:
            sender_info = self.clients.get(sender_socket)
        
        if not sender_info:
            return
        
        username = sender_info['username']
        filename = message.get('filename', 'unknown')
        filesize = message.get('filesize', 0)
        
        print(f"[FILE TRANSFER] {username} is sending {filename} ({filesize} bytes)")
        
        # Notify all clients about file transfer
        notification = {
            'type': 'file_notification',
            'username': username,
            'filename': filename,
            'filesize': filesize,
            'timestamp': datetime.now().isoformat()
        }
        self.broadcast(notification)
        
        # Handle file data transfer
        self.receive_and_broadcast_file(sender_socket, filename, filesize)
    
    def receive_and_broadcast_file(self, sender_socket, filename, filesize):
        """Receive file from sender and broadcast to all clients"""
        try:
            # Receive file data
            file_data = b''
            remaining = filesize
            
            while remaining > 0:
                chunk_size = min(FILE_BUFFER_SIZE, remaining)
                chunk = sender_socket.recv(chunk_size)
                
                if not chunk:
                    break
                
                file_data += chunk
                remaining -= len(chunk)
            
            print(f"[FILE RECEIVED] {filename} ({len(file_data)} bytes)")
            
            # Broadcast file data to all other clients
            file_message = {
                'type': 'file_data',
                'filename': filename,
                'filesize': len(file_data),
                'timestamp': datetime.now().isoformat()
            }
            
            with self.clients_lock:
                for client_socket in self.clients:
                    if client_socket != sender_socket:
                        try:
                            # Send metadata
                            self.send_message(client_socket, file_message)
                            # Send file data
                            client_socket.sendall(file_data)
                        except Exception as e:
                            print(f"[ERROR] Failed to send file to client: {e}")
            
            print(f"[FILE BROADCAST] {filename} sent to all clients")
            
        except Exception as e:
            print(f"[ERROR] File transfer error: {e}")
    
    def broadcast_user_list(self):
        """Send updated user list to all clients"""
        with self.clients_lock:
            user_list = [info['username'] for info in self.clients.values()]
        
        message = {
            'type': 'user_list',
            'users': user_list,
            'timestamp': datetime.now().isoformat()
        }
        self.broadcast(message)
    
    def broadcast(self, message, exclude=None):
        """Broadcast message to all connected clients"""
        disconnected = []
        
        with self.clients_lock:
            for client_socket in self.clients:
                if client_socket == exclude:
                    continue
                
                try:
                    self.send_message(client_socket, message)
                except Exception as e:
                    print(f"[ERROR] Failed to send to client: {e}")
                    disconnected.append(client_socket)
        
        # Remove disconnected clients
        for client_socket in disconnected:
            self.disconnect_client(client_socket, None)
    
    def send_message(self, client_socket, message):
        """Send JSON message to client"""
        try:
            json_data = json.dumps(message)
            client_socket.send(json_data.encode(ENCODING))
        except Exception as e:
            raise e
    
    def disconnect_client(self, client_socket, username=None):
        """Disconnect client and clean up"""
        with self.clients_lock:
            if client_socket in self.clients:
                client_info = self.clients[client_socket]
                username = client_info['username']
                del self.clients[client_socket]
        
        if username:
            print(f"[USER LEFT] {username} disconnected")
            
            # Notify all clients
            notification = {
                'type': 'user_left',
                'username': username,
                'message': f'{username} left the chat',
                'timestamp': datetime.now().isoformat()
            }
            self.broadcast(notification)
            
            # Update user list
            self.broadcast_user_list()
        
        try:
            client_socket.close()
        except:
            pass
    
    def shutdown(self):
        """Shutdown server gracefully"""
        print("[SHUTDOWN] Closing all connections...")
        
        with self.clients_lock:
            for client_socket in list(self.clients.keys()):
                try:
                    shutdown_msg = {
                        'type': 'server_shutdown',
                        'message': 'Server is shutting down'
                    }
                    self.send_message(client_socket, shutdown_msg)
                    client_socket.close()
                except:
                    pass
            self.clients.clear()
        
        self.server_socket.close()
        print("[SHUTDOWN] Server stopped")

if __name__ == '__main__':
    server = ChatServer()
    server.start()

