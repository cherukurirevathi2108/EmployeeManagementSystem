package servlet;

import java.time.LocalDateTime;
import java.time.LocalTime;
import java.time.YearMonth;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;

import jakarta.servlet.ServletContextEvent;
import jakarta.servlet.ServletContextListener;
import jakarta.servlet.annotation.WebListener;

import DAO.PayrollSettingsDAO;
import service.PayrollService;

/**
 * Automatic payroll on the schedule saved in the Payroll Hub (pay day of the
 * month + run time). Checks every minute: once the pay day and time of the
 * current month have arrived and the month has not been run yet, salary is
 * generated and PAID for everybody whose salary structure was saved before
 * this month. If the server was off at that time, it runs as soon as the
 * server is back. A pay day beyond the month's length (31 in November) runs on
 * the last day. Existing payrolls are never duplicated.
 */
@WebListener
public class PayrollScheduler implements ServletContextListener {

    private ScheduledExecutorService scheduler;

    @Override
    public void contextInitialized(ServletContextEvent event) {

        scheduler = Executors.newSingleThreadScheduledExecutor(r -> {
            Thread t = new Thread(r, "payroll-auto-schedule");
            t.setDaemon(true);
            return t;
        });

        scheduler.scheduleWithFixedDelay(() -> {
            try {
                runIfDue();
            } catch (Throwable e) {
                e.printStackTrace(); // never let the schedule die
            }

            // email any PAID salary slip that has not been emailed yet
            service.SalarySlipMailer.sendPending(20);
        }, 30, 60, TimeUnit.SECONDS);
    }

    private void runIfDue() throws Exception {

        PayrollSettingsDAO dao = new PayrollSettingsDAO();
        PayrollSettingsDAO.Settings s = dao.get();

        if (!s.enabled) {
            return;
        }

        YearMonth ym = YearMonth.now();

        if (ym.toString().equals(s.lastRunMonth)) {
            return; // this month is already done
        }

        int day = Math.min(s.payDay, ym.lengthOfMonth());
        LocalDateTime due = ym.atDay(day).atTime(LocalTime.of(s.runHour, 0));

        if (LocalDateTime.now().isBefore(due)) {
            return;
        }

        PayrollService.BatchResult r = new PayrollService().autoGenerate();

        dao.markRun(ym.toString(),
                "Paid " + r.generated + " salary(ies); " + r.alreadyFinal + " already paid; "
                + r.noStructure + " without salary structure; " + r.failed + " failed.");
    }

    @Override
    public void contextDestroyed(ServletContextEvent event) {
        if (scheduler != null) {
            scheduler.shutdownNow();
        }
    }
}
