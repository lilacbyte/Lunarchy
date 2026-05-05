#pragma once

#include "gui/cheatUIElement.h"
#include "client/client.h"
#include <string>

struct ItemStack;

class EquipmentHUD : public CheatUIElement {
public:
	EquipmentHUD(Client *client, const core::rect<s32> &rect);
	void draw(video::IVideoDriver *driver, gui::IGUIFont *font, float dtime,
		ClientEnvironment &env, bool editing) override;

private:
	Client *m_client;

	static int getDurabilityUses(const ItemStack &item, Client *client);
	static int getRemainingDurability(const ItemStack &item, int max_uses);
	static std::wstring getItemLabel(const ItemStack &item, Client *client);
	static void drawEntry(video::IVideoDriver *driver, gui::IGUIFont *font,
		Client *client, const ItemStack &item, const std::wstring &fallback_label,
		const core::rect<s32> &entry_rect, bool editing);
};
