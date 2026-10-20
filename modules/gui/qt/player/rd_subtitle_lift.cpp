/*****************************************************************************
 * Copyright (C) 2026 VLC authors and VideoLAN
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * ( at your option ) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston MA 02110-1301, USA.
 *****************************************************************************/
#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

#include "rd_subtitle_lift.hpp"

#include <algorithm>

#include <vlc_vout.h>

#include "player/player_controller.hpp"

RdSubtitleLift::RdSubtitleLift(PlayerController* player, QObject* parent)
    : QObject(parent)
    , m_player(player)
{
    // a new video output starts without the lift
    connect(m_player, &PlayerController::voutListChanged, this, &RdSubtitleLift::apply);
}

void RdSubtitleLift::setLift(int lift)
{
    lift = std::max(0, lift);
    if (lift == m_lift)
        return;
    m_lift = lift;
    apply();
    emit liftChanged();
}

void RdSubtitleLift::apply()
{
    for (const SharedVOutThread& vout : m_player->getVouts())
        var_SetInteger(vout.get(), "sub-ui-margin", m_lift);
}
