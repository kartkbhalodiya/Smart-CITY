const pptxgen = require("pptxgenjs");
const React = require("react");
const ReactDOMServer = require("react-dom/server");

const {
  FaAmbulance,
  FaBell,
  FaBuilding,
  FaBullseye,
  FaChartBar,
  FaChartLine,
  FaCheckCircle,
  FaCity,
  FaClock,
  FaClipboardCheck,
  FaClipboardList,
  FaCloud,
  FaCog,
  FaComments,
  FaDatabase,
  FaEnvelope,
  FaExclamationTriangle,
  FaFileAlt,
  FaFingerprint,
  FaGlobe,
  FaHandshake,
  FaHeadset,
  FaIdCard,
  FaLayerGroup,
  FaLightbulb,
  FaLock,
  FaMapMarkedAlt,
  FaMapMarkerAlt,
  FaMicrophone,
  FaMobileAlt,
  FaPhone,
  FaProjectDiagram,
  FaRedo,
  FaRobot,
  FaRoute,
  FaSatelliteDish,
  FaSearch,
  FaServer,
  FaShieldAlt,
  FaSms,
  FaStar,
  FaTasks,
  FaTools,
  FaUserCheck,
  FaUsers,
  FaWhatsapp,
  FaWrench,
} = require("react-icons/fa");

function iconSvgData(IconComp, color = "#1565C0", size = 256) {
  const svg = ReactDOMServer.renderToStaticMarkup(
    React.createElement(IconComp, { color, size: String(size) })
  );
  return "data:image/svg+xml;base64," + Buffer.from(svg).toString("base64");
}

const C = {
  navy: "1565C0",
  dark: "0D47A1",
  blue: "1976D2",
  lightBlue: "42A5F5",
  paleBlue: "E3F2FD",
  ink: "0F172A",
  white: "FFFFFF",
  offWhite: "F8FBFF",
  gray: "546E7A",
  paleGray: "ECEFF1",
  green: "2E7D32",
  paleGreen: "E8F5E9",
  amber: "E65100",
  paleAmber: "FFF3E0",
  red: "C62828",
  paleRed: "FFEBEE",
  teal: "00695C",
};

const pptx = new pptxgen();
pptx.layout = "LAYOUT_WIDE";
pptx.author = "Team JanHelp";
pptx.company = "JanHelp";
pptx.subject = "JanHelp Smart City Complaint Management Platform";
pptx.title = "JanHelp - AI Smart City Complaint Platform";
pptx.lang = "en-US";
pptx.theme = {
  headFontFace: "Aptos Display",
  bodyFontFace: "Aptos",
  lang: "en-US",
};
pptx.defineLayout({ name: "LAYOUT_WIDE", width: 13.333, height: 7.5 });

const S = pptx.ShapeType;
const CH = pptx.ChartType;

function shadow(opacity = 0.14) {
  return { type: "outer", color: "000000", opacity, blur: 2, angle: 45, distance: 1 };
}

function addRect(slide, x, y, w, h, color, line = color, opts = {}) {
  slide.addShape(S.rect, {
    x, y, w, h,
    fill: { color, transparency: opts.transparency || 0 },
    line: { color: line || color, width: opts.lineW || 1, transparency: opts.lineTransparency || 0 },
    radius: opts.radius || 0.12,
    shadow: opts.shadow ? shadow(opts.shadowOpacity || 0.12) : undefined,
  });
}

function addIcon(slide, Icon, x, y, w, h, color = C.navy) {
  slide.addImage({ data: iconSvgData(Icon, "#" + color), x, y, w, h });
}

function addText(slide, text, x, y, w, h, opts = {}) {
  slide.addText(text, {
    x, y, w, h,
    fontFace: opts.fontFace || "Aptos",
    fontSize: opts.fontSize || 10,
    color: opts.color || C.ink,
    bold: opts.bold || false,
    italic: opts.italic || false,
    align: opts.align || "left",
    valign: opts.valign || "mid",
    margin: opts.margin === undefined ? 0.04 : opts.margin,
    breakLine: opts.breakLine || false,
    fit: opts.fit || "shrink",
    wrap: opts.wrap !== false,
  });
}

function addBanner(slide, title, page) {
  slide.background = { color: C.white };
  addRect(slide, 0, 0, 13.333, 0.82, C.dark, C.dark, { radius: 0 });
  addText(slide, "JAN", 0.28, 0.12, 0.62, 0.42, { color: C.white, bold: true, fontSize: 21, margin: 0 });
  addText(slide, "HELP", 0.88, 0.12, 0.9, 0.42, { color: "90CAF9", bold: true, fontSize: 21, margin: 0 });
  addText(slide, title, 2.05, 0.14, 9.6, 0.44, { color: "BBDEFB", fontSize: 12.5, italic: true, margin: 0 });
  addText(slide, page, 11.9, 0.18, 1.15, 0.28, { color: "BBDEFB", fontSize: 7.5, align: "right", margin: 0 });
}

function addSection(slide, label, x, y, w) {
  addRect(slide, x, y, w, 0.28, C.navy, C.navy, { radius: 0.05 });
  addText(slide, label, x + 0.04, y + 0.02, w - 0.08, 0.22, {
    color: C.white, bold: true, fontSize: 8.2, align: "center", margin: 0,
  });
}

function addCard(slide, x, y, w, h, opts = {}) {
  addRect(slide, x, y, w, h, opts.fill || C.white, opts.border || "BBDEFB", {
    radius: opts.radius || 0.12,
    lineW: opts.lineW || 1,
    shadow: opts.shadow,
    shadowOpacity: opts.shadowOpacity || 0.10,
  });
}

function addMiniFeature(slide, Icon, title, body, x, y, w, color = C.navy) {
  addCard(slide, x, y, w, 0.82, { fill: C.paleBlue, border: "90CAF9" });
  addIcon(slide, Icon, x + 0.12, y + 0.18, 0.32, 0.32, color);
  addText(slide, title, x + 0.52, y + 0.08, w - 0.6, 0.24, { color, bold: true, fontSize: 7.8 });
  addText(slide, body, x + 0.52, y + 0.34, w - 0.6, 0.38, { color: C.gray, fontSize: 6.7 });
}

function addStat(slide, value, label, x, y, w, color = C.navy) {
  addCard(slide, x, y, w, 0.82, { fill: C.white, border: "90CAF9" });
  addText(slide, value, x, y + 0.08, w, 0.38, { color, bold: true, fontSize: 21, align: "center", margin: 0 });
  addText(slide, label, x + 0.05, y + 0.48, w - 0.1, 0.25, { color: C.gray, fontSize: 7.3, align: "center", margin: 0 });
}

function addWorkflowNode(slide, Icon, title, body, x, y, w, h, color = C.navy, fill = C.paleBlue) {
  addCard(slide, x, y, w, h, { fill, border: "90CAF9", shadow: true, shadowOpacity: 0.08 });
  addIcon(slide, Icon, x + 0.14, y + 0.17, 0.36, 0.36, color);
  addText(slide, title, x + 0.6, y + 0.1, w - 0.7, 0.26, { color, bold: true, fontSize: 8.5 });
  addText(slide, body, x + 0.6, y + 0.39, w - 0.7, h - 0.46, { color: C.gray, fontSize: 6.9 });
}

function addLine(slide, x, y, w, h, color = C.navy, width = 1.2, beginArrow = false, endArrow = true) {
  slide.addShape(S.line, {
    x, y, w, h,
    line: {
      color,
      width,
      beginArrowType: beginArrow ? "triangle" : "none",
      endArrowType: endArrow ? "triangle" : "none",
    },
  });
}

function addPlainList(slide, items, x, y, w, color = C.gray, iconColor = C.navy, gap = 0.3) {
  items.forEach((item, i) => {
    addIcon(slide, FaCheckCircle, x, y + i * gap + 0.035, 0.13, 0.13, iconColor);
    addText(slide, item, x + 0.18, y + i * gap, w - 0.18, 0.22, { color, fontSize: 7.6, margin: 0 });
  });
}

function addFooter(slide, page) {
  addText(slide, page, 0.15, 7.18, 1.8, 0.2, { color: C.gray, fontSize: 6.8, margin: 0 });
}

function addBottomMessage(slide, text) {
  addCard(slide, 0.18, 6.22, 12.97, 0.62, { fill: C.dark, border: C.dark });
  addText(slide, text, 0.3, 6.28, 12.72, 0.5, {
    color: C.white, bold: true, fontSize: 11.5, align: "center", margin: 0,
  });
}

// Slide 1
{
  const s = pptx.addSlide();
  s.background = { color: C.white };
  addRect(s, 0, 0, 13.333, 2.72, C.dark, C.dark, { radius: 0 });
  addRect(s, 0, 2.72, 13.333, 0.1, C.lightBlue, C.lightBlue, { radius: 0 });
  addText(s, "JAN", 0.5, 0.25, 1.15, 0.72, { color: C.white, bold: true, fontSize: 48, margin: 0 });
  addText(s, "HELP", 1.62, 0.25, 2.3, 0.72, { color: "90CAF9", bold: true, fontSize: 48, margin: 0 });
  addText(s, "AI-Powered Smart City Complaint Management Platform", 0.55, 1.24, 8.6, 0.35, { color: "BBDEFB", fontSize: 17, margin: 0 });
  addText(s, "One complaint, verified by AI, delivered to the right department.", 0.55, 1.78, 8.4, 0.45, { color: "64B5F6", fontSize: 13, italic: true, margin: 0 });
  addCard(s, 10.35, 0.28, 2.65, 1.35, { fill: C.navy, border: "90CAF9" });
  addText(s, "TEAM JANHELP", 10.4, 0.34, 2.55, 0.25, { color: "90CAF9", bold: true, fontSize: 8.8, align: "center", margin: 0 });
  addPlainList(s, ["Smart technology", "Citizen first", "Better governance", "Stronger cities"], 10.55, 0.66, 2.3, C.white, "90CAF9", 0.22);

  const features = [
    [FaRobot, "AI Verification", "Gemini proof analysis"],
    [FaSearch, "Duplicate Check", "Reduces repeated reports"],
    [FaRoute, "Smart Routing", "Nearest department assignment"],
    [FaClock, "Live Tracking", "Status and timeline"],
    [FaShieldAlt, "Transparency", "Clear accountability"],
    [FaRedo, "Reopen Flow", "Feedback if not solved"],
  ];
  features.forEach((f, i) => addMiniFeature(s, f[0], f[1], f[2], 0.32 + i * 2.13, 3.05, 1.95));

  addSection(s, "COMPLAINT LIFECYCLE", 0.32, 4.16, 2.3);
  const life = [
    ["Report", "Issue and proof"],
    ["Verify", "AI proof check"],
    ["Check", "Duplicate filter"],
    ["Assign", "Nearest dept"],
    ["Resolve", "Field work"],
    ["Feedback", "Citizen rating"],
    ["Reopen", "If not fixed"],
  ];
  life.forEach((l, i) => {
    const x = 0.32 + i * 1.82;
    addCard(s, x, 4.55, 1.65, 0.68, { fill: "EFF6FF", border: "90CAF9" });
    addText(s, l[0].toUpperCase(), x + 0.05, 4.61, 1.55, 0.18, { color: C.navy, bold: true, fontSize: 7.3, align: "center", margin: 0 });
    addText(s, l[1], x + 0.05, 4.84, 1.55, 0.26, { color: C.gray, fontSize: 6.4, align: "center", margin: 0 });
    if (i < life.length - 1) addLine(s, x + 1.65, 4.89, 0.13, 0, C.navy, 0.8);
  });
  addBottomMessage(s, "Mission: verified complaints, accountable departments, faster civic resolution.");
  addFooter(s, "SLIDE 1 OF 15");
}

// Slide 2
{
  const s = pptx.addSlide();
  addBanner(s, "SLIDE 2 OF 15 - THE REAL-WORLD PROBLEM", "02 / 15");
  addCard(s, 0.25, 1.05, 3.45, 1.46, { fill: C.paleBlue, border: "90CAF9" });
  addText(s, "THE REALITY", 0.35, 1.16, 3.2, 0.25, { color: C.navy, bold: true, fontSize: 10 });
  addText(s, "Cities do not fail only because citizens cannot complain. They fail because complaints become unreliable, unverified and untrackable before they reach the right people.", 0.35, 1.48, 3.2, 0.78, { color: C.gray, fontSize: 8.4 });

  addText(s, "WHAT GOES WRONG?", 4.02, 1.05, 3.2, 0.28, { color: C.red, bold: true, fontSize: 10, margin: 0 });
  const wrongs = [
    [FaBuilding, "Wrong department"], [FaMapMarkerAlt, "Missing location"],
    [FaFileAlt, "Weak evidence"], [FaSearch, "Duplicate reports"],
    [FaClock, "Slow updates"], [FaProjectDiagram, "Manual forwarding"],
    [FaUserCheck, "Unclear ownership"], [FaClipboardCheck, "No proof of work"],
    [FaRedo, "No reopen loop"], [FaShieldAlt, "Low accountability"],
    [FaUsers, "Citizen frustration"], [FaDatabase, "Poor city data"],
  ];
  wrongs.forEach((w, i) => {
    const col = i < 6 ? 0 : 1;
    const row = i < 6 ? i : i - 6;
    addIcon(s, w[0], 4.05 + col * 3.05, 1.42 + row * 0.26, 0.14, 0.14, C.red);
    addText(s, w[1], 4.25 + col * 3.05, 1.39 + row * 0.26, 2.65, 0.2, { color: C.red, fontSize: 7.4, margin: 0 });
  });

  addCard(s, 0.25, 2.78, 12.82, 1.2, { fill: C.paleAmber, border: "FFE082" });
  addText(s, "BREAKDOWN PATH", 0.35, 2.88, 2.1, 0.24, { color: C.amber, bold: true, fontSize: 8.7 });
  const breakSteps = ["Problem", "Search", "Manual form", "Missing info", "Manual duplicate check", "Forwarding", "No status", "False closure", "Lost trust"];
  breakSteps.forEach((b, i) => {
    const x = 0.35 + i * 1.38;
    addCard(s, x, 3.2, 1.25, 0.5, { fill: i === breakSteps.length - 1 ? C.paleRed : "FFFFF8", border: i === breakSteps.length - 1 ? "EF9A9A" : "FFE082" });
    addText(s, b, x + 0.04, 3.25, 1.17, 0.34, { color: i === breakSteps.length - 1 ? C.red : C.amber, bold: i === breakSteps.length - 1, fontSize: 6.5, align: "center", margin: 0 });
    if (i < breakSteps.length - 1) addLine(s, x + 1.25, 3.45, 0.08, 0, C.amber, 0.6);
  });

  addSection(s, "IMPACT ON CITIES", 0.25, 4.32, 2.2);
  const impacts = ["Slow resolution", "High cost", "Low trust", "Wasted manpower", "Poor data", "No accountability", "Low transparency", "Overloaded teams", "Repeated cases", "Public frustration"];
  impacts.forEach((imp, i) => {
    const col = i % 5;
    const row = Math.floor(i / 5);
    addCard(s, 0.25 + col * 1.42, 4.72 + row * 0.5, 1.32, 0.4, { fill: C.paleBlue, border: "90CAF9" });
    addText(s, imp, 0.3 + col * 1.42, 4.78 + row * 0.5, 1.22, 0.25, { color: C.navy, bold: true, fontSize: 6.5, align: "center", margin: 0 });
  });

  addCard(s, 7.6, 4.66, 5.45, 0.95, { fill: C.navy, border: C.navy });
  addText(s, "THIS IS EXACTLY WHAT JANHELP SOLVES.", 7.75, 4.88, 5.15, 0.45, { color: C.white, bold: true, fontSize: 16, align: "center", margin: 0 });
  addBottomMessage(s, "JanHelp converts messy citizen input into a verified, routed and trackable civic work order.");
}

// Slide 3
{
  const s = pptx.addSlide();
  addBanner(s, "SLIDE 3 OF 15 - END-TO-END ARCHITECTURE", "03 / 15");
  addText(s, "AI at the core. Citizen first. Resolution always.", 0.2, 0.92, 12.9, 0.3, { color: C.navy, italic: true, fontSize: 11, align: "center" });

  addSection(s, "1. MULTI-CHANNEL INTAKE", 0.25, 1.32, 3.05);
  const channels = [[FaMobileAlt, "Mobile app"], [FaComments, "AI chatbot"], [FaMicrophone, "Voice assistant"], [FaGlobe, "Web portal"], [FaHeadset, "IVR or call"], [FaWhatsapp, "WhatsApp bot"]];
  channels.forEach((ch, i) => addMiniFeature(s, ch[0], ch[1], "Citizen access path", 0.28, 1.68 + i * 0.63, 3.0));

  addSection(s, "2. JANHELP AI CORE ENGINE", 3.55, 1.32, 4.8);
  const ai = [
    [FaRobot, "Complaint understanding"], [FaFingerprint, "Image verification"],
    [FaClipboardCheck, "Video verification"], [FaSearch, "Duplicate detection"],
    [FaShieldAlt, "Fraud detection"], [FaBullseye, "Severity prediction"],
    [FaMapMarkedAlt, "Location validation"], [FaRoute, "Smart routing"],
    [FaClock, "SLA prediction"], [FaCheckCircle, "Resolution validation"],
  ];
  ai.forEach((a, i) => {
    const col = i % 2;
    const row = Math.floor(i / 2);
    addMiniFeature(s, a[0], a[1], "Structured AI decision", 3.58 + col * 2.43, 1.68 + row * 0.63, 2.35);
  });

  addSection(s, "3. CITY OPERATIONS", 8.62, 1.32, 4.45);
  const ops = [
    [FaRoute, "Smart routing", "Finds nearest matching department"],
    [FaTasks, "Work order", "Creates actionable department task"],
    [FaBell, "Notifications", "Alerts department and citizen"],
    [FaTools, "Field execution", "Tracks work and proof"],
    [FaChartBar, "Dashboards", "Reports, heatmaps and SLA"],
  ];
  ops.forEach((o, i) => addMiniFeature(s, o[0], o[1], o[2], 8.65, 1.68 + i * 0.72, 4.35));

  addSection(s, "TRACKING TO ACCOUNTABILITY", 0.25, 5.68, 12.82);
  const track = ["Registered", "AI verified", "Assigned", "In progress", "Resolution proof", "Citizen rating", "Reopen if needed"];
  track.forEach((t, i) => {
    const x = 0.35 + i * 1.82;
    addCard(s, x, 6.05, 1.55, 0.52, { fill: C.paleBlue, border: "90CAF9" });
    addText(s, t, x + 0.04, 6.13, 1.47, 0.28, { color: C.navy, bold: true, fontSize: 7.2, align: "center", margin: 0 });
    if (i < track.length - 1) addLine(s, x + 1.55, 6.31, 0.15, 0, C.navy, 0.8);
  });
}

// Slide 4
{
  const s = pptx.addSlide();
  addBanner(s, "SLIDE 4 OF 15 - VERIFIED AND ACCOUNTABLE WORKFLOW", "04 / 15");
  addText(s, "From citizen report to ground action in a structured way.", 0.2, 0.92, 12.9, 0.3, { color: C.navy, italic: true, fontSize: 10.5, align: "center" });

  addSection(s, "1. COMPLAINT CREATION", 0.25, 1.28, 3.4);
  addCard(s, 0.28, 1.62, 3.32, 2.18, { fill: C.paleBlue, border: "90CAF9" });
  addIcon(s, FaClipboardList, 0.48, 1.85, 0.55, 0.55);
  addPlainList(s, ["GPS and address", "Category and subcategory", "Photo or video proof", "Description", "Reporter details"], 1.2, 1.8, 2.25, C.gray, C.navy, 0.33);

  addSection(s, "2. AI VERIFICATION LAYER", 3.85, 1.28, 5.25);
  const verify = [
    [FaFingerprint, "Image quality", "Rejects dark, blank or weak images"],
    [FaRobot, "Gemini proof", "Matches evidence to issue"],
    [FaSearch, "Duplicate check", "Prevents repeated tickets"],
    [FaShieldAlt, "Fraud signals", "Flags suspicious reports"],
    [FaExclamationTriangle, "Severity", "Predicts urgency and risk"],
    [FaClock, "SLA estimate", "Predicts resolution timing"],
  ];
  verify.forEach((v, i) => addMiniFeature(s, v[0], v[1], v[2], 3.88 + (i % 2) * 2.58, 1.62 + Math.floor(i / 2) * 0.78, 2.46));

  addSection(s, "3. ROUTING AND ASSIGNMENT", 9.35, 1.28, 3.75);
  addCard(s, 9.38, 1.62, 3.68, 2.55, { fill: C.paleBlue, border: "90CAF9" });
  addIcon(s, FaRoute, 9.62, 1.9, 0.56, 0.56);
  addPlainList(s, ["Find nearest department", "Check active departments", "Set priority and SLA", "Create work order", "Notify department"], 10.35, 1.86, 2.5, C.gray, C.navy, 0.35);

  addSection(s, "4. ACTION, PROOF AND REOPEN", 0.25, 4.55, 12.82);
  const bottom = [
    [FaTasks, "Department queue"], [FaWrench, "Field action"], [FaClipboardCheck, "Resolution proof"],
    [FaStar, "Citizen rating"], [FaRedo, "Reopen if not fixed"],
  ];
  bottom.forEach((b, i) => {
    const x = 0.35 + i * 2.5;
    addWorkflowNode(s, b[0], b[1], "Part of the same complaint lifecycle.", x, 4.95, 2.15, 0.8);
    if (i < bottom.length - 1) addLine(s, x + 2.15, 5.35, 0.24, 0, C.navy, 0.8);
  });
  addBottomMessage(s, "AI filters noise. Departments get actionable work. Citizens get transparent accountability.");
}

// Slide 5
{
  const s = pptx.addSlide();
  addBanner(s, "SLIDE 5 OF 15 - MULTI-CHANNEL COMPLAINT INTAKE", "05 / 15");
  addText(s, "Report your issue, your way.", 0.2, 0.92, 12.9, 0.28, { color: C.navy, italic: true, fontSize: 11, align: "center" });

  const channels = [
    [FaMobileAlt, "Manual app input", "Structured form, GPS, proof and contact.", "Core"],
    [FaRobot, "AI chat assistant", "Guided complaint capture from natural language.", "Core"],
    [FaMicrophone, "Voice assistant", "Speak the issue and confirm the draft.", "Advanced"],
    [FaPhone, "IVR or call", "Report without smartphone or internet.", "2.0"],
    [FaWhatsapp, "WhatsApp bot", "Media upload, tracking and reopen in chat.", "2.0"],
    [FaGlobe, "Web portal", "Browser-based complaint and tracking flow.", "Core"],
  ];
  channels.forEach((ch, i) => {
    const x = 0.28 + i * 2.15;
    addCard(s, x, 1.55, 2.02, 3.55, { fill: C.white, border: "90CAF9", shadow: true });
    addIcon(s, ch[0], x + 0.76, 1.78, 0.46, 0.46);
    addText(s, ch[1].toUpperCase(), x + 0.1, 2.35, 1.82, 0.35, { color: C.navy, bold: true, fontSize: 7.8, align: "center", margin: 0 });
    addText(s, ch[2], x + 0.15, 2.78, 1.72, 0.72, { color: C.gray, fontSize: 7.3, align: "center", margin: 0 });
    addPlainList(s, ["Location", "Media proof", "Tracking"], x + 0.28, 3.72, 1.5, C.gray, C.navy, 0.26);
    addCard(s, x + 0.28, 4.62, 1.45, 0.28, { fill: ch[3] === "2.0" ? C.paleAmber : C.paleBlue, border: ch[3] === "2.0" ? "FFE082" : "90CAF9" });
    addText(s, ch[3], x + 0.28, 4.66, 1.45, 0.16, { color: ch[3] === "2.0" ? C.amber : C.navy, bold: true, fontSize: 6.8, align: "center", margin: 0 });
  });
  addBottomMessage(s, "One platform, multiple citizen access paths, one reliable complaint lifecycle.");
}

// Slide 6
{
  const s = pptx.addSlide();
  addBanner(s, "SLIDE 6 OF 15 - REAL-TIME TRACKING AND TRANSPARENCY", "06 / 15");
  addText(s, "Know where your complaint stands at every step.", 0.2, 0.92, 12.9, 0.28, { color: C.navy, italic: true, fontSize: 10.5, align: "center" });

  addSection(s, "CITIZEN TRACKING", 0.25, 1.25, 3.8);
  addWorkflowNode(s, FaIdCard, "Complaint ID", "Track by complaint number and mobile number for guest cases.", 0.28, 1.6, 3.65, 0.85);
  addWorkflowNode(s, FaMapMarkedAlt, "Map and contact", "Assigned department phone, email, address and coordinates.", 0.28, 2.62, 3.65, 0.85);
  addWorkflowNode(s, FaClock, "Timeline", "Time-stamped status history from report to closure.", 0.28, 3.64, 3.65, 0.85);

  addSection(s, "STATUS TIMELINE", 4.25, 1.25, 8.82);
  const timeline = [
    [FaClipboardList, "Submitted"], [FaRobot, "AI verified"], [FaSearch, "Duplicate check"],
    [FaRoute, "Assigned"], [FaTools, "In progress"], [FaClipboardCheck, "Proof uploaded"],
    [FaCheckCircle, "Solved"], [FaRedo, "Reopen"],
  ];
  timeline.forEach((t, i) => {
    const x = 4.35 + (i % 4) * 2.13;
    const y = 1.72 + Math.floor(i / 4) * 1.28;
    addWorkflowNode(s, t[0], t[1], "Visible to citizen and department.", x, y, 1.88, 0.82);
    if (i % 4 !== 3) addLine(s, x + 1.88, y + 0.41, 0.18, 0, C.navy, 0.7);
  });

  addSection(s, "REOPEN LOGIC", 4.25, 4.65, 8.82);
  const reopen = ["Only solved complaints", "Within 7 days", "Reason required", "Photo proof required", "Returns to review"];
  reopen.forEach((r, i) => {
    addCard(s, 4.35 + i * 1.72, 5.05, 1.52, 0.52, { fill: i === 4 ? C.paleRed : C.paleBlue, border: i === 4 ? "EF9A9A" : "90CAF9" });
    addText(s, r, 4.4 + i * 1.72, 5.1, 1.42, 0.34, { color: i === 4 ? C.red : C.navy, bold: true, fontSize: 7, align: "center", margin: 0 });
  });
  addBottomMessage(s, "Tracking makes the complaint system trustworthy after submission.");
}

// Slide 7
{
  const s = pptx.addSlide();
  addBanner(s, "SLIDE 7 OF 15 - ADMIN COMMAND CENTER AND ANALYTICS", "07 / 15");
  addText(s, "Real-time insights for smarter decisions and better cities.", 0.2, 0.92, 12.9, 0.28, { color: C.navy, italic: true, fontSize: 10.5, align: "center" });

  const kpis = [
    ["12,842", "Total complaints", C.navy],
    ["9,215", "Resolved", C.green],
    ["2,351", "In progress", C.amber],
    ["1,276", "Reopened", C.red],
    ["91.3%", "SLA compliance", C.green],
  ];
  kpis.forEach((k, i) => addStat(s, k[0], k[1], 0.25 + i * 2.55, 1.2, 2.42, k[2]));

  addSection(s, "COMPLAINT TREND", 0.25, 2.3, 4.05);
  s.addChart(CH.line, [{ name: "Complaints", labels: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], values: [1800, 2100, 2250, 2380, 2600, 2750, 2846] }], {
    x: 0.28, y: 2.62, w: 3.98, h: 1.65, chartColors: [C.navy], showLegend: false,
    catAxisLabelColor: C.gray, valAxisLabelColor: C.gray, valGridLine: { color: "E2E8F0", size: 0.5 },
  });

  addSection(s, "TOP CATEGORIES", 4.55, 2.3, 3.05);
  s.addChart(CH.doughnut, [{ name: "Share", labels: ["Roads", "Waste", "Water", "Power", "Other"], values: [35, 22, 15, 12, 16] }], {
    x: 4.58, y: 2.62, w: 3.0, h: 1.65, chartColors: [C.navy, C.lightBlue, "42A5F5", "90CAF9", C.gray],
    showLegend: true, legendPos: "r", showPercent: true,
  });

  addSection(s, "DEPARTMENT PERFORMANCE", 7.92, 2.3, 5.0);
  const rows = [
    ["Dept", "Resolved", "Avg", "SLA"],
    ["Roads", "3,245", "2.1d", "93%"],
    ["Waste", "2,112", "2.6d", "89%"],
    ["Water", "1,642", "2.3d", "92%"],
    ["Power", "1,258", "2.8d", "86%"],
  ];
  s.addTable(rows, {
    x: 7.95, y: 2.62, w: 4.95, h: 1.65,
    border: { pt: 0.5, color: "BBDEFB" },
    color: C.gray,
    fontFace: "Aptos",
    fontSize: 7.2,
    fill: { color: C.white },
    colW: [1.6, 1.1, 1.0, 1.0],
    margin: 0.04,
  });

  addSection(s, "ALERTS AND QUICK ACTIONS", 0.25, 4.65, 12.82);
  const actions = [
    [FaBell, "SLA breach alerts"], [FaExclamationTriangle, "High-risk cases"],
    [FaRedo, "Reopened complaints"], [FaBuilding, "Add departments"],
    [FaFileAlt, "Generate reports"], [FaEnvelope, "Broadcast notices"],
  ];
  actions.forEach((a, i) => addMiniFeature(s, a[0], a[1], "Admin action surface", 0.35 + i * 2.08, 5.0, 1.9));
  addBottomMessage(s, "City admins get operational visibility across complaints, departments, heatmaps and service quality.");
}

// Slide 8
{
  const s = pptx.addSlide();
  addBanner(s, "SLIDE 8 OF 15 - DEPARTMENT DASHBOARD AND FIELD OPERATIONS", "08 / 15");
  addText(s, "Right information. Right time. Right action.", 0.2, 0.92, 12.9, 0.28, { color: C.navy, italic: true, fontSize: 10.5, align: "center" });
  const dKpis = [["1,253", "Assigned", C.navy], ["728", "In progress", C.amber], ["478", "Resolved", C.green], ["47", "Overdue", C.red]];
  dKpis.forEach((k, i) => addStat(s, k[0], k[1], 0.25 + i * 3.2, 1.2, 3.05, k[2]));

  addSection(s, "DEPARTMENT WORKFLOW", 0.25, 2.35, 12.82);
  const flow = [
    [FaTasks, "Assigned queue", "Officer receives verified case."],
    [FaMapMarkedAlt, "Location view", "Proof and map available."],
    [FaWrench, "Field action", "Team starts ground work."],
    [FaClock, "Status updates", "Pending to process to solved."],
    [FaClipboardCheck, "Resolution proof", "Before/after evidence uploaded."],
    [FaStar, "Citizen feedback", "Rating and reopen signal quality."],
  ];
  flow.forEach((f, i) => addWorkflowNode(s, f[0], f[1], f[2], 0.35 + (i % 3) * 4.25, 2.75 + Math.floor(i / 3) * 1.25, 3.78, 0.88));

  addSection(s, "ACCOUNTABILITY METRICS", 0.25, 5.55, 12.82);
  const metrics = [["92%", "SLA compliance"], ["2.6d", "Average resolution"], ["4.6/5", "Citizen rating"], ["3.8%", "Reopen rate"]];
  metrics.forEach((m, i) => addStat(s, m[0], m[1], 0.35 + i * 3.15, 5.9, 3.0, i === 3 ? C.red : C.navy));
}

// Slide 9
{
  const s = pptx.addSlide();
  addBanner(s, "SLIDE 9 OF 15 - CITIZEN TRACKING, FEEDBACK AND REOPEN", "09 / 15");
  addText(s, "Your voice. Our action. Complete until resolution.", 0.2, 0.92, 12.9, 0.28, { color: C.navy, italic: true, fontSize: 10.5, align: "center" });

  addSection(s, "CITIZEN EXPERIENCE", 0.25, 1.25, 12.82);
  const items = [
    [FaClipboardList, "My complaints", "All reports in one place."],
    [FaIdCard, "Complaint details", "ID, category, proof and location."],
    [FaClock, "Timeline", "Status history with timestamps."],
    [FaMapMarkerAlt, "Department contact", "Phone, email and address."],
    [FaStar, "Rating", "Citizen satisfaction captured."],
    [FaRedo, "Reopen", "Reason and proof if not fixed."],
  ];
  items.forEach((it, i) => addWorkflowNode(s, it[0], it[1], it[2], 0.35 + (i % 3) * 4.25, 1.72 + Math.floor(i / 3) * 1.25, 3.78, 0.9));

  addSection(s, "REOPEN RULE", 0.25, 4.65, 12.82);
  const rule = ["Solved status only", "7-day window", "Reason required", "Photo proof required", "Reopened for review"];
  rule.forEach((r, i) => {
    addCard(s, 0.35 + i * 2.53, 5.05, 2.18, 0.6, { fill: i === 4 ? C.paleRed : C.paleBlue, border: i === 4 ? "EF9A9A" : "90CAF9" });
    addText(s, r, 0.45 + i * 2.53, 5.16, 1.98, 0.28, { color: i === 4 ? C.red : C.navy, bold: true, align: "center", fontSize: 7.8 });
  });
  addBottomMessage(s, "Trust begins after submission: tracking, contact, rating and reopen keep closure honest.");
}

// Slide 10
{
  const s = pptx.addSlide();
  addBanner(s, "SLIDE 10 OF 15 - FIELD TEAM APP AND WORK EXECUTION", "10 / 15");
  addText(s, "Right work. Right place. Right time.", 0.2, 0.92, 12.9, 0.28, { color: C.navy, italic: true, fontSize: 10.5, align: "center" });

  addSection(s, "FIELD TEAM CAPABILITIES", 0.25, 1.25, 4.1);
  addPlainList(s, ["Assigned complaint queue", "Route to issue location", "GPS-based site check-in", "Work status updates", "Before/after proof upload", "Offline sync for low network"], 0.35, 1.65, 3.8, C.gray, C.navy, 0.42);

  addSection(s, "FIELD APP SCREENS", 4.65, 1.25, 8.42);
  const screens = [[FaTasks, "Assigned tasks"], [FaMapMarkedAlt, "Task details"], [FaWrench, "Update status"], [FaClipboardCheck, "Resolution proof"], [FaCheckCircle, "Completed"]];
  screens.forEach((sc, i) => addWorkflowNode(s, sc[0], sc[1], "Mobile operational screen.", 4.75 + i * 1.65, 1.72, 1.45, 1.4));

  addSection(s, "WORK STATUS FLOW", 0.25, 4.25, 12.82);
  const status = ["Assigned", "On the way", "On site", "In progress", "Proof submitted", "Resolved"];
  status.forEach((st, i) => {
    const x = 0.35 + i * 2.1;
    addCard(s, x, 4.72, 1.82, 0.65, { fill: C.paleBlue, border: "90CAF9" });
    addText(s, st, x + 0.08, 4.86, 1.66, 0.26, { color: C.navy, bold: true, fontSize: 8, align: "center" });
    if (i < status.length - 1) addLine(s, x + 1.82, 5.05, 0.22, 0, C.navy, 0.8);
  });
  addBottomMessage(s, "Field execution closes the loop between digital complaint and real civic repair.");
}

// Slide 11
{
  const s = pptx.addSlide();
  addBanner(s, "SLIDE 11 OF 15 - ANALYTICS, REPORTS AND INSIGHTS", "11 / 15");
  addText(s, "Data speaks. JanHelp helps cities listen.", 0.2, 0.92, 12.9, 0.28, { color: C.navy, italic: true, fontSize: 10.5, align: "center" });
  const k = [["12,842", "Total"], ["9,215", "Resolved"], ["2.4d", "Avg time"], ["4.5/5", "Rating"], ["91.3%", "SLA"]];
  k.forEach((v, i) => addStat(s, v[0], v[1], 0.25 + i * 2.55, 1.2, 2.42, i === 1 || i === 4 ? C.green : C.navy));

  addSection(s, "TREND", 0.25, 2.35, 4.05);
  s.addChart(CH.line, [{ name: "Complaints", labels: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], values: [1800, 2100, 2250, 2380, 2600, 2750, 2846] }], {
    x: 0.28, y: 2.66, w: 3.98, h: 1.65, chartColors: [C.navy], showLegend: false,
    catAxisLabelColor: C.gray, valAxisLabelColor: C.gray, valGridLine: { color: "E2E8F0", size: 0.5 },
  });
  addSection(s, "SLA PERFORMANCE", 4.6, 2.35, 4.05);
  s.addChart(CH.bar, [{ name: "SLA", labels: ["Roads", "Waste", "Water", "Power", "Drainage"], values: [93, 89, 92, 86, 84] }], {
    x: 4.63, y: 2.66, w: 3.98, h: 1.65, chartColors: [C.green], showLegend: false,
    catAxisLabelColor: C.gray, valAxisLabelColor: C.gray, valGridLine: { color: "E2E8F0", size: 0.5 },
  });
  addSection(s, "CITIZEN FEEDBACK", 8.95, 2.35, 4.05);
  addCard(s, 8.98, 2.66, 3.98, 1.65, { fill: C.paleBlue, border: "90CAF9" });
  addIcon(s, FaStar, 9.35, 3.0, 0.55, 0.55);
  addText(s, "4.5 / 5", 10.05, 2.9, 2.4, 0.4, { color: C.navy, bold: true, fontSize: 22, align: "center" });
  addText(s, "Top suggestions: faster resolution, better communication, cleaner wards.", 9.25, 3.55, 3.45, 0.45, { color: C.gray, fontSize: 7.8, align: "center" });
  addBottomMessage(s, "Analytics turns complaints into planning data for better governance.");
}

// Slide 12
{
  const s = pptx.addSlide();
  addBanner(s, "SLIDE 12 OF 15 - DATA-DRIVEN GOVERNANCE", "12 / 15");
  addText(s, "Better data. Smarter insights. Stronger decisions.", 0.2, 0.92, 12.9, 0.28, { color: C.navy, italic: true, fontSize: 10.5, align: "center" });
  addSection(s, "PREDICTIVE INSIGHTS", 0.25, 1.25, 4.1);
  addPlainList(s, ["Road complaints likely to increase", "Ward-level civic hotspots", "SLA breach risk forecast", "High-risk unresolved complaints", "Resource planning suggestions"], 0.35, 1.65, 3.8, C.gray, C.navy, 0.42);

  addSection(s, "CITY BENCHMARKING", 4.65, 1.25, 4.15);
  const rows = [["City", "SLA", "Avg", "Rating"], ["Bengaluru", "91.3%", "2.4d", "4.5"], ["Mumbai", "88.6%", "2.8d", "4.3"], ["Pune", "85.4%", "2.9d", "4.1"], ["Chennai", "84.2%", "3.1d", "4.0"]];
  s.addTable(rows, { x: 4.7, y: 1.65, w: 4.05, h: 1.8, border: { pt: 0.5, color: "BBDEFB" }, fontFace: "Aptos", fontSize: 7.5, color: C.gray, margin: 0.04, colW: [1.15, 0.95, 0.95, 0.95] });

  addSection(s, "SMART ALERTS", 9.15, 1.25, 3.92);
  addPlainList(s, ["SLA breach risk", "High complaint volume", "Unusual issue trend", "Positive feedback spike", "Repeated reopen case"], 9.25, 1.65, 3.6, C.gray, C.red, 0.42);

  addSection(s, "DECISION SUPPORT", 0.25, 4.25, 12.82);
  const support = [[FaBullseye, "Prioritize impact"], [FaUsers, "Allocate teams"], [FaChartLine, "Monitor performance"], [FaCog, "Improve process"], [FaCity, "Plan city work"]];
  support.forEach((su, i) => addWorkflowNode(s, su[0], su[1], "Data-backed civic decision.", 0.35 + i * 2.52, 4.72, 2.15, 0.9));
  addBottomMessage(s, "JanHelp turns service complaints into a city management intelligence layer.");
}

// Slide 13
{
  const s = pptx.addSlide();
  addBanner(s, "SLIDE 13 OF 15 - INTEGRATIONS, AUTOMATION AND WORKFLOW ENGINE", "13 / 15");
  addText(s, "Seamless integration. Smart automation. Maximum impact.", 0.2, 0.92, 12.9, 0.28, { color: C.navy, italic: true, fontSize: 10.5, align: "center" });

  addSection(s, "SYSTEM INTEGRATIONS", 0.25, 1.25, 4.1);
  const integrations = [[FaMapMarkedAlt, "GIS"], [FaDatabase, "CRM"], [FaEnvelope, "Email"], [FaSms, "SMS"], [FaHeadset, "Call center"], [FaCloud, "Cloud storage"], [FaLock, "SSO"], [FaChartBar, "BI tools"]];
  integrations.forEach((it, i) => addMiniFeature(s, it[0], it[1], "Integration point", 0.3 + (i % 2) * 2.0, 1.65 + Math.floor(i / 2) * 0.72, 1.85));

  addSection(s, "AUTOMATION ENGINE", 4.75, 1.25, 4.15);
  const auto = [[FaBell, "Trigger"], [FaCog, "Rule engine"], [FaTasks, "Action"], [FaCheckCircle, "Outcome"]];
  auto.forEach((a, i) => {
    addWorkflowNode(s, a[0], a[1], "Automated civic workflow.", 4.8 + i * 1.02, 1.7, 0.86, 1.0);
    if (i < auto.length - 1) addLine(s, 5.66 + i * 1.02, 2.2, 0.14, 0, C.navy, 0.7);
  });
  addPlainList(s, ["Auto-assign complaints", "Escalate overdue work", "Send reminders", "Schedule reports", "Notify departments"], 4.95, 3.0, 3.5, C.gray, C.navy, 0.35);

  addSection(s, "WORKFLOW BUILDER", 9.25, 1.25, 3.82);
  const builder = ["New complaint trigger", "High priority check", "Notify supervisor", "Assign department", "Update status", "Close and notify"];
  builder.forEach((b, i) => {
    addCard(s, 9.3, 1.65 + i * 0.52, 3.65, 0.42, { fill: i === 1 ? C.paleAmber : C.paleBlue, border: i === 1 ? "FFE082" : "90CAF9" });
    addText(s, b, 9.4, 1.72 + i * 0.52, 3.45, 0.18, { color: i === 1 ? C.amber : C.navy, fontSize: 7.5, bold: true, align: "center" });
  });

  addSection(s, "AUTOMATION IMPACT", 0.25, 5.4, 12.82);
  [["40%", "Faster resolution"], ["35%", "More productivity"], ["50%", "Less manual work"], ["90%+", "Better satisfaction"]].forEach((m, i) => addStat(s, m[0], m[1], 0.35 + i * 3.15, 5.78, 3.0, i === 3 ? C.green : C.navy));
}

// Slide 14
{
  const s = pptx.addSlide();
  addBanner(s, "SLIDE 14 OF 15 - EXTENSIBILITY, CUSTOMIZATION AND FUTURE READY", "14 / 15");
  addText(s, "Built for today. Ready for tomorrow.", 0.2, 0.92, 12.9, 0.28, { color: C.navy, italic: true, fontSize: 10.5, align: "center" });

  addSection(s, "CUSTOMIZABLE FOR EVERY CITY", 0.25, 1.25, 4.1);
  const custom = [[FaProjectDiagram, "Workflows"], [FaFileAlt, "Fields"], [FaLayerGroup, "Categories"], [FaChartBar, "Dashboards"], [FaLock, "Roles"]];
  custom.forEach((c, i) => addWorkflowNode(s, c[0], c[1], "Configurable without rebuilding.", 0.35 + (i % 2) * 2.0, 1.65 + Math.floor(i / 2) * 1.02, 1.75, 0.82));

  addSection(s, "EXTENSIBLE PLATFORM", 4.7, 1.25, 4.1);
  addPlainList(s, ["Third-party apps", "IoT devices", "AI and ML services", "Open REST APIs", "Webhooks", "Data export", "SSO and IAM"], 4.85, 1.65, 3.75, C.gray, C.navy, 0.39);

  addSection(s, "FUTURE READY CAPABILITIES", 9.15, 1.25, 3.92);
  addPlainList(s, ["AI insights", "Conversational AI", "Computer vision", "Predictive analytics", "Mobile and IoT expansion"], 9.25, 1.65, 3.6, C.gray, C.green, 0.42);

  addSection(s, "DEPLOYMENT FLEXIBILITY", 0.25, 5.2, 12.82);
  [[FaCloud, "Cloud"], [FaServer, "On-premise"], [FaHandshake, "Hybrid"], [FaShieldAlt, "Compliance ready"], [FaDatabase, "Backup and recovery"]].forEach((d, i) => addWorkflowNode(s, d[0], d[1], "Secure deployment option.", 0.35 + i * 2.52, 5.58, 2.15, 0.85));
}

// Slide 15
{
  const s = pptx.addSlide();
  addBanner(s, "SLIDE 15 OF 15 - SMART CITIES, BETTER TOMORROW", "15 / 15");
  addText(s, "Thank you for your time, attention and belief in better civic systems.", 0.2, 0.95, 12.9, 0.28, { color: C.amber, fontSize: 9.2, align: "center" });
  addCard(s, 0.25, 1.45, 3.0, 3.0, { fill: C.paleBlue, border: "90CAF9" });
  addText(s, "WHAT WE BUILD", 0.35, 1.62, 2.8, 0.3, { color: C.navy, bold: true, fontSize: 11, align: "center" });
  addPlainList(s, ["Save time", "Increase transparency", "Improve efficiency", "Empower teams", "Delight citizens"], 0.55, 2.08, 2.35, C.gray, C.navy, 0.42);

  addText(s, "Thank You", 3.7, 1.45, 5.95, 0.8, { color: C.navy, bold: true, fontSize: 46, align: "center", margin: 0 });
  addRect(s, 3.85, 2.34, 5.65, 0.42, C.navy, C.navy, { radius: 0.08 });
  addText(s, "FOR BEING PART OF THE JANHELP JOURNEY", 3.95, 2.42, 5.45, 0.22, { color: C.white, bold: true, fontSize: 9, align: "center", margin: 0 });
  addText(s, "Together, we can create smarter decisions, stronger teams and better cities for everyone.", 3.65, 3.0, 6.1, 0.55, { color: C.navy, fontSize: 11, align: "center" });
  addCard(s, 3.65, 3.78, 6.1, 0.88, { fill: C.paleBlue, border: "90CAF9" });
  addText(s, "TEAMWORK  |  TRUST  |  IMPACT  |  SERVICE  |  CARE", 3.85, 4.1, 5.7, 0.22, { color: C.navy, bold: true, align: "center", fontSize: 11, margin: 0 });

  addCard(s, 10.05, 1.45, 3.0, 3.0, { fill: C.paleBlue, border: "90CAF9" });
  addText(s, "IMPACT", 10.15, 1.62, 2.8, 0.3, { color: C.navy, bold: true, fontSize: 11, align: "center" });
  addPlainList(s, ["Smarter decisions", "Stronger collaboration", "Better outcomes", "Happier communities", "Future-ready cities"], 10.35, 2.08, 2.35, C.gray, C.green, 0.42);

  addCard(s, 0.25, 5.15, 12.82, 1.1, { fill: C.white, border: "90CAF9", shadow: true });
  addRect(s, 0.25, 5.15, 12.82, 0.36, C.navy, C.navy, { radius: 0.08 });
  addText(s, "Q AND A - WE WOULD LOVE TO HEAR FROM YOU", 0.35, 5.22, 12.62, 0.2, { color: C.white, bold: true, fontSize: 11, align: "center", margin: 0 });
  [["Questions", FaComments], ["Feedback", FaStar], ["Ideas", FaLightbulb], ["Partnership", FaHandshake]].forEach((q, i) => {
    addIcon(s, q[1], 1.15 + i * 3.05, 5.72, 0.28, 0.28);
    addText(s, q[0], 1.5 + i * 3.05, 5.75, 1.8, 0.22, { color: C.navy, bold: true, fontSize: 9, margin: 0 });
  });
  addBottomMessage(s, "Let's build better cities, together.");
}

pptx.writeFile({ fileName: "submission_assets/JanHelp_Presentation_Real_SVG.pptx" })
  .then(() => {
    console.log("Created submission_assets/JanHelp_Presentation_Real_SVG.pptx");
  })
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
