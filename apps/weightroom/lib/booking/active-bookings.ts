import type { BookingWeekAvailability } from "@/lib/booking/availability";

export type ActiveBooking = {
  bookingKey: string;
  date: Date;
  timeRange: string;
  status: "reserved" | "confirmed";
  isConfirmationAvailable: boolean;
  isCancellationLocked: boolean;
};

const SANTIAGO_DATE_TIME_FORMATTER = new Intl.DateTimeFormat("en-CA", {
  timeZone: "America/Santiago",
  year: "numeric",
  month: "2-digit",
  day: "2-digit",
  hour: "2-digit",
  minute: "2-digit",
  hourCycle: "h23",
});

type SantiagoDateTime = {
  dateKey: string;
  minutes: number;
};

function getDatePart(
  parts: Intl.DateTimeFormatPart[],
  type: "day" | "month" | "year" | "hour" | "minute",
) {
  const part = parts.find((candidate) => candidate.type === type);
  if (!part) throw new Error(`Missing ${type} from Santiago date.`);

  return Number(part.value);
}

function getSantiagoDateTime(): SantiagoDateTime {
  const parts = SANTIAGO_DATE_TIME_FORMATTER.formatToParts(new Date());
  const year = getDatePart(parts, "year");
  const month = getDatePart(parts, "month");
  const day = getDatePart(parts, "day");
  const hour = getDatePart(parts, "hour");
  const minute = getDatePart(parts, "minute");

  return {
    dateKey: `${year}-${String(month).padStart(2, "0")}-${String(day).padStart(2, "0")}`,
    minutes: hour * 60 + minute,
  };
}

function getWeekStartDateKey(dateKey: string): string {
  const [yearText, monthText, dayText] = dateKey.split("-");
  if (!yearText || !monthText || !dayText) throw new Error("Invalid booking date.");

  const date = new Date(Number(yearText), Number(monthText) - 1, Number(dayText));
  const dayOfWeek = date.getDay();
  const daysFromMonday = dayOfWeek === 0 ? 6 : dayOfWeek - 1;
  date.setDate(date.getDate() - daysFromMonday);

  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, "0")}-${String(
    date.getDate(),
  ).padStart(2, "0")}`;
}

function getFollowingWeekStartDateKey(weekStartDateKey: string): string {
  const [yearText, monthText, dayText] = weekStartDateKey.split("-");
  if (!yearText || !monthText || !dayText) throw new Error("Invalid week start date.");

  const date = new Date(Number(yearText), Number(monthText) - 1, Number(dayText));
  date.setDate(date.getDate() + 7);

  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, "0")}-${String(
    date.getDate(),
  ).padStart(2, "0")}`;
}

function parseBookingDate(dateKey: string): Date {
  const [yearText, monthText, dayText] = dateKey.split("-");
  if (!yearText || !monthText || !dayText) throw new Error("Invalid booking date.");

  return new Date(Number(yearText), Number(monthText) - 1, Number(dayText));
}

function getTimeMinutes(time: string): number {
  const [hoursText, minutesText] = time.split(":");
  if (!hoursText || !minutesText) throw new Error("Invalid time block boundary.");

  return Number(hoursText) * 60 + Number(minutesText);
}

export function getActiveBookingWeekStarts(): [string, string] {
  const currentWeekStart = getWeekStartDateKey(getSantiagoDateTime().dateKey);
  return [currentWeekStart, getFollowingWeekStartDateKey(currentWeekStart)];
}

export function createActiveBookings(availability: BookingWeekAvailability): ActiveBooking[] {
  const now = getSantiagoDateTime();
  const activeBookings: ActiveBooking[] = [];

  for (const cell of availability) {
    if (
      cell.booking_date < now.dateKey ||
      cell.current_booking_id === null ||
      cell.current_booking_is_overcapacity ||
      (cell.current_booking_status !== "reserved" && cell.current_booking_status !== "confirmed")
    ) {
      continue;
    }

    const startMinutes = getTimeMinutes(cell.time_block_t0);
    const isToday = cell.booking_date === now.dateKey;
    const isConfirmationAvailable =
      cell.current_booking_status === "reserved" &&
      isToday &&
      now.minutes >= startMinutes - 4 * 60 &&
      now.minutes < startMinutes - 60;
    const isCancellationLocked =
      cell.current_booking_status === "confirmed" &&
      isToday &&
      now.minutes >= startMinutes - 60 &&
      now.minutes < startMinutes;

    activeBookings.push({
      bookingKey: cell.current_booking_id,
      date: parseBookingDate(cell.booking_date),
      timeRange: `${cell.time_block_t0.slice(0, 5)}-${cell.time_block_t1.slice(0, 5)}`,
      status: cell.current_booking_status,
      isConfirmationAvailable,
      isCancellationLocked,
    });
  }

  return activeBookings
    .sort((left, right) => left.date.getTime() - right.date.getTime())
    .slice(0, 7);
}
