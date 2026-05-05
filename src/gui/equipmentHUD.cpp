#include "gui/equipmentHUD.h"

#include "gui/drawItemStack.h"
#include "inventory.h"
#include "itemdef.h"
#include "itemgroup.h"
#include "client/localplayer.h"
#include "tool.h"
#include "util/string.h"
#include <algorithm>
#include <cmath>
#include <vector>

namespace {
static core::rect<s32> normalizeRect(const core::rect<s32> &rect)
{
	const s32 left = std::min(rect.UpperLeftCorner.X, rect.LowerRightCorner.X);
	const s32 top = std::min(rect.UpperLeftCorner.Y, rect.LowerRightCorner.Y);
	const s32 right = std::max(rect.UpperLeftCorner.X, rect.LowerRightCorner.X);
	const s32 bottom = std::max(rect.UpperLeftCorner.Y, rect.LowerRightCorner.Y);
	return core::rect<s32>(left, top, right, bottom);
}

static std::wstring toWString(const std::string &str)
{
	return utf8_to_wide(str);
}

static std::string getDisplayName(const ItemStack &item, Client *client)
{
	if (!client)
		return item.name;

	if (item.name.find("mcl_meshhand") != std::string::npos ||
			item.name.find("filled_map_hand") != std::string::npos) {
		return "Hand";
	}

	std::string desc = item.getShortDescription(client->idef());
	if (!desc.empty())
		return desc;

	desc = item.getDescription(client->idef());
	if (!desc.empty())
		return desc;

	const ItemDefinition &def = item.getDefinition(client->idef());
	if (!def.short_description.empty())
		return def.short_description;
	if (!def.description.empty())
		return def.description;

	return item.name;
}

static std::string getDurabilityMode()
{
	return g_settings->get("equipment_hud.durability_mode");
}
} // namespace

EquipmentHUD::EquipmentHUD(Client *client, const core::rect<s32> &rect) :
	CheatUIElement(rect), m_client(client)
{
}

int EquipmentHUD::getDurabilityUses(const ItemStack &item, Client *client)
{
	if (!client || item.empty())
		return 0;

	const ItemDefinition &def = item.getDefinition(client->idef());
	const int armor_uses = itemgroup_get(def.groups, "mcl_armor_uses");
	if (armor_uses > 0)
		return armor_uses;

	if (def.type == ITEM_TOOL) {
		const ToolCapabilities &caps = item.getToolCapabilities(client->idef());
		for (const auto &groupcap : caps.groupcaps) {
			if (groupcap.second.uses > 0)
				return groupcap.second.uses;
		}
		if (caps.punch_attack_uses > 0)
			return caps.punch_attack_uses;
	}

	return 0;
}

int EquipmentHUD::getRemainingDurability(const ItemStack &item, int max_uses)
{
	if (max_uses <= 0)
		return 0;

	const float remaining = (65535.0f - static_cast<float>(item.wear)) *
		static_cast<float>(max_uses) / 65535.0f;
	return std::max(0, static_cast<int>(std::floor(remaining + 0.5f)));
}

std::wstring EquipmentHUD::getItemLabel(const ItemStack &item, Client *client)
{
	const std::string display_name = getDisplayName(item, client);
	std::wstring label = toWString(display_name.empty() ? item.name : display_name);

	const int max_uses = getDurabilityUses(item, client);
	if (max_uses > 0) {
		const int remaining = getRemainingDurability(item, max_uses);
		const float percent = max_uses > 0 ? (static_cast<float>(remaining) / max_uses) * 100.f : 0.f;
		const std::string mode = getDurabilityMode();
		if (mode == "Percent") {
			label += L" (" + toWString(itos(static_cast<int>(std::floor(percent + 0.5f)))) + L"%)";
		} else if (mode == "Dur/Max") {
			label += L" (" + toWString(itos(remaining)) + L"/" + toWString(itos(max_uses)) + L")";
		} else {
			label += L" (" + toWString(itos(remaining)) + L"/" + toWString(itos(max_uses)) +
				L", " + toWString(itos(static_cast<int>(std::floor(percent + 0.5f)))) + L"%)";
		}
	}

	return label;
}

void EquipmentHUD::drawEntry(video::IVideoDriver *driver, gui::IGUIFont *font,
	Client *client, const ItemStack &item, const std::wstring &fallback_label,
	const core::rect<s32> &entry_rect, bool editing)
{
	if (!font)
		return;

	const video::SColor outline_color(255, 0, 0, 0);
	const video::SColor background_color(200, 25, 25, 25);
	const video::SColor text_color(255, 255, 255, 255);

	const bool draw_background = editing || g_settings->getBool("equipment_hud.background");
	if ((draw_background && (editing || !item.empty()))) {
		driver->draw2DRectangle(background_color, entry_rect);
		driver->draw2DRectangleOutline(entry_rect, outline_color, 2);
	}

	if (!editing && item.empty())
		return;

	const s32 icon_size = std::max<s32>(16, std::min<s32>(entry_rect.getHeight() - 8, 28));
	const s32 icon_x = entry_rect.UpperLeftCorner.X + 4;
	const s32 icon_y = entry_rect.UpperLeftCorner.Y + (entry_rect.getHeight() - icon_size) / 2;
	const core::rect<s32> icon_rect(icon_x, icon_y, icon_x + icon_size, icon_y + icon_size);

	if (!item.empty())
		drawItemStack(driver, font, item, icon_rect, nullptr, client, IT_ROT_NONE);

	std::wstring label = item.empty() ? fallback_label : getItemLabel(item, client);
	if (label.empty())
		return;

	core::dimension2d<u32> text_size_u32 = font->getDimension(label.c_str());
	core::dimension2d<s32> text_size(text_size_u32.Width, text_size_u32.Height);

	const s32 text_x = icon_rect.LowerRightCorner.X + 6;
	const s32 text_y = entry_rect.UpperLeftCorner.Y + (entry_rect.getHeight() - text_size.Height) / 2;
	font->draw(label.c_str(), core::rect<s32>(text_x, text_y, text_x + text_size.Width, text_y + text_size.Height), text_color, false, false);
}

void EquipmentHUD::draw(video::IVideoDriver *driver, gui::IGUIFont *font, float dtime,
	ClientEnvironment &env, bool editing)
{
	(void)dtime;
	if (!hudShouldRender(editing))
		return;

	const bool enabled = g_settings->getBool("equipment_hud");
	if (!enabled && !editing)
		return;

	LocalPlayer *player = env.getLocalPlayer();
	if (!player)
		return;

	InventoryList *armor = player->inventory.getList("armor");
	ItemStack wielded;
	ItemStack hand;
	ItemStack &effective = player->getWieldedItem(&wielded, &hand);

	std::vector<std::pair<ItemStack, std::wstring>> entries;
	entries.emplace_back(effective, L"Held item");

	if (armor) {
		const std::pair<u32, std::wstring> armor_slots[] = {
			// Mineclonia keeps the quick-equip slot at index 0; worn armor starts at 1.
			{1, L"Helmet"},
			{2, L"Chestplate"},
			{3, L"Leggings"},
			{4, L"Boots"},
		};

		for (const auto &slot : armor_slots) {
			if (slot.first < armor->getSize())
				entries.emplace_back(armor->getItem(slot.first), slot.second);
		}
	}

	core::rect<s32> draw_bounds = normalizeRect(bounds);
	if (draw_bounds.getWidth() <= 0 || draw_bounds.getHeight() <= 0) {
		draw_bounds = core::rect<s32>(10, 10, 260, 190);
	}

	const video::SColor outline_color(255, 0, 0, 0);
	const video::SColor background_color(180, 25, 25, 25);
	const bool draw_background = editing || g_settings->getBool("equipment_hud.background");
	if (draw_background) {
		driver->draw2DRectangle(background_color, draw_bounds);
		driver->draw2DRectangleOutline(draw_bounds, outline_color, 2);
	}

	const s32 row_height = std::max<s32>(32, font ? static_cast<s32>(font->getDimension(L"M").Height) + 12 : 32);
	const s32 start_y = draw_bounds.UpperLeftCorner.Y + 6;
	const s32 row_width = std::max<s32>(0, draw_bounds.getWidth() - 12);
	for (size_t i = 0; i < entries.size(); ++i) {
		const ItemStack &item = entries[i].first;
		const std::wstring &fallback_label = entries[i].second;
		const s32 top = start_y + static_cast<s32>(i) * row_height;
		const core::rect<s32> row(
			draw_bounds.UpperLeftCorner.X + 6,
			top,
			draw_bounds.UpperLeftCorner.X + 6 + row_width,
			top + row_height
		);
		drawEntry(driver, font, m_client, item, fallback_label, row, editing);
	}
}
