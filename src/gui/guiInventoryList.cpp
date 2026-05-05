// Luanti
// SPDX-License-Identifier: LGPL-2.1-or-later
// Copyright (C) 2013 celeron55, Perttu Ahola <celeron55@gmail.com>

#include "guiInventoryList.h"
#include "guiFormSpecMenu.h"
#include "drawItemStack.h"
#include "client/client.h"
#include "client/localplayer.h"
#include "client/renderingengine.h"
#include "serialization.h"
#include "itemgroup.h"
#include "util/base64.h"
#include "settings.h"
#include <IVideoDriver.h>
#include <algorithm>
#include <cctype>
#include <sstream>
#include <unordered_map>
GUIInventoryList::GUIInventoryList(gui::IGUIEnvironment *env,
	gui::IGUIElement *parent,
	s32 id,
	const core::rect<s32> &rectangle,
	InventoryManager *invmgr,
	const InventoryLocation &inventoryloc,
	const std::string &listname,
	const v2s32 &geom,
	const s32 start_item_i,
	const v2s32 &slot_size,
	const v2f32 &slot_spacing,
	GUIFormSpecMenu *fs_menu,
	const Options &options,
	gui::IGUIFont *font) :
	gui::IGUIElement(gui::EGUIET_ELEMENT, env, parent, id, rectangle),
	m_invmgr(invmgr),
	m_inventoryloc(inventoryloc),
	m_listname(listname),
	m_geom(geom),
	m_start_item_i(start_item_i),
	m_slot_size(slot_size),
	m_slot_spacing(slot_spacing),
	m_fs_menu(fs_menu),
	m_options(options),
	m_font(font),
	m_hovered_i(-1),
	m_already_warned(false)
{
}

static std::vector<ItemStack> parse_shulker_contents(const ItemStack &item, Client *client)
{
	std::vector<ItemStack> stacks(27);
	if (itemgroup_get(item.getDefinition(client->idef()).groups, "shulker_box") <= 0)
		return stacks;

	std::string serialized = item.metadata.getString("");
	const std::string compressed = item.metadata.getString("compressed");
	if (!compressed.empty()) {
		try {
			std::istringstream iss(base64_decode(compressed), std::ios::binary);
			std::ostringstream oss(std::ios::binary);
			decompressZstd(iss, oss);
			serialized = oss.str();
		} catch (const std::exception &) {
			// Fall back to the plain string below.
		}
	}
	if (serialized.empty())
		return stacks;

	auto unescape_lua_string = [](const std::string &input) {
		std::string out;
		out.reserve(input.size());
		for (size_t i = 0; i < input.size(); ++i) {
			char c = input[i];
			if (c != '\\' || i + 1 >= input.size()) {
				out.push_back(c);
				continue;
			}

			char next = input[++i];
			switch (next) {
			case '\\': out.push_back('\\'); break;
			case '"': out.push_back('"'); break;
			case 'n': out.push_back('\n'); break;
			case 'r': out.push_back('\r'); break;
			case 't': out.push_back('\t'); break;
			case 'b': out.push_back('\b'); break;
			case 'f': out.push_back('\f'); break;
			case 'a': out.push_back('\a'); break;
			case 'v': out.push_back('\v'); break;
			default: out.push_back(next); break;
			}
		}
		return out;
	};

	auto skip_ws = [](const std::string &text, size_t &pos) {
		while (pos < text.size() && std::isspace(static_cast<unsigned char>(text[pos])))
			++pos;
	};

	auto parse_quoted = [&](const std::string &text, size_t &pos) -> std::string {
		std::string raw;
		bool escaped = false;
		if (pos >= text.size() || text[pos] != '"')
			return raw;
		++pos;
		for (; pos < text.size(); ++pos) {
			char c = text[pos];
			if (escaped) {
				raw.push_back('\\');
				raw.push_back(c);
				escaped = false;
				continue;
			}
			if (c == '\\') {
				escaped = true;
				continue;
			}
			if (c == '"')
				break;
			raw.push_back(c);
		}
		return unescape_lua_string(raw);
	};

	auto parse_number = [](const std::string &text, size_t &pos) -> int {
		size_t start = pos;
		while (pos < text.size() && std::isdigit(static_cast<unsigned char>(text[pos])))
			++pos;
		if (start == pos)
			return -1;
		try {
			return stoi(text.substr(start, pos - start));
		} catch (const std::exception &) {
			return -1;
		}
	};

	std::unordered_map<int, std::string> refs;
	size_t return_pos = serialized.find("return ");
	if (return_pos != std::string::npos) {
		size_t p = 0;
		while (p < return_pos) {
			size_t ref_pos = serialized.find("_[", p);
			if (ref_pos == std::string::npos || ref_pos >= return_pos)
				break;
			size_t num_pos = ref_pos + 2;
			int ref_num = parse_number(serialized, num_pos);
			if (ref_num < 0) {
				p = ref_pos + 2;
				continue;
			}
			if (num_pos >= return_pos || serialized[num_pos] != ']') {
				p = num_pos;
				continue;
			}
			++num_pos;
			skip_ws(serialized, num_pos);
			if (num_pos >= return_pos || serialized[num_pos] != '=') {
				p = num_pos;
				continue;
			}
			++num_pos;
			skip_ws(serialized, num_pos);
			if (num_pos >= return_pos || serialized[num_pos] != '"') {
				p = num_pos;
				continue;
			}
			refs[ref_num] = parse_quoted(serialized, num_pos);
			p = num_pos;
		}
	}

	size_t pos = return_pos == std::string::npos ? 0 : return_pos;
	pos = serialized.find('{', pos);
	if (pos == std::string::npos)
		return stacks;
	++pos;

	size_t next_slot = 0;
	while (pos < serialized.size() && next_slot < stacks.size()) {
		skip_ws(serialized, pos);
		if (pos >= serialized.size() || serialized[pos] == '}')
			break;
		if (serialized[pos] == ',') {
			++pos;
			continue;
		}

		std::string itemstring;
		if (serialized[pos] == '[') {
			++pos;
			while (pos < serialized.size() && serialized[pos] != ']')
				++pos;
			if (pos >= serialized.size())
				break;
			++pos;
			skip_ws(serialized, pos);
			if (pos >= serialized.size() || serialized[pos] != '=')
				continue;
			++pos;
			skip_ws(serialized, pos);
		}

		if (pos >= serialized.size())
			break;
		if (serialized[pos] == '"') {
			itemstring = parse_quoted(serialized, pos);
		} else if (serialized[pos] == '_' && pos + 1 < serialized.size() && serialized[pos + 1] == '[') {
			pos += 2;
			int ref_num = parse_number(serialized, pos);
			if (ref_num >= 0 && pos < serialized.size() && serialized[pos] == ']') {
				auto it = refs.find(ref_num);
				if (it != refs.end())
					itemstring = it->second;
				++pos;
			}
		} else {
			while (pos < serialized.size() && serialized[pos] != ',' && serialized[pos] != '}')
				++pos;
			continue;
		}

		if (!itemstring.empty()) {
			ItemStack stack;
			stack.deSerialize(itemstring, client ? client->idef() : nullptr);
			stacks[next_slot++] = stack;
		}

		while (pos < serialized.size() && serialized[pos] != ',' && serialized[pos] != '}')
			++pos;
		if (pos < serialized.size() && serialized[pos] == ',')
			++pos;
	}

	return stacks;
}

static std::vector<ItemStack> copy_inventory_list(const InventoryList *list)
{
	std::vector<ItemStack> stacks;
	if (!list)
		return stacks;
	const std::vector<ItemStack> &items = list->getItems();
	stacks.reserve(items.size());
	for (const ItemStack &stack : items)
		stacks.push_back(stack);
	return stacks;
}

void GUIInventoryList::draw()
{
	if (!IsVisible)
		return;

	Inventory *inv = m_invmgr->getInventory(m_inventoryloc);
	if (!inv) {
		if (!m_already_warned) {
			warningstream << "GUIInventoryList::draw(): "
					<< "The inventory location "
					<< "\"" << m_inventoryloc.dump() << "\" doesn't exist"
					<< std::endl;
			m_already_warned = true;
		}
		return;
	}
	InventoryList *ilist = inv->getList(m_listname);
	if (!ilist) {
		if (!m_already_warned) {
			warningstream << "GUIInventoryList::draw(): "
					<< "The inventory list \"" << m_listname << "\" @ \""
					<< m_inventoryloc.dump() << "\" doesn't exist"
					<< std::endl;
			m_already_warned = true;
		}
		return;
	}
	m_already_warned = false;

	video::IVideoDriver *driver = Environment->getVideoDriver();
	Client *client = m_fs_menu->getClient();
	const ItemSpec *selected_item = m_fs_menu->getSelectedItem();

	core::rect<s32> imgrect(0, 0, m_slot_size.X, m_slot_size.Y);
	v2s32 base_pos = AbsoluteRect.UpperLeftCorner;

	const s32 list_size = (s32)ilist->getSize();

	for (s32 i = 0; i < m_geom.X * m_geom.Y; i++) {
		s32 item_i = i + m_start_item_i;
		if (item_i >= list_size)
			break;

		v2s32 p((i % m_geom.X) * m_slot_spacing.X,
				(i / m_geom.X) * m_slot_spacing.Y);
		core::rect<s32> rect = imgrect + base_pos + p;

		if (!getAbsoluteClippingRect().isRectCollided(rect))
			continue; // out of (parent) clip area

		const ItemStack &orig_item = ilist->getItem(item_i);
		ItemStack item = orig_item;

		bool selected = selected_item
			&& m_invmgr->getInventory(selected_item->inventoryloc) == inv
			&& selected_item->listname == m_listname
			&& selected_item->i == item_i;
		bool hovering = m_hovered_i == item_i;
		const bool is_shulker_box = itemgroup_get(orig_item.getDefinition(client->idef()).groups, "shulker_box") > 0;
		const bool is_ender_chest = orig_item.name == "mcl_chests:ender_chest";
		const bool is_filled_map = itemgroup_get(orig_item.getDefinition(client->idef()).groups, "filled_map") > 0;
		ItemRotationKind rotation_kind = selected ? IT_ROT_SELECTED :
			(hovering ? IT_ROT_HOVERED : IT_ROT_NONE);

		// layer 0
		if (hovering) {
			driver->draw2DRectangle(m_options.slotbg_h, rect, &AbsoluteClippingRect);
		} else {
			driver->draw2DRectangle(m_options.slotbg_n, rect, &AbsoluteClippingRect);
		}

		// Draw inv slot borders
		if (m_options.slotborder) {
			s32 x1 = rect.UpperLeftCorner.X;
			s32 y1 = rect.UpperLeftCorner.Y;
			s32 x2 = rect.LowerRightCorner.X;
			s32 y2 = rect.LowerRightCorner.Y;
			s32 border = 1;
			core::rect<s32> clipping_rect = Parent ? Parent->getAbsoluteClippingRect()
					: core::rect<s32>();
			core::rect<s32> *clipping_rect_ptr = Parent ? &clipping_rect : nullptr;
			driver->draw2DRectangle(m_options.slotbordercolor,
				core::rect<s32>(v2s32(x1 - border, y1 - border),
								v2s32(x2 + border, y1)), clipping_rect_ptr);
			driver->draw2DRectangle(m_options.slotbordercolor,
				core::rect<s32>(v2s32(x1 - border, y2),
								v2s32(x2 + border, y2 + border)), clipping_rect_ptr);
			driver->draw2DRectangle(m_options.slotbordercolor,
				core::rect<s32>(v2s32(x1 - border, y1),
								v2s32(x1, y2)), clipping_rect_ptr);
			driver->draw2DRectangle(m_options.slotbordercolor,
				core::rect<s32>(v2s32(x2, y1),
								v2s32(x2 + border, y2)), clipping_rect_ptr);
		}

		// layer 1
		if (selected)
			item.takeItem(m_fs_menu->getSelectedAmount());

		if (!item.empty()) {
			// Draw item stack
			drawItemStack(driver, m_font, item, rect, &AbsoluteClippingRect,
					client, rotation_kind);
		}

		// Add hovering tooltip. The tooltip disappears if any item is selected,
		// including the currently hovered one.
		bool show_tooltip = !item.empty() && hovering && (!selected_item || is_shulker_box || is_ender_chest || is_filled_map);

		if (RenderingEngine::getLastPointerType() == PointerType::Touch) {
			// Touchscreen users cannot hover over an item without selecting it.
			// To allow touchscreen users to see item tooltips, we also show the
			// tooltip if the item is selected and the finger is still on the
			// source slot.
			// The selected amount may be 0 in rare cases during "left-dragging"
			// (used to distribute items evenly).
			// In this case, the user doesn't see an item being dragged,
			// so we don't show the tooltip.
			// Note: `m_fs_menu->getSelectedAmount() != 0` below refers to the
			// part of the selected item the user is dragging.
			// `!item.empty()` would refer to the part of the selected item
			// remaining in the source slot.
			show_tooltip |= hovering && selected && m_fs_menu->getSelectedAmount() != 0;
		}

			if (show_tooltip) {
				const bool preview_enabled = g_settings->getBool("content_previewer") || g_settings->getBool("shulker_preview");
				const bool preview_shulker = g_settings->getBool("content_previewer.shulker") || g_settings->getBool("shulker_preview");
				const bool preview_enderchest = g_settings->getBool("content_previewer.enderchest");
				const bool preview_maps = g_settings->getBool("content_previewer.maps");
				const bool preview_special =
					preview_enabled &&
					((preview_shulker && is_shulker_box) ||
					(preview_enderchest && is_ender_chest) ||
					(preview_maps && is_filled_map));
				std::string tooltip = preview_special
					? orig_item.getShortDescription(client->idef())
					: orig_item.getDescription(client->idef());
				if (!preview_special && m_fs_menu->doTooltipAppendItemname())
					tooltip += "\n[" + orig_item.name + "]";
				if (preview_special) {
					if (is_shulker_box) {
						const std::vector<ItemStack> shulker_contents = parse_shulker_contents(orig_item, client);
						if (!shulker_contents.empty())
							m_fs_menu->setHoveredItemPreview(shulker_contents);
					} else if (is_ender_chest) {
						LocalPlayer *player = client->getEnv().getLocalPlayer();
						const InventoryList *ender_list = player ? player->inventory.getList("enderchest") : nullptr;
						const std::vector<ItemStack> ender_contents = copy_inventory_list(ender_list);
						if (!ender_contents.empty())
							m_fs_menu->setHoveredItemPreview(ender_contents);
					} else if (is_filled_map) {
						const std::string id = orig_item.metadata.getString("mcl_maps:id");
						if (!id.empty())
							m_fs_menu->setHoveredItemPreviewTexture("mcl_maps_map_texture_" + id + ".tga");
					}
				}
				m_fs_menu->addHoveredItemTooltip(tooltip);
			}
	}

	IGUIElement::draw();
}

bool GUIInventoryList::OnEvent(const SEvent &event)
{
	if (event.EventType != EET_MOUSE_INPUT_EVENT) {
		if (event.EventType == EET_GUI_EVENT &&
				event.GUIEvent.EventType == EGET_ELEMENT_LEFT) {
			// element is no longer hovered
			m_hovered_i = -1;
		}
		return IGUIElement::OnEvent(event);
	}

	m_hovered_i = getItemIndexAtPos(v2s32(event.MouseInput.X, event.MouseInput.Y));

	if (m_hovered_i != -1)
		return IGUIElement::OnEvent(event);

	// no item slot at pos of mouse event => allow clicking through
	// find the element that would be hovered if this inventorylist was invisible
	bool was_visible = IsVisible;
	IsVisible = false;
	IGUIElement *hovered =
		Environment->getRootGUIElement()->getElementFromPoint(
			core::position2d<s32>(event.MouseInput.X, event.MouseInput.Y));

	// if the player clicks outside of the formspec window, hovered is not
	// m_fs_menu, but some other weird element (with ID -1). we do however need
	// hovered to be m_fs_menu as item dropping when clicking outside of the
	// formspec window is handled in its OnEvent callback
	if (!hovered || hovered->getID() == -1)
		hovered = m_fs_menu;

	bool ret = hovered->OnEvent(event);

	IsVisible = was_visible;

	return ret;
}

s32 GUIInventoryList::getItemIndexAtPos(v2s32 p) const
{
	// no item if no gui element at pointer
	if (!IsVisible || AbsoluteClippingRect.getArea() <= 0 ||
			!AbsoluteClippingRect.isPointInside(p))
		return -1;

	// there cannot be an item if the inventory or the inventorylist does not exist
	Inventory *inv = m_invmgr->getInventory(m_inventoryloc);
	if (!inv)
		return -1;
	InventoryList *ilist = inv->getList(m_listname);
	if (!ilist)
		return -1;

	core::rect<s32> imgrect(0, 0, m_slot_size.X, m_slot_size.Y);
	v2s32 base_pos = AbsoluteRect.UpperLeftCorner;

	// instead of looping through each slot, we look where p would be in the grid
	s32 i = static_cast<s32>((p.X - base_pos.X) / m_slot_spacing.X)
			+ static_cast<s32>((p.Y - base_pos.Y) / m_slot_spacing.Y) * m_geom.X;

	v2s32 p0((i % m_geom.X) * m_slot_spacing.X,
			(i / m_geom.X) * m_slot_spacing.Y);

	core::rect<s32> rect = imgrect + base_pos + p0;

	rect.clipAgainst(AbsoluteClippingRect);

	if (rect.getArea() > 0 && rect.isPointInside(p) &&
			i + m_start_item_i < (s32)ilist->getSize())
		return i + m_start_item_i;

	return -1;
}
