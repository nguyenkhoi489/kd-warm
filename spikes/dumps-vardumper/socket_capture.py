import socket
import struct
import os
import sys

HOST = '127.0.0.1'
PORT = 9912
OUTPUT_DIR = os.path.dirname(os.path.abspath(__file__))

def receive_all(conn, n):
    data = b''
    while len(data) < n:
        chunk = conn.recv(n - len(data))
        if not chunk:
            break
        data += chunk
    return data

def main():
    messages = []
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as srv:
        srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        srv.bind((HOST, PORT))
        srv.listen(5)
        srv.settimeout(5.0)
        print(f"Listening on {HOST}:{PORT}", flush=True)

        try:
            while True:
                try:
                    conn, addr = srv.accept()
                except socket.timeout:
                    if messages:
                        break
                    continue

                with conn:
                    print(f"Connection from {addr}", flush=True)
                    conn.settimeout(3.0)
                    try:
                        while True:
                            header = receive_all(conn, 4)
                            if len(header) < 4:
                                break
                            length = struct.unpack('>I', header)[0]
                            payload = receive_all(conn, length)
                            if len(payload) < length:
                                break
                            messages.append(payload)
                            print(f"  Received message: {length} bytes", flush=True)
                    except socket.timeout:
                        pass
        except KeyboardInterrupt:
            pass

    raw_path = os.path.join(OUTPUT_DIR, 'captured_payloads.bin')
    with open(raw_path, 'wb') as f:
        for i, msg in enumerate(messages):
            f.write(struct.pack('>I', len(msg)))
            f.write(msg)

    print(f"\nCaptured {len(messages)} messages → {raw_path}", flush=True)

    analysis_path = os.path.join(OUTPUT_DIR, 'payload_analysis.txt')
    with open(analysis_path, 'w') as f:
        for i, msg in enumerate(messages):
            f.write(f"=== Message {i+1} ({len(msg)} bytes) ===\n")
            f.write(f"Raw hex (first 256 bytes):\n{msg[:256].hex()}\n\n")
            try:
                decoded = msg.decode('utf-8', errors='replace')
                f.write(f"UTF-8 text (first 512 chars):\n{decoded[:512]}\n\n")
            except Exception as e:
                f.write(f"Decode error: {e}\n\n")

    print(f"Analysis → {analysis_path}", flush=True)

if __name__ == '__main__':
    main()
