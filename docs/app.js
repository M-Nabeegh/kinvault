// Field boxes exported from KinVault's own store after it read the specimen passport.
// Coordinates are fractions of the page, origin top-left.
const fields = [
  { label: "Country code", value: "ARC", x: 0.4224, y: 0.1812, w: 0.0358, h: 0.0271 },
  { label: "Passport No.", value: "A0937155", x: 0.558, y: 0.1802, w: 0.0824, h: 0.0293 },
  { label: "Surname", value: "ROWAN", x: 0.2954, y: 0.2412, w: 0.0659, h: 0.0342 },
  { label: "Given names", value: "DANIEL JAMES", x: 0.2955, y: 0.3187, w: 0.1164, h: 0.0271 },
  { label: "Nationality", value: "ARCADIAN", x: 0.2955, y: 0.387, w: 0.0852, h: 0.026 },
  { label: "Date of birth", value: "02 JUN 1978", x: 0.5582, y: 0.3871, w: 0.1001, h: 0.0259 },
  { label: "Place of birth", value: "PORT ELLIS", x: 0.2954, y: 0.454, w: 0.0928, h: 0.0266 },
  { label: "Date of issue", value: "14 MAR 2021", x: 0.4194, y: 0.454, w: 0.1045, h: 0.0275 },
  { label: "Date of expiry", value: "14 MAR 2031", x: 0.5582, y: 0.4563, w: 0.1015, h: 0.025 },
];

const answers = {
  expiry: {
    text: "Dad’s passport expires on 14 MAR 2031.",
    field: "Date of expiry",
    note: "Answered by Apple Intelligence on this Mac · valid for 4 more years",
  },
  number: {
    text: "Dad’s passport number is A0937155.",
    field: "Passport No.",
    note: "Answered by Apple Intelligence on this Mac",
  },
  birth: {
    text: "Daniel was born on 02 JUN 1978.",
    field: "Date of birth",
    note: "Answered by Apple Intelligence on this Mac",
  },
  wifi: {
    text: "Not found in the vault",
    field: null,
    note: "None of the documents mention a Wi-Fi password. KinVault won’t guess.",
  },
};

const scan = document.getElementById("scan");
const pad = 0.18; // the app pads each box by a fraction of its height, too

// The image on this page is cropped to the card; the app's coordinates include a 60 px margin
// around a 2120 × 1520 render. Map them onto the crop.
const margin = { x: 60 / 2120, y: 60 / 1520 };
const toCrop = (v, axis) => (v - margin[axis]) / (1 - margin[axis] * 2);
const toCropSize = (v, axis) => v / (1 - margin[axis] * 2);

const boxes = new Map(
  fields.map((field) => {
    const el = document.createElement("div");
    el.className = "box";
    const p = field.h * pad;
    el.style.left = `${toCrop(field.x - p, "x") * 100}%`;
    el.style.top = `${toCrop(field.y - p, "y") * 100}%`;
    el.style.width = `${toCropSize(field.w + p * 2, "x") * 100}%`;
    el.style.height = `${toCropSize(field.h + p * 2, "y") * 100}%`;
    el.title = `${field.label}: ${field.value}`;
    scan.appendChild(el);
    return [field.label, el];
  })
);

const text = document.getElementById("answer-text");
const source = document.getElementById("answer-source");
const fieldName = document.getElementById("answer-field");
const value = document.getElementById("answer-value");
const note = document.getElementById("answer-note");
const buttons = document.querySelectorAll(".questions button");

function show(key) {
  const answer = answers[key];
  buttons.forEach((b) => b.setAttribute("aria-pressed", String(b.dataset.q === key)));
  boxes.forEach((el, label) => el.classList.toggle("active", label === answer.field));

  text.textContent = answer.text;
  text.classList.toggle("missing", !answer.field);
  note.textContent = answer.note;
  source.hidden = !answer.field;
  if (answer.field) {
    const field = fields.find((f) => f.label === answer.field);
    fieldName.textContent = field.label;
    value.textContent = field.value;
  }
}

buttons.forEach((b) => b.addEventListener("click", () => show(b.dataset.q)));
show("expiry");
