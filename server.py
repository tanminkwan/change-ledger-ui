#server.py
import asyncio
import websockets
import logging

# 로깅 설정
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler("server.log"),
        logging.StreamHandler()
    ]
)

connected_clients = set()

async def handle_client(websocket, path):
    # 새로운 클라이언트 연결 로그
    client_address = websocket.remote_address
    logging.info(f"Client connected: {client_address}")
    connected_clients.add(websocket)
    
    try:
        # 클라이언트로부터 메시지를 수신하고 다른 클라이언트에게 전달
        async for message in websocket:
            logging.info(f"Received message from {client_address}: {message}")
            
            # 다른 클라이언트에게 메시지 전달
            await asyncio.wait(
                [asyncio.create_task(client.send(message)) for client in connected_clients if client != websocket]
            )
    except websockets.exceptions.ConnectionClosed as e:
        logging.info(f"Client disconnected: {client_address}")
        logging.debug(f"Disconnect reason: {e}")
    finally:
        # 연결 해제 시 클라이언트 목록에서 제거
        connected_clients.remove(websocket)
        logging.info(f"Client removed from active connections: {client_address}")

async def start_server():
    server = await websockets.serve(handle_client, "localhost", 3000)
    logging.info("WebSocket server is running on ws://localhost:3000")
    await server.wait_closed()

# 서버 실행
asyncio.run(start_server())
