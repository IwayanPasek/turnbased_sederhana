import json
from typing import Dict, List
from fastapi import WebSocket
from app.game.engine import GameRoom


class ArenaManager:
    def __init__(self):
        self.waiting_players: List[dict] = []
        self.active_rooms: Dict[str, GameRoom] = {}

    async def connect_and_match(self, websocket: WebSocket, username: str):
        await websocket.accept()

        # Cek apakah player sedang berada di dalam match aktif (reconnect)
        for room_id, room in self.active_rooms.items():
            if username in room.players:
                # Update WS ke koneksi baru
                room.players[username]["ws"] = websocket
                await room.broadcast_state(f"{username} terhubung kembali.")
                return

        # Cek apakah player sudah ada di waiting list
        for p in self.waiting_players:
            if p["username"] == username:
                # Ganti ws lama dengan yang baru
                p["ws"] = websocket
                await websocket.send_json(
                    {"type": "waiting", "message": "Menunggu lawan..."}
                )
                return

        self.waiting_players.append({"username": username, "ws": websocket})

        if len(self.waiting_players) >= 2:
            p1 = self.waiting_players.pop(0)
            p2 = self.waiting_players.pop(0)
            room_id = f"room_{p1['username']}_{p2['username']}"

            room = GameRoom(
                player1=p1["username"],
                player1_ws=p1["ws"],
                player2=p2["username"],
                player2_ws=p2["ws"],
            )
            self.active_rooms[room_id] = room

            print(
                f"ArenaManager: {p1['username']} vs {p2['username']} mulai di {room_id}"
            )

            await room.broadcast_state(
                message=f"BATTLE START! {p1['username']} vs {p2['username']}",
                extra={"event": "battle_started", "room_id": room_id},
            )
        else:
            await websocket.send_json(
                {"type": "waiting", "message": "Menunggu lawan..."}
            )

    async def disconnect(self, websocket: WebSocket):
        self.waiting_players = [p for p in self.waiting_players if p["ws"] != websocket]

        rooms_to_delete = []
        for room_id, room in self.active_rooms.items():
            player_left = None
            if room.players[room.player_names[0]]["ws"] == websocket:
                player_left = room.player_names[0]
            elif room.players[room.player_names[1]]["ws"] == websocket:
                player_left = room.player_names[1]

            if player_left:
                room.is_active = False
                winner_name = (
                    room.player_names[1]
                    if player_left == room.player_names[0]
                    else room.player_names[0]
                )
                try:
                    await room.broadcast_state(
                        f"🚨 {player_left} terputus. {winner_name} menang!"
                    )
                except Exception:
                    pass
                # BUG-10 fix: finalize battle stats on disconnect
                try:
                    await room._finalize_battle(winner_name, player_left)
                except Exception as e:
                    print(f"Gagal finalize battle saat disconnect: {e}")
                rooms_to_delete.append(room_id)

        for rid in rooms_to_delete:
            del self.active_rooms[rid]

    async def handle_action(self, websocket: WebSocket, action_data: str):
        try:
            data = json.loads(action_data)
            action = data.get("action")
            if not action:
                return

            for room in self.active_rooms.values():
                for player_name, pdata in room.players.items():
                    if pdata["ws"] == websocket:
                        if room.is_active:
                            if action == "surrender" or action.startswith("emote:"):
                                await room.process_action(player_name, action)
                            elif room.turn == player_name:
                                await room.process_action(player_name, action)
                        return
        except json.JSONDecodeError:
            pass
