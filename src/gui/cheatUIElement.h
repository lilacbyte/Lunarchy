#pragma once
#include <irrlicht.h>
#include <memory>
#include "client/content_cao.h"
#include <IVideoDriver.h>
#include <IGUIFont.h>
#include "gui/mainmenumanager.h"

using namespace irr;
using namespace gui;

class CheatUIElement {

public:
    CheatUIElement(const core::rect<s32>& rect) : bounds(rect), resizeBounds( 
        rect.LowerRightCorner.X - 5,
        rect.LowerRightCorner.Y - 5,
        rect.LowerRightCorner.X + 5,
        rect.LowerRightCorner.Y + 5
    ) {}

    virtual ~CheatUIElement() = default;

    virtual void draw(video::IVideoDriver* driver, gui::IGUIFont* font, float dtime, ClientEnvironment &env, bool editing) = 0;

    core::rect<s32> bounds;
    core::rect<s32> resizeBounds;
    bool isHovered = false;
    bool isResizeHovered = false;
    std::string elementName;
};

static inline bool hudShouldRender(bool editing)
{
	return editing || !isMenuActive();
}
