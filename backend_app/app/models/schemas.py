from pydantic import BaseModel, Field
from typing import Optional


class UserAuth(BaseModel):
    username: str = Field(..., min_length=3, max_length=20, pattern=r"^[a-zA-Z0-9_]+$")
    password: str = Field(..., min_length=6)


class PracticeSimRequest(BaseModel):
    player1: str = Field(..., min_length=1)
    player2: str = Field(..., min_length=1)
    action: str = Field(..., min_length=1)
    player1_state: Optional[dict] = None
    player2_state: Optional[dict] = None


class BuyItemRequest(BaseModel):
    shop_item_id: int = Field(..., gt=0)


class UpgradeItemRequest(BaseModel):
    inventory_item_id: int = Field(..., gt=0)


class EquipItemRequest(BaseModel):
    inventory_item_id: int = Field(..., gt=0)

class AllocateAttributeRequest(BaseModel):
    stat_name: str = Field(..., pattern=r"^(strength|agility|intelligence)$")
    points: int = Field(1, gt=0, le=100)

class GachaRequest(BaseModel):
    chest_type: str = Field(..., pattern=r"^(bronze|silver|gold)$")

class CreateGuildRequest(BaseModel):
    name: str = Field(..., min_length=3, max_length=30)
    description: str = Field(..., max_length=200)

class GuildChatRequest(BaseModel):
    message: str = Field(..., min_length=1, max_length=500)

class GuildMemberActionRequest(BaseModel):
    target_username: str = Field(..., min_length=3, max_length=20)

class UpdateAvatarRequest(BaseModel):
    avatar_style: str = Field(..., max_length=50)

class SetTitleRequest(BaseModel):
    title: Optional[str] = Field(None, max_length=50)

from datetime import datetime
from typing import List, Dict

class ShopItemResponse(BaseModel):
    id: int
    name: str
    item_type: str
    description: Optional[str] = None
    base_stat: int
    stat_type: str
    base_cost_coins: int
    base_cost_gems: int
    rarity: str
    is_upgradeable: bool
    max_level: int
    icon_url: Optional[str] = None
    granted_skill: Optional[str] = None
    is_active: bool

class ShopItemsListResponse(BaseModel):
    items: List[ShopItemResponse]

class UpgradeCostResponse(BaseModel):
    from_level: int
    to_level: int
    level: int
    cost_coins: int
    cost_gems: int
    stat_bonus_per_level: float

class ShopItemDetailsResponse(BaseModel):
    item: ShopItemResponse
    upgrade_costs: List[UpgradeCostResponse]

class InventoryItemResponse(BaseModel):
    id: int
    inventory_id: int
    shop_item_id: int
    current_level: int
    quantity: int
    is_equipped: bool
    equipped_slot: Optional[str] = None
    acquired_at: datetime
    last_upgraded_at: Optional[datetime] = None
    si_item_id: int
    name: str
    description: Optional[str] = None
    item_type: str
    rarity: str
    base_stat: int
    max_level: int
    base_cost_coins: int
    base_cost_gems: int
    stat_type: str
    granted_skill: Optional[str] = None

class PlayerInventoryResponse(BaseModel):
    inventory: List[InventoryItemResponse]
    player_id: int

class EquippedItemResponse(BaseModel):
    inventory_id: int
    current_level: int
    equipped_slot: Optional[str] = None
    item_id: int
    name: str
    base_stat: int
    stat_type: str
    item_type: str

class PlayerStatsResponse(BaseModel):
    player_id: int
    username: str
    coins: int
    gems: int
    active_title: Optional[str] = None
    mmr: int
    tier: str
    wins: int
    losses: int
    matches_played: int
    equipped: Dict[str, EquippedItemResponse]
    has_unclaimed_rewards: bool
    is_admin: bool
    gacha_pity_counter: int = 0
    level: int = 1
    exp: int = 0
    announcement: Optional[str] = None

class PlayerAttributesResponse(BaseModel):
    strength: int
    agility: int
    intelligence: int
    available_points: int

class MatchHistoryItemResponse(BaseModel):
    battle_id: int
    opponent: str
    is_winner: bool
    winner: str
    total_rounds: int
    battle_type: str
    ended_at: Optional[datetime] = None

class PlayerMatchHistoryResponse(BaseModel):
    history: List[MatchHistoryItemResponse]

class EquippedItemProfileResponse(BaseModel):
    inventory_id: int
    item_name: str
    base_stat_boost: int
    stat_type: str
    current_level: int

class PlayerProfileResponse(BaseModel):
    player_id: int
    username: str
    coins: int
    gems: int
    mmr: int
    wins: int
    losses: int
    matches_played: int
    equipped: List[EquippedItemProfileResponse]
    guild_name: Optional[str] = None
    guild_level: int
    guild_role: Optional[str] = None
    avatar_style: str
    is_admin: bool

from pydantic import Field

class GiveCurrencyRequest(BaseModel):
    coins: int = Field(0, ge=0)
    gems: int = Field(0, ge=0)

class GiveItemRequest(BaseModel):
    item_id: int
    level: int = 1
    amount: int = 1

class BroadcastRequest(BaseModel):
    message: str

class AdminUserResponse(BaseModel):
    id: int
    username: str
    coins: int
    gems: int
    is_banned: bool
    is_admin: bool
    mmr_score: Optional[int] = None
    matches_played: Optional[int] = None

class AdminUsersListResponse(BaseModel):
    users: List[AdminUserResponse]

class AdminActionResponse(BaseModel):
    success: bool
    message: str

# Daily Quests
class DailyQuestResponse(BaseModel):
    id: int
    quest_id: int
    type: str
    name: str
    description: str
    target_value: int
    reward_type: str
    reward_amount: int
    current_progress: int
    is_completed: bool
    is_claimed: bool

class DailyQuestsListResponse(BaseModel):
    quests: List[DailyQuestResponse]

class DailyQuestClaimResponse(BaseModel):
    success: bool
    message: str
    reward_type: str
    reward_amount: int

# Achievements
class AchievementResponse(BaseModel):
    id: int
    type: str
    name: str
    description: str
    target_value: int
    reward_type: str
    reward_amount: int
    reward_title: Optional[str] = None
    current_progress: int
    is_completed: bool
    is_claimed: bool

class AchievementsListResponse(BaseModel):
    achievements: List[AchievementResponse]

class AchievementClaimResponse(BaseModel):
    success: bool
    message: str
    reward_type: str
    reward_amount: int
    reward_title: Optional[str] = None

# Leaderboard
class LeaderboardEntry(BaseModel):
    rank: int
    player_id: int
    username: str
    mmr_score: int
    tier: str
    wins: int
    losses: int
    matches_played: int

class LeaderboardResponse(BaseModel):
    success: bool
    leaderboard: List[LeaderboardEntry]

# Guilds
class GuildListEntry(BaseModel):
    id: int
    name: str
    description: str
    level: int
    member_count: int

class GuildsListResponse(BaseModel):
    success: bool
    guilds: List[GuildListEntry]

class GuildMemberResponse(BaseModel):
    player_id: int
    username: str
    role: str
    mmr_score: int

class GuildChatResponse(BaseModel):
    id: int
    username: str
    message: str
    sent_at: datetime

class GuildDetailsResponse(BaseModel):
    id: int
    name: str
    description: str
    level: int
    exp: int
    leader_id: int

class MyGuildInfoResponse(BaseModel):
    success: bool
    has_guild: bool
    guild: Optional[GuildDetailsResponse] = None
    my_role: Optional[str] = None
    members: Optional[List[GuildMemberResponse]] = None
    chats: Optional[List[GuildChatResponse]] = None

class GenericGuildActionResponse(BaseModel):
    success: bool
    message: str
    guild_id: Optional[int] = None

# Auth Responses
class RegisterResponse(BaseModel):
    message: str

class LoginResponse(BaseModel):
    access_token: str
    token_type: str
    is_admin: bool

# Arena Responses
class SkillInfo(BaseModel):
    id: str
    name: str
    description: str
    cooldown: int
    rage_required: int
    is_ultimate: bool
    is_defensive: bool
    is_heal: bool
    apply_status: Optional[str] = None

class SkillsListResponse(BaseModel):
    skills: List[SkillInfo]

class StatusEffectState(BaseModel):
    name: str
    turns_left: int
    value: int = 0

class PracticePlayerState(BaseModel):
    name: str
    hp: int
    max_hp: int
    rage: int
    max_rage: int
    status_effects: List[StatusEffectState]
    cooldowns: Dict[str, int]
    streak: int
    momentum_stacks: int

class PracticeSimResponse(BaseModel):
    messages: List[str]
    animation_events: List[dict] = []
    player1: PracticePlayerState
    player2: PracticePlayerState

class AdminResetPasswordRequest(BaseModel):
    new_password: str = Field(..., min_length=4)

class AdminStatsResponse(BaseModel):
    total_players: int
    total_banned: int
    total_admins: int
    total_coins: int
    total_gems: int







