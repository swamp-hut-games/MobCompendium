local _, NS = ...

NS.DB_VERSION = 2

-- Rank Configuration
NS.RANK_CONFIG = {
    boss = {
        text = "Boss",
        icon = "Interface\\Icons\\inv_misc_bone_humanskull_02",
        coords = { 0, 1, 0, 1 },
        color = { 1, 1, 1 }
    },
    rareelite = {
        text = "Rare Elite",
        icon = "Interface\\Icons\\inv_misc_head_dragon_black",
        coords = { 0, 1, 0, 1 },
        color = { 1, 1, 1 }
    },
    elite = {
        text = "Elite",
        icon = "Interface\\Icons\\inv_misc_head_dragon_bronze",
        coords = { 0, 1, 0, 1 },
        color = { 1, 1, 1 }
    },
    rare = {
        text = "Rare",
        icon = "Interface\\Icons\\inv_misc_head_dragon_blue",
        coords = { 0, 1, 0, 1 },
        color = { 1, 1, 1 }
    },
    minion = {
        text = "Minion",
        icon = "Interface\\Icons\\inv_babyfaeriedragon",
        coords = { 0, 1, 0, 1 },
        color = { 1, 1, 1 }
    },
    wildpet = {
        text = "Wild Pet",
        icon = "Interface\\Icons\\inv_box_petcarrier_01",
        coords = { 0, 1, 0, 1 },
        color = { 1, 1, 1 }
    },
    critter = {
        text = "Critter",
        icon = "Interface\\Icons\\INV_Misc_Rabbit_2",
        coords = { 0, 1, 0, 1 },
        color = { 1, 1, 1 }
    },
    normal = {
        text = "Normal",
        icon = "Interface\\Icons\\Achievement_character_human_male",
        coords = { 0, 1, 0, 1 },
        color = { 1, 1, 1 }
    },
    unknown = {
        text = "Unknown",
        icon = "Interface\\Icons\\INV_Misc_QuestionMark",
        coords = { 0, 1, 0, 1 },
        color = { 0.7, 0.7, 0.7 }
    }
}

-- Zone Icon Configuration
NS.ZONE_ICONS = {
    raid = {
        icon = "Interface\\Minimap\\Raid_Icon",
        color = { 1, 1, 1 },
        size = 40
    },
    party = {
        icon = "Interface\\Minimap\\Dungeon_Icon",
        color = { 1, 1, 1 },
        size = 40
    },
    scenario = {
        icon = "Interface\\Icons\\Icon_Scenarios",
        color = { 1, 1, 1 }
    },
    pvp = {
        icon = "Interface\\Icons\\Faction_Alliance_Vanguard",
        color = { 1, 0, 0 }
    },
    none = {
        icon = "Interface\\Icons\\INV_Misc_Map02",
        color = { 1, 1, 1 }
    }
}