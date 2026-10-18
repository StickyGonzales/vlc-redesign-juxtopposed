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

#include "style/rdwidgetstyle.hpp"
#include "style/systempalette.hpp"
#include "maininterface/mainctx.hpp"
#include "util/color_scheme_model.hpp"

#include <QPalette>
#include <QStyle>
#include <QWidget>

#include <cassert>
#include <utility>

namespace {

QString cssColor( const QColor& c )
{
    return QStringLiteral( "rgba(%1, %2, %3, %4)" )
            .arg( c.red() ).arg( c.green() ).arg( c.blue() ).arg( c.alpha() );
}

/* Figma shows disabled buttons at 50 % opacity; style sheets have no opacity, so the
 * color is blended with the dialog background instead */
QColor halfOver( const QColor& c, const QColor& bg )
{
    return QColor( ( c.red() + bg.red() ) / 2,
                   ( c.green() + bg.green() ) / 2,
                   ( c.blue() + bg.blue() ) / 2 );
}

/* Sizes are the Figma dialog values (FIGMA_FLOWS.md "Dialogs", "Cancel / Save", fields):
 * text Inter 400 14 (the application font), section titles 16, fields and buttons
 * radius 6 with a 2 px border, tab underline 2 px. */
const char rdDialogStyleSheet[] = R"RAW(
QDialog, QWizard, QWizardPage {
    background-color: {bg};
}
QWidget {
    color: {fgA2};
    font-size: 14px;
}
QLabel, QCheckBox, QRadioButton {
    background: transparent;
}
/* About: the product name, the License / Authors / Credits links and the footer bar */
QLabel[rdTitle="true"] {
    color: {fg1};
}
QLabel[rdLink="true"] {
    color: {accentMain};
}
QFrame[rdFooter="true"] {
    border: none;
    border-top: 1px solid {dividerDim};
}
QLabel:disabled, QCheckBox:disabled, QRadioButton:disabled, QGroupBox:disabled {
    color: {fgA4};
}
QGroupBox {
    color: {fg2};
    font-size: 16px;
    border: none;
    border-top: 1px solid {dividerDim};
    margin-top: 28px;
    padding-top: 8px;
}
QGroupBox::title {
    subcontrol-origin: margin;
    subcontrol-position: top left;
    left: 0px;
    padding: 0px;
}
QFrame[frameShape="4"], QFrame[frameShape="HLine"] {
    border: none;
    background-color: {dividerDim};
    min-height: 1px;
    max-height: 1px;
}
QFrame[frameShape="5"], QFrame[frameShape="VLine"] {
    border: none;
    background-color: {dividerDim};
    min-width: 1px;
    max-width: 1px;
}
QScrollArea, QScrollArea > QWidget > QWidget, QStackedWidget, QTabWidget > QWidget {
    background: transparent;
}

QLineEdit, QComboBox, QSpinBox, QDoubleSpinBox, QTimeEdit,
QPlainTextEdit, QTextEdit, QListView, QTreeView {
    background-color: {bgB2};
    color: {fg2};
    border: 2px solid {bgA4};
    border-radius: 6px;
    padding: 4px 8px;
    selection-background-color: {accentDim};
    selection-color: {selectionFg};
}
QLineEdit:hover, QComboBox:hover, QSpinBox:hover, QDoubleSpinBox:hover, QTimeEdit:hover,
QPlainTextEdit:hover, QTextEdit:hover, QListView:hover, QTreeView:hover {
    border-color: {dividerBright};
}
QLineEdit:focus, QComboBox:focus, QSpinBox:focus, QDoubleSpinBox:focus, QTimeEdit:focus,
QPlainTextEdit:focus, QTextEdit:focus, QListView:focus, QTreeView:focus {
    border-color: {accentMain};
}
QLineEdit:disabled, QComboBox:disabled, QSpinBox:disabled, QDoubleSpinBox:disabled,
QTimeEdit:disabled, QPlainTextEdit:disabled, QTextEdit:disabled {
    color: {fgA4};
}
QListView::item, QTreeView::item {
    padding: 4px;
    border-radius: 4px;
}
QListView::item:hover, QTreeView::item:hover {
    background-color: {bgA2};
}
QListView::item:selected, QTreeView::item:selected {
    background-color: {bgA1};
    color: {fg2};
}

/* the drop-down and spin arrows stay native: they follow the text color */
QComboBox QAbstractItemView {
    background-color: {bgA3};
    color: {fgA1};
    border: 1px solid {dividerBright};
    selection-background-color: {bgA2};
    selection-color: {fg2};
    outline: 0px;
}

QPushButton, QToolButton {
    background-color: {btnBg};
    color: {btnFg};
    border: 1px solid transparent;
    border-radius: 6px;
    padding: 4px 8px;
    font-weight: 600;
}
/* fixed 100 px in open_net.ui, too narrow for the Figma button text */
QPushButton#clearHistoryButton {
    max-width: 160px;
}
QPushButton:hover, QToolButton:hover {
    background-color: {btnHoverBg};
    color: {btnHoverFg};
}
QPushButton:pressed, QToolButton:pressed {
    background-color: {btnPressedBg};
}
QPushButton:focus, QToolButton:focus {
    border-color: {btnFocus};
}
QPushButton:disabled, QToolButton:disabled {
    background-color: {btnDisabledBg};
    color: {btnDisabledFg};
}
QPushButton[rdPrimary="true"], QToolButton[rdPrimary="true"] {
    background-color: {bgAccentBright};
    color: {accentMain};
}
QPushButton[rdPrimary="true"]:hover, QToolButton[rdPrimary="true"]:hover {
    background-color: {accentMain};
    color: {fgB1};
}
QPushButton[rdPrimary="true"]:disabled, QToolButton[rdPrimary="true"]:disabled {
    background-color: {saveDisabledBg};
    color: {saveDisabledFg};
}

QCheckBox::indicator, QRadioButton::indicator, QGroupBox::indicator {
    width: 14px;
    height: 14px;
    border: 2px solid {dividerBright};
    background-color: {bgB2};
}
QCheckBox::indicator, QGroupBox::indicator {
    border-radius: 3px;
}
QRadioButton::indicator {
    border-radius: 9px;
}
QCheckBox::indicator:hover, QRadioButton::indicator:hover, QGroupBox::indicator:hover {
    border-color: {fgA3};
}
QCheckBox::indicator:checked, QGroupBox::indicator:checked {
    background-color: {accentMain};
    border-color: {accentMain};
}
QCheckBox::indicator:indeterminate {
    background-color: {accentDim};
    border-color: {accentDim};
}
QRadioButton::indicator:checked {
    border-color: {accentMain};
    background-color: qradialgradient(cx: 0.5, cy: 0.5, radius: 0.5, fx: 0.5, fy: 0.5,
                                      stop: 0 {accentMain}, stop: 0.55 {accentMain},
                                      stop: 0.65 {bgB2}, stop: 1 {bgB2});
}
QCheckBox::indicator:disabled, QRadioButton::indicator:disabled {
    border-color: {bgA1};
}

QTabWidget::pane {
    border: none;
    border-top: 1px solid {dividerDim};
}
QTabBar::tab {
    background: transparent;
    color: {fgA3};
    border: none;
    border-bottom: 2px solid transparent;
    padding: 10px 16px;
}
QTabBar::tab:hover {
    color: {fgA2};
}
QTabBar::tab:selected {
    color: {fg2};
    border-bottom: 2px solid {accentMain};
}

QScrollBar:vertical {
    background: transparent;
    width: 10px;
    margin: 0px;
}
QScrollBar:horizontal {
    background: transparent;
    height: 10px;
    margin: 0px;
}
QScrollBar::handle:vertical {
    background-color: {dividerBright};
    border-radius: 3px;
    min-height: 24px;
    margin: 2px;
}
QScrollBar::handle:horizontal {
    background-color: {dividerBright};
    border-radius: 3px;
    min-width: 24px;
    margin: 2px;
}
QScrollBar::add-line, QScrollBar::sub-line {
    width: 0px;
    height: 0px;
}
QScrollBar::add-page, QScrollBar::sub-page {
    background: transparent;
}
)RAW";

QString makeStyleSheet( const SystemPalette& p )
{
    /* opaque dialog window: BG/A3 Transparent seen over nothing (Dark #191919, Light #D5D5D5),
     * like the QML dialogs */
    QColor bg = p.get_rdBgA3Transparent();
    bg.setAlpha( 255 );

    /* push buttons: in Light the dark Standard button of RdButton (FG/A2, hover FG/A1, BG/A1
     * text, accent focus, 50 % when disabled), like "Browse" in the video at 17:43; Dark keeps
     * its BG/A1 buttons */
    const bool dark = p.property( "isDark" ).toBool();
    const QColor btnBg = dark ? p.get_rdBgA1() : p.get_rdFgA2();
    const QColor btnFg = dark ? p.get_rdFgA2() : p.get_rdBgA1();

    const std::pair<const char*, QColor> colors[] = {
        { "{bg}", bg },
        { "{btnBg}", btnBg },
        { "{btnFg}", btnFg },
        { "{btnHoverBg}", dark ? p.get_rdDividerBright() : p.get_rdFgA1() },
        { "{btnHoverFg}", dark ? p.get_rdFg2() : p.get_rdBgA1() },
        { "{btnPressedBg}", dark ? p.get_rdBgA2() : p.get_rdFgA4() },
        { "{btnFocus}", dark ? p.get_rdFg2() : p.get_rdAccentMain() },
        { "{btnDisabledBg}", dark ? btnBg : halfOver( btnBg, bg ) },
        { "{btnDisabledFg}", dark ? p.get_rdFgA4() : halfOver( btnFg, bg ) },
        { "{fg1}", p.get_rdFg1() },
        { "{fg2}", p.get_rdFg2() },
        { "{fgA1}", p.get_rdFgA1() },
        { "{fgA2}", p.get_rdFgA2() },
        { "{fgA3}", p.get_rdFgA3() },
        { "{fgA4}", p.get_rdFgA4() },
        { "{fgB1}", p.get_rdFgB1() },
        { "{bgA1}", p.get_rdBgA1() },
        { "{bgA2}", p.get_rdBgA2() },
        { "{bgA3}", p.get_rdBgA3() },
        { "{bgA4}", p.get_rdBgA4() },
        { "{bgB2}", p.get_rdBgB2() },
        { "{accentMain}", p.get_rdAccentMain() },
        { "{accentDim}", p.get_rdAccentDim() },
        { "{selectionFg}", p.get_rdSelectionText() },
        { "{bgAccentBright}", p.get_rdBgAccentBright() },
        /* disabled Save: gray BG/A1 + FG/A2 at 50 % (RdButton) */
        { "{saveDisabledBg}", halfOver( p.get_rdBgA1(), bg ) },
        { "{saveDisabledFg}", halfOver( p.get_rdFgA2(), bg ) },
        { "{dividerBright}", p.get_rdDividerBright() },
        { "{dividerDim}", p.get_rdDividerDim() },
    };

    QString sheet = QString::fromUtf8( rdDialogStyleSheet );
    for( const auto& color : colors )
        sheet.replace( QLatin1String( color.first ), cssColor( color.second ) );
    return sheet;
}

} // namespace

void RdWidgetStyle::apply( QWidget* widget, qt_intf_t* p_intf )
{
    assert( widget );

    MainCtx* mainCtx = p_intf ? p_intf->p_mi : nullptr;
    if( !mainCtx || !mainCtx->getColorScheme() )
        return;

    ColorSchemeModel* scheme = mainCtx->getColorScheme();

    /* the same palette the QML interface uses (VLCStyle.palette), owned by the widget */
    SystemPalette* palette = new SystemPalette( widget );
    palette->setCtx( mainCtx );
    palette->setSource( scheme->currentScheme() );

    QObject::connect( scheme, &ColorSchemeModel::currentChanged, palette,
                      [palette, scheme]() { palette->setSource( scheme->currentScheme() ); } );

    const auto update = [widget, palette]() {
        widget->setStyleSheet( makeStyleSheet( *palette ) );
        /* links in rich text labels take the palette's link color, which style sheets
         * cannot set */
        QPalette widgetPalette = widget->palette();
        widgetPalette.setColor( QPalette::Link, palette->get_rdAccentMain() );
        widgetPalette.setColor( QPalette::LinkVisited, palette->get_rdAccentMain() );
        widget->setPalette( widgetPalette );
    };
    QObject::connect( palette, &SystemPalette::paletteChanged, widget, update );
    update();
}

void RdWidgetStyle::setPrimary( QWidget* button )
{
    assert( button );

    button->setProperty( "rdPrimary", true );
    /* property selectors are only evaluated when the widget is polished */
    button->style()->unpolish( button );
    button->style()->polish( button );
}
