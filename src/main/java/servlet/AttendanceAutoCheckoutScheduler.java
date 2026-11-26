package servlet;

import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;

import jakarta.servlet.ServletContextEvent;
import jakarta.servlet.ServletContextListener;
import jakarta.servlet.annotation.WebListener;

import service.AttendanceAutoCheckout;

/**
 * Starts the automatic 6:10 PM check-out (see service.AttendanceAutoCheckout).
 * Runs every minute while the server is up, so anyone still checked in
 * (employee, manager or HR) is checked out at 6:10 PM without doing anything.
 * Employees with an APPROVED overtime are checked out at 6:10 PM + the OT hours.
 */
@WebListener
public class AttendanceAutoCheckoutScheduler implements ServletContextListener {

    private ScheduledExecutorService scheduler;

    @Override
    public void contextInitialized(ServletContextEvent event) {

        scheduler = Executors.newSingleThreadScheduledExecutor(r -> {
            Thread t = new Thread(r, "attendance-auto-checkout");
            t.setDaemon(true);
            return t;
        });

        scheduler.scheduleWithFixedDelay(() -> {
            try {
                int[] done = AttendanceAutoCheckout.runOnce();

                if (done[0] + done[1] > 0) {
                    System.out.println("[auto-checkout] checked out automatically ("
                            + AttendanceAutoCheckout.CUTOFF + " or approved OT time): "
                            + done[0] + " employee/manager, " + done[1] + " HR.");
                }
            } catch (Throwable e) {
                e.printStackTrace(); // never let the schedule die
            }
        }, 20, 60, TimeUnit.SECONDS);
    }

    @Override
    public void contextDestroyed(ServletContextEvent event) {
        if (scheduler != null) {
            scheduler.shutdownNow();
        }
    }
}
