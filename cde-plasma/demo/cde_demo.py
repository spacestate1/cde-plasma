#!/usr/bin/env python3
"""
CDE Plasma Theme Demo — six frameless windows with pixel-accurate
CDE-style borders, L-shaped corners, title bars, and buttons.
Matches the real KWin CDE decoration. For screenshots.
"""

import sys
import os

os.environ.setdefault("QT_STYLE_OVERRIDE", "cde")

from PyQt6.QtWidgets import (
    QApplication, QWidget, QVBoxLayout, QHBoxLayout,
    QLabel, QPushButton, QLineEdit, QComboBox, QCheckBox,
    QRadioButton, QGroupBox, QProgressBar, QButtonGroup,
    QMenuBar, QMenu,
)
from PyQt6.QtCore import Qt, QPoint, QRect
from PyQt6.QtGui import QPalette, QColor, QFont, QPainter, QAction, QPolygon, QPen


PALETTES = [
    {
        "name": "Blue-Gray",
        "frame":     QColor(186, 190, 210),
        "titlebar":  QColor(192,  64, 128),
        "text":      QColor(  0,   0,   0),
        "textlight": QColor(255, 255, 255),
        "base":      QColor(220, 224, 238),
        "highlight": QColor( 90, 130, 180),
    },
    {
        "name": "Crimson",
        "frame":     QColor(210, 180, 175),
        "titlebar":  QColor(178,  38,  38),
        "text":      QColor(  0,   0,   0),
        "textlight": QColor(255, 255, 255),
        "base":      QColor(235, 215, 210),
        "highlight": QColor(178,  68,  68),
    },
    {
        "name": "Slate Green",
        "frame":     QColor(175, 200, 182),
        "titlebar":  QColor( 32, 118,  58),
        "text":      QColor(  0,   0,   0),
        "textlight": QColor(255, 255, 255),
        "base":      QColor(210, 230, 216),
        "highlight": QColor( 60, 148,  88),
    },
    {
        "name": "Sand",
        "frame":     QColor(215, 205, 178),
        "titlebar":  QColor(162, 128,  42),
        "text":      QColor(  0,   0,   0),
        "textlight": QColor(255, 255, 255),
        "base":      QColor(238, 230, 208),
        "highlight": QColor(182, 158,  82),
    },
    {
        "name": "Steel",
        "frame":     QColor(190, 190, 205),
        "titlebar":  QColor( 52,  52, 120),
        "text":      QColor(  0,   0,   0),
        "textlight": QColor(255, 255, 255),
        "base":      QColor(222, 222, 235),
        "highlight": QColor( 88,  88, 158),
    },
    {
        "name": "Warm Gray",
        "frame":     QColor(208, 195, 188),
        "titlebar":  QColor(148,  78,  52),
        "text":      QColor(  0,   0,   0),
        "textlight": QColor(255, 255, 255),
        "base":      QColor(235, 225, 218),
        "highlight": QColor(168, 108,  82),
    },
]

# Constants matching cdedecoration.cpp exactly
BW = 7                 # kBaseBorderWidth (m_borderWidth at Normal scale)
TITLE_H = 22           # kBaseTitleHeight (m_titleHeight, also m_buttonSize)
BEVEL_OUTER = 2        # kOuterBevelWidth
BEVEL_INNER = 1        # kInnerBevelWidth
INNER_LINE = 1         # kInnerLineWidth (title bar bevel)
LIGHT_PCT = 120        # kBevelLightPercent
DARK_PCT = 56          # kBevelDarkPercent


def shade(color, percent):
    r = min(255, max(0, color.red() * percent // 100))
    g = min(255, max(0, color.green() * percent // 100))
    b = min(255, max(0, color.blue() * percent // 100))
    return QColor(r, g, b)


def build_widget_palette(p):
    pal = QPalette()
    frame, base, text, hl = p["frame"], p["base"], p["text"], p["highlight"]
    for group in (QPalette.ColorGroup.Active, QPalette.ColorGroup.Inactive):
        pal.setColor(group, QPalette.ColorRole.Window, frame)
        pal.setColor(group, QPalette.ColorRole.Button, frame)
        pal.setColor(group, QPalette.ColorRole.Base, base)
        pal.setColor(group, QPalette.ColorRole.AlternateBase, shade(frame, LIGHT_PCT))
        pal.setColor(group, QPalette.ColorRole.Light, shade(frame, LIGHT_PCT))
        pal.setColor(group, QPalette.ColorRole.Midlight, shade(frame, 110))
        pal.setColor(group, QPalette.ColorRole.Mid, shade(frame, 85))
        pal.setColor(group, QPalette.ColorRole.Dark, shade(frame, DARK_PCT))
        pal.setColor(group, QPalette.ColorRole.Shadow, shade(frame, 35))
        pal.setColor(group, QPalette.ColorRole.Text, text)
        pal.setColor(group, QPalette.ColorRole.WindowText, text)
        pal.setColor(group, QPalette.ColorRole.ButtonText, text)
        pal.setColor(group, QPalette.ColorRole.BrightText, QColor(255, 255, 255))
        pal.setColor(group, QPalette.ColorRole.Highlight, hl)
        pal.setColor(group, QPalette.ColorRole.HighlightedText, QColor(255, 255, 255))
    dt = shade(frame, 55)
    pal.setColor(QPalette.ColorGroup.Disabled, QPalette.ColorRole.Window, frame)
    pal.setColor(QPalette.ColorGroup.Disabled, QPalette.ColorRole.Button, frame)
    pal.setColor(QPalette.ColorGroup.Disabled, QPalette.ColorRole.Text, dt)
    pal.setColor(QPalette.ColorGroup.Disabled, QPalette.ColorRole.WindowText, dt)
    pal.setColor(QPalette.ColorGroup.Disabled, QPalette.ColorRole.ButtonText, dt)
    return pal


def draw_bevel(painter, rect, color, sunken, lw):
    """Matches cdedecoration.cpp drawBevel and cdebutton.cpp drawBevel."""
    light = shade(color, DARK_PCT) if sunken else shade(color, LIGHT_PCT)
    dark = shade(color, LIGHT_PCT) if sunken else shade(color, DARK_PCT)

    inner = rect.adjusted(lw, lw, -lw, -lw)
    if inner.width() > 0 and inner.height() > 0:
        painter.fillRect(inner, color)

    # Top
    painter.fillRect(QRect(rect.left(), rect.top(), rect.width(), lw), light)
    # Left
    painter.fillRect(QRect(rect.left(), rect.top() + lw, lw, rect.height() - lw * 2), light)
    # Bottom
    painter.fillRect(QRect(rect.left(), rect.bottom() - lw + 1, rect.width(), lw), dark)
    # Right
    painter.fillRect(QRect(rect.right() - lw + 1, rect.top(), lw, rect.height() - lw), dark)

    # Diagonal corner fixes
    for i in range(lw):
        painter.setPen(light)
        painter.drawLine(rect.left() + i, rect.bottom() - lw + 1,
                         rect.left() + i, rect.bottom() - i)
        painter.drawLine(rect.right() - lw + 1, rect.top() + i,
                         rect.right() - i - 1, rect.top() + i)


def draw_corner(painter, section, x1, y1, x2, y2, bw, fill):
    """Matches paintCornerHandle in cdedecoration.cpp."""
    lw = BEVEL_OUTER
    light = shade(fill, LIGHT_PCT)
    dark = shade(fill, DARK_PCT)
    poly = QPolygon()

    if section == "tl":
        poly << QPoint(x1,y1) << QPoint(x2,y1) << QPoint(x2,y1+bw) \
             << QPoint(x1+bw,y1+bw) << QPoint(x1+bw,y2) << QPoint(x1,y2)
        painter.setBrush(fill); painter.setPen(Qt.PenStyle.NoPen); painter.drawPolygon(poly)
        painter.fillRect(x1,y1, x2-x1,lw, light)
        painter.fillRect(x1,y1, lw,y2-y1, light)
        painter.fillRect(x1+bw, y1+bw-lw, x2-x1-bw,lw, dark)
        painter.fillRect(x2-lw,y1, lw,bw, dark)
        painter.fillRect(x1+bw-lw, y1+bw, lw,y2-y1-bw, dark)
        painter.fillRect(x1, y2-lw, bw,lw, dark)
    elif section == "tr":
        poly << QPoint(x1,y1) << QPoint(x2,y1) << QPoint(x2,y2) \
             << QPoint(x2-bw,y2) << QPoint(x2-bw,y1+bw) << QPoint(x1,y1+bw)
        painter.setBrush(fill); painter.setPen(Qt.PenStyle.NoPen); painter.drawPolygon(poly)
        painter.fillRect(x1,y1, x2-x1,lw, light)
        painter.fillRect(x1,y1, lw,bw, light)
        painter.fillRect(x2-bw, y1+bw, lw,y2-y1-bw, light)
        painter.fillRect(x2-lw,y1, lw,y2-y1, dark)
        painter.fillRect(x1+lw, y1+bw-lw, x2-x1-bw-lw,lw, dark)
        painter.fillRect(x2-bw, y2-lw, bw,lw, dark)
    elif section == "bl":
        poly << QPoint(x1,y1) << QPoint(x1+bw,y1) << QPoint(x1+bw,y2-bw) \
             << QPoint(x2,y2-bw) << QPoint(x2,y2) << QPoint(x1,y2)
        painter.setBrush(fill); painter.setPen(Qt.PenStyle.NoPen); painter.drawPolygon(poly)
        painter.fillRect(x1,y1, lw,y2-y1, light)
        painter.fillRect(x1,y1, bw,lw, light)
        painter.fillRect(x1+bw, y2-bw, x2-x1-bw,lw, light)
        painter.fillRect(x1, y2-lw, x2-x1,lw, dark)
        painter.fillRect(x1+bw-lw, y1, lw,y2-y1-bw, dark)
        painter.fillRect(x2-lw, y2-bw, lw,bw, dark)
    elif section == "br":
        poly << QPoint(x2-bw,y1) << QPoint(x2,y1) << QPoint(x2,y2) \
             << QPoint(x1,y2) << QPoint(x1,y2-bw) << QPoint(x2-bw,y2-bw)
        painter.setBrush(fill); painter.setPen(Qt.PenStyle.NoPen); painter.drawPolygon(poly)
        painter.fillRect(x2-bw,y1, lw,y2-y1-bw, light)
        painter.fillRect(x2-bw,y1, bw,lw, light)
        painter.fillRect(x1, y2-bw, lw,bw, light)
        painter.fillRect(x1, y2-bw, x2-x1-bw,lw, light)
        painter.fillRect(x2-lw,y1, lw,y2-y1, dark)
        painter.fillRect(x1, y2-lw, x2-x1,lw, dark)


class DemoWindow(QWidget):
    def __init__(self, palette_info, index):
        super().__init__()
        self.p = palette_info
        self.setWindowFlags(Qt.WindowType.FramelessWindowHint)
        self.setFixedSize(400, 380)
        self.setPalette(build_widget_palette(palette_info))
        self._build_content()

    def _build_content(self):
        # Content sits inside frame, below title bar
        # Matches: clientRect(BW, BW + TITLE_H, W - BW*2, H - BW*2 - TITLE_H)
        content = QWidget(self)
        cx = BW
        cy = BW + TITLE_H
        cw = self.width() - BW * 2
        ch = self.height() - BW * 2 - TITLE_H
        content.setGeometry(cx, cy, cw, ch)
        content.setAutoFillBackground(True)

        layout = QVBoxLayout(content)
        layout.setSpacing(6)
        layout.setContentsMargins(8, 8, 8, 8)

        menubar = QMenuBar(content)
        file_menu = menubar.addMenu("File")
        file_menu.addAction("New"); file_menu.addAction("Open...")
        file_menu.addSeparator()
        qa = QAction("Quit", self); qa.triggered.connect(QApplication.quit)
        file_menu.addAction(qa)
        edit_menu = menubar.addMenu("Edit")
        edit_menu.addAction("Cut"); edit_menu.addAction("Copy"); edit_menu.addAction("Paste")
        menubar.addMenu("Help").addAction("About...")
        layout.setMenuBar(menubar)

        r1 = QHBoxLayout()
        r1.addWidget(QLabel("Hostname:"))
        r1.addWidget(QLineEdit("admin-workstation"))
        layout.addLayout(r1)

        r2 = QHBoxLayout()
        r2.addWidget(QLabel("Session:"))
        c = QComboBox(); c.addItems(["Plasma (Wayland)", "Plasma (X11)", "Console"])
        r2.addWidget(c)
        layout.addLayout(r2)

        grp = QHBoxLayout()
        rg = QGroupBox("Window Size"); rl = QVBoxLayout(); bg = QButtonGroup(self)
        for i, t in enumerate(["Normal", "Large", "Oversized"]):
            rb = QRadioButton(t)
            if i == 0: rb.setChecked(True)
            bg.addButton(rb); rl.addWidget(rb)
        rg.setLayout(rl); grp.addWidget(rg)

        cg = QGroupBox("Options"); cl = QVBoxLayout()
        cb1 = QCheckBox("Show borders"); cb1.setChecked(True); cl.addWidget(cb1)
        cl.addWidget(QCheckBox("Enable shadows"))
        cb3 = QCheckBox("Lock on idle"); cb3.setChecked(True); cl.addWidget(cb3)
        cg.setLayout(cl); grp.addWidget(cg)
        layout.addLayout(grp)

        pr = QProgressBar(); pr.setValue(65); pr.setFormat("Loading workspace... %p%")
        layout.addWidget(pr)

        br = QHBoxLayout(); br.addStretch()
        ok = QPushButton("OK"); ok.setFixedWidth(80); ok.clicked.connect(self.close); br.addWidget(ok)
        cn = QPushButton("Cancel"); cn.setFixedWidth(80); cn.clicked.connect(self.close); br.addWidget(cn)
        hb = QPushButton("Help"); hb.setFixedWidth(80); hb.setEnabled(False); br.addWidget(hb)
        layout.addLayout(br)

    def paintEvent(self, event):
        painter = QPainter(self)
        painter.setRenderHint(QPainter.RenderHint.Antialiasing, False)

        frame = self.p["frame"]
        titlebar = self.p["titlebar"]
        W, H = self.width(), self.height()
        corner = TITLE_H + BW  # matches hoverRectForSection

        # --- Frame fill (region subtract like paintFrame) ---
        painter.fillRect(self.rect(), frame)

        # --- L-shaped corner handles ---
        draw_corner(painter, "tl", 0, 0, corner, corner, BW, frame)
        draw_corner(painter, "tr", W-corner, 0, W, corner, BW, frame)
        draw_corner(painter, "bl", 0, H-corner, corner, H, BW, frame)
        draw_corner(painter, "br", W-corner, H-corner, W, H, BW, frame)

        # --- Edge bevels between corners ---
        te = QRect(corner, 0, max(0, W - corner*2), BW)
        if te.width() > 0: draw_bevel(painter, te, frame, False, BEVEL_OUTER)
        be = QRect(corner, H-BW, max(0, W - corner*2), BW)
        if be.width() > 0: draw_bevel(painter, be, frame, False, BEVEL_OUTER)
        le = QRect(0, corner, BW, max(0, H - corner*2))
        if le.height() > 0: draw_bevel(painter, le, frame, False, BEVEL_OUTER)
        re = QRect(W-BW, corner, BW, max(0, H - corner*2))
        if re.height() > 0: draw_bevel(painter, re, frame, False, BEVEL_OUTER)

        # --- Inner sunken bevel around client (matches paintFrame) ---
        client_rect = QRect(BW, BW + TITLE_H, W - BW*2, H - BW*2 - TITLE_H)
        ibr = QRect(client_rect.x() - BEVEL_INNER,
                     client_rect.y() - BEVEL_INNER,
                     client_rect.width() + BEVEL_INNER*2,
                     client_rect.height() + BEVEL_INNER*2)
        draw_bevel(painter, ibr, frame, True, BEVEL_INNER)

        # --- Separator line below title (matches paintFrame) ---
        sep_y = BW + TITLE_H - BEVEL_INNER - 1
        painter.setPen(shade(frame, DARK_PCT))
        painter.drawLine(BW, sep_y, W - BW - 1, sep_y)
        painter.setPen(shade(frame, LIGHT_PCT))
        painter.drawLine(BW, sep_y + 1, W - BW - 1, sep_y + 1)

        # --- Title bar (matches paintTitleBar) ---
        # titleBarRect = QRect(BW, BW, W - BW*2, TITLE_H)
        title_rect = QRect(BW, BW, W - BW*2, TITLE_H)
        draw_bevel(painter, title_rect, titlebar, False, INNER_LINE)

        # --- Buttons: m_buttonSize = m_titleHeight = TITLE_H ---
        # Buttons fill the full title bar height, flush with title_rect edges
        btn_sz = TITLE_H  # m_buttonSize = m_titleHeight

        # Menu button (leftmost, at title_rect origin)
        menu_r = QRect(title_rect.x(), title_rect.y(), btn_sz, btn_sz)
        draw_bevel(painter, menu_r, titlebar, False, 1)
        # Menu glyph: horizontal handle bar
        hh = max(4, menu_r.height() // 5)
        hr = QRect(menu_r.left() + 4, menu_r.center().y() - hh//2,
                    max(0, menu_r.width() - 8), hh)
        draw_bevel(painter, hr, titlebar, False, 1)

        # Right buttons laid out from right edge: close, max, min
        # Close (rightmost)
        rx = title_rect.x() + title_rect.width() - btn_sz
        close_r = QRect(rx, title_rect.y(), btn_sz, btn_sz)
        draw_bevel(painter, close_r, titlebar, False, 1)
        # Close glyph: X (matches paintCloseGlyph)
        pad = max(4, min(6, btn_sz // 4))
        pen = QPen(self.p["textlight"], 2)
        pen.setCosmetic(True)
        painter.setPen(pen)
        painter.drawLine(close_r.left()+pad, close_r.top()+pad,
                         close_r.right()-pad, close_r.bottom()-pad)
        painter.drawLine(close_r.right()-pad, close_r.top()+pad,
                         close_r.left()+pad, close_r.bottom()-pad)

        # Maximize
        rx -= btn_sz
        max_r = QRect(rx, title_rect.y(), btn_sz, btn_sz)
        draw_bevel(painter, max_r, titlebar, False, 1)
        sq = max(5, btn_sz - 8)
        sq_r = QRect(max_r.center().x() - sq//2, max_r.center().y() - sq//2, sq, sq)
        draw_bevel(painter, sq_r, titlebar, False, 1)

        # Minimize
        rx -= btn_sz
        min_r = QRect(rx, title_rect.y(), btn_sz, btn_sz)
        draw_bevel(painter, min_r, titlebar, False, 1)
        dot = 4 if btn_sz >= 12 else 3
        dot_r = QRect(min_r.center().x() - dot//2, min_r.center().y() - dot//2, dot, dot)
        draw_bevel(painter, dot_r, titlebar, False, 1)

        # --- Caption text (matches paintCaption) ---
        title_pad = 6  # kBaseTitlePadding
        cap_left = menu_r.right() + 1 + title_pad
        cap_right = min_r.left() - title_pad
        cap_rect = QRect(cap_left, title_rect.y(),
                          max(0, cap_right - cap_left), title_rect.height())
        painter.setPen(self.p["textlight"])
        painter.setFont(QFont("Sans", 10, QFont.Weight.Bold))
        painter.drawText(cap_rect.adjusted(title_pad//2, 0, -title_pad//2, 0),
                         Qt.AlignmentFlag.AlignVCenter | Qt.AlignmentFlag.AlignLeft,
                         self.p["name"])

        painter.end()

    def mousePressEvent(self, event):
        if event.button() == Qt.MouseButton.LeftButton:
            # startSystemMove works on both Wayland and X11
            window = self.windowHandle()
            if window:
                window.startSystemMove()
            event.accept()


def main():
    app = QApplication(sys.argv)
    app.setFont(QFont("Sans", 10))

    windows = []
    for i, pal in enumerate(PALETTES):
        win = DemoWindow(pal, i)
        win.show()
        windows.append(win)

    sys.exit(app.exec())


if __name__ == "__main__":
    main()
