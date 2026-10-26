import type { AppStatistics } from "@/lib/statistics";

const PREVIEW_MONTH_COUNT = 6;
const WEEKDAY_OCCUPANCY = [72, 94, 61, 111, 83] as const;
const WEEKDAY_AVERAGES = [27.8, 32.4, 24.1, 36.7, 29.3] as const;
const PREVIEW_USERS = [
  ["Camila Rojas", 19, 86],
  ["Matías Soto", 16, 104],
  ["Daniela Vera", 16, 97],
  ["Tomás Fuentes", 13, 76],
  ["Antonia Silva", 12, 89],
  ["Nicolás Torres", 10, 71],
  ["Valentina Díaz", 9, 68],
  ["Benjamín Morales", 8, 63],
  ["Florencia Pérez", 7, 54],
  ["Ignacio Castro", 6, 51],
] as const;

function getSantiagoDateKey() {
  const parts = new Intl.DateTimeFormat("en-CA", {
    day: "2-digit",
    month: "2-digit",
    timeZone: "America/Santiago",
    year: "numeric",
  }).formatToParts(new Date());
  const day = parts.find((part) => part.type === "day")?.value;
  const month = parts.find((part) => part.type === "month")?.value;
  const year = parts.find((part) => part.type === "year")?.value;

  if (!day || !month || !year) throw new Error("Preview date could not be formatted.");

  return `${year}-${month}-${day}`;
}

function createUtcDate(dateKey: string) {
  const [yearText, monthText, dayText] = dateKey.split("-");
  return new Date(Date.UTC(Number(yearText), Number(monthText) - 1, Number(dayText)));
}

function getDateKey(date: Date) {
  return `${date.getUTCFullYear()}-${String(date.getUTCMonth() + 1).padStart(2, "0")}-${String(
    date.getUTCDate(),
  ).padStart(2, "0")}`;
}

function addDays(dateKey: string, dayCount: number) {
  const date = createUtcDate(dateKey);
  date.setUTCDate(date.getUTCDate() + dayCount);
  return getDateKey(date);
}

function getIsoWeekday(dateKey: string) {
  const sundayFirstWeekday = createUtcDate(dateKey).getUTCDay();
  return sundayFirstWeekday === 0 ? 7 : sundayFirstWeekday;
}

function getMonthKeys(today: string) {
  const date = createUtcDate(today);
  const monthKeys: string[] = [];

  for (let offset = PREVIEW_MONTH_COUNT - 1; offset >= 0; offset -= 1) {
    const month = new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth() - offset, 1));
    monthKeys.push(`${month.getUTCFullYear()}-${String(month.getUTCMonth() + 1).padStart(2, "0")}`);
  }

  return monthKeys;
}

function createDailyStatistics(startDate: string, endDate: string) {
  const daily: AppStatistics["daily"] = [];

  for (let dateKey = startDate, dayIndex = 0; dateKey <= endDate; dateKey = addDays(dateKey, 1)) {
    const weekday = getIsoWeekday(dateKey);
    const isOperatingDay = weekday <= 5;
    const base = 17 + ((dayIndex * 11 + weekday * 7) % 34);
    const attendees = isOperatingDay ? base : 0;

    daily.push({
      absences: isOperatingDay ? (dayIndex % 9 === 0 ? 3 : dayIndex % 5 === 0 ? 1 : 0) : 0,
      attendees,
      bookings: isOperatingDay ? attendees + 3 + (dayIndex % 8) : 0,
      capacity: isOperatingDay ? 135 : 0,
      date: dateKey,
    });
    dayIndex += 1;
  }

  return daily;
}

/** Local-only fixture for visual review. It never reaches /api/statistics or Supabase. */
export function getStatisticsPreview(): AppStatistics {
  const today = getSantiagoDateKey();
  const monthKeys = getMonthKeys(today);
  const startDate = `${monthKeys[0]}-01`;
  const currentMonday = addDays(today, 1 - getIsoWeekday(today));
  const daily = createDailyStatistics(startDate, today);

  return {
    activeParticipants: 184,
    attendanceRate: 86,
    attendances: 2_438,
    bookings: 2_835,
    daily,
    historyStartDate: startDate,
    monthly: monthKeys.map((month, index) => ({
      absences: 16 + ((index * 5 + 3) % 14),
      attendees: 314 + index * 27 + (index % 2) * 18,
      bookings: 362 + index * 29 + (index % 3) * 14,
      month,
    })),
    registeredParticipants: 216,
    topStreakUsers: PREVIEW_USERS.map(([userName, streakWeeks, totalAttendances]) => ({
      streakWeeks,
      totalAttendances,
      userName,
    })).sort((first, second) => {
      if (second.totalAttendances !== first.totalAttendances) {
        return second.totalAttendances - first.totalAttendances;
      }
      return second.streakWeeks - first.streakWeeks;
    }),
    weekdayAttendance: WEEKDAY_AVERAGES.map((average, index) => ({
      average,
      weekday: index + 1,
    })),
    weeklyOccupancy: WEEKDAY_OCCUPANCY.map((occupied, index) => {
      const date = addDays(currentMonday, index);
      const state = date < today ? "past" : date === today ? "current" : "future";

      return {
        capacity: 135,
        date,
        occupied,
        state,
        weekday: index + 1,
      };
    }),
  };
}
