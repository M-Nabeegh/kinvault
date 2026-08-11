const answers = {
  "When does Dad's passport expire?": {
    answer: "Dad Rowan’s passport expires on <strong>2026-11-09</strong>.",
    title: "Dad Passport (Synthetic)",
    meta: "Page 2 · Expiry date · 2026-11-09",
    confidence: "HIGH CONFIDENCE",
    percent: "96%",
    tone: "high"
  },
  "What is Sana's date of birth?": {
    answer: "Sana Rowan’s date of birth is <strong>2004-04-18</strong>.",
    title: "Sana ID Card (Synthetic)",
    meta: "Page 1 · Date of birth · 2004-04-18",
    confidence: "NEEDS VERIFICATION",
    percent: "62%",
    tone: "review"
  },
  "Which documents expire in the next 90 days?": {
    answer: "<strong>1 document</strong> expires within the next 90 days.",
    title: "Dad Passport (Synthetic)",
    meta: "Page 2 · Expiry date · 2026-11-09",
    confidence: "HIGH CONFIDENCE",
    percent: "96%",
    tone: "high"
  }
};

const input = document.querySelector("#question-input");
const form = document.querySelector("#question-form");
const card = document.querySelector("#answer-card");
const answerCopy = document.querySelector("#answer-copy");
const citationTitle = document.querySelector("#citation-title");
const citationMeta = document.querySelector("#citation-meta");
const confidenceValue = document.querySelector("#confidence-value");
const confidenceLabel = document.querySelector(".confidence");
const promptButtons = document.querySelectorAll("[data-question]");

function showAnswer(question) {
  const answer = answers[question] || {
    answer: "KinVault could not find that field in the synthetic vault.",
    title: "No source returned",
    meta: "Not found in the vault · no citation invented",
    confidence: "NOT FOUND",
    percent: "n/a",
    tone: "review"
  };
  answerCopy.innerHTML = answer.answer;
  citationTitle.textContent = answer.title;
  citationMeta.textContent = answer.meta;
  confidenceValue.textContent = answer.percent;
  confidenceLabel.className = "confidence confidence--" + answer.tone;
  confidenceLabel.innerHTML = "<i></i>" + answer.confidence;
  if (card.animate) {
    card.animate([{ opacity: 0.45, transform: "translateY(4px)" }, { opacity: 1, transform: "translateY(0)" }], { duration: 220, easing: "ease-out" });
  }
}

form.addEventListener("submit", function (event) {
  event.preventDefault();
  showAnswer(input.value.trim());
});

promptButtons.forEach(function (button) {
  button.addEventListener("click", function () {
    input.value = button.dataset.question;
    showAnswer(input.value);
    input.focus();
  });
});
