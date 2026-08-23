export type WellnessGoals = {
  sleepMinutes: number;
  steps: number;
  screenTimeMinutes: number;
};

export type WellnessRecord = {
  date: string;
  sleepMinutes: number | null;
  steps: number | null;
  screenTimeMinutes: number | null;
  eveningScreenMinutes: number | null;
  dataCoverage: number;
};

export type WellnessDataset = {
  schemaVersion: 1;
  kind: "lessofaloser.wellness-export";
  generatedAt: string;
  records: WellnessRecord[];
  goals: WellnessGoals;
  source: "sample" | "iphone-export";
};

export type MetricTrend = {
  current: number | null;
  baselineAverage: number | null;
  percentChange: number | null;
};

export type TrendSummary = {
  date: string;
  sleep: MetricTrend;
  steps: MetricTrend;
  screenTime: MetricTrend;
  observations: string[];
  dataCoverage: number;
  baselineDayCount: number;
};

export type WeeklyScore = {
  weekId: string;
  stars: number;
  weeklyPoints: number;
  activeDays: number;
  streakDays: number;
  sleepStars: number;
  stepStars: number;
  screenStars: number;
};

const defaultGoals: WellnessGoals = {
  sleepMinutes: 420,
  steps: 8_000,
  screenTimeMinutes: 180,
};

const sampleAnchor = new Date("2026-08-23T12:00:00.000Z");
const sleepPattern = [438, 421, 405, 452, 410, 396, 443, 431, 418, 447, 402];
const stepPattern = [8_640, 9_830, 7_220, 10_480, 6_910, 8_240, 11_320, 7_880, 9_140];
const screenPattern = [172, 188, 211, 164, 198, 181, 155, 224, 176, 192];

function buildSampleRecords(): WellnessRecord[] {
  return Array.from({ length: 29 }, (_, index) => {
    const date = new Date(sampleAnchor);
    date.setUTCDate(date.getUTCDate() - (28 - index));
    const sleep = sleepPattern[index % sleepPattern.length] + (index % 4) * 3;
    const steps = stepPattern[index % stepPattern.length] + index * 37;
    const screen = screenPattern[index % screenPattern.length] + (index % 3) * 4;

    return {
      date: date.toISOString(),
      sleepMinutes: index === 5 ? null : sleep,
      steps: index === 12 ? null : steps,
      screenTimeMinutes: index === 2 || index === 19 ? null : screen,
      eveningScreenMinutes: index === 2 || index === 19 ? null : Math.round(screen * 0.34),
      dataCoverage: index === 5 || index === 12 ? 2 / 3 : index === 2 || index === 19 ? 2 / 3 : 1,
    };
  });
}

export const sampleDataset: WellnessDataset = {
  schemaVersion: 1,
  kind: "lessofaloser.wellness-export",
  generatedAt: sampleAnchor.toISOString(),
  records: buildSampleRecords(),
  goals: defaultGoals,
  source: "sample",
};

export function parseWellnessExport(text: string): WellnessDataset {
  let value: unknown;
  try {
    value = JSON.parse(text);
  } catch {
    throw new Error("That file is not valid JSON.");
  }

  if (!isObject(value)) throw new Error("The export must be a JSON object.");
  if (value.kind !== "lessofaloser.wellness-export") {
    throw new Error("This is not a LessOfALoser wellness export.");
  }
  if (value.schemaVersion !== 1) {
    throw new Error("This export version is not supported yet.");
  }
  if (!Array.isArray(value.records) || value.records.length === 0) {
    throw new Error("The export does not contain any daily records.");
  }
  if (value.records.length > 366) {
    throw new Error("For privacy and performance, import at most one year of daily records.");
  }

  const records = value.records.map((record, index) => parseRecord(record, index));
  const generatedAt = parseDate(value.generatedAt, "generatedAt");
  const goals = parseGoals(value.goals);

  return {
    schemaVersion: 1,
    kind: "lessofaloser.wellness-export",
    generatedAt,
    records: records.sort((a, b) => Date.parse(a.date) - Date.parse(b.date)),
    goals,
    source: "iphone-export",
  };
}

export function summarize(records: WellnessRecord[], baselineDays = 28): TrendSummary | null {
  const sorted = [...records].sort((a, b) => Date.parse(a.date) - Date.parse(b.date));
  const current = sorted.at(-1);
  if (!current) return null;
  const baseline = sorted.slice(0, -1).slice(-Math.max(1, baselineDays));
  const sleep = metricTrend(current.sleepMinutes, baseline.map((record) => record.sleepMinutes));
  const steps = metricTrend(current.steps, baseline.map((record) => record.steps));
  const screenTime = metricTrend(
    current.screenTimeMinutes,
    baseline.map((record) => record.screenTimeMinutes),
  );
  const observations = [
    metricObservation("Sleep", sleep, formatDuration),
    metricObservation("Steps", steps, (value) => Math.round(value).toLocaleString("en-US")),
    metricObservation("Screen time", screenTime, formatDuration),
  ].filter((observation): observation is string => Boolean(observation));

  return {
    date: current.date,
    sleep,
    steps,
    screenTime,
    observations: observations.length > 0
      ? observations
      : ["Not enough comparable data is available yet."],
    dataCoverage: current.dataCoverage,
    baselineDayCount: baseline.length,
  };
}

export function weeklyScore(records: WellnessRecord[], goals: WellnessGoals): WeeklyScore {
  const sorted = [...records].sort((a, b) => Date.parse(a.date) - Date.parse(b.date));
  const latest = new Date(sorted.at(-1)?.date ?? sampleAnchor);
  const weekStart = startOfUTCWeek(latest);
  const weekEnd = new Date(weekStart);
  weekEnd.setUTCDate(weekEnd.getUTCDate() + 7);
  const latestByDay = new Map<string, WellnessRecord>();

  for (const record of sorted) {
    const date = new Date(record.date);
    if (date >= weekStart && date < weekEnd) {
      latestByDay.set(date.toISOString().slice(0, 10), record);
    }
  }

  let sleepStars = 0;
  let stepStars = 0;
  let screenStars = 0;
  let activeDays = 0;
  for (const record of latestByDay.values()) {
    if ([record.sleepMinutes, record.steps, record.screenTimeMinutes].some((value) => value != null)) {
      activeDays += 1;
    }
    if (record.sleepMinutes != null && record.sleepMinutes >= goals.sleepMinutes) sleepStars += 1;
    if (record.steps != null && record.steps >= goals.steps) stepStars += 1;
    if (record.screenTimeMinutes != null && record.screenTimeMinutes <= goals.screenTimeMinutes) {
      screenStars += 1;
    }
  }

  const stars = sleepStars + stepStars + screenStars;
  return {
    weekId: isoWeekId(latest),
    stars,
    weeklyPoints: stars * 10,
    activeDays,
    streakDays: currentStreak(sorted, goals),
    sleepStars,
    stepStars,
    screenStars,
  };
}

export function answerInsightQuestion(question: string, summary: TrendSummary | null): string {
  if (!summary) return "There is not enough connected wellness data to answer that yet.";
  const normalized = question.toLocaleLowerCase();
  const match = normalized.match(/sleep|rest|bed/)
    ? summary.observations.find((item) => item.startsWith("Sleep"))
    : normalized.match(/step|walk|active|activity/)
      ? summary.observations.find((item) => item.startsWith("Steps"))
      : normalized.match(/screen|phone|scroll|device/)
        ? summary.observations.find((item) => item.startsWith("Screen time"))
        : summary.observations.slice(0, 3).join(" ");

  if (!match || match.startsWith("Not enough")) {
    return "The latest totals are available, but there is not enough comparable history for that pattern yet. Missing data stays unknown.";
  }
  return `${match} This is a comparison with your own recent baseline—not a diagnosis or a claim that one habit caused another.`;
}

export function formatDuration(value: number): string {
  const rounded = Math.round(value);
  return `${Math.floor(rounded / 60)}h ${rounded % 60}m`;
}

export function formatDay(value: string): string {
  return new Intl.DateTimeFormat("en-US", { month: "short", day: "numeric", timeZone: "UTC" })
    .format(new Date(value));
}

export function trendDirection(change: number | null): "up" | "down" | "flat" | "unknown" {
  if (change == null) return "unknown";
  if (Math.abs(change) < 1) return "flat";
  return change > 0 ? "up" : "down";
}

function parseRecord(value: unknown, index: number): WellnessRecord {
  if (!isObject(value)) throw new Error(`Daily record ${index + 1} is invalid.`);
  const date = parseDate(value.date, `records[${index}].date`);
  const sleepMinutes = optionalNumber(value.sleepMinutes, 0, 1_440, "sleepMinutes");
  const steps = optionalNumber(value.steps, 0, 500_000, "steps");
  const screenTimeMinutes = optionalNumber(
    value.screenTimeMinutes,
    0,
    1_440,
    "screenTimeMinutes",
  );
  const eveningScreenMinutes = optionalNumber(
    value.eveningScreenMinutes,
    0,
    1_440,
    "eveningScreenMinutes",
  );
  const coverage = optionalNumber(value.dataCoverage, 0, 1, "dataCoverage");
  const available = [sleepMinutes, steps, screenTimeMinutes].filter((item) => item != null).length;

  return {
    date,
    sleepMinutes,
    steps,
    screenTimeMinutes,
    eveningScreenMinutes,
    dataCoverage: coverage ?? available / 3,
  };
}

function parseGoals(value: unknown): WellnessGoals {
  if (!isObject(value)) return defaultGoals;
  return {
    sleepMinutes: requiredNumber(value.sleepMinutes, 60, 900, "goals.sleepMinutes"),
    steps: requiredNumber(value.steps, 100, 100_000, "goals.steps"),
    screenTimeMinutes: requiredNumber(
      value.screenTimeMinutes,
      0,
      1_440,
      "goals.screenTimeMinutes",
    ),
  };
}

function metricTrend(current: number | null, candidates: Array<number | null>): MetricTrend {
  const baseline = candidates.filter((value): value is number => value != null);
  const baselineAverage = baseline.length > 0
    ? baseline.reduce((total, value) => total + value, 0) / baseline.length
    : null;
  const percentChange = current != null && baselineAverage != null && baselineAverage > 0
    ? ((current - baselineAverage) / baselineAverage) * 100
    : null;
  return { current, baselineAverage, percentChange };
}

function metricObservation(
  name: string,
  trend: MetricTrend,
  formatter: (value: number) => string,
): string | null {
  if (trend.current == null || trend.baselineAverage == null || trend.percentChange == null) return null;
  const direction = trend.percentChange >= 0 ? "above" : "below";
  return `${name} was ${formatter(trend.current)}, ${Math.round(Math.abs(trend.percentChange))}% ${direction} the recent average of ${formatter(trend.baselineAverage)}.`;
}

function currentStreak(records: WellnessRecord[], goals: WellnessGoals): number {
  const latestByDay = new Map<string, WellnessRecord>();
  for (const record of records) latestByDay.set(record.date.slice(0, 10), record);
  const days = [...latestByDay.keys()].sort().reverse();
  let streak = 0;
  for (const day of days) {
    const record = latestByDay.get(day);
    if (!record) break;
    const earned = (record.sleepMinutes != null && record.sleepMinutes >= goals.sleepMinutes)
      || (record.steps != null && record.steps >= goals.steps)
      || (record.screenTimeMinutes != null && record.screenTimeMinutes <= goals.screenTimeMinutes);
    if (!earned) break;
    streak += 1;
  }
  return streak;
}

function startOfUTCWeek(date: Date): Date {
  const start = new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()));
  const day = start.getUTCDay() || 7;
  start.setUTCDate(start.getUTCDate() - day + 1);
  return start;
}

function isoWeekId(date: Date): string {
  const target = new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()));
  const day = target.getUTCDay() || 7;
  target.setUTCDate(target.getUTCDate() + 4 - day);
  const first = new Date(Date.UTC(target.getUTCFullYear(), 0, 1));
  const week = Math.ceil((((target.getTime() - first.getTime()) / 86_400_000) + 1) / 7);
  return `${target.getUTCFullYear()}-W${String(week).padStart(2, "0")}`;
}

function optionalNumber(
  value: unknown,
  minimum: number,
  maximum: number,
  field: string,
): number | null {
  if (value == null) return null;
  return requiredNumber(value, minimum, maximum, field);
}

function requiredNumber(value: unknown, minimum: number, maximum: number, field: string): number {
  if (typeof value !== "number" || !Number.isFinite(value) || value < minimum || value > maximum) {
    throw new Error(`${field} is outside the supported range.`);
  }
  return value;
}

function parseDate(value: unknown, field: string): string {
  if (typeof value !== "string" || !Number.isFinite(Date.parse(value))) {
    throw new Error(`${field} is not a valid date.`);
  }
  return new Date(value).toISOString();
}

function isObject(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
