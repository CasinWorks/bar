import { useMemo, useState } from 'react';

const WEEKDAYS = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
const MONTHS = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

const TIME_PRESETS = [
  { label: '6:00 PM', value: '18:00' },
  { label: '7:00 PM', value: '19:00' },
  { label: '8:00 PM', value: '20:00' },
  { label: '9:00 PM', value: '21:00' },
  { label: '10:00 PM', value: '22:00' },
  { label: '11:00 PM', value: '23:00' },
  { label: '12:00 AM', value: '00:00' },
];

function pad(n) {
  return String(n).padStart(2, '0');
}

function toLocalDateValue(date) {
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`;
}

function toLocalDateTimeValue(date, time) {
  return `${toLocalDateValue(date)}T${time}`;
}

function parseValue(value) {
  if (!value) return { date: null, time: '20:00' };
  const [datePart, timePart] = value.split('T');
  const [y, m, d] = datePart.split('-').map(Number);
  return {
    date: new Date(y, m - 1, d),
    time: timePart?.slice(0, 5) || '20:00',
  };
}

function startOfDay(d) {
  return new Date(d.getFullYear(), d.getMonth(), d.getDate());
}

export default function EventDateTimePicker({
  value,
  onChange,
  required,
  timeLabel = 'Start time',
  allowPast = false,
  busyDates = [],
}) {
  const busySet = useMemo(
    () => new Set(Array.isArray(busyDates) ? busyDates : [...busyDates]),
    [busyDates],
  );
  const parsed = parseValue(value);
  const today = startOfDay(new Date());

  const [viewYear, setViewYear] = useState(
    () => (parsed.date ?? today).getFullYear(),
  );
  const [viewMonth, setViewMonth] = useState(
    () => (parsed.date ?? today).getMonth(),
  );

  const selectedDate = parsed.date;
  const selectedTime = parsed.time;

  const cells = useMemo(() => {
    const first = new Date(viewYear, viewMonth, 1);
    const daysInMonth = new Date(viewYear, viewMonth + 1, 0).getDate();
    const leading = first.getDay();
    const items = [];

    for (let i = 0; i < leading; i++) items.push(null);
    for (let day = 1; day <= daysInMonth; day++) {
      items.push(new Date(viewYear, viewMonth, day));
    }
    return items;
  }, [viewYear, viewMonth]);

  function emit(date, time) {
    if (!date) {
      onChange('');
      return;
    }
    onChange(toLocalDateTimeValue(date, time));
  }

  function pickDate(date) {
    if (!allowPast && startOfDay(date) < today) return;
    emit(date, selectedTime);
    setViewYear(date.getFullYear());
    setViewMonth(date.getMonth());
  }

  function pickTime(time) {
    if (!selectedDate) return;
    emit(selectedDate, time);
  }

  function shiftMonth(delta) {
    const next = new Date(viewYear, viewMonth + delta, 1);
    setViewYear(next.getFullYear());
    setViewMonth(next.getMonth());
  }

  const summary = selectedDate
    ? new Date(`${toLocalDateValue(selectedDate)}T${selectedTime}`).toLocaleString(undefined, {
        weekday: 'short',
        month: 'short',
        day: 'numeric',
        year: 'numeric',
        hour: 'numeric',
        minute: '2-digit',
      })
    : 'Pick a date from the calendar';

  return (
    <div className="event-datetime-picker">
      <input type="hidden" value={value} onChange={() => {}} />

      <div className="dtp-summary">{summary}</div>

      <div className="dtp-calendar">
        <div className="dtp-cal-header">
          <button type="button" className="dtp-nav" onClick={() => shiftMonth(-1)} aria-label="Previous month">
            ‹
          </button>
          <span className="dtp-month-label">
            {MONTHS[viewMonth]} {viewYear}
          </span>
          <button type="button" className="dtp-nav" onClick={() => shiftMonth(1)} aria-label="Next month">
            ›
          </button>
        </div>

        <div className="dtp-weekdays">
          {WEEKDAYS.map((d) => (
            <span key={d}>{d}</span>
          ))}
        </div>

        <div className="dtp-grid">
          {cells.map((date, i) => {
            if (!date) return <span key={`empty-${i}`} className="dtp-day empty" />;

            const isPast = !allowPast && startOfDay(date) < today;
            const isToday = startOfDay(date).getTime() === today.getTime();
            const isSelected =
              selectedDate &&
              startOfDay(date).getTime() === startOfDay(selectedDate).getTime();
            const dateKey = toLocalDateValue(date);
            const hasEvent = busySet.has(dateKey);

            return (
              <button
                key={date.toISOString()}
                type="button"
                title={hasEvent ? 'Event already booked this day' : undefined}
                className={[
                  'dtp-day',
                  isPast ? 'past' : '',
                  isToday ? 'today' : '',
                  isSelected ? 'selected' : '',
                  hasEvent ? 'busy' : '',
                ].filter(Boolean).join(' ')}
                disabled={isPast}
                onClick={() => pickDate(date)}
              >
                {date.getDate()}
                {hasEvent ? <span className="dtp-busy-dot" aria-hidden /> : null}
              </button>
            );
          })}
        </div>
      </div>

      <div className="dtp-time">
        <span className="dtp-time-label">{timeLabel}</span>
        <div className="dtp-time-presets">
          {TIME_PRESETS.map((preset) => (
            <button
              key={preset.value}
              type="button"
              className={`dtp-time-btn${selectedTime === preset.value ? ' selected' : ''}`}
              disabled={!selectedDate}
              onClick={() => pickTime(preset.value)}
            >
              {preset.label}
            </button>
          ))}
        </div>
        <label className="dtp-custom-time">
          Or custom
          <input
            type="time"
            value={selectedTime}
            disabled={!selectedDate}
            onChange={(e) => pickTime(e.target.value)}
          />
        </label>
      </div>
    </div>
  );
}
