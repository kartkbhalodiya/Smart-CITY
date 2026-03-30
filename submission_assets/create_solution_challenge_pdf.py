from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, Sequence

from pypdf import PdfReader, PdfWriter
from reportlab.lib.colors import Color, HexColor, black, white
from reportlab.lib.utils import ImageReader
from reportlab.pdfbase.pdfmetrics import stringWidth
from reportlab.pdfgen import canvas


ROOT = Path(__file__).resolve().parents[1]
TEMPLATE_PDF = Path(r"C:\Users\bhalo\Downloads\-EXT- Solution Challenge 2026 - Prototype PPT Template.pdf")
OVERLAY_PDF = ROOT / "submission_assets" / "_janhelp_overlay.pdf"
OUTPUT_PDF = ROOT / "submission_assets" / "JanHelp_Solution_Challenge_2026_Submission.pdf"
LOGO_PATH = ROOT / "smartcity_application" / "assets" / "images" / "logo.png"

PAGE_WIDTH = 720
PAGE_HEIGHT = 405

# We intentionally skip the template guideline cover and optional blank pages to stay near the
# challenge recommendation of roughly 10 slides while preserving the original visual style.
TEMPLATE_PAGE_INDICES = [1, 2, 3, 4, 5, 7, 8, 10, 11, 12]

TEAM_NAME = "JanHelp"
TEAM_LEADER = "Kartik Bhalodiya"
PROBLEM_STATEMENT = (
    "How might we help citizens report civic issues in their own language, verify proof with AI, "
    "and route complaints to the right department faster for transparent urban grievance redressal?"
)

GITHUB_REPO = "https://github.com/kartkbhalodiya/Smart-CITY"
MVP_LINK = "https://janhelp.vercel.app"
WORKING_PROTOTYPE_LINK = "https://janhelp.vercel.app"
DEMO_VIDEO_LINK = "Add your 3-minute YouTube or Drive demo link here"


BLUE = HexColor("#2563EB")
BLUE_DARK = HexColor("#1D4ED8")
GREEN = HexColor("#16A34A")
GREEN_SOFT = HexColor("#DCFCE7")
AMBER = HexColor("#F59E0B")
AMBER_SOFT = HexColor("#FEF3C7")
SKY = HexColor("#0EA5E9")
SKY_SOFT = HexColor("#E0F2FE")
SLATE = HexColor("#334155")
SLATE_LIGHT = HexColor("#64748B")
SLATE_SOFT = HexColor("#E2E8F0")
SLATE_BG = HexColor("#F8FAFC")
RED = HexColor("#EF4444")
PURPLE = HexColor("#7C3AED")
TEAL = HexColor("#0F766E")


@dataclass
class FeatureCard:
    title: str
    description: str
    color: Color
    soft_color: Color


def rounded_box(
    pdf: canvas.Canvas,
    x: float,
    y: float,
    w: float,
    h: float,
    fill: Color = white,
    stroke: Color | None = SLATE_SOFT,
    radius: float = 14,
    stroke_width: float = 1,
) -> None:
    pdf.saveState()
    pdf.setLineWidth(stroke_width)
    if stroke is None:
        pdf.setStrokeColor(fill)
    else:
        pdf.setStrokeColor(stroke)
    pdf.setFillColor(fill)
    pdf.roundRect(x, y, w, h, radius, stroke=1 if stroke is not None else 0, fill=1)
    pdf.restoreState()


def wrap_text(text: str, font_name: str, font_size: float, max_width: float) -> list[str]:
    words = text.split()
    lines: list[str] = []
    current = ""
    for word in words:
        trial = word if not current else f"{current} {word}"
        if stringWidth(trial, font_name, font_size) <= max_width:
            current = trial
            continue
        if current:
            lines.append(current)
        current = word
    if current:
        lines.append(current)
    return lines


def draw_wrapped(
    pdf: canvas.Canvas,
    text: str,
    x: float,
    y: float,
    max_width: float,
    font_name: str = "Helvetica",
    font_size: float = 14,
    leading: float | None = None,
    color: Color = SLATE,
) -> float:
    leading = leading or (font_size + 4)
    lines = wrap_text(text, font_name, font_size, max_width)
    pdf.saveState()
    pdf.setFillColor(color)
    pdf.setFont(font_name, font_size)
    cursor = y
    for line in lines:
        pdf.drawString(x, cursor, line)
        cursor -= leading
    pdf.restoreState()
    return cursor


def draw_centered(
    pdf: canvas.Canvas,
    text: str,
    x: float,
    y: float,
    width: float,
    font_name: str = "Helvetica-Bold",
    font_size: float = 18,
    color: Color = SLATE,
) -> None:
    pdf.saveState()
    pdf.setFont(font_name, font_size)
    pdf.setFillColor(color)
    text_width = stringWidth(text, font_name, font_size)
    pdf.drawString(x + max((width - text_width) / 2, 0), y, text)
    pdf.restoreState()


def draw_chip(
    pdf: canvas.Canvas,
    x: float,
    y: float,
    text: str,
    fill: Color,
    text_color: Color = SLATE,
    font_size: float = 10.5,
) -> float:
    padding_x = 10
    padding_y = 5
    width = stringWidth(text, "Helvetica-Bold", font_size) + padding_x * 2
    height = font_size + padding_y * 2
    rounded_box(pdf, x, y, width, height, fill=fill, stroke=None, radius=10)
    pdf.setFont("Helvetica-Bold", font_size)
    pdf.setFillColor(text_color)
    pdf.drawString(x + padding_x, y + padding_y + 1, text)
    return width


def draw_bullet_list(
    pdf: canvas.Canvas,
    bullets: Sequence[str],
    x: float,
    y: float,
    width: float,
    font_size: float = 13,
    bullet_color: Color = BLUE,
    text_color: Color = SLATE,
    gap: float = 19,
) -> float:
    cursor = y
    for bullet in bullets:
        pdf.setFillColor(bullet_color)
        pdf.circle(x + 4, cursor + 4, 2.4, stroke=0, fill=1)
        cursor = draw_wrapped(
            pdf,
            bullet,
            x + 14,
            cursor,
            width - 14,
            font_name="Helvetica",
            font_size=font_size,
            leading=font_size + 3,
            color=text_color,
        )
        cursor -= max(gap - (font_size + 3), 6)
    return cursor


def draw_arrow(pdf: canvas.Canvas, x1: float, y1: float, x2: float, y2: float, color: Color = BLUE) -> None:
    pdf.saveState()
    pdf.setStrokeColor(color)
    pdf.setFillColor(color)
    pdf.setLineWidth(2)
    pdf.line(x1, y1, x2, y2)
    if abs(x2 - x1) >= abs(y2 - y1):
        direction = 1 if x2 >= x1 else -1
        pdf.line(x2, y2, x2 - 8 * direction, y2 + 4)
        pdf.line(x2, y2, x2 - 8 * direction, y2 - 4)
    else:
        direction = 1 if y2 >= y1 else -1
        pdf.line(x2, y2, x2 - 4, y2 - 8 * direction)
        pdf.line(x2, y2, x2 + 4, y2 - 8 * direction)
    pdf.restoreState()


def draw_logo(pdf: canvas.Canvas, x: float, y: float, width: float) -> None:
    if not LOGO_PATH.exists():
        return
    logo = ImageReader(str(LOGO_PATH))
    pdf.drawImage(logo, x, y, width=width, height=width, mask="auto", preserveAspectRatio=True)


def draw_phone(
    pdf: canvas.Canvas,
    x: float,
    y: float,
    w: float,
    h: float,
    variant: str,
) -> None:
    rounded_box(pdf, x, y, w, h, fill=HexColor("#0F172A"), stroke=None, radius=22)
    rounded_box(pdf, x + 6, y + 6, w - 12, h - 12, fill=white, stroke=None, radius=18)
    rounded_box(pdf, x + (w - 42) / 2, y + h - 12, 42, 5, fill=HexColor("#CBD5E1"), stroke=None, radius=4)

    screen_x = x + 12
    screen_y = y + 12
    screen_w = w - 24
    screen_h = h - 24

    rounded_box(pdf, screen_x, screen_y, screen_w, screen_h, fill=HexColor("#F8FAFC"), stroke=None, radius=14)
    rounded_box(pdf, screen_x, screen_y + screen_h - 32, screen_w, 32, fill=BLUE, stroke=None, radius=14)
    pdf.setFont("Helvetica-Bold", 9)
    pdf.setFillColor(white)
    pdf.drawString(screen_x + 10, screen_y + screen_h - 20, "JanHelp")

    if variant == "dashboard":
        for i, label in enumerate(("Live Stats", "Departments", "Quick Report")):
            card_y = screen_y + screen_h - 70 - (i * 38)
            rounded_box(pdf, screen_x + 8, card_y, screen_w - 16, 28, fill=white, stroke=SLATE_SOFT, radius=9)
            pdf.setFillColor(SLATE)
            pdf.setFont("Helvetica-Bold", 7.5)
            pdf.drawString(screen_x + 16, card_y + 16, label)
            pdf.setFillColor(BLUE)
            pdf.circle(screen_x + screen_w - 24, card_y + 14, 5, stroke=0, fill=1)
        rounded_box(pdf, screen_x + 8, screen_y + 18, screen_w - 16, 34, fill=SKY_SOFT, stroke=None, radius=10)
        pdf.setFillColor(SLATE)
        pdf.setFont("Helvetica-Bold", 7.5)
        pdf.drawString(screen_x + 14, screen_y + 37, "12 categories available")
    elif variant == "assistant":
        bubble_specs = [
            (screen_x + 10, screen_y + screen_h - 68, screen_w - 42, 24, SKY_SOFT),
            (screen_x + 28, screen_y + screen_h - 102, screen_w - 52, 22, GREEN_SOFT),
            (screen_x + 10, screen_y + screen_h - 134, screen_w - 40, 26, SKY_SOFT),
            (screen_x + 30, screen_y + screen_h - 170, screen_w - 54, 22, GREEN_SOFT),
        ]
        for bx, by, bw, bh, fill in bubble_specs:
            rounded_box(pdf, bx, by, bw, bh, fill=fill, stroke=None, radius=9)
        rounded_box(pdf, screen_x + 8, screen_y + 12, screen_w - 16, 20, fill=white, stroke=SLATE_SOFT, radius=8)
        pdf.setFillColor(SLATE_LIGHT)
        pdf.setFont("Helvetica", 6.7)
        pdf.drawString(screen_x + 14, screen_y + 19, "Describe issue in English / Hindi / Gujarati")
    elif variant == "submit":
        rounded_box(pdf, screen_x + 8, screen_y + screen_h - 72, screen_w - 16, 34, fill=white, stroke=SLATE_SOFT, radius=10)
        rounded_box(pdf, screen_x + 8, screen_y + screen_h - 118, screen_w - 16, 38, fill=AMBER_SOFT, stroke=None, radius=10)
        rounded_box(pdf, screen_x + 8, screen_y + 54, screen_w - 16, 54, fill=HexColor("#E2E8F0"), stroke=None, radius=10)
        pdf.setFillColor(SLATE)
        pdf.setFont("Helvetica-Bold", 7.5)
        pdf.drawString(screen_x + 14, screen_y + screen_h - 55, "Road/Pothole")
        pdf.drawString(screen_x + 14, screen_y + screen_h - 99, "AI proof check with Gemini")
        pdf.drawString(screen_x + 14, screen_y + 86, "Photo + location + details")
        rounded_box(pdf, screen_x + 22, screen_y + 16, screen_w - 44, 24, fill=BLUE, stroke=None, radius=10)
        pdf.setFillColor(white)
        pdf.setFont("Helvetica-Bold", 8)
        pdf.drawString(screen_x + 48, screen_y + 24, "Submit Complaint")
    else:
        steps = [
            ("SC482913", BLUE),
            ("Assigned to Road Dept", SKY),
            ("In progress", AMBER),
            ("Resolved + reopen window", GREEN),
        ]
        for i, (label, dot_color) in enumerate(steps):
            item_y = screen_y + screen_h - 64 - i * 34
            pdf.setFillColor(dot_color)
            pdf.circle(screen_x + 16, item_y, 4, stroke=0, fill=1)
            pdf.setStrokeColor(SLATE_SOFT)
            if i < len(steps) - 1:
                pdf.setLineWidth(1.2)
                pdf.line(screen_x + 16, item_y - 4, screen_x + 16, item_y - 24)
            pdf.setFillColor(SLATE)
            pdf.setFont("Helvetica-Bold", 7.2)
            pdf.drawString(screen_x + 28, item_y - 2, label)

def build_overlay() -> None:
    pdf = canvas.Canvas(str(OVERLAY_PDF), pagesize=(PAGE_WIDTH, PAGE_HEIGHT))

    draw_team_slide(pdf)
    pdf.showPage()

    draw_brief_slide(pdf)
    pdf.showPage()

    draw_opportunities_slide(pdf)
    pdf.showPage()

    draw_features_slide(pdf)
    pdf.showPage()

    draw_process_slide(pdf)
    pdf.showPage()

    draw_architecture_slide(pdf)
    pdf.showPage()

    draw_technology_slide(pdf)
    pdf.showPage()

    draw_snapshots_slide(pdf)
    pdf.showPage()

    draw_future_slide(pdf)
    pdf.showPage()

    draw_links_slide(pdf)
    pdf.save()


def draw_team_slide(pdf: canvas.Canvas) -> None:
    pdf.setFillColor(BLUE_DARK)
    pdf.setFont("Helvetica-Bold", 18)
    pdf.drawString(238, 150, TEAM_NAME)

    pdf.setFillColor(SLATE)
    pdf.setFont("Helvetica-Bold", 16)
    pdf.drawString(286, 110, TEAM_LEADER)

    rounded_box(pdf, 268, 14, 388, 68, fill=SLATE_BG, stroke=SLATE_SOFT, radius=16)
    pdf.setFillColor(BLUE)
    pdf.setFont("Helvetica-Bold", 13)
    pdf.drawString(284, 60, "Problem Statement")
    draw_wrapped(
        pdf,
        PROBLEM_STATEMENT,
        284,
        41,
        356,
        font_name="Helvetica",
        font_size=11.2,
        leading=13,
        color=SLATE,
    )

    rounded_box(pdf, 454, 120, 196, 116, fill=white, stroke=SLATE_SOFT, radius=18)
    draw_logo(pdf, 470, 176, 42)
    pdf.setFillColor(SLATE)
    pdf.setFont("Helvetica-Bold", 18)
    pdf.drawString(520, 198, "JanHelp")
    pdf.setFillColor(SLATE_LIGHT)
    pdf.setFont("Helvetica", 10.5)
    pdf.drawString(520, 181, "AI-enabled civic complaint platform")
    draw_chip(pdf, 470, 145, "Multilingual intake", fill=SKY_SOFT, text_color=BLUE)
    draw_chip(pdf, 470, 118, "Gemini proof verification", fill=GREEN_SOFT, text_color=GREEN)


def draw_brief_slide(pdf: canvas.Canvas) -> None:
    rounded_box(pdf, 34, 58, 652, 244, fill=white, stroke=SLATE_SOFT, radius=22)
    rounded_box(pdf, 34, 58, 238, 244, fill=HexColor("#EFF6FF"), stroke=None, radius=22)

    draw_logo(pdf, 56, 218, 48)
    pdf.setFillColor(BLUE_DARK)
    pdf.setFont("Helvetica-Bold", 26)
    pdf.drawString(116, 236, "JanHelp")
    pdf.setFillColor(SLATE)
    pdf.setFont("Helvetica-Bold", 13)
    pdf.drawString(56, 203, "Accessible urban grievance redressal")
    draw_bullet_list(
        pdf,
        [
            "Citizens report issues in English, Hindi, or Gujarati through a guided mobile app.",
            "Google Gemini 1.5 Flash verifies uploaded civic evidence before submission.",
            "The backend detects duplicates, routes the case to the nearest department, and tracks SLA progress.",
        ],
        54,
        176,
        200,
        font_size=10.3,
        gap=10,
    )

    rounded_box(pdf, 292, 76, 372, 208, fill=HexColor("#FCFCFD"), stroke=SLATE_SOFT, radius=18)
    pdf.setFillColor(SLATE)
    pdf.setFont("Helvetica-Bold", 17)
    pdf.drawString(314, 256, "Solution Summary")
    summary = (
        "JanHelp combines a Flutter citizen app, a Django REST backend, and AI-assisted verification for smarter urban "
        "complaint reporting. Citizens submit issues with location and media while the platform validates evidence, "
        "detects duplicates, routes each case to the nearest department, and adds live tracking and city analytics."
    )
    draw_wrapped(pdf, summary, 314, 230, 326, font_name="Helvetica", font_size=11.3, leading=15, color=SLATE)

    metric_y = 94
    metric_specs = [
        ("Citizen-first UX", "Low-friction reporting on mobile", SKY_SOFT, BLUE),
        ("AI + Governance", "Gemini proof checks + workflow routing", GREEN_SOFT, GREEN),
        ("Cloud-ready", "Vercel deployment + managed services", AMBER_SOFT, AMBER),
    ]
    x_positions = [314, 430, 546]
    for (title, desc, fill, accent), x in zip(metric_specs, x_positions):
        rounded_box(pdf, x, metric_y, 104, 72, fill=fill, stroke=None, radius=14)
        pdf.setFillColor(accent)
        pdf.setFont("Helvetica-Bold", 10.2)
        pdf.drawString(x + 10, metric_y + 46, title)
        draw_wrapped(pdf, desc, x + 10, metric_y + 30, 84, font_name="Helvetica", font_size=8.7, leading=11, color=SLATE)


def draw_opportunities_slide(pdf: canvas.Canvas) -> None:
    answer_cards = [
        (
            174,
            178,
            480,
            46,
            "Unlike static complaint forms, JanHelp combines multilingual guided intake, AI proof screening, duplicate suppression, and geo-based routing in one workflow.",
        ),
        (
            174,
            118,
            480,
            46,
            "The platform improves report quality, reduces wrong-category submissions, prevents repeated tickets, and sends each complaint to the nearest relevant department faster.",
        ),
        (
            174,
            58,
            480,
            46,
            "USP: a citizen-friendly mobile journey backed by Google AI verification, departmental SLA tracking, and city-scale analytics for accountability.",
        ),
    ]
    for x, y, w, h, text in answer_cards:
        rounded_box(pdf, x, y, w, h, fill=white, stroke=SLATE_SOFT, radius=16)
        pdf.setFillColor(BLUE)
        pdf.setFont("Helvetica-Bold", 10)
        pdf.drawString(x + 14, y + h - 16, "Answer")
        draw_wrapped(pdf, text, x + 14, y + h - 31, w - 28, font_name="Helvetica", font_size=11, leading=13, color=SLATE)


def draw_features_slide(pdf: canvas.Canvas) -> None:
    cards = [
        FeatureCard("Multilingual AI intake", "Users describe issues in English, Hindi, or Gujarati.", BLUE, SKY_SOFT),
        FeatureCard("OTP-secured onboarding", "Email OTP based login and role-aware access control.", GREEN, GREEN_SOFT),
        FeatureCard("Gemini proof verification", "Images are checked for category-relevant civic evidence.", AMBER, AMBER_SOFT),
        FeatureCard("Dynamic categories", "Categories and subcategories load from managed backend data.", PURPLE, HexColor("#F3E8FF")),
        FeatureCard("Duplicate detection", "Nearby repeat complaints are suppressed using geo-radius rules.", RED, HexColor("#FEE2E2")),
        FeatureCard("Nearest department routing", "Complaints auto-assign based on type, city, state, and distance.", TEAL, HexColor("#CCFBF1")),
        FeatureCard("Tracking, SLA, reopen", "Citizens monitor status, resolution windows, and follow-up actions.", BLUE_DARK, HexColor("#DBEAFE")),
        FeatureCard("Analytics and notifications", "Department workflows, heatmaps, reminders, and status alerts.", GREEN, HexColor("#DCFCE7")),
    ]

    left_x = 40
    right_x = 372
    top_y = 230
    card_w = 308
    card_h = 50
    gap_y = 14

    for idx, card in enumerate(cards):
        col_x = left_x if idx % 2 == 0 else right_x
        row = idx // 2
        y = top_y - row * (card_h + gap_y)
        rounded_box(pdf, col_x, y, card_w, card_h, fill=card.soft_color, stroke=None, radius=16)
        pdf.setFillColor(card.color)
        pdf.circle(col_x + 16, y + 25, 6, stroke=0, fill=1)
        pdf.setFillColor(SLATE)
        pdf.setFont("Helvetica-Bold", 12.2)
        pdf.drawString(col_x + 30, y + 31, card.title)
        pdf.setFont("Helvetica", 10.2)
        pdf.setFillColor(SLATE)
        pdf.drawString(col_x + 30, y + 15, card.description)


def draw_process_slide(pdf: canvas.Canvas) -> None:
    nodes = [
        (48, 226, 142, 58, BLUE, "1. Citizen Login", "OTP login or guest flow"),
        (212, 226, 142, 58, GREEN, "2. Describe Issue", "AI assistant captures context"),
        (376, 226, 142, 58, AMBER, "3. Add Proof", "Photo, location, and details"),
        (540, 226, 132, 58, PURPLE, "4. AI Validate", "Gemini proof screening"),
        (48, 104, 142, 58, RED, "5. Duplicate Check", "Prevent repeated tickets"),
        (212, 104, 142, 58, TEAL, "6. Route Department", "Nearest relevant office"),
        (376, 104, 142, 58, BLUE_DARK, "7. Track & Notify", "Status, SLA, reminders"),
        (540, 104, 132, 58, GREEN, "8. Resolve / Reopen", "Citizen feedback loop"),
    ]

    for x, y, w, h, accent, title, desc in nodes:
        rounded_box(pdf, x, y, w, h, fill=white, stroke=SLATE_SOFT, radius=18)
        rounded_box(pdf, x, y + h - 16, w, 16, fill=accent, stroke=None, radius=18)
        pdf.setFillColor(SLATE)
        pdf.setFont("Helvetica-Bold", 11.6)
        pdf.drawString(x + 12, y + 28, title)
        pdf.setFont("Helvetica", 9.4)
        pdf.setFillColor(SLATE_LIGHT)
        pdf.drawString(x + 12, y + 13, desc)

    draw_arrow(pdf, 190, 255, 212, 255)
    draw_arrow(pdf, 354, 255, 376, 255)
    draw_arrow(pdf, 518, 255, 540, 255)
    draw_arrow(pdf, 606, 226, 606, 172)
    draw_arrow(pdf, 540, 133, 518, 133)
    draw_arrow(pdf, 354, 133, 376, 133)
    draw_arrow(pdf, 190, 133, 212, 133)

    rounded_box(pdf, 116, 26, 488, 48, fill=HexColor("#EFF6FF"), stroke=None, radius=16)
    draw_centered(
        pdf,
        "Outcome: cleaner complaints, faster routing, fewer duplicates, and better citizen trust.",
        126,
        44,
        468,
        font_name="Helvetica-Bold",
        font_size=12.2,
        color=BLUE_DARK,
    )


def draw_architecture_slide(pdf: canvas.Canvas) -> None:
    rounded_box(pdf, 52, 152, 186, 100, fill=HexColor("#F8FAFC"), stroke=SLATE_SOFT, radius=18)
    pdf.setFillColor(BLUE_DARK)
    pdf.setFont("Helvetica-Bold", 15)
    pdf.drawString(74, 228, "Citizen Layer")
    draw_bullet_list(
        pdf,
        [
            "Flutter mobile app",
            "Dashboard + tracking screens",
            "AI chat and complaint submission",
        ],
        72,
        208,
        146,
        font_size=9.8,
        gap=8,
    )

    rounded_box(pdf, 268, 140, 184, 122, fill=white, stroke=SLATE_SOFT, radius=18)
    pdf.setFillColor(BLUE)
    pdf.setFont("Helvetica-Bold", 16)
    pdf.drawString(290, 238, "Application Core")
    draw_bullet_list(
        pdf,
        [
            "Django REST API",
            "Authentication, OTP, JWT",
            "Complaint workflow engine",
            "Category / department services",
            "Tracking, SLA, reopen logic",
        ],
        288,
        214,
        144,
        font_size=9.6,
        gap=7,
    )

    rounded_box(pdf, 482, 152, 186, 100, fill=HexColor("#FAF5FF"), stroke=SLATE_SOFT, radius=18)
    pdf.setFillColor(PURPLE)
    pdf.setFont("Helvetica-Bold", 15)
    pdf.drawString(502, 228, "Stakeholder Layer")
    draw_bullet_list(
        pdf,
        [
            "Department dashboards",
            "City admin analytics",
            "Heatmaps and complaint views",
            "Operational notifications",
        ],
        500,
        208,
        146,
        font_size=9.8,
        gap=8,
        bullet_color=PURPLE,
    )

    rounded_box(pdf, 52, 22, 186, 92, fill=SKY_SOFT, stroke=None, radius=18)
    pdf.setFillColor(BLUE)
    pdf.setFont("Helvetica-Bold", 14)
    pdf.drawString(72, 90, "AI Services")
    draw_wrapped(
        pdf,
        "Google Gemini 1.5 Flash proof verification, SmartCityAI extraction, duplicate heuristics, and routing decisions.",
        72,
        70,
        146,
        font_name="Helvetica",
        font_size=10.1,
        leading=13,
        color=SLATE,
    )

    rounded_box(pdf, 268, 22, 184, 92, fill=GREEN_SOFT, stroke=None, radius=18)
    pdf.setFillColor(GREEN)
    pdf.setFont("Helvetica-Bold", 14)
    pdf.drawString(288, 90, "Data Layer")
    draw_wrapped(
        pdf,
        "Supabase PostgreSQL, complaint metadata, categories, departments, and session/cache support.",
        288,
        70,
        144,
        font_name="Helvetica",
        font_size=10.1,
        leading=13,
        color=SLATE,
    )

    rounded_box(pdf, 482, 22, 186, 92, fill=AMBER_SOFT, stroke=None, radius=18)
    pdf.setFillColor(AMBER)
    pdf.setFont("Helvetica-Bold", 14)
    pdf.drawString(502, 90, "Cloud Services")
    draw_wrapped(
        pdf,
        "Vercel deployment, Cloudinary media storage, email services, and push-ready notification support.",
        502,
        70,
        146,
        font_name="Helvetica",
        font_size=10.1,
        leading=13,
        color=SLATE,
    )

    draw_arrow(pdf, 238, 202, 268, 202)
    draw_arrow(pdf, 452, 202, 482, 202)
    draw_arrow(pdf, 360, 140, 360, 114)
    draw_arrow(pdf, 168, 152, 146, 114)
    draw_arrow(pdf, 552, 152, 574, 114)


def draw_technology_slide(pdf: canvas.Canvas) -> None:
    groups = [
        ("Mobile & UX", ["Flutter", "Dart", "Provider", "SharedPreferences"], SKY_SOFT, BLUE),
        ("Backend & APIs", ["Python", "Django", "DRF", "JWT"], GREEN_SOFT, GREEN),
        ("AI & Intelligence", ["Google Gemini 1.5 Flash", "SmartCityAI", "NLP Extraction", "Duplicate Logic"], AMBER_SOFT, AMBER),
        ("Cloud & Data", ["Vercel", "Supabase PostgreSQL", "Cloudinary", "Redis / Cache"], HexColor("#EDE9FE"), PURPLE),
        ("Maps & Alerts", ["Geolocation", "Map-ready services", "Resend + Push Alerts"], HexColor("#CCFBF1"), TEAL),
    ]

    positions = [
        (42, 188, 200, 122),
        (260, 188, 200, 122),
        (478, 188, 200, 122),
        (152, 48, 200, 112),
        (370, 48, 200, 112),
    ]

    for (title, chips, fill, accent), (x, y, w, h) in zip(groups, positions):
        rounded_box(pdf, x, y, w, h, fill=fill, stroke=None, radius=18)
        pdf.setFillColor(accent)
        pdf.setFont("Helvetica-Bold", 14)
        pdf.drawString(x + 16, y + h - 24, title)
        chip_x = x + 16
        chip_y = y + h - 52
        current_x = chip_x
        current_y = chip_y
        for chip in chips:
            chip_width = stringWidth(chip, "Helvetica-Bold", 9.5) + 20
            if current_x + chip_width > x + w - 16:
                current_x = chip_x
                current_y -= 26
            actual_width = draw_chip(pdf, current_x, current_y, chip, fill=white, text_color=SLATE, font_size=9.5)
            current_x += actual_width + 8

    rounded_box(pdf, 42, 26, 636, 16, fill=HexColor("#EFF6FF"), stroke=None, radius=10)
    draw_centered(pdf, "Cloud deployment + Google AI are already reflected in the current stack.", 52, 31, 616, font_name="Helvetica-Bold", font_size=10.8, color=BLUE_DARK)


def draw_snapshots_slide(pdf: canvas.Canvas) -> None:
    label_specs = [
        (72, "Home Dashboard"),
        (286, "AI Assistant"),
        (500, "Tracking Flow"),
    ]
    for x, label in label_specs:
        rounded_box(pdf, x + 12, 286, 124, 20, fill=HexColor("#EFF6FF"), stroke=None, radius=10)
        draw_centered(pdf, label, x + 12, 292, 124, font_name="Helvetica-Bold", font_size=8.8, color=BLUE_DARK)

    draw_phone(pdf, 72, 58, 148, 210, "dashboard")
    draw_phone(pdf, 286, 58, 148, 210, "assistant")
    draw_phone(pdf, 500, 58, 148, 210, "tracking")

    rounded_box(pdf, 118, 12, 484, 30, fill=white, stroke=SLATE_SOFT, radius=14)
    draw_centered(
        pdf,
        "Other implemented screens: OTP login, category selection, proof upload, location picker, and complaint submission.",
        128,
        22,
        464,
        font_name="Helvetica",
        font_size=9.4,
        color=SLATE,
    )


def draw_future_slide(pdf: canvas.Canvas) -> None:
    rounded_box(pdf, 42, 78, 302, 210, fill=white, stroke=SLATE_SOFT, radius=20)
    rounded_box(pdf, 376, 78, 302, 210, fill=white, stroke=SLATE_SOFT, radius=20)

    pdf.setFillColor(BLUE_DARK)
    pdf.setFont("Helvetica-Bold", 16)
    pdf.drawString(64, 258, "Near-Term Development")
    draw_bullet_list(
        pdf,
        [
            "Voice-first complaint filing using speech-to-text for low-literacy users.",
            "Support for more Indian languages and localized assistant prompts.",
            "Faster department escalation when SLA breaches are predicted.",
            "Expanded feedback loop with post-resolution quality scoring.",
        ],
        62,
        232,
        262,
        font_size=11,
        gap=13,
    )

    pdf.setFillColor(PURPLE)
    pdf.setFont("Helvetica-Bold", 16)
    pdf.drawString(398, 258, "City-Scale Vision")
    draw_bullet_list(
        pdf,
        [
            "Heatmap-based hotspot detection for ward-level planning and preventive maintenance.",
            "Cross-department orchestration for multi-issue complaints in the same locality.",
            "Citizen-to-admin insights dashboard for budget and service prioritization.",
            "API integrations with municipal ERP, helpline, and WhatsApp / IVR channels.",
        ],
        396,
        232,
        262,
        font_size=11,
        gap=13,
        bullet_color=PURPLE,
    )

    rounded_box(pdf, 170, 28, 380, 34, fill=HexColor("#EFF6FF"), stroke=None, radius=14)
    draw_centered(pdf, "JanHelp is designed to start as an MVP and scale into a city operations platform.", 180, 40, 360, font_name="Helvetica-Bold", font_size=11, color=BLUE_DARK)


def fit_link_font(text: str, max_width: float, start: float = 11.5, minimum: float = 8.0) -> float:
    size = start
    while size > minimum and stringWidth(text, "Helvetica", size) > max_width:
        size -= 0.3
    return size


def draw_link_row(pdf: canvas.Canvas, x: float, y: float, number: int, label: str, value: str, accent: Color, pending: bool = False) -> None:
    rounded_box(pdf, x, y, 620, 44, fill=white, stroke=SLATE_SOFT, radius=14)
    pdf.setFillColor(accent)
    pdf.circle(x + 18, y + 22, 10, stroke=0, fill=1)
    pdf.setFillColor(white)
    pdf.setFont("Helvetica-Bold", 11)
    number_width = stringWidth(str(number), "Helvetica-Bold", 11)
    pdf.drawString(x + 18 - number_width / 2, y + 18, str(number))
    pdf.setFillColor(SLATE)
    pdf.setFont("Helvetica-Bold", 12.5)
    pdf.drawString(x + 38, y + 24, label)
    link_color = AMBER if pending else BLUE_DARK
    link_size = fit_link_font(value, 560)
    pdf.setFont("Helvetica", link_size)
    pdf.setFillColor(link_color)
    pdf.drawString(x + 38, y + 10, value)


def draw_links_slide(pdf: canvas.Canvas) -> None:
    rounded_box(pdf, 18, 12, 684, 296, fill=white, stroke=None, radius=14)
    draw_link_row(pdf, 50, 192, 1, "GitHub Public Repository", GITHUB_REPO, BLUE)
    draw_link_row(pdf, 50, 138, 2, "Demo Video Link (3 Minutes)", DEMO_VIDEO_LINK, AMBER, pending=True)
    draw_link_row(pdf, 50, 84, 3, "MVP Link", MVP_LINK, GREEN)
    draw_link_row(pdf, 50, 30, 4, "Working Prototype Link", WORKING_PROTOTYPE_LINK, PURPLE)


def merge_with_template() -> None:
    if not TEMPLATE_PDF.exists():
        raise FileNotFoundError(f"Template not found: {TEMPLATE_PDF}")

    template_reader = PdfReader(str(TEMPLATE_PDF))
    overlay_reader = PdfReader(str(OVERLAY_PDF))
    writer = PdfWriter()

    for overlay_index, template_index in enumerate(TEMPLATE_PAGE_INDICES):
        base_page = template_reader.pages[template_index]
        base_page.merge_page(overlay_reader.pages[overlay_index])
        writer.add_page(base_page)

    with OUTPUT_PDF.open("wb") as fh:
        writer.write(fh)


def main() -> None:
    build_overlay()
    merge_with_template()
    print(f"Created: {OUTPUT_PDF}")


if __name__ == "__main__":
    main()
