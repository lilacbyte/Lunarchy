#pragma once

#include "gui/cheatUIElement.h"
#include "client/clientenvironment.h"
#include "settings.h"
#include <string>
#include <vector>

class WelcomeHUD : public CheatUIElement {
public:
	WelcomeHUD(const core::rect<s32> &rect);
	void draw(video::IVideoDriver *driver, gui::IGUIFont *font, float dtime,
		ClientEnvironment &env, bool editing) override;

private:
	core::rect<s32> calculateBounds(video::IVideoDriver *driver, gui::IGUIFont *font,
		const std::vector<std::wstring> &lines) const;
};
