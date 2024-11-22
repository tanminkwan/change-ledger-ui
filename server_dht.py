# server.py
import asyncio
from kademlia.network import Server
import logging

# 로깅 설정
logging.basicConfig(level=logging.INFO)

async def run():
    server = Server()
    await server.listen(8468)  # Kademlia 노드의 포트 번호

    # 부트스트랩 노드에 연결 (없을 경우 자신의 IP를 사용)
    bootstrap_node = ("127.0.0.1", 8468)
    await server.bootstrap([bootstrap_node])

    # 예시로 데이터를 저장하고 검색
    await server.set("key", "value")
    result = await server.get("key")
    print("Result:", result)

if __name__ == "__main__":
    loop = asyncio.get_event_loop()
    loop.run_until_complete(run())
