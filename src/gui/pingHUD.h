#pragma once

#include "gui/cheatUIElement.h"
#include "client/client.h"
#include "client/clientenvironment.h"
#include "settings.h"

class pingHUD : public CheatUIElement {
public:
	pingHUD(Client *client, const core::rect<s32> &rect);
	void draw(video::IVideoDriver *driver, gui::IGUIFont *font, float dtime,
		ClientEnvironment &env, bool editing) override;

private:
	Client *m_client;
};
