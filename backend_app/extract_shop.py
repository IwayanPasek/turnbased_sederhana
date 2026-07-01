with open('main.py', 'r', encoding='utf-8') as f:
    lines = f.readlines()

shop_lines = []
in_shop = False
for line in lines:
    if line.startswith('@app.get("/shop/items")') or 'def get_shop_items(' in line:
        in_shop = True
    if in_shop:
        shop_lines.append(line)

with open('app/routers/shop.py', 'w', encoding='utf-8') as f:
    f.write('from typing import Optional\n')
    f.write('from fastapi import APIRouter, Header, HTTPException\n')
    f.write('from app.core.database import get_db_connection\n')
    f.write('from app.core.security import verify_token\n')
    f.write('from app.models.schemas import BuyRequest, EquipRequest\n')
    f.write('router = APIRouter()\n\n')
    content = ''.join(shop_lines)
    content = content.replace('@app.', '@router.')
    f.write(content)
print('Extracted shop routes to app/routers/shop.py')
