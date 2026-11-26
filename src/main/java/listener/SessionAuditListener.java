package listener;

import jakarta.servlet.ServletContextEvent;
import jakarta.servlet.ServletContextListener;
import jakarta.servlet.annotation.WebListener;
import jakarta.servlet.http.HttpSessionEvent;
import jakarta.servlet.http.HttpSessionListener;
import service.AuditSchema;
import service.AuditService;
import service.SystemSettingsService;

/**
 * - creates tables / default settings at startup
 * - applies the configured session timeout to every new session
 * - records SESSION_EXPIRED when a session ends without an explicit logout
 * - flushes queued audit writes at shutdown
 */
@WebListener
public class SessionAuditListener implements ServletContextListener, HttpSessionListener {

    @Override
    public void contextInitialized(ServletContextEvent sce) {
        try {
            AuditSchema.ensure();
            SystemSettingsService.ensureDefaults();
        } catch (Exception e) {
            System.err.println("[Audit] startup initialisation failed: " + e.getMessage());
        }
    }

    @Override
    public void contextDestroyed(ServletContextEvent sce) {
        AuditService.shutdown();
    }

    @Override
    public void sessionCreated(HttpSessionEvent se) {
        int minutes = SystemSettingsService.getInt("session_timeout_minutes", 30);
        se.getSession().setMaxInactiveInterval(minutes * 60);
    }

    @Override
    public void sessionDestroyed(HttpSessionEvent se) {
        AuditService.recordSessionExpired(se.getSession());
    }
}
