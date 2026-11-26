package service;

import java.sql.Connection;
import java.sql.Date;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.Time;
import java.sql.Statement;
import java.time.Duration;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import model.DBcConnection;

/**
 * Automatic check-out for employees, managers and HR.
 *
 * Anyone who has checked in but not checked out is checked out automatically
 * at CUTOFF (6:10 PM): check_out_time is saved as 18:10:00, the attendance
 * status is worked out with the SAME rule as the manual Check Out button
 * (8 h or more = PRESENT, more than 4 h = HALF DAY, otherwise ABSENT) and a
 * break that is still running is ended at 18:10 as well.
 *
 * Tables:  employees + managers -> attendance / breaks
 *          HR                   -> hr_attendance / hr_breaks
 *
 * It is started every minute by AttendanceAutoCheckoutScheduler. If the server
 * was off at 6:10 PM, the next run still saves 18:10 as the check-out time
 * (also for earlier days that were left open). Overtime: if the manager has
 * APPROVED an overtime request (see OvertimeService) for that day, the person is NOT
 * checked out at 6:10 PM but at 6:10 PM + the approved OT hours (e.g. 8:10 PM for
 * 2 h). Someone who checks in after
 * 6:10 PM is not touched. Date and time comparisons use the database clock
 * (CURDATE / CURTIME), the same clock that stamps the check-in.
 */
public final class AttendanceAutoCheckout {

    /** Everybody still checked in at this time is checked out automatically. */
    public static final LocalTime CUTOFF = LocalTime.of(18, 10);

    private AttendanceAutoCheckout() { }

    /** Same thresholds as the Check Out button on the dashboards. */
    static String statusFor(LocalTime checkIn) {
        return statusFor(checkIn, CUTOFF);
    }

    /** Status for any check-out time (used for the overtime check-out too). */
    static String statusFor(LocalTime checkIn, LocalTime checkOut) {

        long worked = Duration.between(checkIn, checkOut).toMinutes();

        if (worked >= 480) return "PRESENT";
        if (worked > 240) return "HALF DAY";
        return "ABSENT";
    }

    /**
     * Checks out everybody who is due.
     *
     * @return {employees + managers checked out, HR checked out}
     */
    public static synchronized int[] runOnce() {

        OvertimeService.ensureSchema(); // makes sure ot_requests exists

        // people with an approved overtime are not closed at 6:10 PM ...
        Map<String, java.math.BigDecimal> overtime = approvedOvertime();

        int people = closeOpen("attendance", "employee_id", "date",
                               "breaks", "employee_id", "break_date", overtime);

        // ... they are closed at 6:10 PM + approved OT hours
        people += closeOvertime();

        int hr = 0;

        try {
            HrSchema.ensure(); // makes sure hr_attendance / hr_breaks exist
            hr = closeOpen("hr_attendance", "hr_id", "att_date",
                           "hr_breaks", "hr_id", "break_date",
                           new HashMap<String, java.math.BigDecimal>());
        } catch (Throwable t) {
            t.printStackTrace();
        }

        return new int[] { people, hr };
    }

    /** key "employeeId|yyyy-MM-dd" -> approved OT hours (until today). */
    private static Map<String, java.math.BigDecimal> approvedOvertime() {

        Map<String, java.math.BigDecimal> map = new HashMap<String, java.math.BigDecimal>();

        try (Connection con = DBcConnection.getConnection()) {

            if (con == null) {
                return map;
            }

            try (PreparedStatement ps = con.prepareStatement(
                    "SELECT employee_id, ot_date, ot_hours FROM ot_requests "
                    + "WHERE status = 'APPROVED' AND ot_date <= CURDATE()");
                 ResultSet rs = ps.executeQuery()) {

                while (rs.next()) {
                    map.put(rs.getString(1) + "|" + rs.getDate(2), rs.getBigDecimal(3));
                }
            }

        } catch (Exception e) {
            e.printStackTrace();
        }

        return map;
    }

    /**
     * Checks out the people who are still checked in although their overtime is
     * approved: check-out = 6:10 PM + approved hours (today only once that time
     * has arrived; earlier days at once).
     */
    private static int closeOvertime() {

        int closed = 0;

        try (Connection con = DBcConnection.getConnection()) {

            if (con == null) {
                return 0;
            }

            LocalDate today = LocalDate.now();
            LocalTime now = LocalTime.now();

            try (Statement st = con.createStatement();
                 ResultSet rs = st.executeQuery("SELECT CURDATE(), CURTIME()")) {
                if (rs.next()) {
                    today = rs.getDate(1).toLocalDate();
                    now = rs.getTime(2).toLocalTime();
                }
            }

            List<Object[]> approved = new ArrayList<Object[]>();

            try (PreparedStatement ps = con.prepareStatement(
                    "SELECT employee_id, ot_date, ot_hours FROM ot_requests "
                    + "WHERE status = 'APPROVED' AND ot_date <= CURDATE()");
                 ResultSet rs = ps.executeQuery()) {

                while (rs.next()) {
                    approved.add(new Object[] { rs.getString(1), rs.getDate(2), rs.getBigDecimal(3) });
                }
            }

            for (Object[] row : approved) {

                String id = (String) row[0];
                Date day = (Date) row[1];
                LocalTime out = OvertimeService.checkOutFor((java.math.BigDecimal) row[2]);

                if (day.toLocalDate().equals(today) && now.isBefore(out)) {
                    continue; // the overtime is not over yet
                }

                Time checkIn = null;
                boolean open = false;

                try (PreparedStatement ps = con.prepareStatement(
                        "SELECT check_in_time, check_out_time FROM attendance "
                        + "WHERE employee_id = ? AND date = ?")) {
                    ps.setString(1, id);
                    ps.setDate(2, day);
                    try (ResultSet rs = ps.executeQuery()) {
                        if (rs.next()) {
                            checkIn = rs.getTime(1);
                            open = rs.getTime(2) == null;
                        }
                    }
                }

                if (checkIn == null || !open || !checkIn.toLocalTime().isBefore(CUTOFF)) {
                    continue;
                }

                if (OvertimeService.writeCheckOut(con, id, day.toLocalDate(),
                                                  checkIn.toLocalTime(), out)) {
                    closed++;
                }
            }

        } catch (Exception e) {
            e.printStackTrace();
        }

        return closed;
    }

    /**
     * Table and column names are fixed strings from this class (never user input).
     */
    private static int closeOpen(String attTable, String idCol, String dateCol,
                                 String breakTable, String breakIdCol, String breakDateCol,
                                 Map<String, java.math.BigDecimal> skip) {

        int closed = 0;
        Time cutoff = Time.valueOf(CUTOFF);

        // checked in before the cut-off, not checked out, and the cut-off has
        // passed (an earlier day, or today after 18:10)
        String select =
                "SELECT " + idCol + ", " + dateCol + ", check_in_time FROM " + attTable + " "
                + "WHERE check_in_time IS NOT NULL AND check_out_time IS NULL "
                + "AND check_in_time < ? "
                + "AND (" + dateCol + " < CURDATE() "
                + "OR (" + dateCol + " = CURDATE() AND CURTIME() >= ?))";

        String update =
                "UPDATE " + attTable + " SET check_out_time = ?, status = ? "
                + "WHERE " + idCol + " = ? AND " + dateCol + " = ? "
                + "AND check_out_time IS NULL";   // never overwrite a manual check-out

        String endBreaks =
                "UPDATE " + breakTable + " SET break_end = ? "
                + "WHERE " + breakIdCol + " = ? AND " + breakDateCol + " = ? "
                + "AND break_end IS NULL AND break_start <= ?";

        try (Connection con = DBcConnection.getConnection()) {

            if (con == null) {
                return 0;
            }

            List<Object[]> due = new ArrayList<Object[]>();

            try (PreparedStatement ps = con.prepareStatement(select)) {
                ps.setTime(1, cutoff);
                ps.setTime(2, cutoff);

                try (ResultSet rs = ps.executeQuery()) {
                    while (rs.next()) {
                        due.add(new Object[] { rs.getString(1), rs.getDate(2), rs.getTime(3) });
                    }
                }
            }

            for (Object[] row : due) {

                String id = (String) row[0];
                Date day = (Date) row[1];
                Time checkIn = (Time) row[2];

                if (skip.containsKey(id + "|" + day)) {
                    continue; // approved overtime: closed later by closeOvertime()
                }

                int changed;

                try (PreparedStatement ps = con.prepareStatement(update)) {
                    ps.setTime(1, cutoff);
                    ps.setString(2, statusFor(checkIn.toLocalTime()));
                    ps.setString(3, id);
                    ps.setDate(4, day);
                    changed = ps.executeUpdate();
                }

                if (changed > 0) {
                    closed++;

                    try (PreparedStatement ps = con.prepareStatement(endBreaks)) {
                        ps.setTime(1, cutoff);
                        ps.setString(2, id);
                        ps.setDate(3, day);
                        ps.setTime(4, cutoff);
                        ps.executeUpdate();
                    }
                }
            }

        } catch (Exception e) {
            e.printStackTrace();
        }

        return closed;
    }
}
