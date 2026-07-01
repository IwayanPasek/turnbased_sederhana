from pydantic import BaseModel
from typing import Optional


class UserAuth(BaseModel):
    username: str
    password: str


class PracticeSimRequest(BaseModel):
    player1: str
    player2: str
    action: str
    player1_state: Optional[dict] = None
    player2_state: Optional[dict] = None


class BuyItemRequest(BaseModel):
    shop_item_id: int


class UpgradeItemRequest(BaseModel):
    inventory_item_id: int


class EquipItemRequest(BaseModel):
    inventory_item_id: int
