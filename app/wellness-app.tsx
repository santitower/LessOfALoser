"use client";

import { useMemo, useRef, useState, useSyncExternalStore } from "react";
import {
  answerInsightQuestion,
  formatDay,
  formatDuration,
  parseWellnessExport,
  sampleDataset,
  summarize,
  trendDirection,
  weeklyScore,
  type MetricTrend,
  type TrendSummary,
  type WellnessDataset,
  type WellnessRecord,
  type WeeklyScore,
} from "../lib/wellness";

type ViewId = "today" | "review" | "coach" | "league" | "report";

type Standing = {
  displayName: string;
  stars: number;
  activeDays: number;
  streakDays: number;
  isViewer?: boolean;
};

const navItems: Array<{ id: ViewId; label: string; icon: string }> = [
  { id: "today", label: "Today", icon: "✓" },
  { id: "review", label: "Review", icon: "↗" },
  { id: "coach", label: "Model", icon: "✦" },
  { id: "league", label: "League", icon: "◆" },
  { id: "report", label: "Report", icon: "▤" },
];

const sampleStandings: Standing[] = [
  { displayName: "Maya", stars: 20, activeDays: 7, streakDays: 12 },
  { displayName: "Nico", stars: 19, activeDays: 7, streakDays: 8 },
  { displayName: "Priya", stars: 16, activeDays: 6, streakDays: 5 },
  { displayName: "Theo", stars: 14, activeDays: 6, streakDays: 4 },
  { displayName: "Jules", stars: 13, activeDays: 5, streakDays: 3 },
];

const suggestedQuestions = [
  "What stands out today?",
  "How was my sleep?",
  "What changed in my screen time?",
];

const localLeagueEvent = "lessofaloser-local-league-change";

export default function WellnessApp() {
  const [activeView, setActiveView] = useState<ViewId>("today");
  const [dataset, setDataset] = useState<WellnessDataset>(sampleDataset);
  const [baselineDays, setBaselineDays] = useState(28);
  const [question, setQuestion] = useState(suggestedQuestions[0]);
  const [answer, setAnswer] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [importError, setImportError] = useState<string | null>(null);
  const fileInput = useRef<HTMLInputElement>(null);

  const summary = useMemo(
    () => summarize(dataset.records, baselineDays),
    [dataset.records, baselineDays],
  );
  const score = useMemo(
    () => weeklyScore(dataset.records, dataset.goals),
    [dataset.records, dataset.goals],
  );
  const latest = dataset.records.at(-1) ?? null;

  const sharing = useSyncExternalStore(
    subscribeToLocalLeague,
    () => window.localStorage.getItem(localLeagueKey(score.weekId)) === "pinned",
    () => false,
  );

  function announce(message: string) {
    setNotice(message);
    window.setTimeout(() => setNotice(null), 2600);
  }

  async function importFile(file: File | undefined) {
    if (!file) return;
    setImportError(null);
    if (file.size > 1_000_000) {
      setImportError("Choose an aggregate export smaller than 1 MB.");
      return;
    }
    try {
      const imported = parseWellnessExport(await file.text());
      setDataset(imported);
      setAnswer(null);
      setActiveView("today");
      announce(`Imported ${imported.records.length} aggregate days from your iPhone.`);
    } catch (error) {
      setImportError(error instanceof Error ? error.message : "The export could not be imported.");
    } finally {
      if (fileInput.current) fileInput.current.value = "";
    }
  }

  function resetSample() {
    setDataset(sampleDataset);
    setAnswer(null);
    setImportError(null);
    announce("Sample data restored.");
  }

  function askModel(nextQuestion = question) {
    setQuestion(nextQuestion);
    setAnswer(answerInsightQuestion(nextQuestion, summary));
  }

  function updateSharing() {
    const nextSharing = !sharing;
    if (nextSharing) {
      window.localStorage.setItem(localLeagueKey(score.weekId), "pinned");
    } else {
      window.localStorage.removeItem(localLeagueKey(score.weekId));
    }
    window.dispatchEvent(new Event(localLeagueEvent));
    announce(nextSharing ? "Score pinned in this browser only." : "Local score removed.");
  }

  const title = navItems.find((item) => item.id === activeView)?.label ?? "Today";

  return (
    <div className="app-shell">
      <aside className="side-nav" aria-label="Main navigation">
        <button className="wordmark" type="button" onClick={() => setActiveView("today")}>
          <LogoFace />
          <span><b>LessOfALoser</b><small>Wellness, with receipts</small></span>
        </button>

        <nav>
          {navItems.map((item) => (
            <button
              type="button"
              key={item.id}
              className={activeView === item.id ? "active" : ""}
              onClick={() => setActiveView(item.id)}
            >
              <span className="nav-icon" aria-hidden="true">{item.icon}</span>
              {item.label}
            </button>
          ))}
        </nav>

        <div className="privacy-seal">
          <span>✓</span>
          <p><b>Private by default</b>Exact wellness values stay in this session unless you export or print them.</p>
        </div>
      </aside>

      <main className="workspace">
        <header className="topbar">
          <div className="mobile-brand"><LogoFace /><b>LessOfALoser</b></div>
          <div>
            <span className="eyebrow">{dataset.source === "sample" ? "GUIDED DEMO" : "IPHONE EXPORT"}</span>
            <h1>{title}</h1>
          </div>
          <div className="topbar-actions">
            <span className={`source-pill ${dataset.source}`}><i />{dataset.source === "sample" ? "Sample data" : `${dataset.records.length} days imported`}</span>
            <input
              ref={fileInput}
              className="file-input"
              type="file"
              accept="application/json,.json"
              onChange={(event) => void importFile(event.target.files?.[0])}
              aria-label="Import iPhone aggregate wellness export"
            />
            <button className="secondary-button" type="button" onClick={() => fileInput.current?.click()}>
              Import from iPhone
            </button>
          </div>
        </header>

        {importError ? (
          <div className="error-banner" role="alert">
            <span>!</span><p><b>Could not import that file.</b>{importError}</p>
            <button type="button" onClick={() => setImportError(null)}>Dismiss</button>
          </div>
        ) : null}

        {activeView === "today" ? <TodayView dataset={dataset} summary={summary} score={score} latest={latest} onReview={() => setActiveView("review")} onImport={() => fileInput.current?.click()} /> : null}
        {activeView === "review" ? <ReviewView dataset={dataset} summary={summary} baselineDays={baselineDays} setBaselineDays={setBaselineDays} /> : null}
        {activeView === "coach" ? <CoachView summary={summary} question={question} setQuestion={setQuestion} answer={answer} askModel={askModel} /> : null}
        {activeView === "league" ? <LeagueView score={score} sharing={sharing} updateSharing={updateSharing} /> : null}
        {activeView === "report" ? <ReportView dataset={dataset} summary={summary} score={score} /> : null}

        {dataset.source !== "sample" ? (
          <button className="sample-reset" type="button" onClick={resetSample}>Return to guided sample</button>
        ) : null}
      </main>

      <nav className="bottom-nav" aria-label="Mobile navigation">
        {navItems.map((item) => (
          <button key={item.id} type="button" className={activeView === item.id ? "active" : ""} onClick={() => setActiveView(item.id)}>
            <span>{item.icon}</span>{item.label}
          </button>
        ))}
      </nav>

      {notice ? <div className="toast" role="status">{notice}</div> : null}
    </div>
  );
}

function TodayView({
  dataset,
  summary,
  score,
  latest,
  onReview,
  onImport,
}: {
  dataset: WellnessDataset;
  summary: TrendSummary | null;
  score: WeeklyScore;
  latest: WellnessRecord | null;
  onReview: () => void;
  onImport: () => void;
}) {
  const insight = summary?.observations[0] ?? "A few connected days will unlock your personal baseline.";
  return (
    <div className="view-stack">
      <section className="today-hero">
        <div className="hero-copy">
          <span className="eyebrow light">DAILY READOUT · {latest ? formatDay(latest.date).toUpperCase() : "NO DATA"}</span>
          <h2>{summary?.dataCoverage === 1 ? "Your signals are fully connected." : "Your review is taking shape."}</h2>
          <p>{insight}</p>
          <div className="hero-actions">
            <button className="light-button" type="button" onClick={onReview}>Open retrospective</button>
            {dataset.source === "sample" ? <button className="ghost-light-button" type="button" onClick={onImport}>Use my data</button> : null}
          </div>
        </div>
        <div className="hero-score" aria-label={`${score.stars} of 21 weekly stars earned`}>
          <span>★</span><b>{score.stars}</b><small>of 21 weekly stars</small>
          <div><i style={{ width: `${score.stars / 21 * 100}%` }} /></div>
        </div>
      </section>

      <section className="metric-grid" aria-label="Latest wellness metrics">
        <MetricCard label="Sleep" icon="☾" color="purple" value={latest?.sleepMinutes == null ? "—" : formatDuration(latest.sleepMinutes)} trend={summary?.sleep ?? null} />
        <MetricCard label="Steps" icon="↟" color="green" value={latest?.steps == null ? "—" : Math.round(latest.steps).toLocaleString("en-US")} trend={summary?.steps ?? null} />
        <MetricCard label="Screen time" icon="▣" color="orange" value={latest?.screenTimeMinutes == null ? "—" : formatDuration(latest.screenTimeMinutes)} trend={summary?.screenTime ?? null} invertTrend />
        <article className="metric-card coverage-card">
          <span className="metric-icon sky">◫</span>
          <div><span className="card-label">Coverage</span><strong>{Math.round((latest?.dataCoverage ?? 0) * 100)}%</strong></div>
          <p>{summary?.baselineDayCount ?? 0} baseline days available</p>
        </article>
      </section>

      <div className="two-column">
        <section className="panel signal-panel">
          <div className="panel-heading"><div><span className="eyebrow">14-DAY SIGNAL</span><h2>Behavior, in context</h2></div><span className="verified-chip">✓ Verified totals</span></div>
          <TrendRows records={dataset.records.slice(-14)} />
        </section>
        <section className="panel next-step-panel">
          <span className="spark">✦</span>
          <span className="eyebrow">MODEL-GROUNDED NEXT STEP</span>
          <h2>{summary?.screenTime.percentChange && summary.screenTime.percentChange > 8 ? "Protect a short wind-down tonight." : "Keep the routine that is working."}</h2>
          <p>Built from aggregate totals and your own baseline. Missing measurements remain unknown.</p>
          <button type="button" onClick={onReview}>See the evidence <span>→</span></button>
        </section>
      </div>

      <DataBoundary source={dataset.source} />
    </div>
  );
}

function ReviewView({
  dataset,
  summary,
  baselineDays,
  setBaselineDays,
}: {
  dataset: WellnessDataset;
  summary: TrendSummary | null;
  baselineDays: number;
  setBaselineDays: (days: number) => void;
}) {
  const visible = dataset.records.slice(-(baselineDays + 1));
  return (
    <div className="view-stack">
      <section className="review-intro panel">
        <div>
          <span className="eyebrow">RETROSPECTIVE WINDOW</span>
          <h2>See today against your own normal.</h2>
          <p>No population benchmark, diagnosis, or causal claim—just a clean comparison with the history you supplied.</p>
        </div>
        <div className="segmented" aria-label="Retrospective baseline window">
          {[7, 14, 28].map((days) => <button type="button" key={days} className={baselineDays === days ? "active" : ""} onClick={() => setBaselineDays(days)}>{days}d</button>)}
        </div>
      </section>

      <section className="comparison-grid">
        <ComparisonCard label="Sleep" trend={summary?.sleep ?? null} formatter={formatDuration} accent="purple" />
        <ComparisonCard label="Steps" trend={summary?.steps ?? null} formatter={(value) => Math.round(value).toLocaleString("en-US")} accent="green" />
        <ComparisonCard label="Screen time" trend={summary?.screenTime ?? null} formatter={formatDuration} accent="orange" invert />
      </section>

      <section className="panel history-panel">
        <div className="panel-heading"><div><span className="eyebrow">DAILY HISTORY</span><h2>{visible.length} days, one honest view</h2></div><span className="coverage-copy">{Math.round(visible.reduce((sum, record) => sum + record.dataCoverage, 0) / Math.max(1, visible.length) * 100)}% average coverage</span></div>
        <TrendRows records={visible} expanded />
      </section>

      <section className="panel observations-panel">
        <div><span className="spark small">✦</span><span className="eyebrow">VERIFIED OBSERVATIONS</span></div>
        <ol>{summary?.observations.map((observation) => <li key={observation}>{observation}</li>)}</ol>
      </section>
    </div>
  );
}

function CoachView({
  summary,
  question,
  setQuestion,
  answer,
  askModel,
}: {
  summary: TrendSummary | null;
  question: string;
  setQuestion: (value: string) => void;
  answer: string | null;
  askModel: (question?: string) => void;
}) {
  return (
    <div className="view-stack coach-layout">
      <section className="model-status panel">
        <div className="model-orb">✦</div>
        <div><span className="eyebrow">MODEL CONTROL</span><h2>Grounded and ready</h2><p>The web review uses the same reviewed aggregate context as the iPhone model boundary.</p></div>
        <span className="status-badge"><i /> Local insight engine</span>
      </section>

      <div className="coach-grid">
        <section className="panel ask-panel">
          <div className="panel-heading"><div><span className="eyebrow">ASK YOUR REVIEW</span><h2>One question. Evidence attached.</h2></div></div>
          <div className="question-chips">{suggestedQuestions.map((suggestion) => <button type="button" key={suggestion} onClick={() => askModel(suggestion)}>{suggestion}</button>)}</div>
          <label htmlFor="model-question">Question</label>
          <textarea id="model-question" maxLength={280} value={question} onChange={(event) => setQuestion(event.target.value)} />
          <button className="primary-button" type="button" onClick={() => askModel()} disabled={!question.trim()}>Generate grounded insight <span>✦</span></button>
          {answer ? <div className="model-answer" role="status"><span>✦</span><div><b>LessOfALoser model</b><p>{answer}</p></div></div> : null}
        </section>

        <aside className="panel context-panel">
          <span className="eyebrow">CONTEXT INSPECTOR</span>
          <h2>What the model can see</h2>
          <ContextRow label="Daily totals" value="Sleep, steps, screen" included />
          <ContextRow label="Recent baseline" value={`${summary?.baselineDayCount ?? 0} comparison days`} included />
          <ContextRow label="Raw HealthKit samples" value="Never included" />
          <ContextRow label="Apps and websites" value="Never included" />
          <ContextRow label="Conversation history" value="Not persisted here" />
          <p className="model-caution">General wellness only. The model does not diagnose, predict a condition, or recommend treatment changes.</p>
        </aside>
      </div>
    </div>
  );
}

function LeagueView({
  score,
  sharing,
  updateSharing,
}: {
  score: WeeklyScore;
  sharing: boolean;
  updateSharing: () => void;
}) {
  const preview = useMemo(() => {
    return [...sampleStandings, { displayName: "You", stars: score.stars, activeDays: score.activeDays, streakDays: score.streakDays, isViewer: true }]
      .sort((a, b) => b.stars - a.stars);
  }, [score]);
  return (
    <div className="view-stack">
      <section className="league-hero">
        <div><span className="eyebrow light">{score.weekId} · CONSISTENCY LEAGUE</span><h2>{score.stars} of 21 stars earned</h2><p>One personal goal met earns one star. Friends never see the underlying sleep, step, or Screen Time value.</p><div className="week-progress"><i style={{ width: `${score.stars / 21 * 100}%` }} /></div></div>
        <div className="star-medallion">★<small>{score.stars}</small></div>
      </section>

      <section className="achievement-grid">
        <Achievement label="Sleep goal" icon="☾" stars={score.sleepStars} color="purple" />
        <Achievement label="Steps goal" icon="↟" stars={score.stepStars} color="green" />
        <Achievement label="Screen goal" icon="▣" stars={score.screenStars} color="orange" />
      </section>

      <div className="league-grid">
        <section className="panel standings-card">
          <div className="panel-heading"><div><span className="eyebrow">BROWSER-LOCAL PREVIEW</span><h2>Star board</h2></div><span className="rank-chip">Stars only</span></div>
          <div className="standing-list">
            {preview.map((standing, index) => (
              <div className={standing.isViewer ? "standing-row viewer" : "standing-row"} key={`${standing.displayName}-${index}`}>
                <b className="standing-rank">{index + 1}</b>
                <span className={`avatar avatar-${index % 5}`}>{initials(standing.displayName)}</span>
                <span><b>{standing.displayName}{standing.isViewer ? " · you" : ""}</b><small>{standing.activeDays} active days · {standing.streakDays} day streak</small></span>
                <strong>★ {standing.stars}</strong>
              </div>
            ))}
          </div>
          <p className="demo-note">Competitors are sample profiles. Your pinned state stays only in this browser; no account or shared league is connected.</p>
        </section>

        <aside className="panel sharing-card">
          <span className="share-lock">✓</span>
          <span className="eyebrow">CONTROLLED SHARING</span>
          <h2>{sharing ? "Your score is pinned locally." : "Preview competition without an account."}</h2>
          <ul><li>Weekly points</li><li>Active-day count</li><li>Streak length</li></ul>
          <p>No score or health data is uploaded. This control saves only a local pinned/not-pinned preference in this browser.</p>
          <button className={sharing ? "danger-button" : "primary-button"} type="button" onClick={updateSharing}>
            {sharing ? "Remove local score" : "Pin my score locally"}
          </button>
        </aside>
      </div>
    </div>
  );
}

function ReportView({ dataset, summary, score }: { dataset: WellnessDataset; summary: TrendSummary | null; score: WeeklyScore }) {
  const latest = dataset.records.at(-1);
  const coverage = dataset.records.reduce((sum, record) => sum + record.dataCoverage, 0) / Math.max(1, dataset.records.length);
  return (
    <div className="view-stack report-view">
      <section className="report-toolbar panel">
        <div><span className="eyebrow">PDF-READY REVIEW</span><h2>A report with evidence, provenance, and privacy context.</h2><p>Use your browser’s print sheet to save a clean PDF. Navigation and controls are removed automatically.</p></div>
        <button className="primary-button export-pdf" type="button" onClick={() => window.print()}>Export PDF <span>↓</span></button>
      </section>

      <article className="report-sheet">
        <header className="report-header">
          <div className="report-brand"><LogoFace /><span><b>LessOfALoser</b><small>Personal wellness retrospective</small></span></div>
          <div><span>REPORT DATE</span><b>{latest ? formatDay(latest.date) : "—"}</b><small>{dataset.records.length} aggregate days</small></div>
        </header>

        <section className="report-summary">
          <span className="eyebrow">EXECUTIVE READOUT</span>
          <h2>{summary?.observations[0] ?? "More connected days are needed for a personal baseline."}</h2>
          <p>{summary?.observations.slice(1).join(" ") || "Missing measurements remain unknown and are not scored as failures."}</p>
        </section>

        <section className="report-kpis">
          <ReportKpi label="Sleep" value={latest?.sleepMinutes == null ? "—" : formatDuration(latest.sleepMinutes)} change={summary?.sleep.percentChange ?? null} />
          <ReportKpi label="Steps" value={latest?.steps == null ? "—" : Math.round(latest.steps).toLocaleString("en-US")} change={summary?.steps.percentChange ?? null} />
          <ReportKpi label="Screen" value={latest?.screenTimeMinutes == null ? "—" : formatDuration(latest.screenTimeMinutes)} change={summary?.screenTime.percentChange ?? null} />
          <ReportKpi label="Coverage" value={`${Math.round(coverage * 100)}%`} change={null} />
        </section>

        <section className="report-chart">
          <div><span className="eyebrow">RECENT SIGNAL</span><h3>Last 14 days</h3></div>
          <TrendRows records={dataset.records.slice(-14)} />
        </section>

        <section className="report-columns">
          <div><span className="eyebrow">MODEL OBSERVATIONS</span><ol>{summary?.observations.map((item) => <li key={item}>{item}</li>)}</ol></div>
          <div><span className="eyebrow">WEEKLY CONSISTENCY</span><b className="report-stars">★ {score.stars}<small> of 21 stars</small></b><p>{score.activeDays} active days · {score.streakDays} day streak</p></div>
        </section>

        <footer className="report-footer"><p><b>Data provenance.</b> User-initiated aggregate export from LessOfALoser for iPhone. Raw HealthKit samples, app identities, websites, and model conversations are excluded.</p><p>General wellness only · Not medical advice</p></footer>
      </article>
    </div>
  );
}

function MetricCard({ label, icon, color, value, trend, invertTrend = false }: { label: string; icon: string; color: string; value: string; trend: MetricTrend | null; invertTrend?: boolean }) {
  const change = trend?.percentChange ?? null;
  const direction = trendDirection(change);
  const good = invertTrend ? direction === "down" : direction === "up";
  return (
    <article className="metric-card">
      <span className={`metric-icon ${color}`}>{icon}</span>
      <div><span className="card-label">{label}</span><strong>{value}</strong></div>
      <p className={change == null ? "unknown" : good ? "good" : "watch"}>{change == null ? "Not enough baseline data" : `${change >= 0 ? "↑" : "↓"} ${Math.abs(change).toFixed(0)}% vs baseline`}</p>
    </article>
  );
}

function ComparisonCard({ label, trend, formatter, accent, invert = false }: { label: string; trend: MetricTrend | null; formatter: (value: number) => string; accent: string; invert?: boolean }) {
  const change = trend?.percentChange ?? null;
  const favorable = change != null && (invert ? change < 0 : change > 0);
  return (
    <article className={`comparison-card ${accent}`}>
      <span className="card-label">{label}</span>
      <strong>{trend?.current == null ? "—" : formatter(trend.current)}</strong>
      <div><span>Recent average</span><b>{trend?.baselineAverage == null ? "—" : formatter(trend.baselineAverage)}</b></div>
      <p className={change == null ? "neutral" : favorable ? "favorable" : "attention"}>{change == null ? "Waiting for comparison data" : `${change >= 0 ? "+" : ""}${change.toFixed(0)}% from baseline`}</p>
    </article>
  );
}

function TrendRows({ records, expanded = false }: { records: WellnessRecord[]; expanded?: boolean }) {
  const rows = [
    { label: "Sleep", key: "sleepMinutes" as const, color: "purple", max: 540 },
    { label: "Steps", key: "steps" as const, color: "green", max: 13_000 },
    { label: "Screen", key: "screenTimeMinutes" as const, color: "orange", max: 300 },
  ];
  return (
    <div className={expanded ? "trend-rows expanded" : "trend-rows"}>
      {rows.map((row) => (
        <div className="trend-row" key={row.key}>
          <span>{row.label}</span>
          <div className="spark-bars" aria-label={`${row.label} daily history`}>
            {records.map((record) => {
              const value = record[row.key];
              return <i key={record.date} className={`${row.color} ${value == null ? "missing" : ""}`} style={{ height: `${value == null ? 8 : Math.max(12, Math.min(100, value / row.max * 100))}%` }} title={`${formatDay(record.date)}: ${value ?? "missing"}`} />;
            })}
          </div>
          <b>{records.at(-1)?.[row.key] == null ? "—" : row.key === "steps" ? Math.round(records.at(-1)![row.key]!).toLocaleString("en-US") : formatDuration(records.at(-1)![row.key]!)}</b>
        </div>
      ))}
    </div>
  );
}

function ContextRow({ label, value, included = false }: { label: string; value: string; included?: boolean }) {
  return <div className="context-row"><span className={included ? "included" : "excluded"}>{included ? "✓" : "—"}</span><p><b>{label}</b><small>{value}</small></p></div>;
}

function Achievement({ label, icon, stars, color }: { label: string; icon: string; stars: number; color: string }) {
  return <article className="achievement-card"><span className={`metric-icon ${color}`}>{icon}</span><span><b>{label}</b><small>{stars} valid days</small></span><strong>★ {stars}</strong></article>;
}

function DataBoundary({ source }: { source: WellnessDataset["source"] }) {
  return <section className="data-boundary"><span>✓</span><p><b>{source === "sample" ? "You are exploring a guided sample." : "Your export was processed in this browser session."}</b> Raw HealthKit samples and app-level Screen Time details are not part of this web data package.</p></section>;
}

function ReportKpi({ label, value, change }: { label: string; value: string; change: number | null }) {
  return <div><span>{label}</span><b>{value}</b><small>{change == null ? "Aggregate value" : `${change >= 0 ? "+" : ""}${change.toFixed(0)}% vs baseline`}</small></div>;
}

function LogoFace() {
  return <span className="logo-face" aria-hidden="true"><i /><i /></span>;
}

function initials(name: string): string {
  return name.split(/\s+/).slice(0, 2).map((part) => part[0]?.toUpperCase()).join("") || "?";
}

function localLeagueKey(weekId: string): string {
  return `lessofaloser.local-league.${weekId}`;
}

function subscribeToLocalLeague(onStoreChange: () => void): () => void {
  window.addEventListener("storage", onStoreChange);
  window.addEventListener(localLeagueEvent, onStoreChange);
  return () => {
    window.removeEventListener("storage", onStoreChange);
    window.removeEventListener(localLeagueEvent, onStoreChange);
  };
}
